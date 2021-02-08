module text.xml.EncodeTest;

import boilerplate;
import dshould;
import dxml.writer;
import std.array;
import std.datetime;
import std.typecons;
import sumtype : match, SumType;
import text.xml.Encode;
import text.xml.Tree;
import text.xml.Writer;
import text.xml.Xml;

@("fields tagged as Element are encoded as XML elements")
unittest
{
    const expected =
        `<root>` ~
            `<IntValueElement>23</IntValueElement>` ~
            `<StringValueElement>FOO</StringValueElement>` ~
            `<BoolValueElement>true</BoolValueElement>` ~
            `<NestedElement>` ~
                `<Element>BAR</Element>` ~
            `</NestedElement>` ~
            `<ArrayElement>1</ArrayElement>` ~
            `<ArrayElement>2</ArrayElement>` ~
            `<ArrayElement>3</ArrayElement>` ~
            `<DateElement>2000-01-02</DateElement>` ~
            `<SysTimeElement>2000-01-02T10:00:00Z</SysTimeElement>` ~
            `<ContentElement attribute="hello">World</ContentElement>` ~
        `</root>`
    ;

    // given
    const value = (){
        import text.time.Convert : Convert;

        with (Value.Builder())
        {
            intValue = 23;
            stringValue = "FOO";
            boolValue = true;
            nestedValue = NestedValue("BAR");
            arrayValue = [1, 2, 3];
            dateValue = Date(2000, 1, 2);
            sysTimeValue = SysTime.fromISOExtString("2000-01-02T10:00:00Z");
            contentValue = ContentValue("hello", "World");
            return value;
        }
    }();

    // when
    auto text = encode(value);

    // then
    text.should.equal(expected);
}

@("fields tagged as Attribute are encoded as XML attributes")
unittest
{
    const expected = `<root intAttribute="23"/>`;

    // given
    const valueWithAttribute = ValueWithAttribute(23);

    // when
    auto text = encode(valueWithAttribute);

    // then
    text.should.equal(expected);
}

@("custom encoders are used on fields")
unittest
{
    // given
    const value = ValueWithEncoders("bla", "bla");

    // when
    auto text = encode(value);

    // then
    const expected = `<root asFoo="foo"><asBar>bar</asBar></root>`;

    text.should.equal(expected);
}

@("custom encoders are used on types")
unittest
{
    @(Xml.Element("root"))
    struct Value
    {
        @(Xml.Element("foo"))
        EncodeNodeTestType foo;

        @(Xml.Attribute("bar"))
        EncodeAttributeTestType bar;
    }

    // given
    const value = Value(EncodeNodeTestType(), EncodeAttributeTestType());

    // when
    auto text = .encode(value);

    // then
    const expected = `<root bar="123"><foo>123</foo></root>`;

    text.should.equal(expected);
}

@("custom encoder on Nullable element")
unittest
{
    @(Xml.Element("root"))
    struct Value
    {
        @(Xml.Element("foo"))
        @(Xml.Encode!encodeNodeTestType)
        Nullable!EncodeNodeTestType foo;
    }

    // given
    const value = Value(Nullable!EncodeNodeTestType());

    // when
    const text = .encode(value);

    // then
    const expected = `<root/>`;

    text.should.equal(expected);
}

@("fields with characters requiring predefined entities")
unittest
{
    @(Xml.Element("root"))
    struct Value
    {
        @(Xml.Attribute("foo"))
        string foo;

        @(Xml.Element("bar"))
        string bar;
    }

    // given
    enum invalidInAttr = `<&"`;
    enum invalidInText = `<&]]>`;
    const value = Value(invalidInAttr, invalidInText);

    // when
    auto text = .encode(value);

    // then
    const expected = `<root foo="&lt;&amp;&quot;"><bar>&lt;&amp;]]&gt;</bar></root>`;

    text.should.equal(expected);
}

@("regression: encodes optional elements with arrays")
unittest
{
    struct Nested
    {
        @(Xml.Element("item"))
        string[] items;
    }

    @(Xml.Element("root"))
    struct Root
    {
        @(Xml.Element("foo"))
        Nullable!Nested nested;
    }

    // given
    const root = Root(Nullable!Nested(Nested(["foo", "bar"])));

    // when
    const text = root.encode;

    // then
    text.should.equal(`<root><foo><item>foo</item><item>bar</item></foo></root>`);
}

@(Xml.Element("root"))
private struct Value
{
    @(Xml.Element("IntValueElement"))
    public int intValue;

    @(Xml.Element("StringValueElement"))
    public string stringValue;

    @(Xml.Element("BoolValueElement"))
    public bool boolValue;

    @(Xml.Element("NestedElement"))
    public NestedValue nestedValue;

    // Fails to compile when serializing const values
    @(Xml.Element("ArrayElement"))
    public int[] arrayValue;

    @(Xml.Element("DateElement"))
    public Date dateValue;

    @(Xml.Element("SysTimeElement"))
    public SysTime sysTimeValue;

    @(Xml.Element("ContentElement"))
    public ContentValue contentValue;

    mixin (GenerateAll);
}

private struct NestedValue
{
    @(Xml.Element("Element"))
    public string value;

    mixin (GenerateAll);
}

private struct ContentValue
{
    @(Xml.Attribute("attribute"))
    public string attribute;

    @(Xml.Text)
    public string content;

    mixin (GenerateAll);
}

@(Xml.Element("root"))
private struct ValueWithAttribute
{
    @(Xml.Attribute("intAttribute"))
    public int value;

    mixin(GenerateAll);
}

@(Xml.Element("root"))
private struct ValueWithEncoders
{
    @(Xml.Attribute("asFoo"))
    @(Xml.Encode!asFoo)
    public string foo;

    @(Xml.Element("asBar"))
    @(Xml.Encode!asBar)
    public string bar;

    static string asFoo(string field)
    {
        field.should.equal("bla");

        return "foo";
    }

    static void asBar(ref XMLWriter!(Appender!string) writer, string field)
    {
        field.should.equal("bla");

        writer.writeText("bar", Newline.no);
    }

    mixin(GenerateThis);
}

package void encodeNodeTestType(ref XMLWriter!(Appender!string) writer, EncodeNodeTestType)
{
    writer.writeText("123", Newline.no);
}

@(Xml.Encode!encodeNodeTestType)
package struct EncodeNodeTestType
{
}

package string encodeAttributeTestType(EncodeAttributeTestType)
{
    return "123";
}

@(Xml.Encode!encodeAttributeTestType)
package struct EncodeAttributeTestType
{
}

@("struct with optional date attribute")
unittest
{
    @(Xml.Element("root"))
    static struct NullableAttributes
    {
        @(Xml.Attribute("date"))
        @(This.Default)
        Nullable!Date date;

        mixin(GenerateThis);
    }

    // given
    const root = NullableAttributes();

    // when
    const text = root.encode;

    // then
    text.should.equal(`<root/>`);
}

@("SumType")
unittest
{
    with (SumTypeFixture)
    {
        alias Either = SumType!(A, B);

        @(Xml.Element("root"))
        static struct Struct
        {
            Either field;

            mixin(GenerateThis);
        }

        // given/when/then
        Struct(Either(A(5))).encode.should.equal(`<root><A a="5"/></root>`);

        Struct(Either(B(3))).encode.should.equal(`<root><B b="3"/></root>`);
    }
}

@("SumType with arrays")
unittest
{
    with (SumTypeFixture)
    {
        alias Either = SumType!(A[], B[]);

        @(Xml.Element("root"))
        static struct Struct
        {
            Either field;

            mixin(GenerateThis);
        }

        // given/when/then
        Struct(Either([A(5), A(6)])).encode.should.equal(`<root><A a="5"/><A a="6"/></root>`);
    }
}

private struct SumTypeFixture
{
    @(Xml.Element("A"))
    static struct A
    {
        @(Xml.Attribute("a"))
        int a;
    }

    @(Xml.Element("B"))
    static struct B
    {
        @(Xml.Attribute("b"))
        int b;
    }
}

@("attribute/element without specified name")
unittest
{
    struct Value
    {
        @(Xml.Attribute)
        private int value_;

        mixin(GenerateThis);
    }

    @(Xml.Element)
    struct Container
    {
        @(Xml.Element)
        immutable(Value)[] values;

        mixin(GenerateThis);
    }

    // when
    const text = Container([Value(1), Value(2), Value(3)]).encode;

    // then
    text.should.equal(`<Container><Value value="1"/><Value value="2"/><Value value="3"/></Container>`);
}
