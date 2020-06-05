module text.xml.WriterTest;

import dshould;
import std.array;
import std.string;
import std.typecons;
import text.xml.Parser;
import text.xml.Tree;
import text.xml.Writer;

@("XML is pretty printed")
unittest
{
    // given
    const expected = `
        <root>
            <Foo>23</Foo>
            <Bar value="23"/>
        </root>
        `.outdent.stripLeft;
    auto xmlRoot = parse(expected);

    // when
    auto sink = appender!string;
    auto writer = customXmlWriter!(Yes.pretty)(sink);
    writer.write(xmlRoot);

    // then
    sink.data.should.equal(expected);
}

@("XML contains no trailing newline")
unittest
{
    // given
    auto xmlRoot = XmlNode(XmlNode.Type.element, "root");

    // when
    auto sink = appender!string;
    auto writer = customXmlWriter!(No.pretty)(sink);
    writer.write(xmlRoot);

    // then
    const expected = `<root/>`;

    sink.data.should.equal(expected);
}
