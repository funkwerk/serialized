module text.xml.Encode;

import boilerplate.util;
import dxml.util;
import dxml.writer;
import meta.attributesOrNothing;
import std.array;
import std.meta;
import std.traits;
import std.typecons;
import sumtype : match, SumType;
import text.xml.Convert;
import text.xml.Xml;

/**
 * The `text.xml.encode` function encodes an arbitrary type as XML.
 * Each tagged field in the type is encoded.
 * Tags are @(Xml.Attribute("attributeName")) and @(Xml.Element("tagName")).
 * Types passed directly to `encode` must be annotated with an @(Xml.Element("...")) attribute.
 * Child types must be annotated at their fields in the containing type.
 * For array fields, their values are encoded sequentially.
 * Nullable fields are omitted if they are null.
 */
public string encode(T)(const T value)
in
{
    static if (is(T == class))
    {
        assert(value !is null);
    }
}
do
{
    mixin enforceTypeHasElementTag!(T, "type passed to text.xml.encode");

    alias attributes = AliasSeq!(__traits(getAttributes, T));
    auto writer = xmlWriter(appender!string);

    encodeNode!(T, attributes)(writer, value);

    return writer.output.data;
}

private void encodeNode(T, attributes...)(ref XMLWriter!(Appender!string) writer, const T value)
{
    writer.openStartTag(attributes[udaIndex!(Xml.Element, attributes)].name, Newline.no);

    // encode all the attribute members
    static foreach (member; FilterMembers!(T, value, true))
    {{
        auto memberValue = __traits(getMember, value, member);
        alias memberAttrs = AliasSeq!(__traits(getAttributes, __traits(getMember, value, member)));
        alias PlainMemberT = typeof(cast() memberValue);
        enum name = memberAttrs[udaIndex!(Xml.Attribute, memberAttrs)].name;

        static if (is(PlainMemberT : Nullable!Arg, Arg))
        {
            if (!memberValue.isNull)
            {
                writer.writeAttr(name, encodeLeafImpl!(Arg, memberAttrs)(memberValue.get).encodeAttr, Newline.no);
            }
        }
        else
        {
            writer.writeAttr(name, encodeLeafImpl!(PlainMemberT, memberAttrs)(memberValue).encodeAttr, Newline.no);
        }
    }}

    bool tagIsEmpty = true;

    static foreach (member; FilterMembers!(T, value, false))
    {{
        auto memberValue = __traits(getMember, value, member);
        alias memberAttrs = AliasSeq!(__traits(getAttributes, __traits(getMember, value, member)));
        alias PlainMemberT = typeof(cast() memberValue);
        enum hasXmlTag = udaIndex!(Xml.Element, memberAttrs) != -1 || udaIndex!(Xml.Text, memberAttrs) != -1;
        enum isSumType = is(PlainMemberT : SumType!U, U...);

        static if (hasXmlTag || isSumType)
        {
            static if (is(PlainMemberT : Nullable!Arg, Arg))
            {
                if (!memberValue.isNull)
                {
                    tagIsEmpty = false;
                }
            }
            else
            {
                tagIsEmpty = false;
            }
        }
    }}

    writer.closeStartTag(tagIsEmpty ? EmptyTag.yes : EmptyTag.no);

    if (!tagIsEmpty)
    {
        static foreach (member; FilterMembers!(T, value, false))
        {{
            auto memberValue = __traits(getMember, value, member);
            alias memberAttrs = AliasSeq!(__traits(getAttributes, __traits(getMember, value, member)));

            static if (udaIndex!(Xml.Element, memberAttrs) != -1)
            {
                alias PlainMemberT = typeof(cast() memberValue);
                enum name = memberAttrs[udaIndex!(Xml.Element, memberAttrs)].name;

                encodeNodeImpl!(name, PlainMemberT, memberAttrs)(writer, memberValue);
            }
            else static if (udaIndex!(Xml.Text, memberAttrs) != -1)
            {
                writer.writeText(memberValue.encodeText, Newline.no);
            }
            else static if (is(typeof(cast() memberValue) : SumType!U, U...))
            {
                encodeSumType(writer, memberValue);
            }
        }}

        writer.writeEndTag(Newline.no);
    }
}

private void encodeSumType(T)(ref XMLWriter!(Appender!string) writer, const T value)
{
    value.match!(staticMap!((const value) {
        alias T = typeof(value);

        static if (is(T: U[], U))
        {
            alias BaseType = U;
        }
        else
        {
            alias BaseType = T;
        }

        mixin enforceTypeHasElementTag!(BaseType, "every member type of SumType");

        alias attributes = AliasSeq!(__traits(getAttributes, BaseType));
        enum name = attributes[udaIndex!(Xml.Element, attributes)].name;

        encodeNodeImpl!(name, T, attributes)(writer, value);
    }, T.Types));
}

private mixin template enforceTypeHasElementTag(T, string context)
{
    static assert(
        udaIndex!(Xml.Element, __traits(getAttributes, T)) != -1,
        fullyQualifiedName!T ~
        ": " ~ context ~ " must have an Xml.Element attribute indicating its element name.");
}

private template FilterMembers(T, alias value, bool keepXmlAttributes)
{
    alias pred = ApplyLeft!(attrFilter, value, keepXmlAttributes);
    alias FilterMembers = Filter!(pred, __traits(derivedMembers, T));
}

private template attrFilter(alias value, bool keepXmlAttributes, string member)
{
    static if (__traits(compiles, { return __traits(getMember, value, member); }))
    {
        alias attributes = AliasSeq!(__traits(getAttributes, __traits(getMember, value, member)));
        static if (keepXmlAttributes)
        {
            enum bool attrFilter = udaIndex!(Xml.Attribute, attributes) != -1;
        }
        else
        {
            enum bool attrFilter = udaIndex!(Xml.Attribute, attributes) == -1;
        }
    }
    else
    {
        enum bool attrFilter = false;
    }
}

private void encodeNodeImpl(string name, T, attributes...)(ref XMLWriter!(Appender!string) writer, const T value)
{
    alias PlainT = typeof(cast() value);

    static if (__traits(compiles, __traits(getAttributes, T)))
    {
        alias typeAttributes = AliasSeq!(__traits(getAttributes, T));
    }
    else
    {
        alias typeAttributes = AliasSeq!();
    }

    static if (is(PlainT : Nullable!Arg, Arg))
    {
        if (!value.isNull)
        {
            encodeNodeImpl!(name, Arg, attributes)(writer, value.get);
        }
    }
    else static if (udaIndex!(Xml.Encode, attributes) != -1)
    {
        alias customEncoder = attributes[udaIndex!(Xml.Encode, attributes)].EncodeFunction;

        writer.openStartTag(name, Newline.no);
        writer.closeStartTag;

        customEncoder(writer, value);
        writer.writeEndTag(name, Newline.no);
    }
    else static if (udaIndex!(Xml.Encode, typeAttributes) != -1)
    {
        alias customEncoder = typeAttributes[udaIndex!(Xml.Encode, typeAttributes)].EncodeFunction;

        writer.openStartTag(name, Newline.no);
        writer.closeStartTag;

        customEncoder(writer, value);
        writer.writeEndTag(name, Newline.no);
    }
    else static if (isLeafType!(PlainT, attributes))
    {
        writer.openStartTag(name, Newline.no);
        writer.closeStartTag;

        writer.writeText(encodeLeafImpl(value).encodeText, Newline.no);
        writer.writeEndTag(name, Newline.no);
    }
    else static if (isIterable!PlainT)
    {
        alias IterationType(T) = typeof({ foreach (value; T.init) return value; assert(0); }());

        foreach (IterationType!PlainT a; value)
        {
            encodeNodeImpl!(name, typeof(a), attributes)(writer, a);
        }
    }
    else
    {
        encodeNode!(PlainT, attributes)(writer, value);
    }
}

// must match encodeLeafImpl
private enum bool isLeafType(T, attributes...) =
    udaIndex!(Xml.Encode, attributes) != -1
    || udaIndex!(Xml.Encode, attributesOrNothing!T) != -1
    || is(T == string)
    || __traits(compiles, { Convert.toString(T.init); });

private string encodeLeafImpl(T, attributes...)(T value)
{
    alias typeAttributes = attributesOrNothing!T;

    static if (udaIndex!(Xml.Encode, attributes) != -1)
    {
        alias customEncoder = attributes[udaIndex!(Xml.Encode, attributes)].EncodeFunction;

        return customEncoder(value);
    }
    else static if (udaIndex!(Xml.Encode, typeAttributes) != -1)
    {
        alias customEncoder = typeAttributes[udaIndex!(Xml.Encode, typeAttributes)].EncodeFunction;

        return customEncoder(value);
    }
    else static if (is(T == string))
    {
        return value;
    }
    else static if (__traits(compiles, Convert.toString(value)))
    {
        return Convert.toString(value);
    }
    else
    {
        static assert(false, "Unknown value type: " ~ T.stringof);
    }
}
