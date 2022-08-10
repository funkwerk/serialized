module text.xml.Decode;

import boilerplate.util : udaIndex;
static import dxml.util;
import meta.attributesOrNothing;
import meta.never;
import meta.SafeUnqual;
import std.format : format;
import std.sumtype;
import text.xml.Tree;
import text.xml.Validation : enforceName, normalize, require, requireChild;
public import text.xml.Xml;

/**
 * Throws: XmlException if the message is not well-formed or doesn't match the type
 */
public T decode(T, alias customDecode = never)(string message)
{
    import text.xml.Parser : parse;

    static assert(__traits(isSame, customDecode, never), "XML does not yet support a decode function");

    XmlNode rootNode = parse(message);

    return decodeXml!T(rootNode);
}

/**
 * Throws: XmlException if the XML element doesn't match the type
 */
public T decodeXml(T)(XmlNode node)
{
    import std.traits : fullyQualifiedName;

    enum name = Xml.elementName!(__traits(getAttributes, T))(typeName!T);

    static assert(
        !name.isNull,
        fullyQualifiedName!T ~
        ": type passed to text.xml.decode must have an Xml.Element attribute indicating its element name.");

    node.enforceName(name.get);

    return decodeUnchecked!T(node);
}

/**
 * Throws: XmlException if the XML element doesn't match the type
 * Returns: T, or the type returned from a decoder function defined on T.
 */
public auto decodeUnchecked(T, attributes...)(XmlNode node)
{
    import boilerplate.util : formatNamed, optionallyRemoveTrailingUnderline, udaIndex;
    import std.algorithm : map;
    import std.meta : AliasSeq, anySatisfy, ApplyLeft;
    import std.range : array, ElementType;
    import std.string : empty, strip;
    import std.traits : fullyQualifiedName, isIterable, Unqual;
    import std.typecons : Nullable, Tuple;

    static if (isNodeLeafType!(T, attributes))
    {
        return decodeNodeLeaf!(T, attributes)(node);
    }
    else
    {
        static assert(
            __traits(hasMember, T, "ConstructorInfo"),
            fullyQualifiedName!T ~ " does not have a boilerplate constructor!");

        auto builder = T.Builder();

        alias Info = Tuple!(string, "builderField", string, "constructorField");

        static foreach (string constructorField; T.ConstructorInfo.fields)
        {{
            enum builderField = optionallyRemoveTrailingUnderline!constructorField;

            alias Type = Unqual!(__traits(getMember, T.ConstructorInfo.FieldInfo, constructorField).Type);
            alias attributes = AliasSeq!(
                __traits(getMember, T.ConstructorInfo.FieldInfo, constructorField).attributes);

            static if (is(Type : Nullable!Arg, Arg))
            {
                alias DecodeType = Arg;
                enum isNullable = true;
            }
            else
            {
                alias DecodeType = SafeUnqual!Type;
                enum isNullable = false;
            }

            static if (is(Type : SumType!T, T...))
            {
                __traits(getMember, builder, builderField) = decodeSumType!T(node);
            }
            else static if (is(Type : SumType!T[], T...))
            {
                __traits(getMember, builder, builderField) = decodeSumTypeArray!T(node);
            }
            else static if (!Xml.attributeName!attributes(builderField).isNull)
            {
                enum name = Xml.attributeName!attributes(builderField).get;

                static if (isNullable || __traits(getMember, T.ConstructorInfo.FieldInfo, constructorField).useDefault)
                {
                    if (name in node.attributes)
                    {
                        __traits(getMember, builder, builderField)
                            = decodeAttributeLeaf!(DecodeType, name, attributes)(node);
                    }
                }
                else
                {
                    __traits(getMember, builder, builderField)
                        = decodeAttributeLeaf!(DecodeType, name, attributes)(node);
                }
            }
            else static if (!Xml.elementName!attributes(typeName!Type).isNull)
            {

                enum canDecodeNode = isNodeLeafType!(DecodeType, attributes)
                    || __traits(compiles, .decodeUnchecked!(DecodeType, attributes)(XmlNode.init));

                static if (canDecodeNode)
                {
                    enum name = Xml.elementName!attributes(typeName!Type).get;

                    static if (isNullable)
                    {
                        static if (__traits(getMember, T.ConstructorInfo.FieldInfo, constructorField).useDefault)
                        {
                            // missing element = null
                            auto child = node.findChild(name);

                            if (!child.isNull)
                            {
                                __traits(getMember, builder, builderField)
                                    = decodeUnchecked!(DecodeType, attributes)(child.get);
                            }
                        }
                        else
                        {
                            auto child = node.requireChild(name);

                            if (child.text.strip.empty)
                            {
                                // empty element = null
                                __traits(getMember, builder, builderField) = Type();
                            }
                            else
                            {
                                __traits(getMember, builder, builderField)
                                    = .decodeUnchecked!(DecodeType, attributes)(child);
                            }
                        }
                    }
                    else
                    {
                        auto child = node.requireChild(name);

                        __traits(getMember, builder, builderField)
                            = .decodeUnchecked!(DecodeType, attributes)(child);
                    }
                }
                else static if (is(DecodeType: U[], U))
                {
                    enum name = Xml.elementName!attributes(typeName!U).get;

                    alias decodeChild = delegate U(XmlNode child)
                    {
                        return .decodeUnchecked!(U, attributes)(child);
                    };

                    auto children = node.findChildren(name).map!decodeChild.array;

                    __traits(getMember, builder, builderField) = children;
                }
                else
                {
                    pragma(msg, "While decoding field '" ~ constructorField ~ "' of type " ~ DecodeType.stringof ~ ":");

                    // reproduce the error we swallowed earlier
                    auto _ = .decodeUnchecked!(DecodeType, attributes)(XmlNode.init);
                }
            }
            else static if (udaIndex!(Xml.Text, attributes) != -1)
            {
                __traits(getMember, builder, builderField) = dxml.util.decodeXML(node.text);
            }
            else
            {
                enum sameField(string lhs, string rhs)
                    = optionallyRemoveTrailingUnderline!lhs == optionallyRemoveTrailingUnderline!rhs;
                enum memberIsAliasedToThis = anySatisfy!(
                    ApplyLeft!(sameField, constructorField),
                    __traits(getAliasThis, T));

                static if (memberIsAliasedToThis)
                {
                    // decode inline
                    __traits(getMember, builder, builderField) = .decodeUnchecked!(DecodeType, attributes)(node);
                }
                else
                {
                    static assert(
                        __traits(getMember, T.ConstructorInfo.FieldInfo, constructorField).useDefault,
                        "Field " ~ fullyQualifiedName!T ~ "." ~ constructorField ~ " is required but has no Xml tag");
                }
            }
        }}

        return builder.builderValue();
    }
}

/**
 * Throws: XmlException if the XML element doesn't have a child matching exactly one of the subtypes,
 * or if the child doesn't match the subtype.
 */
private SumType!Types decodeSumType(Types...)(XmlNode node)
{
    import std.algorithm : find, map, moveEmplace, sum;
    import std.array : array, front;
    import std.exception : enforce;
    import std.meta : AliasSeq, staticMap;
    import std.traits : fullyQualifiedName;
    import std.typecons : apply, Nullable, nullable;
    import text.xml.XmlException : XmlException;

    Nullable!(SumType!Types)[Types.length] decodedValues;

    static foreach (i, Type; Types)
    {{
        static if (is(Type: U[], U))
        {
            enum isArray = true;
            alias BaseType = U;
        }
        else
        {
            enum isArray = false;
            alias BaseType = Type;
        }

        alias attributes = AliasSeq!(__traits(getAttributes, BaseType));

        static assert(
            !Xml.elementName!attributes(typeName!BaseType).isNull,
            fullyQualifiedName!Type ~
            ": SumType component type must have an Xml.Element attribute indicating its element name.");

        enum name = Xml.elementName!attributes(typeName!BaseType).get;

        static if (isArray)
        {
            auto children = node.findChildren(name);

            if (!children.empty)
            {
                decodedValues[i] = SumType!Types(children.map!(a => a.decodeUnchecked!U).array);
            }
        }
        else
        {
            auto child = node.findChild(name);

            decodedValues[i] = child.apply!(a => SumType!Types(a.decodeUnchecked!Type));
        }
    }}

    const matchedValues = decodedValues[].map!(a => a.isNull ? 0 : 1).sum;

    enforce!XmlException(matchedValues != 0,
        format!`Element "%s": no child element of %(%s, %)`(node.tag, [staticMap!(typeName, Types)]));
    enforce!XmlException(matchedValues == 1,
        format!`Element "%s": contained more than one of %(%s, %)`(node.tag, [staticMap!(typeName, Types)]));
    return decodedValues[].find!(a => !a.isNull).front.get;
}

private SumType!Types[] decodeSumTypeArray(Types...)(XmlNode node)
{
    import std.meta : AliasSeq;
    import std.traits : fullyQualifiedName;

    SumType!Types[] result;

    foreach (child; node.children)
    {
        static foreach (Type; Types)
        {{
            alias attributes = AliasSeq!(__traits(getAttributes, Type));

            static assert(
                !Xml.elementName!attributes(typeName!Type).isNull,
                fullyQualifiedName!Type ~
                ": SumType component type must have an Xml.Element attribute indicating its element name.");

            enum name = Xml.elementName!attributes(typeName!Type).get;

            if (child.tag == name)
            {
                result ~= SumType!Types(child.decodeUnchecked!Type);
            }
        }}
    }
    return result;
}

private enum typeName(T) = typeof(cast() T.init).stringof;

private auto decodeAttributeLeaf(T, string name, attributes...)(XmlNode node)
{
    alias typeAttributes = attributesOrNothing!T;

    static if (udaIndex!(Xml.Decode, attributes) != -1)
    {
        alias decodeFunction = attributes[udaIndex!(Xml.Decode, attributes)].DecodeFunction;

        return decodeFunction(dxml.util.decodeXML(node.attributes[name]));
    }
    else static if (udaIndex!(Xml.Decode, typeAttributes) != -1)
    {
        alias decodeFunction = typeAttributes[udaIndex!(Xml.Decode, typeAttributes)].DecodeFunction;

        return decodeFunction(dxml.util.decodeXML(node.attributes[name]));
    }
    else
    {
        return node.require!T(name);
    }
}

// must match decodeNodeLeaf
enum isNodeLeafType(T, attributes...) =
    udaIndex!(Xml.Decode, attributes) != -1
    || udaIndex!(Xml.Decode, attributesOrNothing!T) != -1
    || __traits(compiles, XmlNode.init.require!(SafeUnqual!T)());

private auto decodeNodeLeaf(T, attributes...)(XmlNode node)
{
    alias typeAttributes = attributesOrNothing!T;

    static if (udaIndex!(Xml.Decode, attributes) != -1 || udaIndex!(Xml.Decode, typeAttributes) != -1)
    {
        static if (udaIndex!(Xml.Decode, attributes) != -1)
        {
            alias decodeFunction = attributes[udaIndex!(Xml.Decode, attributes)].DecodeFunction;
        }
        else
        {
            alias decodeFunction = typeAttributes[udaIndex!(Xml.Decode, typeAttributes)].DecodeFunction;
        }

        static if (__traits(isTemplate, decodeFunction))
        {
            return decodeFunction!T(node);
        }
        else
        {
            return decodeFunction(node);
        }
    }
    else static if (is(T == string))
    {
        return dxml.util.decodeXML(node.text).normalize;
    }
    else
    {
        return node.require!(SafeUnqual!T)();
    }
}
