module text.xml.DecodeTest;

import boilerplate;
import dshould;
import std.datetime;
import std.sumtype : match, SumType;
import text.xml.Decode;
import text.xml.Tree;
import text.xml.Xml;

@("XML elements are decoded to various types")
unittest
{
    // given
    const text = `
        <root>
            <IntValueElement>23</IntValueElement>
            <StringValueElement>FOO</StringValueElement>
            <BoolValueElement>true</BoolValueElement>
            <NestedElement>
                <Element>BAR</Element>
            </NestedElement>
            <ArrayElement>1</ArrayElement>
            <ArrayElement>2</ArrayElement>
            <ArrayElement>3</ArrayElement>
            <DateElement>2000-01-02</DateElement>
            <SysTimeElement>2000-01-02T10:00:00Z</SysTimeElement>
            <ContentElement attribute="hello">World</ContentElement>
        </root>
        `;

    // when
    auto value = decode!Value(text);

    // then
    auto expected = Value.Builder();

    with (expected)
    {
        intValue = 23;
        stringValue = "FOO";
        boolValue = true;
        nestedValue = NestedValue("BAR");
        arrayValue = [1, 2, 3];
        dateValue = Date(2000, 1, 2);
        sysTimeValue = SysTime.fromISOExtString("2000-01-02T10:00:00Z");
        contentValue = ContentValue("hello", "World");
    }

    value.should.equal(expected.value);
}

@("XML attributes are decoded")
unittest
{
    const expected = ValueWithAttribute(23);

    // given
    const text = `<root intAttribute="23"/>`;

    // when
    auto value = decode!ValueWithAttribute(text);

    // then
    value.should.equal(expected);
}

@("custom decoders are used on fields")
unittest
{
    // given
    const text = `<root asFoo="bla"><asBar>bla</asBar></root>`;

    // when
    auto value = decode!ValueWithDecoders(text);

    // then
    const expected = ValueWithDecoders("foo", "bar");

    value.should.equal(expected);
}

@("custom decoders are used on types")
unittest
{
    @(Xml.Element("root"))
    struct Value
    {
        @(Xml.Element("foo"))
        DecodeNodeTestType foo;

        @(Xml.Attribute("bar"))
        DecodeAttributeTestType bar;

        mixin(GenerateAll);
    }

    // given
    const text = `<root bar="123"><foo>123</foo></root>`;

    // when
    auto value = decode!Value(text);

    // then
    const expected = Value(DecodeNodeTestType("foo"), DecodeAttributeTestType("bar"));

    value.should.equal(expected);
}

@("field is Nullable")
unittest
{
    import std.typecons : Nullable;

    @(Xml.Element("root"))
    struct Value
    {
        @(Xml.Element("foo"))
        @(This.Default)
        Nullable!int foo;

        mixin(GenerateAll);
    }

    // given
    const text = `<root></root>`;

    // when
    auto value = decode!Value(text);

    // Then
    const expected = Value(Nullable!int());

    value.should.equal(expected);
}

@("field and decoder are Nullable")
unittest
{
    import std.typecons : Nullable;

    static Nullable!int returnsNull(const XmlNode)
    {
        return Nullable!int();
    }

    @(Xml.Element("root"))
    struct Value
    {
        @(Xml.Element("foo"))
        @(Xml.Decode!returnsNull)
        @(This.Default)
        Nullable!int foo;

        mixin(GenerateAll);
    }

    // given
    const text = `<root><foo>5</foo></root>`;

    // when
    auto value = decode!Value(text);

    // then
    const expected = Value(Nullable!int());

    value.should.equal(expected);
}

@("Element with whitespace around content")
unittest
{
    @(Xml.Element("root"))
    struct Value
    {
        @(Xml.Element("Content"))
        string content;

        mixin(GenerateAll);
    }

    // given
    const text = `<root><Content>  Foo  Bar  </Content></root>`;

    // when
    const value = decode!Value(text);

    // then
    value.content.should.equal("Foo Bar");
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

        mixin(GenerateThis);
    }

    // given
    const text = `<root foo="&lt;&amp;&quot;"><bar>&lt;&amp;]]&gt;</bar></root>`;

    // when
    const value = decode!Value(text);

    // then
    value.foo.should.equal(`<&"`);
    value.bar.should.equal(`<&]]>`);
}

@("fields with reserved names")
unittest
{
    @(Xml.Element("root"))
    struct Value
    {
        @(Xml.Attribute("version"))
        string version_;

        mixin(GenerateThis);
    }

    // given
    const text = `<root version="1.0.0"/>`;

    // when
    const value = decode!Value(text);

    // then
    value.version_.should.equal(`1.0.0`);
}

@("field aliased to this")
unittest
{
    struct Nested
    {
        @(Xml.Attribute("foo"))
        string foo;

        mixin(GenerateThis);
    }

    @(Xml.Element("Value"))
    struct Value
    {
        public Nested nested;

        alias nested this;

        mixin(GenerateThis);
    }

    // given
    const text = `<Value foo="bar"/>`;

    // when
    const value = decode!Value(text);

    // then
    value.foo.should.equal("bar");
}

@("SumType")
unittest
{
    import text.xml.XmlException : XmlException;
    with (SumTypeFixture)
    {
        alias Either = SumType!(A, B);

        @(Xml.Element("Value"))
        struct Value
        {
            /**
            * One of A or B.
            *
            * equivalent to:
            * ---
            * @(Xml.Element("A"))
            * @(This.Default)
            * Nullable!A a;
            *
            * @(Xml.Element("B"))
            * @(This.Default)
            * Nullable!B b;
            *
            * invariant(!a.isNull && b.isNull || a.isNull && !b.isNull);
            * ---
            */
            Either field;

            mixin(GenerateThis);
        }

        // given/when/then
        decode!Value(`<Value><A a="5"/></Value>`).should.equal(Value(Either(A(5))));

        decode!Value(`<Value><B b="3"/></Value>`).should.equal(Value(Either(B(3))));

        decode!Value(`<Value/>`).should.throwAn!XmlException
            (`Element "Value": no child element of "A", "B"`);

        decode!Value(`<Value><A a="5"/><B b="3"/></Value>`).should.throwAn!XmlException
            (`Element "Value": contained more than one of "A", "B"`);
    }
}

@("SumType of arrays")
unittest
{
    import text.xml.XmlException : XmlException;

    with (SumTypeFixture)
    {
        alias Either = SumType!(A[], B[]);

        @(Xml.Element("Value"))
        struct Value
        {
            /**
            * either at least one A or at least one B
            *
            * equivalent to:
            * ---
            * @(Xml.Element("A"))
            * @(This.Default)
            * A[] as;
            *
            * @(Xml.Element("B"))
            * @(This.Default)
            * B[] bs;
            *
            * invariant(!a.empty && b.empty || a.empty && !b.empty);
            * ---
            */
            Either field;

            mixin(GenerateThis);
        }

        // given/when/then
        decode!Value(`<Value><A a="5"/></Value>`).should.equal(Value(Either([A(5)])));

        decode!Value(`<Value><A a="5"/><A a="6"/></Value>`).should.equal(Value(Either([A(5), A(6)])));

        decode!Value(`<Value/>`).should.throwAn!XmlException
            (`Element "Value": no child element of "A[]", "B[]"`);

        decode!Value(`<Value><A a="5"/><B b="3"/></Value>`).should.throwAn!XmlException
            (`Element "Value": contained more than one of "A[]", "B[]"`);
    }
}

@("array of SumTypes")
unittest
{
    import text.xml.XmlException : XmlException;

    with (SumTypeFixture)
    {
        alias Either = SumType!(A, B);

        @(Xml.Element("Value"))
        struct Value
        {
            // any number of either A or B
            Either[] entries;

            mixin(GenerateThis);
        }

        // given/when/then
        decode!Value(`<Value><A a="5"/></Value>`).should.equal(Value([Either(A(5))]));

        decode!Value(`<Value><B b="5"/><A a="6"/></Value>`).should.equal(Value([Either(B(5)), Either(A(6))]));

        decode!Value(`<Value/>`).should.equal(Value([]));
    }
}

private struct SumTypeFixture
{
    @(Xml.Element("A"))
    static struct A
    {
        @(Xml.Attribute("a"))
        int a;

        mixin(GenerateThis);
    }

    @(Xml.Element("B"))
    static struct B
    {
        @(Xml.Attribute("b"))
        int b;

        mixin(GenerateThis);
    }
}

@("immutable arrays")
unittest
{
    struct Value
    {
        @(Xml.Attribute("value"))
        int value;

        mixin(GenerateThis);
    }

    @(Xml.Element("Container"))
    struct Container
    {
        @(Xml.Element("Value"))
        immutable(Value)[] values;

        mixin(GenerateThis);
    }

    // when
    auto value = decode!Container(`<Container><Value value="1"/><Value value="2"/><Value value="3"/></Container>`);

    // then
    auto expected = Container([Value(1), Value(2), Value(3)]);

    value.should.equal(expected);
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
    auto value = decode!Container(`<Container><Value value="1"/><Value value="2"/><Value value="3"/></Container>`);

    // then
    auto expected = Container([Value(1), Value(2), Value(3)]);

    value.should.equal(expected);
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

    mixin(GenerateThis);
}

@(Xml.Element("root"))
private struct ValueWithDecoders
{
    @(Xml.Attribute("asFoo"))
    @(Xml.Decode!asFoo)
    public string foo;

    @(Xml.Element("asBar"))
    @(Xml.Decode!asBar)
    public string bar;

    static string asFoo(string attribute)
    {
        attribute.should.equal("bla");

        return "foo";
    }

    static string asBar(XmlNode node)
    {
        import std.string : strip;

        node.text.strip.should.equal("bla");

        return "bar";
    }

    mixin(GenerateThis);
}

@(Xml.Element)
@(Xml.Decode!decodeNodeTestType)
package struct DecodeNodeTestType
{
    string value;
}

package DecodeNodeTestType decodeNodeTestType(XmlNode node)
{
    return DecodeNodeTestType("foo");
}

@(Xml.Attribute)
@(Xml.Decode!decodeAttributeTestType)
package struct DecodeAttributeTestType
{
    string value;
}

package DecodeAttributeTestType decodeAttributeTestType(string)
{
    return DecodeAttributeTestType("bar");
}
