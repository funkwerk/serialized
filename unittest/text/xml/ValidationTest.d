module text.xml.ValidationTest;

import dshould;
import std.algorithm;
import std.array;
import text.xml.Parser;
import text.xml.Tree;
import text.xml.Validation;
import text.xml.XmlException;

@("passes when element has required name")
unittest
{
    // given
    XmlNode root = parse("<Element/>");

    // when/then
    root.enforceName("Element");
}

@("fails when element does not have required name")
unittest
{
    // given
    XmlNode root = parse("<element/>");

    // when/then
    root.enforceName("Element").should.throwAn!XmlException;
}

@("passes when required attribute has fixed value")
unittest
{
    // given
    XmlNode root = parse("<Element name='expected'/>");

    // when/then
    root.enforceFixed("name", "expected");
}

@("fails when required attribute does not have fixed value")
unittest
{
    // given
    XmlNode root = parse("<Element name='unexpected'/>");

    // when/then
    root.enforceFixed("name", "expected").should.throwAn!XmlException;
}

@("gets required descendant")
unittest
{
    // given
    XmlNode root = parse("<Element><Child><Descendant/></Child></Element>");

    // when
    XmlNode descendant = root.requireDescendant("Descendant");

    // then
    descendant.tag.should.equal("Descendant");
}

@("fails to get missing descendant")
unittest
{
    // given
    XmlNode root = parse("<Element/>");

    // when/then
    root.requireDescendant("Descendant").should.throwAn!XmlException;
}

@("fails to get non-specific descendant")
unittest
{
    // given
    XmlNode root = parse("<Element><Child><Descendant/></Child><Descendant/></Element>");

    // when/then
    root.requireDescendant("Descendant").should.throwAn!XmlException;

}

@("gets required child by name")
unittest
{
    // given
    XmlNode root = parse("<Element><Child/></Element>");

    // when
    XmlNode child = root.requireChild("Child");

    // then
    child.tag.should.equal("Child");
}

@("fails to get missing child by name")
unittest
{
    // given
    XmlNode root = parse("<Element/>");

    // when/then
    root.requireChild("Child").should.throwAn!XmlException;
}

@("fails to get non-specific child by name")
unittest
{
    // given
    XmlNode root = parse("<Element><Child/><Child/></Element>");

    // when/then
    root.requireChild("Child").should.throwAn!XmlException;

}

@("gets required child")
unittest
{
    // given
    XmlNode root = parse("<Element><Child/></Element>");

    // when
    XmlNode child = root.requireChild;

    // then
    child.tag.should.equal("Child");
}

@("fails to get missing child")
unittest
{
    // given
    XmlNode root = parse("<Element/>");

    // when/then
    root.requireChild.should.throwAn!XmlException;
}

@("fails to get non-specific child")
unittest
{
    // given
    XmlNode root = parse("<Element><Child/><Child/></Element>");

    // when/then
    root.requireChild.should.throwAn!XmlException;

}

@("gets required content")
unittest
{
    // given
    XmlNode root = parse("<Element> -1 </Element>");

    // when
    long value = root.require!long;

    // then
    value.should.equal(-1);
}

@("fails to get invalid content")
unittest
{
    // given
    XmlNode root = parse("<Element> 0xab </Element>");

    // when/then
    root.require!int.should.throwAn!XmlException;
}

@("gets required value")
unittest
{
    // given
    XmlNode root = parse("<Element name=' -1 '/>");

    // when
    long value = root.require!long("name");

    // then
    value.should.equal(-1);
}

@("fails to get missing value")
unittest
{
    // given
    XmlNode root = parse("<Element Name='42'/>");

    // when/then
    root.require!int("name").should.throwAn!XmlException;
}

@("fails to get invalid value")
unittest
{
    // given
    XmlNode root = parse("<Element name='0xab'/>");

    // when/then
    root.require!int("name").should.throwAn!XmlException;
}

@("gets required value instead of fallback")
unittest
{
    // given
    XmlNode root = parse("<Element name=' -1 '/>");

    // when
    long value = root.require!long("name", 42);

    // then
    value.should.equal(-1);
}

@("gets fallback when required value is missing")
unittest
{
    //given
    XmlNode root = parse("<Element Name=' -1 '/>");

    // when
    long value = root.require!long("name", 42);

    // then
    value.should.equal(42);
}

@("fails to get invalid value instead of fallback")
unittest
{
    // given
    XmlNode root = parse("<Element name='0xab'/>");

    // when/then
    root.require!int("name", 42).should.throwAn!XmlException;
}
