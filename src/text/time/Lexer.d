module text.time.Lexer;

import core.time;
version(unittest) import dshould;
import std.conv;
import std.string;

/**
 * This service class allows to convert duration representations into corresponding values.
 *
 * Standards: ISO 8601
 * "Data elements and interchange formats — Information interchange — Representation of dates and times"
 */
package struct Lexer
{
    private static const char END = 0;

    private static const char DIGITS = '0';

    private string representation;

    /**
     * The slice of the representation yet to be analyzed.
     */
    private string rest;

    private string value;

    private this(string representation) @nogc nothrow pure @safe
    {
        this.representation = representation;
        this.rest = representation;
    }

    /**
     * Converts the specified representation into its duration value. While the duration data type of the XML Schema
     * language allows to also specify year and month fields, such representations cannot be converted to durations.
     * Consequently, only the derived data type 'dayTimeDuration' of the XML Schema language is supported here,
     * where all representations with year or month fields are excluded.
     * For decimal fractions, digits representing less than one millisecond are disregarded.
     *
     * Throws: TimeException on syntax error.
     */
    package static Duration toDuration(string representation) pure @safe
    {
        auto lexer = Lexer(representation);

        return lexer.toDuration;
    }

    unittest
    {
        toDuration("P1DT2H3M4.5S").should.equal(1.days + 2.hours + 3.minutes + 4.seconds + 500.msecs);
        toDuration("-P1D").should.equal(-1.days);
        toDuration("+PT1S").should.equal(1.seconds);

        toDuration("PT1S2M3H").should.throwA!TimeException
            .because("disarranged representation");
        toDuration("01H05M10S").should.throwA!TimeException
            .because("missing 'P'");
        toDuration("PT1.S").should.throwA!TimeException
            .because("clipped decimal fraction");
        toDuration("PT1").should.throwA!TimeException
            .because("missing 'S'");
        toDuration("PT").should.throwA!TimeException;
    }

    /**
     * Converts the representation according to the following (simplified) regular expression into its duration value:
     *
     *   ('+'|'-')? 'P' ([0-9]+ 'D')? ('T' ([0-9]+ 'H')? ([0-9]+ 'M')? ([0-9]+ ('.' [0-9]+)? 'S')?)?
     */
    private Duration toDuration() pure @safe
    {
        Duration duration;
        bool positive = true;
        bool complete = false;
        enum ERROR_MESSAGE = "'%s' is not a valid duration value";
        char prev;
        char next;

        next = readSymbol;
        if (next == '+' || next == '-')
        {
            positive = (next == '+');
            next = readSymbol;
        }
        if (next != 'P')
        {
            throw new TimeException(format!ERROR_MESSAGE(this.representation));
        }
        prev = readSymbol;
        next = readSymbol;
        if (prev == DIGITS && next == 'D')
        {
            complete = true;
            duration += this.value.to!long.days;
            prev = readSymbol;
            next = readSymbol;
        }
        if (prev == 'T')
        {
            complete = false;
            prev = next;
            next = readSymbol;
            if (prev == DIGITS && next == 'H')
            {
                complete = true;
                duration += this.value.to!long.hours;
                prev = readSymbol;
                next = readSymbol;
            }
            if (prev == DIGITS && next == 'M')
            {
                complete = true;
                duration += this.value.to!long.minutes;
                prev = readSymbol;
                next = readSymbol;
            }
            if (prev == DIGITS)
            {
                complete = true;
                duration += this.value.to!long.seconds;
                if (next == '.')
                {
                    next = readSymbol;
                    if (next != DIGITS)
                    {
                        throw new TimeException(format!ERROR_MESSAGE(this.representation));
                    }
                    this.value = (this.value ~ "000")[0 .. 3];
                    duration += this.value.to!long.msecs;
                    next = readSymbol;
                }
                if (next != 'S')
                {
                    throw new TimeException(format!ERROR_MESSAGE(this.representation));
                }
                prev = readSymbol;
            }
        }
        if (!complete || prev != END)
        {
            throw new TimeException(format!ERROR_MESSAGE(this.representation));
        }
        return (positive) ? duration : -duration;
    }

    /**
     * Returns: The next "symbol" in the representation ('END', 'DIGITS', or the next character itself).
     */
    private char readSymbol() @nogc nothrow pure @safe
    {
        if (this.rest.length == 0)
        {
            return END;
        }

        char c = this.rest[0];

        if ('0' <= c && c <= '9')
        {
            uint index = 0;

            do
            {
                ++index;
                if (index >= this.rest.length)
                {
                    break;
                }
                c = this.rest[index];
            }
            while ('0' <= c && c <= '9');
            this.value = this.rest[0 .. index];
            this.rest = this.rest[index .. $];
            return DIGITS;
        }
        this.rest = this.rest[1 .. $];
        return c;
    }

}
