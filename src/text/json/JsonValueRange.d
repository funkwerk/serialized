/**
 * This module takes a `std.json` JSONValue and generates a `stdx.data.json` token stream.
 * It provides Phobos backwards compatibility for `std_data_json`.
 */
module text.json.JsonValueRange;

import funkwerk.stdx.data.json.lexer;
import funkwerk.stdx.data.json.parser;
import std.algorithm : count;
import std.json;
import std.range : drop;

static assert(isJSONParserNodeInputRange!JsonValueRange);

struct JsonValueRange
{
    public bool empty;

    private JSONParserNode!string currentValue;

    private ValueIterator[] iterators;

    // Authoritative version of this.iterators[this.level].
    // Pulled out of `iterators` to ensure that "auto foo = jsonValueRange;" duplicates its state.
    // This allows us to be dup-less.
    // For the complete rationale for this, see doc/why-we-dont-need-save.md
    private ValueIterator current;

    private int level;

    invariant(this.level < cast(int) this.iterators.length);

    public this(JSONValue value)
    {
        this.empty = false;
        this.level = -1;
        stepInto(value);
    }

    public @property ref JSONParserNode!string front() return
    in (!empty)
    {
        return this.currentValue;
    }

    private void stepInto(JSONValue value)
    {
        alias Token = JSONToken!string;

        with (JSONType) final switch (value.type)
        {
            case null_:
                this.currentValue.literal = Token(null);
                break;
            case string:
                this.currentValue.literal = Token(value.str);
                break;
            case integer:
                this.currentValue.literal = Token(value.integer);
                break;
            case uinteger:
                this.currentValue.literal = Token(value.uinteger);
                break;
            case float_:
                this.currentValue.literal = Token(value.floating);
                break;
            case array:
                this.currentValue.kind = JSONParserNodeKind.arrayStart;
                pushState(value);
                break;
            case object:
                this.currentValue.kind = JSONParserNodeKind.objectStart;
                pushState(value);
                break;
            case true_:
                this.currentValue.literal = Token(true);
                break;
            case false_:
                this.currentValue.literal = Token(false);
                break;
        }
    }

    private void pushState(JSONValue value)
    {
        if (this.level != -1)
        {
            this.iterators[this.level] = this.current;
        }
        this.current = ValueIterator(value);
        this.level++;
        if (this.level == this.iterators.length)
        {
            this.iterators ~= this.current;
        }
        else
        {
            this.iterators[this.level] = this.current;
        }
    }

    public void popFront()
    in (!empty)
    {
        if (outOfValues)
        {
            empty = true;
            return;
        }

        if (current.value.type == JSONType.object)
        {
            if (current.nextIndex == current.value.objectNoRef.length)
            {
                this.currentValue.kind = JSONParserNodeKind.objectEnd;
                popState;
                return;
            }

            if (!current.usedKey)
            {
                this.currentValue.key = current.value.objectNoRef.byKeyValue.drop(current.nextIndex).front.key;
                current.usedKey = true;
                return;
            }

            auto value = current.value.objectNoRef.byKeyValue.drop(current.nextIndex).front.value;

            current.usedKey = false;
            current.nextIndex++;
            stepInto(value);
            return;
        }
        else if (current.value.type == JSONType.array)
        {
            if (current.nextIndex == current.value.arrayNoRef.length)
            {
                this.currentValue.kind = JSONParserNodeKind.arrayEnd;
                popState;
                return;
            }
            stepInto(current.value.arrayNoRef[current.nextIndex++]);
        }
        else
        {
            assert(false, "unexpected value type");
        }
    }

    private void popState()
    {
        this.level--;
        if (!outOfValues)
        {
            this.current = this.iterators[this.level];
        }
    }

    public bool outOfValues() const
    {
        return this.level == -1;
    }
}

private struct ValueIterator
{
    JSONValue value;

    invariant(value.type == JSONType.array || value.type == JSONType.object);

    // if `value` is an array or object, indicates the next element to be selected.
    size_t nextIndex = 0;

    bool usedKey; // objects are key, value, key, value => false, true, false, true...
}
