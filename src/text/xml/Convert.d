module text.xml.Convert;

version(unittest) import dshould;
import std.array;
static import std.conv;
import std.datetime;
import std.exception;
import std.string;
import std.traits;
static import text.time.Convert;
import text.xml.XmlException;

/**
 * This service class provides static member functions to convert between values and their representations
 * according to the data type definitions of the XML Schema language. When a conversion (from representation to value)
 * cannot be performed, an exception indicating the XML validity violation is thrown.
 * @Immutable
 */
class Convert
{

    /**
     * Converts the specified representation into its boolean value.
     *
     * Throws: XmlException on validity violation.
     */
    public static T to(T : bool)(string value)
    {
        switch (value.strip)
        {
            case "false":
            case "0":
                return false;
            case "true":
            case "1":
                return true;
            default:
                throw new XmlException(format!`"%s" is not a valid value of type boolean`(value));
        }
    }

    unittest
    {
        to!bool(" true ").should.equal(true);
        to!bool(" false ").should.equal(false);

        to!bool("True").should.throwAn!XmlException;
    }

    /**
     * Converts the specified representation into its integer or floating-point value.
     *
     * Throws: XmlException on validity violation.
     */
    public static T to(T)(string value)
    if ((isIntegral!T && !is(T == enum)) || isFloatingPoint!T)
    {
        try
        {
            return std.conv.to!T(value.strip);
        }
        catch (std.conv.ConvException)
        {
            throw new XmlException(format!`"%s" is not a valid value of type %s`(value, T.stringof));
        }
    }

    unittest
    {
        to!int(" -1 ").should.equal(-1);
        to!uint(" 0 ").should.equal(0);
        to!long("-9223372036854775808").should.equal(long.min);
        to!ulong(" 18446744073709551615 ").should.equal(ulong.max);
        to!double(" 1.2 ").should.be.approximately(1.2, error = 1e-6);

        to!int("1.2").should.throwAn!XmlException;
        to!uint("0xab").should.throwAn!XmlException;
    }

    /**
     * Converts the specified representation into its positive integer value.
     *
     * Throws: XmlException on validity violation.
     */
    public static T toPositive(T)(string value)
    if (isIntegral!T)
    out (result; result > 0)
    {
        try
        {
            T result = std.conv.to!T(value.strip);

            if (result <= 0)
            {
                throw new XmlException(format!`"%s" is not a valid value of type positive integer`(value));
            }
            return result;
        }
        catch (std.conv.ConvException)
        {
            throw new XmlException(format!`"%s" is not a valid value of type %s`(value, T.stringof));
        }
    }

    unittest
    {
        toPositive!int(" +1 ").should.equal(1);
        toPositive!long("9223372036854775807").should.equal(long.max);

        toPositive!uint("0").should.throwAn!XmlException;
    }

    /**
     * Converts the specified representation into its enumeration value.
     *
     * Throws: XmlException on validity violation.
     */
    public static T to(T)(string value)
    if (is(T == enum))
    {
        try
        {
            return std.conv.to!T(value.strip);
        }
        catch (std.conv.ConvException)
        {
            throw new XmlException(format!`"%s" is not a valid value of enumeration %s`(value, T.stringof));
        }
    }

    unittest
    {
        enum Enum {VALUE}

        to!Enum(" VALUE ").should.equal(Enum.VALUE);

        to!Enum(" 0 ").should.throwAn!XmlException;
    }

    /**
     * Converts the specified representation into its date value.
     *
     * Throws: XmlException on validity violation.
     */
    public static T to(T : Date)(string value)
    {
        import std.ascii : isDigit;

        try
        {
            return text.time.Convert.Convert.to!Date(value.strip);
        }
        catch (DateTimeException)
        {
            value = value.strip;

            size_t index = value.length;

            enum NoResult = ptrdiff_t.max;

            ptrdiff_t endsWithTimezone()
            {
                import std.algorithm : max;

                if (value.endsWith("Z"))
                {
                    return "Z".length;
                }

                auto offsetIndex = max(value.lastIndexOf('+'), value.lastIndexOf('-'));

                if (offsetIndex == -1)
                {
                    return NoResult;
                }

                auto tzRange = value[offsetIndex + 1 .. $];

                if (tzRange.length != "00:00".length)
                {
                    return NoResult;
                }

                if (isDigit(tzRange[0]) && isDigit(tzRange[1]) && tzRange[2] == ':'
                    && isDigit(tzRange[3]) && isDigit(tzRange[4]))
                {
                    return "+00:00".length;
                }
                else
                {
                    return NoResult;
                }
            }

            auto timezoneLength = endsWithTimezone();

            if (timezoneLength != NoResult)
            {
                index -= timezoneLength;
            }
            try
            {
                return cast(Date) to!SysTime(value[0 .. index] ~ "T00:00:00" ~ value[index .. $]);
            }
            catch (XmlException)
            {
                throw new XmlException(format!`"%s" is not a valid value of type date`(value));
            }
        }
    }

    unittest
    {
        to!Date("2003-02-01").should.equal(Date(2003, 2, 1));
        to!Date("2003-02-01Z").should.equal(Date(2003, 2, 1));
        to!Date("2003-02-01-01:00").should.equal(Date(2003, 2, 1));

        to!Date("01.02.2003").should.throwAn!XmlException;
        to!Date("today").should.throwAn!XmlException;
    }

    /**
     * Converts the specified representation into its date and time value.
     *
     * Throws: XmlException on validity violation.
     */
    public static T to(T : SysTime)(string value)
    {
        try
        {
            return text.time.Convert.Convert.to!SysTime(value.strip);
        }
        catch (DateTimeException)
        {
            return fixDateTimeInTooDistantFuture(value);
        }
    }

    unittest
    {
        to!SysTime(" 2003-02-01T11:55:00+01:00 ")
            .should.equal(SysTime(DateTime(2003, 2, 1, 11, 55), new immutable SimpleTimeZone(1.hours)));
        to!SysTime("292278994-08-17T08:12:55+01:00").should.equal(SysTime.max);

        to!SysTime("2003-02-01 11:55:00").should.throwAn!XmlException
            .because("missing 'T'");
        to!SysTime("2003-02-01T24:00:00").should.throwAn!XmlException
            .because("XML Schema 1.1 not yet supported");
    }

    /**
     * Throws: XmlException when the given value does not match the lexical representation of a date and time,
     * or when the date is not in the too distant future.
     */
    private static SysTime fixDateTimeInTooDistantFuture(string value) @safe
    {
        // std.regex unduly explodes our compiletime

        // import std.regex;
        // auto lexicalRepresentation = regex(`^(?P<year>-?\d{4,})-(?P<month>\d{2})-(?P<day>\d{2})T`
        //     ~ `(?P<hour>\d{2}):(?P<minute>\d{2}):(?P<second>\d{2})(?P<timezone>(Z|[+-]\d{2}:\d{2})?)$`);

        string yearStr;
        bool matchLexicalRepresentationSaveYear() @nogc @safe
        {
            import std.ascii : isDigit;
            import text.RecursiveDescentParser : RecursiveDescentParser;

            with (RecursiveDescentParser(value))
            {
                alias acceptDigits = i => matchTimes(i, () => acceptAsciiChar(ch => ch.isDigit));

                // ^(?P<year>-?\d{4,})
                if (!captureGroupInto(yearStr, () =>
                    matchOptional(() => accept("-"))
                    && acceptDigits(4) && matchZeroOrMore(() => acceptDigits(1))))
                {
                    return false;
                }

                // -\d{2}-\d{2}T\d{2}:\d{2}:\d{2}
                if (!(accept("-")
                    && acceptDigits(2) && accept("-")
                    && acceptDigits(2) && accept("T")
                    && acceptDigits(2) && accept(":")
                    && acceptDigits(2) && accept(":")
                    && acceptDigits(2)))
                {
                    return false;
                }

                // (Z|[+-]\d{2}:\d{2})?
                accept("Z") || matchGroup(() =>
                    acceptAsciiChar((ch) => ch == '+' || ch == '-')
                        && acceptDigits(2) && accept(":") && acceptDigits(2));

                // $
                if (!eof)
                {
                    return false;
                }

                return true;
            }
        }

        // if (auto captures = value.strip.matchFirst(lexicalRepresentation))
        if (matchLexicalRepresentationSaveYear)
        {
            try
            {
                const year = std.conv.to!long(yearStr);

                if (year > SysTime.max.year)
                {
                    return SysTime.max;
                }
            }
            catch (std.conv.ConvException)
            {
                // fall through
            }
        }
        throw new XmlException(format!`"%s" is not a valid value of type date-time`(value));
    }

    /**
     * Converts the specified representation into its duration (strictly speaking, 'dayTimeDuration') value.
     * For decimal fractions, digits representing less than one millisecond are disregarded.
     *
     * Throws: XmlException on validity violation.
     */
    public static T to(T : Duration)(string value)
    {
        try
        {
            return text.time.Convert.Convert.to!Duration(value.strip);
        }
        catch (TimeException)
        {
            throw new XmlException(format!`"%s" is not a valid value of type duration`(value));
        }
    }

    unittest
    {
        to!Duration("P1DT2H3M4.5S").should.equal(1.days + 2.hours + 3.minutes + 4.seconds + 500.msecs);

        to!Duration("PT1S2M3H").should.throwAn!XmlException.
            because("disarranged representation");
    }

    /**
     * Converts the specified representation into its time value.
     *
     * Throws: XmlException on validity violation.
     */
    public static T to(T : TimeOfDay)(string value)
    {
        try
        {
            return text.time.Convert.Convert.to!TimeOfDay(value.strip);
        }
        catch (DateTimeException)
        {
            throw new XmlException(format!`"%s" is not a valid value of type time`(value));
        }
    }

    unittest
    {
        Convert.to!TimeOfDay("01:02:03").should.equal(TimeOfDay(1, 2, 3));

        to!TimeOfDay("1:2:3").should.throwAn!XmlException;
        to!TimeOfDay("24:00:00").should.throwAn!XmlException
            .because("XML Schema 1.1 not yet supported");
    }

    /**
     * Returns the specified string value.
     * This specialization allows to use the template with any relevant type.
     */
    public static T to(T : string)(string value)
    {
        return value;
    }

    /**
     * Converts the specified "time" representation (time of day with optional fractional seconds)
     * into the corresponding time of day (without fractional seconds).
     *
     * Throws: XmlException on validity violation.
     */
    public static T toTime(T : TimeOfDay)(string value)
    {
        return TimeOfDay.min + toTime!Duration(value);
    }

    @safe unittest
    {
        toTime!TimeOfDay("01:02:03").should.equal(TimeOfDay(1, 2, 3));
        toTime!TimeOfDay("01:02:03.456").should.equal(TimeOfDay(1, 2, 3));
    }

    /**
     * Converts the specified "time" representation (time of day with optional fractional seconds)
     * into the corresponding duration since midnight.
     *
     * Throws: XmlException on validity violation.
     */
    public static T toTime(T : Duration = Duration)(string value)
    {
        import std.algorithm : findSplitBefore;

        auto result = value.strip.findSplitBefore(".");

        try
        {
            const timeOfDay = TimeOfDay.fromISOExtString(result[0]);
            const fracSecs = fracSecsFromISOString(result[1]);

            return timeOfDay - TimeOfDay.min + fracSecs;
        }
        catch (DateTimeException)
        {
            throw new XmlException(format!`"%s" is not a valid value of type time`(value));
        }
    }

    @safe unittest
    {
        toTime("01:02:03").should.equal(TimeOfDay(1, 2, 3) - TimeOfDay.min);
        toTime("01:02:03.456").should.equal(TimeOfDay(1, 2, 3) - TimeOfDay.min + 456.msecs);
    }

    /**
     * See_Also: private helper function of std.datetime with same name
     * Throws: DateTimeException on syntax error.
     */
    private static Duration fracSecsFromISOString(string value) @safe
    {
        import std.conv : ConvException, to;
        import std.range : empty;

        if (value.empty)
        {
            return Duration.zero;
        }

        enforce!DateTimeException(value.front == '.' && value.length > 1);

        char[7] digits;  // hnsecs

        foreach (i, ref digit; digits)
        {
            digit = (i + 1 < value.length) ? value[i + 1] : '0';
        }
        try
        {
            return digits.to!int.hnsecs;
        }
        catch (ConvException exception)
        {
            throw new DateTimeException(exception.msg);
        }

    }

    unittest
    {
        fracSecsFromISOString("").should.equal(Duration.zero);
        fracSecsFromISOString(".1").should.equal(1_000_000.hnsecs);
        fracSecsFromISOString(".01").should.equal(100_000.hnsecs);
        fracSecsFromISOString(".001").should.equal(10_000.hnsecs);
        fracSecsFromISOString(".0001").should.equal(1_000.hnsecs);
        fracSecsFromISOString(".00001").should.equal(100.hnsecs);
        fracSecsFromISOString(".000001").should.equal(10.hnsecs);
        fracSecsFromISOString(".0000001").should.equal(1.hnsecs);

        fracSecsFromISOString("?").should.throwA!DateTimeException;
        fracSecsFromISOString(".").should.throwA!DateTimeException;
        fracSecsFromISOString("...").should.throwA!DateTimeException;
    }

    /**
     * Converts the specified boolean value into its canonical representation.
     */
    public static string toString(bool value) @nogc @safe
    {
        return value ? "true" : "false";
    }

    @safe unittest
    {
        toString(true).should.equal("true");
        toString(false).should.equal("false");
    }

    /**
     * Converts the specified integer or floating-point value into its canonical representation.
     */
    public static string toString(T)(T value)
    if (isIntegral!T || isFloatingPoint!T)
    {
        return std.conv.to!string(value);
    }

    @safe unittest
    {
        toString(42).should.equal("42");
        toString(-42).should.equal("-42");
        toString(1.2).should.equal("1.2");
    }

    /**
     * Converts the specified date into its canonical representation.
     */
    public static string toString(Date date) @safe
    {
        return text.time.Convert.Convert.toString(date);
    }

    @safe unittest
    {
        toString(Date(2003, 2, 1)).should.equal("2003-02-01");
    }

    /**
     * Converts the specified date and time value into its canonical representation.
     */
    public static string toString(SysTime dateTime) @safe
    {
        return text.time.Convert.Convert.toString(dateTime);
    }

    @safe unittest
    {
        DateTime dateTime = DateTime.fromISOExtString("2003-02-01T11:55:00");

        toString(SysTime(dateTime)).should.equal("2003-02-01T11:55:00");
        toString(SysTime(dateTime, UTC())).should.equal("2003-02-01T11:55:00Z");
    }

    /**
     * Converts the specified duration value into its canonical representation.
     */
    public static string toString(Duration duration) @safe
    {
        return text.time.Convert.Convert.toString(duration);
    }

    @safe unittest
    {
        toString(1.days + 2.hours + 3.minutes + 4.seconds + 500.msecs).should.equal("P1DT2H3M4.5S");
    }

    /**
     * Converts the specified time of day value into its canonical representation.
     */
    public static string toString(TimeOfDay timeOfDay) @safe
    {
        return text.time.Convert.Convert.toString(timeOfDay);
    }

    @safe unittest
    {
        toString(TimeOfDay(1, 2, 3)).should.equal("01:02:03");
    }

}
