module text.json.EncodeTest;

import boilerplate;
import dshould;
import std.datetime;
import std.json;
import text.json.Encode;
import text.json.Json;

// All the tests are executed with both `encodeJson` (encodes to a JSONValue)
// and `encode` (encodes to a string).
static foreach (bool useEncodeJson; [false, true])
{
    mixin encodeTests!(useEncodeJson);
}

template encodeTests(bool useEncodeJson)
{
    static if (useEncodeJson)
    {
        enum prefix = "encodeJson:";

        template testEncode(Args...)
        {
            JSONValue testEncode(T)(const T value)
            {
                return value.encodeJson!(Args);
            }
        }
    }
    else
    {
        enum prefix = "encode:";

        template testEncode(Args...)
        {
            JSONValue testEncode(T)(const T value)
            {
                return value.encode!(Args).parseJSON;
            }
        }
    }

    @(prefix ~ "aggregate types are encoded to JSON text")
    unittest
    {
        // given
        const value = (){
            import text.time.Convert : Convert;

            with (Value.Builder())
            {
                intValue = 23;
                stringValue = "FOO";
                boolValue = true;
                nestedValue = NestedValue("Bar");
                arrayValue = [1, 2, 3];
                assocArray = ["foo": NestedValue("bar"), "baz": NestedValue("whee")];
                nestedArray = [NestedValue("Foo"), NestedValue("Bar")];
                dateValue = Date(2000, 1, 2);
                sysTimeValue = SysTime.fromISOExtString("2000-01-02T10:00:00Z");
                return value;
            }
        }();

        // when
        const actual = testEncode(value);

        const expected = `
        {
            "IntValueElement": 23,
            "StringValueElement": "FOO",
            "BoolValueElement": true,
            "NestedElement": {
                "Element": "Bar"
            },
            "ArrayElement": [1, 2, 3],
            "AssocArrayElement": {
                "baz": { "Element": "whee" },
                "foo": { "Element": "bar" }
            },
            "NestedArray": [
                { "Element": "Foo" },
                { "Element": "Bar" }
            ],
            "DateElement": "2000-01-02",
            "SysTimeElement": "2000-01-02T10:00:00Z"
        }
        `.parseJSON;

        // then
        actual.should.equal(expected);
    }

    @(prefix ~ "custom encoders are used on fields")
    unittest
    {
        // given
        const value = ValueWithEncoders("bla", "bla");

        // when
        auto actual = testEncode(value);

        // then
        const expected = `{ "asFoo": "foo", "asBar": "bar" }`.parseJSON;

        actual.should.equal(expected);
    }

    @(prefix ~ "custom encoders are used on a type")
    unittest
    {
        // given
        struct Value
        {
            TypeWithEncoder field;

            mixin(GenerateAll);
        }

        const value = Value(TypeWithEncoder());

        // when
        auto actual = testEncode(value);

        // then
        const expected = `{ "field": "123" }`.parseJSON;

        actual.should.equal(expected);
    }

    @(prefix ~ "enums are encoded as strings")
    unittest
    {
        enum Enum
        {
            A
        }

        struct Value
        {
            Enum field;

            mixin(GenerateAll);
        }

        // given
        const value = Value(Enum.A);

        // when
        const actual = testEncode(value);

        // then
        const expected = `{ "field": "A" }`.parseJSON;

        actual.should.equal(expected);
    }

    @(prefix ~ "alias-this is encoded inline")
    unittest
    {
        struct A
        {
            int value2;

            mixin(GenerateAll);
        }

        struct B
        {
            int value1;

            A a;

            alias a this;

            mixin(GenerateAll);
        }

        // given
        const value = B(3, A(5));

        // when
        const actual = testEncode(value);

        // then
        const expected = `{ "value1": 3, "value2": 5 }`.parseJSON;

        actual.should.equal(expected);
    }

    @(prefix ~ "alias-this is encoded inline for aliased methods")
    unittest
    {
        struct A
        {
            int value2;

            mixin(GenerateAll);
        }

        struct B
        {
            int value1;

            @ConstRead
            A a_;

            mixin(GenerateAll);

            alias a this;
        }

        // given
        const value = B(3, A(5));

        // when
        const actual = testEncode(value);

        // then
        const expected = `{ "value1": 3, "value2": 5 }`.parseJSON;

        actual.should.equal(expected);
    }

    @(prefix ~ "arrays of enums are encoded as strings")
    unittest
    {
        enum Enum
        {
            A,
        }

        struct Value
        {
            Enum[] value;

            mixin(GenerateAll);
        }

        // given
        const value = Value([Enum.A]);

        // when
        auto actual = testEncode(value);

        // then
        const expected = `{ "value": ["A"] }`.parseJSON;

        actual.should.equal(expected);
    }

    @(prefix ~ "transform functions may modify the values that are encoded")
    unittest
    {
        import std.conv : to;

        struct Inner
        {
            int value;

            mixin(GenerateThis);
        }

        struct InnerDto
        {
            string encodedValue;

            mixin(GenerateThis);
        }

        struct Struct
        {
            Inner inner;

            mixin(GenerateThis);
        }

        InnerDto transform(Inner inner)
        {
            return InnerDto(inner.value.to!string);
        }

        // given
        const value = Struct(Inner(5));

        // when
        const actual = testEncode!(Struct, transform)(value);

        // then
        const expected = `{ "inner": { "encodedValue": "5" } }`.parseJSON;

        actual.should.equal(expected);
    }

    @(prefix ~ "transform functions returning JSONValue")
    unittest
    {
        import std.conv : to;

        struct Inner
        {
            int value;

            mixin(GenerateThis);
        }

        struct Struct
        {
            Inner inner;

            mixin(GenerateThis);
        }

        JSONValue transform(Inner inner)
        {
            return JSONValue(inner.value.to!string);
        }

        // given
        const value = Struct(Inner(5));

        // when
        const actual = testEncode!(Struct, transform)(value);

        // then
        const expected = `{ "inner": "5" }`.parseJSON;

        actual.should.equal(expected);
    }

    @(prefix ~ "struct with version_ field")
    unittest
    {
        // given
        struct Value
        {
            int version_;

            mixin(GenerateAll);
        }

        const value = Value(1);

        // when
        auto actual = testEncode(value);

        // then
        const expected = `{ "version": 1 }`.parseJSON;

        actual.should.equal(expected);
    }

    @(prefix ~ "encode class")
    unittest
    {
        // given
        class Value
        {
            int field;

            mixin(GenerateAll);
        }

        const value = new Value(1);

        // when
        auto actual = testEncode(value);

        // then
        const expected = `{ "field": 1 }`.parseJSON;

        actual.should.equal(expected);
    }

    @(prefix ~ "encode null object")
    unittest
    {
        // given
        class Value
        {
            mixin(GenerateAll);
        }

        // when
        const actual = testEncode!Value(null);

        // then
        enum expected = `null`.parseJSON;

        actual.should.equal(expected);
    }

    @(prefix ~ "encode null object with transform")
    unittest
    {
        import std.conv : to;

        JSONValue transform(const Object obj)
        {
            if (obj is null)
            {
                return JSONValue(null);
            }
            assert(false);
        }

        // given
        const Object value = null;

        // when
        const actual = testEncode!(Object, transform)(value);

        // then
        enum expected = `null`.parseJSON;

        actual.should.equal(expected);
    }

    static if (__traits(compiles, { import std.sumtype; }))
    {
        @(prefix ~ "encode std.sumtype")
        unittest
        {
            import std.sumtype : SumType;

            // given
            alias S = SumType!(int, string);

            const value = [S(1), S("foo")];

            // when
            auto actual = testEncode(value);

            // then
            const expected = `[1, "foo"]`.parseJSON;

            actual.should.equal(expected);
        }

        @(prefix ~ "encode std.sumtype with transform function")
        unittest
        {
            import std.sumtype : match, SumType;

            // given
            alias S = SumType!(int, string);

            string transform(const S s)
            {
                return s.match!((int i) => "int", (string s) => "string");
            }

            const value = [S(1), S("foo")];

            // when
            auto actual = testEncode!(S[], transform)(value);

            // then
            enum expected = `["int", "string"]`.parseJSON;

            actual.should.equal(expected);
        }
    }
}

struct NestedValue
{
    @(Json("Element"))
    public string value;

    mixin (GenerateAll);
}

struct Value
{
    @(Json("IntValueElement"))
    public int intValue;

    @(Json("StringValueElement"))
    public string stringValue;

    @(Json("BoolValueElement"))
    public bool boolValue;

    @(Json("NestedElement"))
    public NestedValue nestedValue;

    @(Json("ArrayElement"))
    public const int[] arrayValue;

    @(Json("AssocArrayElement"))
    public NestedValue[string] assocArray;

    @(Json("NestedArray"))
    public NestedValue[] nestedArray;

    @(Json("DateElement"))
    public Date dateValue;

    @(Json("SysTimeElement"))
    public SysTime sysTimeValue;

    mixin (GenerateAll);
}

struct ValueWithEncoders
{
    @(Json("asFoo"))
    @(Json.Encode!asFoo)
    public string foo;

    @(Json("asBar"))
    @(Json.Encode!asBar)
    public string bar;

    static JSONValue asFoo(string field)
    {
        field.should.equal("bla");

        return JSONValue("foo");
    }

    static JSONValue asBar(string field)
    {
        field.should.equal("bla");

        return JSONValue("bar");
    }

    mixin(GenerateThis);
}

@(Json.Encode!encodeTypeWithEncoder)
struct TypeWithEncoder
{
}

JSONValue encodeTypeWithEncoder(TypeWithEncoder)
{
    return JSONValue("123");
}
