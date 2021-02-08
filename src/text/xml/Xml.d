module text.xml.Xml;

import std.typecons;

// UDA for text.xml.Encode/Decode
struct Xml
{
    // free function so both @(Xml.Attribute) and @(Xml.Attribute("name")) work
    // (you can't pass a type to an UDA, but you can pass a function.)
    public static AttributeName Attribute(string name)
    {
        return AttributeName(name);
    }

    public static ElementName Element(string name)
    {
        return ElementName(name);
    }

    public static struct Text
    {
    }

    public alias attributeName(attributes...) = attributeNameImpl!(Attribute, AttributeName, attributes);

    public alias elementName(attributes...) = attributeNameImpl!(Element, ElementName, attributes);

    deprecated("Node is now Element")
    alias Node = Element;

    public static struct Decode(alias DecodeFunction_)
    {
        alias DecodeFunction = DecodeFunction_;
    }

    public static struct Encode(alias EncodeFunction_)
    {
        alias EncodeFunction = EncodeFunction_;
    }

    private static struct AttributeName
    {
        string name;
    }

    private static struct ElementName
    {
        string name;
    }
}

private static Nullable!string attributeNameImpl(alias function_, alias type, attributes...)(string name)
{
    assert(__ctfe);

    import meta.udaIndex : udaIndex;

    alias functionIndex = udaIndex!function_;
    alias structIndex = udaIndex!type;

    static if (functionIndex!attributes != -1)
    {
        return Nullable!string(name);
    }
    else static if (structIndex!attributes != -1)
    {
        return Nullable!string(attributes[structIndex!attributes].name);
    }
    else
    {
        return Nullable!string();
    }
}
