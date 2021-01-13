module text.json.Enum;

import std.algorithm;
import std.ascii : isLower;
import std.json;
import std.range;
import std.utf;

version (unittest) import dshould;

/**
 * Helper to encode a DStyle enum ("entryName") as JSON style ("ENTRY_NAME").
 *
 * Use like so: `alias encode = encodeEnum!EnumType;` when forming your encode overload.
 */
string encodeEnum(T)(const T value)
if (is(T == enum))
{
    import std.conv : to;
    import std.uni : toUpper;

    const enumString = value.to!string;

    return enumString.splitByPredicate!isWord.map!toUpper.join("_");
}

/// ditto
unittest
{
    import text.json.Encode : encodeJson;

    enum Enum
    {
        testValue,
        isHttp,
    }

    alias encode = encodeEnum!Enum;

    encodeJson!(Enum, encode)(Enum.testValue).should.be(JSONValue("TEST_VALUE"));
    encodeJson!(Enum, encode)(Enum.isHttp).should.be(JSONValue("IS_HTTP"));
}

/**
 * Helper to decode a JSON style enum string (ENTRY_NAME) as a DStyle enum (entryName).
 *
 * Use like so: `alias decode = decodeEnum!EnumType;` when forming your encode overload.
 */
template decodeEnum(T)
if (is(T == enum))
{
    U decodeEnum(U : T)(const string text)
    {
        import std.conv : to;
        import std.string : capitalize;
        import std.uni : toLower;

        return (text.split("_").front.toLower ~ text.split("_").dropOne.map!capitalize.join).to!T;
    }
}

/// ditto
unittest
{
    import text.json.Decode : decodeJson;

    enum Enum
    {
        testValue,
        isHttp,
    }

    alias decode = decodeEnum!Enum;

    decodeJson!(Enum, decode)(JSONValue("TEST_VALUE")).should.be(Enum.testValue);
    decodeJson!(Enum, decode)(JSONValue("IS_HTTP")).should.be(Enum.isHttp);
}

alias isWord = text => text.length > 0 && text.drop(1).all!isLower;

private string[] splitByPredicate(alias pred)(string text)
{
    string[] result;
    while (text.length > 0)
    {
        size_t scan = 0;

        while (scan < text.length)
        {
            const newscan = scan + text[scan .. $].stride;

            if (pred(text[0 .. newscan]))
            {
                scan = newscan;
            }
            else
            {
                break;
            }
        }

        result ~= text[0 .. scan];
        text = text[scan .. $];
    }
    return result;
}

unittest
{
    splitByPredicate!isWord("FooBar").should.be(["Foo", "Bar"]);
    splitByPredicate!isWord("FooBAR").should.be(["Foo", "B", "A", "R"]);
    splitByPredicate!isWord("").should.be([]);
}
