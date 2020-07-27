module text.xml.Validation;

version(unittest) import dshould;
import dxml.parser;
static import dxml.util;
import std.algorithm;
import std.array;
import std.exception;
import std.range;
import std.string;
import text.xml.Convert;
import text.xml.Tree;
import text.xml.XmlException;

alias nodes = filter!(node => node.type == XmlNode.Type.element);

/**
 * Throws: XmlException on validity violation.
 */
void enforceName(XmlNode node, string name) pure @safe
in (node.type == XmlNode.Type.element)
{
    enforce!XmlException(node.tag == name,
        format!`element "%s": unexpected element (expected is "%s")`(node.tag, name));
}

/**
 * Throws: XmlException on validity violation.
*/
void enforceFixed(XmlNode node, string name, string expected) pure @safe
{
    const actual = node.require!string(name);

    enforce!XmlException(actual == expected,
        format!`element "%s": unexpected %s "%s" (expected is "%s")`(node.tag, name, actual, expected));
}

/**
 * Throws: XmlException on validity violation.
 */
XmlNode requireChild(XmlNode node, string name)
in (node.type == XmlNode.Type.element)
out (resultNode; resultNode.type == XmlNode.Type.element)
{
    auto nodes = node.requireChildren(name);

    enforce!XmlException(nodes.dropOne.empty,
        format!`element "%s": unexpected extra child element "%s"`(node.tag, name));

    return nodes.front;
}

/**
 * Throws: XmlException on validity violation.
 */
XmlNode requireChild(XmlNode node)
in (node.type == XmlNode.Type.element)
out (resultNode; resultNode.type == XmlNode.Type.element)
{
    auto nodes = node.requireChildren;

    enforce!XmlException(nodes.dropOne.empty,
        format!`element "%s": unexpected extra child element "%s"`(node.tag, nodes.front.tag));

    return nodes.front;
}

/**
 * Throws: XmlException on validity violation.
 */
auto requireChildren(XmlNode node, string name)
in (node.type == XmlNode.Type.element)
out (nodes; nodes.save.all!(node => node.type == XmlNode.Type.element))
out (nodes; !nodes.empty)
{
    auto nodes = node.findChildren(name);

    enforce!XmlException(!nodes.empty,
        format!`element "%s": required child element "%s" is missing`(node.tag, name));

    return nodes;
}

/**
 * Throws: XmlException on validity violation.
 */
XmlNode[] requireChildren(XmlNode node)
in (node.type == XmlNode.Type.element)
out (nodes; nodes.all!(node => node.type == XmlNode.Type.element))
out (nodes; !nodes.empty)
{
    XmlNode[] nodes = node.children.nodes.array;

    enforce!XmlException(!nodes.empty,
        format!`element "%s": required child element is missing`(node.tag));

    return nodes;
}

/**
 * Throws: XmlException on validity violation.
 */
XmlNode requireDescendant(XmlNode node, string name) pure @safe
in (node.type == XmlNode.Type.element)
out (resultNode; resultNode.type == XmlNode.Type.element)
{
    auto nodes = node.requireDescendants(name);
    XmlNode front = nodes.front;

    nodes.popFront;
    enforce!XmlException(nodes.empty,
        format!`element "%s": unexpected extra descendant element "%s"`(node.tag, name));

    return front;
}

/**
 * Throws: XmlException on validity violation.
 */
auto requireDescendants(XmlNode node, string name) pure @safe
in (node.type == XmlNode.Type.element)
{
    auto nodes = node.findDescendants(name);

    enforce!XmlException(!nodes.empty,
        format!`element "%s": required descendant element "%s" is missing`(node.tag, name));

    return nodes;
}

auto findDescendants(XmlNode node, string name) nothrow pure @safe
out (nodes; nodes.all!(node => node.type == XmlNode.Type.element))
{
    void traverse(XmlNode node, ref Appender!(XmlNode[]) result)
    {
        foreach (child; node.children.nodes)
        {
            if (child.tag == name)
            {
                result ~= child;
            }
            traverse(child, result);
        }
    }

    auto result = appender!(XmlNode[]);

    traverse(node, result);
    return result.data;
}

alias require = requireImpl!"to";
alias requirePositive = requireImpl!"toPositive";
alias requireTime = requireImpl!"toTime";

template requireImpl(string conversion)
{
    /**
     * Throws: XmlException on validity violation.
     */
    T requireImpl(T)(XmlNode node)
    in (node.type == XmlNode.Type.element)
    {
        string text = dxml.util.decodeXML(node.text);

        static if (is(T == string))
        {
            if (text.sameHead(node.text))
            {
                text = text.idup;
            }
        }

        try
        {
            return mixin("Convert." ~ conversion ~ "!T(text)");
        }
        catch (XmlException exception)
        {
            throw new XmlException(format!`element "%s": %s`(node.tag, exception.msg));
        }
    }

    /**
     * Throws: XmlException on validity violation.
     */
    T requireImpl(T)(XmlNode node, string name)
    in (node.type == XmlNode.Type.element)
    {
        enforce!XmlException(name in node.attributes,
            format!`element "%s": required attribute "%s" is missing`(node.tag, name));

        string value = dxml.util.decodeXML(node.attributes[name]);

        static if (is(T == string))
        {
            if (value.sameHead(node.attributes[name]))
            {
                value = value.idup;
            }
        }

        try
        {
            return mixin("Convert." ~ conversion ~ "!T(value)");
        }
        catch (XmlException exception)
        {
            throw new XmlException(format!`element "%s", attribute "%s": %s`(node.tag, name, exception.msg));
        }
    }

    /**
     * Throws: XmlException on validity violation.
     */
    T requireImpl(T)(XmlNode node, string name, lazy T fallback)
    in (node.type == XmlNode.Type.element)
    {
        if (name !in node.attributes)
        {
            return fallback;
        }

        string value = dxml.util.decodeXML(node.attributes[name]);

        static if (is(T == string))
        {
            if (value.sameHead(node.attributes[name]))
            {
                value = value.idup;
            }
        }

        try
        {
            return mixin("Convert." ~ conversion ~ "!T(value)");
        }
        catch (XmlException exception)
        {
            throw new XmlException(format!`element "%s", attribute "%s": %s`(node.tag, name, exception.msg));
        }
    }
}

public string normalize(string value) pure @safe
{
    return value.split.join(" ");
}

@("normalize strings with newlines and tabs")
@safe unittest
{
    normalize("\tfoo\r\nbar    baz ").should.equal("foo bar baz");
}

@("normalize allocates memory even in the trivial case")
unittest
{
    const foo = "foo";

    normalize(foo).ptr.should.not.be(foo.ptr);
}
