module text.json.ParserMarker;

import funkwerk.stdx.data.json.lexer;
import funkwerk.stdx.data.json.parser;
import meta.never;
import std.json;
import std.typecons;
import text.json.Decode;
import text.json.JsonValueRange;

/**
 * This magic type represents an offset into a JSON parser input stream.
 * While parsing a message, a value of this type is skipped.
 * Later on, it can be parsed into a (now better known) type.
 */
struct ParserMarker
{
    alias StringStream = typeof(parseJSONStream!(LexOptions.noTrackLocation)(""));
    alias JsonStream = JsonValueRange;

    private Nullable!StringStream stringStream;

    private Nullable!JsonStream jsonStream;

    invariant (this.stringStream.isNull != this.jsonStream.isNull);

    public this(StringStream stringStream)
    {
        this.stringStream = stringStream.nullable;
    }

    public this(JsonStream jsonStream)
    {
        this.jsonStream = jsonStream.nullable;
    }

    public this(JSONValue value)
    {
        this.jsonStream = JsonStream(value).nullable;
    }

    public T decode(T, alias transform = never)() const
    {
        import std.typecons: Yes;

        if (!this.stringStream.isNull)
        {
            StringStream stream = this.stringStream.get.dup;

            return decodeJson!(T, transform, Yes.logErrors)(stream, T.stringof);
        }
        else
        {
            JsonStream stream = this.jsonStream.get.dup;

            return decodeJson!(T, transform, Yes.logErrors)(stream, T.stringof);
        }
    }
}
