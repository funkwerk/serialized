module text.xml.Parser;

import dxml.parser;
import dxml.util;
import std.algorithm;
import std.array;
import std.conv;
import std.format;
import std.typecons;
import text.xml.Tree;
import text.xml.XmlException;

/**
 * Parses the specified content as an XML document.
 *
 * This wrapper function improves the behavior of the library implementation that XML well-formedness violations
 * either result in a range error or are not properly indicated.
 *
 * Throws: XmlException on well-formedness violation.
 */
public XmlNode parse(string content)
{
    try
    {
        auto range = parseXML!simpleXML(content);
        return parse(range);
    }
    catch (XMLParsingException exception)
    {
        throw new XmlException(format!"not well-formed XML: %s"(exception.msg),
                exception.file, exception.line, exception);
    }
}

/// ditto
public XmlNode parse(R)(ref R range)
if(!is(R == string))
{
    try
    {
        return parseDocumentImpl(range, new MemoryManager);
    }
    catch (XMLParsingException exception)
    {
        throw new XmlException(format!"not well-formed XML: %s"(exception.msg),
                exception.file, exception.line, exception);
    }
}

private XmlNode parseDocumentImpl(R)(ref R range,
        MemoryManager memoryManager)
in (!range.empty)
in (memoryManager !is null)
{
    XmlNode xmlNode;
    alias toAttribute = attr => Attribute(attr.name, attr.value);

    final switch (range.front.type) with (EntityType)
    {
        case cdata:
        case comment:
        case text:
            xmlNode = XmlNode(range.front.type.asOriginalType.to!(XmlNode.Type),
                range.front.text.decodeXML);
            break;
        case elementStart:
            xmlNode = XmlNode(XmlNode.Type.element, range.front.name);
            xmlNode.attributes = map!toAttribute(range.front.attributes);
            range.popFront;

            auto children = memoryManager.getAppender;

            scope (exit)
            {
                memoryManager.releaseAppender(children);
            }
            for (; range.front.type != EntityType.elementEnd; range.popFront)
            {
                children.put(parseDocumentImpl(range, memoryManager));
            }
            xmlNode.children = children.data.dup;

            break;
        case elementEmpty:
            xmlNode = XmlNode(XmlNode.Type.element, range.front.name);
            xmlNode.attributes = map!toAttribute(range.front.attributes);
            break;
        case pi:
            xmlNode = XmlNode(XmlNode.Type.pi, range.front.text);
            break;
        case elementEnd:
            assert(false);
    }

    return xmlNode;
}

private class MemoryManager
{
    Appender!(Appender!(XmlNode[])[]) appenders;

    Appender!(XmlNode[]) getAppender()
    {
        if (this.appenders.data.empty)
        {
            return appender!(XmlNode[]);
        }
        auto appender = this.appenders.data.back;

        this.appenders.shrinkTo(this.appenders.data.length - 1);
        return appender;
    }

    void releaseAppender(Appender!(XmlNode[]) appender)
    {
        appender.clear;
        this.appenders.put(appender);
    }
}
