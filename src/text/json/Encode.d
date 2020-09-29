module text.json.Encode;

import meta.attributesOrNothing;
import meta.never;
import meta.SafeUnqual;
import std.json;
import std.traits;
import text.json.Json;

/**
 * Encodes an arbitrary type as a JSON string using introspection.
 */
public string encode(T, alias transform = never)(const T value)
{
    auto json = encodeJson!(T, transform)(value);

    return json.toJSON;
}

/// ditto
public JSONValue encodeJson(T)(const T value)
{
    return encodeJson!(T, transform)(value);
}

public JSONValue encodeJson(T, alias transform, attributes...)(const T parameter)
in
{
    static if (is(T == class))
    {
        assert(parameter !is null);
    }
}
do
{
    import boilerplate.util : formatNamed, optionallyRemoveTrailingUnderline, removeTrailingUnderline, udaIndex;
    import std.algorithm : map;
    import std.array : assocArray;
    import std.format : format;
    import std.meta : AliasSeq, anySatisfy, ApplyLeft;
    import std.range : array;
    import std.traits : fullyQualifiedName, isIterable, Unqual;
    import std.typecons : Nullable, Tuple, tuple;

    static if (__traits(compiles, transform(parameter)))
    {
        auto transformedValue = transform(parameter);
        static assert(!is(Unqual!(typeof(transformedValue)) == Unqual!T),
            "transform must not return the same type as it takes!");

        return encodeJson!(typeof(transformedValue), transform)(transformedValue);
    }
    else
    {
        static assert(
            !__traits(compiles, transform(Unqual!T.init)),
            "transform() must take its parameter as const!");

        auto value = parameter;
        alias Type = T;

        alias typeAttributes = attributesOrNothing!Type;

        static if (udaIndex!(Json.Encode, attributes) != -1)
        {
            alias encodeFunction = attributes[udaIndex!(Json.Encode, attributes)].EncodeFunction;
            enum hasEncodeFunction = true;
        }
        else static if (udaIndex!(Json.Encode, typeAttributes) != -1)
        {
            alias encodeFunction = typeAttributes[udaIndex!(Json.Encode, typeAttributes)].EncodeFunction;
            enum hasEncodeFunction = true;
        }
        else
        {
            enum hasEncodeFunction = false;
        }

        static if (hasEncodeFunction)
        {
            static if (__traits(compiles, encodeFunction!(typeof(value), transform, attributes)))
            {
                return encodeFunction!(typeof(value), transform, attributes)(value);
            }
            else
            {
                return encodeFunction(value);
            }
        }
        else static if (__traits(compiles, encodeValue(value)))
        {
            return encodeValue(value);
        }
        else static if (is(Type : V[string], V))
        {
            // TODO json encode of associative arrays with non-string keys
            return JSONValue(value.byKeyValue.map!(pair => tuple!("key", "value")(
                    pair.key,
                    .encodeJson!(typeof(pair.value), transform, attributes)(pair.value)))
                .assocArray);
        }
        else static if (isIterable!Type)
        {
            return JSONValue(value.map!(a => .encodeJson!(typeof(a), transform, attributes)(a)).array);
        }
        else
        {
            JSONValue[string] members = null;

            static assert(
                __traits(hasMember, Type, "ConstructorInfo"),
                fullyQualifiedName!Type ~ " does not have a boilerplate constructor!");

            alias Info = Tuple!(string, "builderField", string, "constructorField");

            static foreach (string constructorField; Type.ConstructorInfo.fields)
            {{
                enum builderField = optionallyRemoveTrailingUnderline!constructorField;

                mixin(formatNamed!q{
                    alias MemberType = SafeUnqual!(Type.ConstructorInfo.FieldInfo.%(constructorField).Type);

                    const MemberType memberValue = value.%(builderField);

                    static if (is(MemberType : Nullable!Arg, Arg))
                    {
                        bool includeMember = !memberValue.isNull;
                        enum getMemberValue = "memberValue.get";
                    }
                    else
                    {
                        enum includeMember = true;
                        enum getMemberValue = "memberValue";
                    }

                    alias attributes = AliasSeq!(Type.ConstructorInfo.FieldInfo.%(constructorField).attributes);

                    if (includeMember)
                    {
                        static if (udaIndex!(Json, attributes) != -1)
                        {
                            enum name = attributes[udaIndex!(Json, attributes)].name;
                        }
                        else
                        {
                            enum name = constructorField.removeTrailingUnderline;
                        }

                        auto finalMemberValue = mixin(getMemberValue);

                        enum sameField(string lhs, string rhs)
                            = optionallyRemoveTrailingUnderline!lhs== optionallyRemoveTrailingUnderline!rhs;
                        enum memberIsAliasedToThis = anySatisfy!(
                            ApplyLeft!(sameField, constructorField),
                            __traits(getAliasThis, T));

                        static if (memberIsAliasedToThis)
                        {
                            auto json = encodeJson!(typeof(finalMemberValue), transform, attributes)(finalMemberValue);

                            foreach (string key, newValue; json)
                            {
                                // impossible as it would have caused compiletime errors on access
                                assert(key !in members,
                                    format!"key collision: %s both in %s and member %s which is aliased to this"
                                        (key, T.stringof, constructorField));

                                members[key] = newValue;
                            }
                        }
                        else
                        {
                            members[name] = encodeJson!(typeof(finalMemberValue), transform, attributes)
                                (finalMemberValue);
                        }
                    }
                }.values(Info(builderField, constructorField)));
            }}

            return JSONValue(members);
        }
    }
}

public JSONValue encodeJson(T : JSONValue, alias transform, attributes...)(const T parameter)
{
    return parameter;
}

private JSONValue encodeValue(T)(T value)
if (!is(T: Nullable!Arg, Arg))
{
    import std.conv : to;
    import text.xml.Convert : Convert;

    static if (is(T == enum))
    {
        return JSONValue(value.to!string);
    }
    else static if (
        isBoolean!T || isIntegral!T || isFloatingPoint!T || isSomeString!T || is(T == typeof(null)))
    {
        return JSONValue(value);
    }
    else static if (__traits(compiles, Convert.toString(value)))
    {
        return JSONValue(Convert.toString(value));
    }
    else
    {
        static assert(false, "Cannot encode " ~ T.stringof ~ " as value");
    }
}
