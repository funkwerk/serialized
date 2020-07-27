module text.RecursiveDescentParser;

import std.algorithm;
import std.range;
import std.string;

@safe
struct RecursiveDescentParser
{
    private string text;

    private size_t cursor;

    public this(string text) @nogc
    {
        this.text = text;
    }

    invariant
    {
        import std.utf : stride;

        assert(this.cursor >= 0 && this.cursor <= this.text.length);

        // validate that this.cursor lies at the start of a utf-8 character
        assert(this.cursor == this.text.length || this.text[this.cursor .. $].stride > 0);
    }

    public bool matchGroup(scope bool delegate() @nogc @safe action) @nogc
    {
        auto backup = this.cursor;
        auto result = action();

        if (!result) // parse failure, roll back state
        {
            this.cursor = backup;
        }

        return result;
    }

    public bool captureGroupInto(out string target, scope bool delegate() @nogc @safe action) @nogc
    {
        auto startCursor = this.cursor;
        auto result = action();

        if (result)
        {
            auto endCursor = this.cursor;

            target = this.text[startCursor .. endCursor];
        }

        return result;
    }

    public bool matchZeroOrMore(scope bool delegate() @nogc @safe action) @nogc
    {
        action.generate.find(false);

        return true;
    }

    public bool matchOptional(scope bool delegate() @nogc @safe action) @nogc
    {
        action();

        return true;
    }

    public bool matchTimes(int num, scope bool delegate() @nogc @safe action) @nogc
    {
        return matchGroup(() => action.generate.takeExactly(num).all);
    }

    public bool acceptAsciiChar(scope bool delegate(char) @nogc @safe predicate) @nogc
    {
        import std.ascii : isASCII;

        bool advance()
        {
            this.cursor = this.cursor + 1;
            return true;
        }

        return !eof
            // it's safe to do this check because we only advance in ways that cause text[cursor] to be valid utf-8
            // (see invariant)
            && this.text[this.cursor].isASCII
            && predicate(this.text[this.cursor])
            && advance;
    }

    public bool eof() @nogc
    {
        return this.remainingText.length == 0;
    }

    public bool accept(string needle) @nogc
    {
        bool advance()
        {
            this.cursor = this.cursor + needle.length;
            return true;
        }

        return this.remainingText.startsWith(needle) && advance;
    }

    public @property string remainingText() const @nogc
    {
        return this.text[this.cursor .. $];
    }
}

unittest
{
    import dshould : be, equal, should;

    with (RecursiveDescentParser("aaaaaaaa"))
    {
        matchTimes(8, () => accept("a")).should.be(true);
        matchTimes(1, () => accept("a")).should.be(false);
        accept("a").should.be(false);
        remainingText.should.equal("");
    }
}

unittest
{
    import dshould : be, equal, should;

    with (RecursiveDescentParser("aaaaaaaa"))
    {
        matchZeroOrMore(() => accept("a")).should.be(true);
        remainingText.should.equal("");
        matchZeroOrMore(() => accept("a")).should.be(true);
    }
}
