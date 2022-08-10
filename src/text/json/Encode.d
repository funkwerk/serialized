module text.json.Encode;

import meta.attributesOrNothing;
import meta.never;
import meta.SafeUnqual;
import std.datetime;
import std.format;
import std.json;
import std.range;
import std.traits;
import std.typecons;
import text.json.Json;

/**
 * Encodes an arbitrary type as a JSON string using introspection.
 */
public string encode(T, alias transform = never)(const T value)
{
    auto sink = StringSink();
    encodeJsonStream!(T, transform, StringSink)(sink, value);
    return sink.output[];
}

/// ditto
public JSONValue encodeJson(T)(const T value)
{
    return encodeJson!(T, never)(value);
}

public JSONValue encodeJson(T, alias transform)(const T value)
{
    auto sink = JSONValueSink();
    encodeJsonStream!(T, transform, JSONValueSink)(sink, value);
    return sink.value;
}

// range is an output range over `JSONOutputToken`s.
private void encodeJsonStream(T, alias transform, Range, attributes...)(ref Range output, const T parameter)
{
    import boilerplate.util : udaIndex;
    import std.traits : isIterable, Unqual;

    static if (__traits(compiles, transform(parameter)))
    {
        auto transformedValue = transform(parameter);
        static assert(!is(Unqual!(typeof(transformedValue)) == Unqual!T),
            "transform must not return the same type as it takes!");

        encodeJsonStream!(typeof(transformedValue), transform, Range)(output, transformedValue);
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
                auto jsonValue = encodeFunction!(typeof(value), transform, attributes)(value);
            }
            else
            {
                auto jsonValue = encodeFunction(value);
            }
            output.put(JSONOutputToken(jsonValue));
        }
        else static if (__traits(compiles, encodeValue(output, value)))
        {
            encodeValue(output, value);
        }
        else static if (is(Type : V[string], V))
        {
            output.put(JSONOutputToken.objectStart);
            foreach (key, element; value)
            {
                output.put(JSONOutputToken.key(key));
                encodeJsonStream!(typeof(element), transform, Range, attributes)(output, element);
            }
            output.put(JSONOutputToken.objectEnd);
        }
        else static if (isIterable!Type)
        {
            output.put(JSONOutputToken.arrayStart);
            foreach (element; value)
            {
                encodeJsonStream!(typeof(element), transform, Range, attributes)(output, element);
            }
            output.put(JSONOutputToken.arrayEnd);
        }
        else static if (is(Type : Nullable!U, U))
        {
            if (value.isNull)
            {
                output.put(JSONOutputToken(null));
            }
            else
            {
                encodeJsonStream!(U, transform, Range, attributes)(output, value.get);
            }
        }
        else static if (__traits(compiles, { import std.sumtype : SumType; static assert(isInstanceOf!(SumType, T)); }))
        {
            import std.sumtype : match, SumType;

            value.match!(
                staticMap!(
                    a => encodeJsonStream!(typeof(a), transform, Range, attributes)(output, a),
                    TemplateArgsOf!T));
        }
        else
        {
            static if (is(Type == class))
            {
                if (value is null)
                {
                    output.put(JSONOutputToken(null));
                    return;
                }
            }

            output.put(JSONOutputToken.objectStart);
            encodeStruct!(T, transform, Range, attributes)(output, value);
            output.put(JSONOutputToken.objectEnd);
        }
    }
}

private void encodeStruct(Type, alias transform, Range, attributes...)(ref Range output, const Type value)
in
{
    static if (is(T == class))
    {
        assert(parameter !is null);
    }
}
do
{
    import boilerplate.util : optionallyRemoveTrailingUnderline, removeTrailingUnderline, udaIndex;
    import std.meta : AliasSeq, anySatisfy, ApplyLeft;
    import std.traits : fullyQualifiedName;

    static assert(
        __traits(hasMember, Type, "ConstructorInfo"),
        fullyQualifiedName!Type ~ " does not have a boilerplate constructor!");

    alias Info = Tuple!(string, "builderField", string, "constructorField");

    static foreach (string constructorField; Type.ConstructorInfo.fields)
    {{
        enum builderField = optionallyRemoveTrailingUnderline!constructorField;
        alias constructorFieldSymbol = __traits(getMember, Type.ConstructorInfo.FieldInfo, constructorField);
        alias MemberType = constructorFieldSymbol.Type;
        enum useDefault = constructorFieldSymbol.useDefault;
        const MemberType memberValue = __traits(getMember, value, builderField);

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

        alias attributes = AliasSeq!(constructorFieldSymbol.attributes);

        static if (udaIndex!(Json, attributes) != -1)
        {
            enum name = attributes[udaIndex!(Json, attributes)].name;
        }
        else
        {
            enum name = constructorField.removeTrailingUnderline;
        }

        if (includeMember)
        {
            auto finalMemberValue = mixin(getMemberValue);

            enum sameField(string lhs, string rhs)
                = optionallyRemoveTrailingUnderline!lhs== optionallyRemoveTrailingUnderline!rhs;
            enum memberIsAliasedToThis = anySatisfy!(
                ApplyLeft!(sameField, constructorField),
                __traits(getAliasThis, Type));

            static if (memberIsAliasedToThis)
            {
                encodeStruct!(typeof(finalMemberValue), transform, Range, attributes)(
                    output, finalMemberValue);
            }
            else
            {
                output.put(JSONOutputToken.key(name));
                encodeJsonStream!(typeof(finalMemberValue), transform, Range, attributes)(
                    output, finalMemberValue);
            }
        }
        else if (!useDefault)
        {
            output.put(JSONOutputToken.key(name));
            output.put(JSONOutputToken(null));
        }
    }}
}

private void encodeJsonStream(T : JSONValue, alias transform, Range, attributes...)(
    ref Range output, const T value)
{
    output.put(JSONOutputToken(value));
}

private void encodeValue(T, Range)(ref Range output, T value)
if (!is(T: Nullable!Arg, Arg))
{
    import std.conv : to;
    import text.xml.Convert : Convert;

    static if (is(T == enum))
    {
        output.put(JSONOutputToken(value.to!string));
    }
    else static if (isBoolean!T || isIntegral!T || isFloatingPoint!T || isSomeString!T)
    {
        output.put(JSONOutputToken(value));
    }
    else static if (is(T == typeof(null)))
    {
        output.put(JSONOutputToken(null));
    }
    else static if (is(T : const SysTime))
    {
        // fastpath for SysTime (it's a very common type)
        SysTime noFractionalSeconds = value;

        noFractionalSeconds.fracSecs = 0.seconds;
        output.put(JSONOutputToken(noFractionalSeconds));
    }
    else static if (__traits(compiles, Convert.toString(value)))
    {
        output.put(JSONOutputToken(Convert.toString(value)));
    }
    else
    {
        static assert(false, "Cannot encode " ~ T.stringof ~ " as value");
    }
}

// An output range over JSONOutputToken that results in a string.
private struct StringSink
{
    private Stack!bool comma;

    private Appender!string output;

    static StringSink opCall()
    {
        StringSink sink;
        sink.output = appender!string();
        sink.comma.push(false);
        return sink;
    }

    public void put(JSONOutputToken token)
    {
        import funkwerk.stdx.data.json.generator : escapeString;

        with (JSONOutputToken.Kind)
        {
            if (token.kind != arrayEnd && token.kind != objectEnd)
            {
                if (this.comma.head)
                {
                    this.output.put(",");
                }
                this.comma.head = true;
            }
            final switch (token.kind)
            {
                case arrayStart:
                    this.output.put("[");
                    this.comma.push(false);
                    break;
                case arrayEnd:
                    this.output.put("]");
                    this.comma.pop;
                    break;
                case objectStart:
                    this.output.put("{");
                    this.comma.push(false);
                    break;
                case objectEnd:
                    this.output.put("}");
                    this.comma.pop;
                    break;
                case key:
                    this.output.put("\"");
                    this.output.escapeString(token.key);
                    this.output.put("\":");
                    // Suppress the next element's comma.
                    this.comma.head = false;
                    break;
                case bool_:
                    this.output.put(token.bool_ ? "true" : "false");
                    break;
                case long_:
                    this.output.formattedWrite("%s", token.long_);
                    break;
                case double_:
                    this.output.formattedWrite("%s", token.double_);
                    break;
                case string_:
                    this.output.put("\"");
                    this.output.escapeString(token.string_);
                    this.output.put("\"");
                    break;
                case sysTime:
                    this.output.put("\"");
                    token.sysTime.toISOExtString(this.output);
                    this.output.put("\"");
                    break;
                case null_:
                    this.output.put("null");
                    break;
                case json:
                    this.output.put(token.json.toJSON);
                    break;
            }
        }
    }
}

// An output range over JSONOutputToken that results in a JSONValue.
private struct JSONValueSink
{
    private alias KeyValuePair = Tuple!(string, "key", JSONValue, "value");

    private Stack!KeyValuePair stack;

    static JSONValueSink opCall()
    {
        JSONValueSink sink;
        // For convenience, wrap the parse stream in [].
        sink.stack.push(KeyValuePair(string.init, JSONValue(JSONValue[].init)));
        return sink;
    }

    public void put(JSONOutputToken token)
    {
        with (JSONOutputToken.Kind)
        {
            final switch (token.kind)
            {
                case arrayStart:
                    this.stack.push(KeyValuePair(string.init, JSONValue(JSONValue[].init)));
                    break;
                case arrayEnd:
                    assert(head.value.type == JSONType.array);
                    addValue(pop);
                    break;
                case objectStart:
                    this.stack.push(KeyValuePair(string.init, JSONValue((JSONValue[string]).init)));
                    break;
                case objectEnd:
                    assert(head.value.type == JSONType.object);
                    addValue(pop);
                    break;
                case key:
                    assert(head.key.empty);
                    head.key = token.key;
                    break;
                case bool_:
                    addValue(JSONValue(token.bool_));
                    break;
                case long_:
                    addValue(JSONValue(token.long_));
                    break;
                case double_:
                    addValue(JSONValue(token.double_));
                    break;
                case string_:
                    addValue(JSONValue(token.string_));
                    break;
                case sysTime:
                    addValue(JSONValue(token.sysTime.toISOExtString));
                    break;
                case null_:
                    addValue(JSONValue(null));
                    break;
                case json:
                    addValue(token.json);
                    break;
            }
        }
    }

    public JSONValue value()
    {
        assert(this.stack.length == 1 && head.value.type == JSONType.array && head.value.array.length == 1);
        return head.value.array[0];
    }

    private ref KeyValuePair head() return
    {
        return this.stack.head;
    }

    private JSONValue pop()
    {
        assert(head.key.empty);

        return this.stack.pop.value;
    }

    private void addValue(JSONValue value)
    {
        if (head.value.type == JSONType.array)
        {
            head.value.array ~= value;
        }
        else if (head.value.type == JSONType.object)
        {
            assert(!head.key.empty);
            head.value.object[head.key] = value;
            head.key = null;
        } else {
            assert(false);
        }
    }
}

// Why is this not built in, D!
private struct Stack(T)
{
    T[] backing;

    size_t length;

    void push(T value)
    {
        if (this.length < this.backing.length)
        {
            this.backing[this.length++] = value;
        }
        else
        {
            this.backing ~= value;
            this.length++;
        }
    }

    T pop()
    in (this.length > 0)
    {
        return this.backing[--this.length];
    }

    ref T head()
    in (this.length > 0)
    {
        return this.backing[this.length - 1];
    }
}

///
@("stack of ints")
unittest
{
    import dshould : be, should;

    Stack!int stack;
    stack.push(2);
    stack.push(3);
    stack.push(4);
    stack.pop.should.be(4);
    stack.pop.should.be(3);
    stack.pop.should.be(2);
}

struct JSONOutputToken
{
    enum Kind
    {
        objectStart,
        objectEnd,
        arrayStart,
        arrayEnd,
        key,
        bool_,
        long_,
        double_,
        string_,
        sysTime,
        null_,
        json,
    }
    Kind kind;
    union
    {
        bool bool_;
        long long_;
        double double_;
        string string_;
        SysTime sysTime;
        string key_;
        JSONValue json;
    }

    this(Kind kind)
    {
        this.kind = kind;
    }

    static foreach (member; ["objectStart", "objectEnd", "arrayStart", "arrayEnd"])
    {
        mixin(format!q{
            static JSONOutputToken %s()
            {
                return JSONOutputToken(Kind.%s);
            }
        }(member, member));
    }

    string key()
    in (this.kind == Kind.key)
    {
        return this.key_;
    }

    static JSONOutputToken key(string key)
    {
        auto result = JSONOutputToken(Kind.key);

        result.key_ = key;
        return result;
    }

    static foreach (member; ["bool_", "long_", "double_", "string_", "sysTime", "json"])
    {
        mixin(format!q{
            this(typeof(this.%s) value)
            {
                this.kind = Kind.%s;
                this.%s = value;
            }
        }(member, member, member));
    }

    this(typeof(null) nullptr)
    {
        this.kind = Kind.null_;
    }
}
