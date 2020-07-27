/**
 * This module takes a `std.json` JSONValue and generates a `stdx.data.json` token stream.
 * It provides Phobos backwards compatibility for `std_data_json`.
 */
module text.json.JsonValueRange;

import std.algorithm : count;
import std.json;
import std.range : drop;
import stdx.data.json.lexer;
import stdx.data.json.parser;

static assert(isJSONParserNodeInputRange!JsonValueRange);

struct JsonValueRange
{
    public JSONParserNode!string front;

    public bool empty;

    private ValueIterator[] iterators;

    private int level;

    invariant(this.level < cast(int) this.iterators.length);

    public this(JSONValue value)
    {
        this.empty = false;
        this.level = -1;
        stepInto(value);
    }

    private void stepInto(JSONValue value)
    {
        alias Token = JSONToken!string;

        with (JSONType) final switch (value.type)
        {
            case null_:
                this.front.literal = Token(null);
                break;
            case string:
                this.front.literal = Token(value.str);
                break;
            case integer:
                this.front.literal = Token(value.integer);
                break;
            case uinteger:
                this.front.literal = Token(value.uinteger);
                break;
            case float_:
                this.front.literal = Token(value.floating);
                break;
            case array:
                this.front.kind = JSONParserNodeKind.arrayStart;
                pushState(value);
                break;
            case object:
                this.front.kind = JSONParserNodeKind.objectStart;
                pushState(value);
                break;
            case true_:
                this.front.literal = Token(true);
                break;
            case false_:
                this.front.literal = Token(false);
                break;
        }
    }

    private void pushState(JSONValue value)
    {
        if (this.level + 1 == this.iterators.length)
        {
            this.iterators ~= ValueIterator(value);
        }
        else
        {
            this.iterators[this.level + 1] = ValueIterator(value);
        }
        this.level++;
    }

    public void popFront()
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
                this.front.kind = JSONParserNodeKind.objectEnd;
                popState;
                return;
            }

            if (!current.usedKey)
            {
                this.front.key = current.value.objectNoRef.byKeyValue.drop(current.nextIndex).front.key;
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
                this.front.kind = JSONParserNodeKind.arrayEnd;
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
    }

    private ref ValueIterator current()
    in (!outOfValues)
    {
        return this.iterators[this.level];
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
