module text.xml.ParserTest;

import dshould;
import text.xml.Parser;
import text.xml.Tree;
import text.xml.Validation;
import text.xml.XmlException;

@("parses content")
unittest
{
    // when
    XmlNode node = parse("<!-- comment --><FOO><BAR/></FOO><!-- comment -->");

    // then
    node.findChild("BAR").isNull.should.be(false);
}

@("rejects empty content")
unittest
{
    // when/then
    parse("").should.throwAn!XmlException;
}

@("rejects corrupted content")
unittest
{
    // when/then
    parse("!$#?").should.throwAn!XmlException;
}

@("rejects malformed content")
unittest
{
    // when/then
    parse("Element></Element>").should.throwAn!XmlException;
}
