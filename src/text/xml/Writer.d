module text.xml.Writer;

import dxml.util;
import dxml.writer;
import std.array;
import std.range;
import std.typecons;
import text.xml.Tree;

/**
 * This struct is used to output XML string representation in a specific
 * format.
 */
struct CustomXmlWriter(Flag!"pretty" pretty, Sink)
{
    private XMLWriter!Sink writer;
    private bool skipIndent = false;

    static if (pretty)
    {
        private enum newline = Newline.yes;
        private enum insertIndent = InsertIndent.yes;
    }
    else
    {
        private enum newline = Newline.no;
        private enum insertIndent = InsertIndent.no;
    }

    public this(Sink sink)
    {
        this.writer = xmlWriter(sink);
    }

    public Sink sink()
    {
        return this.writer.output;
    }

    public void openStartTag(string name)
    {
        this.writer.openStartTag(name, newline);
    }

    public void writeAttr(string name, string value)
    {
        this.writer.writeAttr(name, value);
    }

    public void closeStartTag(Flag!"emptyTag" emptyTag = No.emptyTag)
    {
        this.writer.closeStartTag(emptyTag ? EmptyTag.yes : EmptyTag.no);
    }

    public void writeText(string text)
    {
        this.writer.writeText(text.encodeText, Newline.no, InsertIndent.no);
        this.skipIndent = true;
    }

    public void writeCDATA(string text)
    {
        this.writer.writeCDATA(text.encodeText, newline, insertIndent);
    }

    public void writeEndTag(string name)
    {
        this.writer.writeEndTag(name, this.skipIndent ? Newline.no : newline);
        this.skipIndent = false;
    }

    private void finishTag(const XmlNode document)
    {
        foreach (attribute; document.attributes)
        {
            writeAttr(attribute.name, attribute.value);
        }
        if (document.children.empty)
        {
            closeStartTag(Yes.emptyTag);
        }
        else
        {
            closeStartTag();
            foreach (child; document.children)
            {
                writeImpl(child);
            }
            writeEndTag(document.tag);
        }
    }

    private void writeImpl(const XmlNode document)
    {
        switch (document.type) with (XmlNode.Type)
        {
            case element:
                openStartTag(document.tag);
                finishTag(document);
                break;
            case comment:
                break;
            case cdata:
                writeCDATA(document.text);
                break;
            case text:
                writeText(document.text);
                break;
            default:
                assert(false);
        }
    }

    public void write(const XmlNode document)
    {
        if (document.type == XmlNode.Type.element)
        {
            if (!document.tag.empty)
            {
                this.writer.openStartTag(document.tag, Newline.no);
                finishTag(document);
                static if (pretty)
                {
                    this.writer.output.put('\n');
                }
            }
            else
            {
                write(document.children.front);
            }
        }
        else
        {
            writeImpl(document);
        }
    }
}

template customXmlWriter(Flag!"pretty" pretty)
{
    CustomXmlWriter!(pretty, Sink) customXmlWriter(Sink)(Sink sink)
    {
        return typeof(return)(sink);
    }
}
