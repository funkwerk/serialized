module text.time.Convert;

version(unittest) import dshould;
import std.array;
import std.datetime;
import std.string;
import text.time.Lexer;

/**
 * This service class provides functions to convert between date and time values and their representations.
 *
 * Standards: ISO 8601
 * "Data elements and interchange formats — Information interchange — Representation of dates and times"
 * @Immutable
 */
class Convert
{

    /**
     * Converts the specified representation into its (date and) time value.
     *
     * Throws: DateTimeException on syntax error.
     */
    public static T to(T : SysTime)(string value)
    {
        return SysTime.fromISOExtString(value);
    }

    unittest
    {
        Convert.to!SysTime("2003-02-01T11:55:00+01:00")
            .should.equal(SysTime(DateTime(2003, 2, 1, 11, 55), new immutable SimpleTimeZone(1.hours)));

        Convert.to!SysTime("2003-02-01 11:55:00").should.throwA!DateTimeException
            .because("missing 'T'");
        Convert.to!SysTime(null).should.throwA!DateTimeException;
    }

    /**
     * Converts the specified representation into its date value.
     *
     * Throws: DateTimeException on syntax error.
     */
    public static T to(T : Date)(string value)
    {
        return Date.fromISOExtString(value);
    }

    unittest
    {
        Convert.to!Date("2003-02-01").should.equal(Date(2003, 2, 1));

        Convert.to!Date("01.02.2003").should.throwA!DateTimeException;
        Convert.to!Date(null).should.throwA!DateTimeException;
    }

    /**
     * Converts the specified representation into its time-of-day value.
     *
     * Throws: DateTimeException on syntax error.
     */
    public static T to(T : TimeOfDay)(string value)
    {
        return TimeOfDay.fromISOExtString(value);
    }

    unittest
    {
        Convert.to!TimeOfDay("01:02:03").should.equal(TimeOfDay(1, 2, 3));
        Convert.to!TimeOfDay("23:59:59").should.equal(TimeOfDay(23, 59, 59));

        Convert.to!TimeOfDay("1:2:3").should.throwA!DateTimeException;
        Convert.to!TimeOfDay(null).should.throwA!DateTimeException;
    }

    /**
     * Converts the specified representation into its duration value.
     * For decimal fractions, digits representing less than one millisecond are disregarded.
     *
     * Throws: TimeException on syntax error.
     */
    public static T to(T : Duration)(string value)
    {
        return Lexer.toDuration(value);
    }

    /**
     * Converts the specified (date and) time value into its representation.
     *
     * Throws: DateTimeException when the specified time is undefined.
     */
    public static string toString(SysTime time) @trusted
    {
        return toStringSinkProxy(time);
    }

    /// ditto
    public static void toString(SysTime sysTime, scope void delegate(const(char)[]) sink)
    {
        if (sysTime == SysTime.init && sysTime.timezone is null)
        {
            throw new DateTimeException("time undefined");
        }

        sysTime.fracSecs = Duration.zero;
        sysTime.toISOExtString(sink);
    }

    unittest
    {
        DateTime dateTime = DateTime.fromISOExtString("2003-02-01T11:55:00");

        Convert.toString(SysTime(dateTime)).should.equal("2003-02-01T11:55:00");
        Convert.toString(SysTime(dateTime, UTC())).should.equal("2003-02-01T11:55:00Z");
        Convert.toString(SysTime(dateTime, 123.msecs)).should.equal("2003-02-01T11:55:00");

        DateTime epoch = DateTime.fromISOExtString("0001-01-01T00:00:00");

        Convert.toString(SysTime(epoch)).should.equal("0001-01-01T00:00:00");
        Convert.toString(SysTime(epoch, UTC())).should.equal("0001-01-01T00:00:00Z");
    }

    /**
     * Converts the specified date into its representation.
     */
    public static string toString(Date date) @trusted
    {
        return toStringSinkProxy(date);
    }

    /// ditto
    public static void toString(Date date, scope void delegate(const(char)[]) sink)
    {
        date.toISOExtString(sink);
    }

    @safe unittest
    {
        Convert.toString(Date(2003, 2, 1)).should.equal("2003-02-01");
    }

    /**
     * Converts the specified date and time-of-day value into its representation.
     */
    public static string toString(TimeOfDay timeOfDay) @trusted
    {
        return toStringSinkProxy(timeOfDay);
    }

    /// ditto
    public static void toString(TimeOfDay timeOfDay, scope void delegate(const(char)[]) sink)
    {
        timeOfDay.toISOExtString(sink);
    }

    @safe unittest
    {
        Convert.toString(TimeOfDay(1, 2, 3)).should.equal("01:02:03");
    }

    /**
     * Converts the specified duration value into its canonical representation.
     */
    public static string toString(Duration duration) @trusted
    {
        return toStringSinkProxy(duration);
    }

    /// ditto
    public static void toString(Duration duration, scope void delegate(const(char)[]) sink)
    {
        import std.format : formattedWrite;

        if (duration < Duration.zero)
        {
            sink("-");
            duration = -duration;
        }

        auto result = duration.split!("days", "hours", "minutes", "seconds", "msecs");

        with (result)
        {
            sink("P");

            if (days != 0)
            {
                sink.formattedWrite("%sD", days);
            }

            const bool allTimesNull = hours == 0 && minutes == 0 && seconds == 0 && msecs == 0;
            const bool allNull = allTimesNull && days == 0;

            if (!allTimesNull || allNull)
            {
                sink("T");
                if (hours != 0)
                {
                    sink.formattedWrite("%sH", hours);
                }
                if (minutes != 0)
                {
                    sink.formattedWrite("%sM", minutes);
                }
                if (seconds != 0 || msecs != 0 || allNull)
                {
                    sink.formattedWrite("%s", seconds);
                    sink.writeMillis(msecs);
                    sink("S");
                }
            }
        }
    }

    @safe unittest
    {
        Convert.toString(1.days + 2.hours + 3.minutes + 4.seconds + 500.msecs).should.equal("P1DT2H3M4.5S");
        Convert.toString(1.days).should.equal("P1D");
        Convert.toString(Duration.zero).should.equal("PT0S");
        Convert.toString(1.msecs).should.equal("PT0.001S");
        Convert.toString(-(1.hours + 2.minutes + 3.seconds + 450.msecs)).should.equal("-PT1H2M3.45S");
    }
}

private string toStringSinkProxy(T)(T t)
{
    string str = null;

    Convert.toString(t, (fragment) { str ~= fragment; });

    return str;
}

/**
 * Converts the specified milliseconds value into a representation with as few digits as possible.
 */
private void writeMillis(scope void delegate(const(char)[]) sink, long millis)
in (0 <= millis && millis < 1000)
{
    import std.format : formattedWrite;

    if (millis == 0)
    {
        sink("");
    }
    else if (millis % 100 == 0)
    {
        sink.formattedWrite(".%01d", millis / 100);
    }
    else if (millis % 10 == 0)
    {
        sink.formattedWrite(".%02d", millis / 10);
    }
    else
    {
        sink.formattedWrite(".%03d", millis);
    }
}
