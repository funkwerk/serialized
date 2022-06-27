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

    private JSONParserNode currentValue;

    private ValueIterator[] iterators;

    /**
     * In order to allow us to be save()-less, it is not enough to just have the current iterator as array state!
     * Consider the following case: [ A, B ], where A and B are objects.
     * When decoding A, we are set to objectStart, but the current iterator is already A: that is, the iteration
     * state on the level of [] is the previous state and thus must be saved also.
     * Otherwise, when we finish parsing A, we will *consume* objectEnd and position ourselves at objectStart
     * for B, advancing the state for the array iterator - which is one up from where we started.
     */
    private ValueIterator current, previous;

    private int level;

    invariant(this.level <= cast(int) this.iterators.length);

    public this(JSONValue value)
    {
        this.empty = false;
        // current = 0, previous = -1
        this.level = -2;
        stepInto(value);
    }

    // For debugging.
    string toString()
    {
        import std.format : format;
        import std.algorithm : max;

        return format!"JsonValueRange(%s, %s, %s: %s > %s > %s)"(
            empty, currentValue, level, current, previous, iterators[0 .. max(0, level)]);
    }

    public @property ref JSONParserNode front() return
    in (!empty)
    {
        return this.currentValue;
    }

    public JsonValueRange dup() const
    {
        JsonValueRange result;

        result.empty = this.empty;
        result.currentValue = this.currentValue;
        result.iterators = this.iterators.dup;
        result.current = current;
        result.previous = previous;
        result.level = level;
        return result;
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
            auto value = current.value.arrayNoRef[current.nextIndex];

            current.nextIndex++;
            stepInto(value);
        }
        else
        {
            import std.format : format;

            assert(false, format!"unexpected value type: %s in %s"(current.value.type, this));
        }
    }

    private void stepInto(JSONValue value)
    {
        with (JSONType) final switch (value.type)
        {
            case null_:
                this.currentValue.literal = JSONToken(null);
                break;
            case string:
                this.currentValue.literal = JSONToken(value.str);
                break;
            case integer:
                this.currentValue.literal = JSONToken(value.integer);
                break;
            case uinteger:
                this.currentValue.literal = JSONToken(value.uinteger);
                break;
            case float_:
                this.currentValue.literal = JSONToken(value.floating);
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
                this.currentValue.literal = JSONToken(true);
                break;
            case false_:
                this.currentValue.literal = JSONToken(false);
                break;
        }
    }

    private void pushState(JSONValue value)
    {
        if (this.level >= 0)
        {
            if (this.level == this.iterators.length)
            {
                this.iterators ~= this.previous;
            }
            else
            {
                this.iterators[this.level] = this.previous;
            }
        }
        this.previous = this.current;
        this.current = ValueIterator(value);
        this.level++;
    }

    private void popState()
    {
        this.level--;
        if (!outOfValues)
        {
            this.current = this.previous;
            if (this.level >= 0) // handle -1 case
            {
                this.previous = this.iterators[this.level];
            }
        }
    }

    public bool outOfValues() const
    {
        return this.level == -2;
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
