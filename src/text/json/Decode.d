module text.json.Decode;

import funkwerk.stdx.data.json.lexer;
import funkwerk.stdx.data.json.parser;
import meta.attributesOrNothing;
import meta.never;
import std.algorithm : canFind, map;
import std.conv;
import std.format;
import std.json : JSONException, JSONValue;
import std.traits;
import std.typecons : Nullable;
import text.json.Json;
import text.json.JsonValueRange;
import text.time.Convert;

/**
 * This function decodes a JSON string into a given type using introspection.
 * Throws: JSONException
 */
public T decode(T, alias transform = never)(string json)
{
    auto stream = parseJSONStream(json);

    scope(success)
    {
        assert(stream.empty);
    }

    return decodeJson!(T, transform)(stream, T.stringof);
}

/// ditto
public T decode(T, alias transform = never)(JSONValue value)
{
    auto jsonStream = JsonValueRange(value);

    return decodeJson!(T, transform)(jsonStream);
}

/// ditto
public T decodeJson(T)(JSONValue value)
{
    auto jsonStream = JsonValueRange(value);

    return decodeJson!(T, never)(jsonStream, T.stringof);
}

/// ditto
public T decodeJson(T, alias transform, attributes...)(JSONValue value)
{
    auto jsonStream = JsonValueRange(value);

    return decodeJson!(T, transform, attributes)(jsonStream, T.stringof);
}

// lazy string target documents the member or array index which is being decoded.
public template decodeJson(T, alias transform, attributes...)
{
    public T decodeJson(JsonStream)(ref JsonStream jsonStream, lazy string target)
    in (isJSONParserNodeInputRange!JsonStream)
    {
        import boilerplate.util : formatNamed, optionallyRemoveTrailingUnderline, removeTrailingUnderline, udaIndex;
        import std.exception : enforce;
        import std.meta : AliasSeq, anySatisfy, ApplyLeft;
        import std.range : array, assocArray, ElementType, enumerate;

        static if (is(Unqual!T == JSONValue))
        {
            return decodeJSONValue(jsonStream);
        }
        else static if (__traits(compiles, transform!T) && isCallable!(transform!T))
        {
            static assert(Parameters!(transform!T).length == 1, "`transform` must take one parameter.");

            alias EncodedType = Parameters!(transform!T)[0];

            static assert(!is(EncodedType == T),
                    "`transform` must not return the same type as it takes (infinite recursion).");

            return transform!T(.decodeJson!(EncodedType, transform, attributes)(jsonStream, target));
        }
        else
        {
            alias typeAttributes = attributesOrNothing!T;

            static if (udaIndex!(Json.Decode, attributes) != -1 || udaIndex!(Json.Decode, typeAttributes) != -1)
            {
                static if (udaIndex!(Json.Decode, attributes) != -1)
                {
                    alias decodeFunction = attributes[udaIndex!(Json.Decode, attributes)].DecodeFunction;
                }
                else
                {
                    alias decodeFunction = typeAttributes[udaIndex!(Json.Decode, typeAttributes)].DecodeFunction;
                }

                JSONValue value = decodeJSONValue(jsonStream);

                static if (__traits(isTemplate, decodeFunction))
                {
                    // full meta form
                    static if (__traits(compiles, decodeFunction!(T, transform, attributes)(value, target)))
                    {
                        return decodeFunction!(T, transform, attributes)(value, target);
                    }
                    else
                    {
                        return decodeFunction!T(value);
                    }
                }
                else
                {
                    return decodeFunction(value);
                }
            }
            else static if (__traits(compiles, decodeValue!T(jsonStream, target)))
            {
                return decodeValue!T(jsonStream, target);
            }
            else static if (is(T: V[K], K, V))
            {
                static assert(is(string: K), "cannot decode associative array with non-string key from json");

                // decoded separately to handle const values
                K[] keys;
                V[] values;

                jsonStream.readObject((string key) @trusted
                {
                    auto value = .decodeJson!(Unqual!V, transform, attributes)(
                        jsonStream, format!`%s[%s]`(target, key));

                    keys ~= key;
                    values ~= value;
                });
                return assocArray(keys, values);
            }
            else static if (is(T : E[], E))
            {
                Unqual!T result;

                size_t index;
                jsonStream.readArray(() @trusted {
                    result ~= .decodeJson!(E, transform, attributes)(jsonStream, format!`%s[%s]`(target, index));
                    index++;
                });
                return result;
            }
            else // object
            {
                static if (is(T == struct) || is(T == class))
                {
                    static assert(
                        __traits(hasMember, T, "ConstructorInfo"),
                        fullyQualifiedName!T ~ " does not have a boilerplate constructor!");
                }
                else
                {
                    static assert(
                        false,
                        fullyQualifiedName!T ~ " cannot be decoded!");
                }

                auto builder = T.Builder();
                auto streamCopy = jsonStream;

                bool[T.ConstructorInfo.fields.length] fieldAssigned;

                jsonStream.readObject((string key) @trusted
                {
                    bool keyUsed = false;

                    static foreach (fieldIndex, string constructorField; T.ConstructorInfo.fields)
                    {{
                        enum builderField = optionallyRemoveTrailingUnderline!constructorField;

                        alias Type = Unqual!(__traits(getMember, T.ConstructorInfo.FieldInfo, constructorField).Type);
                        alias attributes = AliasSeq!(
                            __traits(getMember, T.ConstructorInfo.FieldInfo, constructorField).attributes);

                        static if (is(Type : Nullable!Arg, Arg))
                        {
                            alias DecodeType = Arg;
                            enum isNullable = true;
                        }
                        else
                        {
                            alias DecodeType = Type;
                            enum isNullable = false;
                        }

                        static if (udaIndex!(Json, attributes) != -1)
                        {
                            enum name = attributes[udaIndex!(Json, attributes)].name;
                        }
                        else
                        {
                            enum name = constructorField.removeTrailingUnderline;
                        }

                        if (key == name)
                        {
                            keyUsed = true;
                            static if (isNullable ||
                                __traits(getMember, T.ConstructorInfo.FieldInfo, constructorField).useDefault)
                            {
                                const tokenIsNull = jsonStream.front.kind == JSONParserNodeKind.literal
                                    && jsonStream.front.literal.kind == JSONTokenKind.null_;

                                if (tokenIsNull)
                                {
                                    jsonStream.skipValue;
                                }
                                else
                                {
                                    __traits(getMember, builder, builderField)
                                        = .decodeJson!(DecodeType, transform, attributes)(
                                            jsonStream, fullyQualifiedName!T ~ "." ~ name);

                                    fieldAssigned[fieldIndex] = true;
                                }
                            }
                            else
                            {
                                enum string[] aliasThisMembers = [__traits(getAliasThis, T)];
                                enum memberIsAliasedToThis = aliasThisMembers
                                    .map!removeTrailingUnderline
                                    .canFind(constructorField.removeTrailingUnderline);

                                static if (!memberIsAliasedToThis)
                                {
                                    __traits(getMember, builder, builderField)
                                        = .decodeJson!(DecodeType, transform, attributes)(
                                            jsonStream, target ~ "." ~ name);

                                    fieldAssigned[fieldIndex] = true;
                                }
                            }
                        }
                    }}

                    if (!keyUsed)
                    {
                        jsonStream.skipValue;
                    }
                });

                static foreach (fieldIndex, const constructorField; T.ConstructorInfo.fields)
                {{
                    enum builderField = optionallyRemoveTrailingUnderline!constructorField;
                    alias Type = Unqual!(__traits(getMember, T.ConstructorInfo.FieldInfo, constructorField).Type);

                    static if (is(Type : Nullable!Arg, Arg))
                    {
                        // Nullable types are always treated as optional, so fill in with default value
                        if (!fieldAssigned[fieldIndex])
                        {
                            __traits(getMember, builder, builderField) = Type();
                        }
                    }
                    else
                    {
                        enum string[] aliasThisMembers = [__traits(getAliasThis, T)];
                        enum memberIsAliasedToThis = aliasThisMembers
                            .map!removeTrailingUnderline
                            .canFind(constructorField.removeTrailingUnderline);
                        enum useDefault = __traits(getMember, T.ConstructorInfo.FieldInfo, constructorField)
                            .useDefault;

                        static if (memberIsAliasedToThis)
                        {
                            // alias this: decode from the same json value as the whole object
                            __traits(getMember, builder, builderField)
                                = .decodeJson!(Type, transform, attributes)(
                                    streamCopy, fullyQualifiedName!T ~ "." ~ constructorField);
                        }
                        else static if (!useDefault)
                        {
                            // not alias-this, not nullable, not default - must be set.
                            enforce!JSONException(
                                fieldAssigned[fieldIndex],
                                format!`expected %s.%s, but got %s`(
                                    target, builderField, streamCopy.decodeJSONValue));
                        }
                    }
                }}

                return builder.builderValue;
            }
        }
    }
}

private template decodeValue(T: bool)
if (!is(T == enum))
{
    private T decodeValue(JsonStream)(ref JsonStream jsonStream, lazy string target)
    {
        scope(success)
        {
            jsonStream.popFront;
        }

        if (jsonStream.front.kind == JSONParserNodeKind.literal
            && jsonStream.front.literal.kind == JSONTokenKind.boolean)
        {
            return jsonStream.front.literal.boolean;
        }
        throw new JSONException(
            format!"Invalid JSON:%s expected bool, but got %s"(
                target ? (" " ~ target) : null, jsonStream.decodeJSONValue));
    }
}

private template decodeValue(T: float)
if (!is(T == enum))
{
    private T decodeValue(JsonStream)(ref JsonStream jsonStream, lazy string target)
    {
        scope(success)
        {
            jsonStream.popFront;
        }

        if (jsonStream.front.kind == JSONParserNodeKind.literal
            && jsonStream.front.literal.kind == JSONTokenKind.number)
        {
            return jsonStream.front.literal.number.doubleValue.to!T;
        }
        throw new JSONException(
            format!"Invalid JSON:%s expected float, but got %s"(
                target ? (" " ~ target) : null, jsonStream.decodeJSONValue));
    }
}

private template decodeValue(T: int)
if (!is(T == enum))
{
    private T decodeValue(JsonStream)(ref JsonStream jsonStream, lazy string target)
    {
        scope(success)
        {
            jsonStream.popFront;
        }

        if (jsonStream.front.kind == JSONParserNodeKind.literal
            && jsonStream.front.literal.kind == JSONTokenKind.number)
        {
            switch (jsonStream.front.literal.number.type)
            {
                case JSONNumber.Type.long_:
                    return jsonStream.front.literal.number.longValue.to!int;
                default:
                    break;
            }
        }
        throw new JSONException(
            format!"Invalid JSON:%s expected int, but got %s"(
                target ? (" " ~ target) : null, jsonStream.decodeJSONValue));
    }
}

private template decodeValue(T)
if (is(T == enum))
{
    private T decodeValue(JsonStream)(ref JsonStream jsonStream, lazy string target)
    {
        scope(success)
        {
            jsonStream.popFront;
        }

        if (jsonStream.front.kind == JSONParserNodeKind.literal
            && jsonStream.front.literal.kind == JSONTokenKind.string)
        {
            string str = jsonStream.front.literal.string;

            try
            {
                return parse!(Unqual!T)(str);
            }
            catch (ConvException exception)
            {
                throw new JSONException(
                    format!"Invalid JSON:%s expected member of %s, but got \"%s\""
                        (target ? (" " ~ target) : null, T.stringof, str));
            }
        }
        throw new JSONException(
            format!"Invalid JSON:%s expected enum string, but got %s"(
                target ? (" " ~ target) : null, jsonStream.decodeJSONValue));
    }
}

private template decodeValue(T: string)
if (!is(T == enum))
{
    private T decodeValue(JsonStream)(ref JsonStream jsonStream, lazy string target)
    {
        scope(success)
        {
            jsonStream.popFront;
        }

        if (jsonStream.front.kind == JSONParserNodeKind.literal
            && jsonStream.front.literal.kind == JSONTokenKind.string)
        {
            return jsonStream.front.literal.string;
        }
        throw new JSONException(
            format!"Invalid JSON:%s expected string, but got %s"(
                target ? (" " ~ target) : null, jsonStream.decodeJSONValue));
    }
}

private template decodeValue(T)
if (__traits(compiles, Convert.to!T(string.init)))
{
    private T decodeValue(JsonStream)(ref JsonStream jsonStream, lazy string target)
    {
        scope(success)
        {
            jsonStream.popFront;
        }

        if (jsonStream.front.kind == JSONParserNodeKind.literal
            && jsonStream.front.literal.kind == JSONTokenKind.string)
        {
            return Convert.to!T(jsonStream.front.literal.string);
        }
        throw new JSONException(
            format!"Invalid JSON:%s expected string, but got %s"(
                target ? (" " ~ target) : null, jsonStream.decodeJSONValue));
    }
}

private JSONValue decodeJSONValue(JsonStream)(ref JsonStream jsonStream)
in (isJSONParserNodeInputRange!JsonStream)
{
    with (JSONParserNodeKind) final switch (jsonStream.front.kind)
    {
        case arrayStart:
            JSONValue[] children;
            jsonStream.readArray(delegate void() @trusted
            {
                children ~= .decodeJSONValue(jsonStream);
            });
            return JSONValue(children);
        case objectStart:
            JSONValue[string] children;
            jsonStream.readObject(delegate void(string key) @trusted
            {
                children[key] = .decodeJSONValue(jsonStream);
            });
            return JSONValue(children);
        case literal:
            with (JSONTokenKind) switch (jsonStream.front.literal.kind)
            {
                case null_:
                    jsonStream.popFront;
                    return JSONValue(null);
                case boolean: return JSONValue(jsonStream.readBool);
                case string: return JSONValue(jsonStream.readString);
                case number:
                {
                    scope(success)
                    {
                        jsonStream.popFront;
                    }

                    switch (jsonStream.front.literal.number.type)
                    {
                        case JSONNumber.Type.long_:
                            return JSONValue(jsonStream.front.literal.number.longValue);
                        case JSONNumber.Type.double_:
                            return JSONValue(jsonStream.front.literal.number.doubleValue);
                        default:
                            throw new JSONException(format!"Unexpected number: %s"(jsonStream.front.literal));
                    }
                }
                default:
                    throw new JSONException(format!"Unexpected JSON token: %s"(jsonStream.front));
            }
        case key:
            throw new JSONException("Unexpected object key");
        case arrayEnd:
            throw new JSONException("Unexpected end of array");
        case objectEnd:
            throw new JSONException("Unexpected end of object");
        case none:
            assert(false); // "never occurs in a node stream"
    }
}
