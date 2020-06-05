module text.xml.Xml;

// UDA for text.xml.Encode/Decode
struct Xml
{
    static struct Attribute
    {
        string name;
    }

    static struct Element
    {
        string name;
    }

    static struct Text
    {
    }

    deprecated("Node is now Element")
    alias Node = Element;

    static struct Decode(alias DecodeFunction_)
    {
        alias DecodeFunction = DecodeFunction_;
    }

    static struct Encode(alias EncodeFunction_)
    {
        alias EncodeFunction = EncodeFunction_;
    }
}
