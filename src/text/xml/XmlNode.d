module text.xml.XmlNode;

import boilerplate;
import dxml.parser;
import std.algorithm;
import std.range;
import std.typecons;
import text.xml.Writer;
version (unittest)
{
    import dshould;
}

/**
 * This struct represents an XML node.
 */
struct XmlNode
{
    enum Type : EntityType
    {
        cdata = EntityType.cdata,
        comment = EntityType.comment,
        text = EntityType.text,
        pi = EntityType.pi,
        element = EntityType.elementStart,
    }

    private Type type_;

    private string tag_;

    public XmlNode[] children;

    public Attributes attributes;

    /// Create an XML node with a tag.
    public this(const string tag) @nogc nothrow pure @safe
    {
        this.type_ = Type.element;
        this.tag_ = tag;
    }

    ///
    unittest
    {
        XmlNode("Foo").toString.should.be(
            `<Foo/>`
        );
    }

    /// Create an XML node with a tag and a list of children.
    public this(const string tag, XmlNode[] children) nothrow pure @safe
    {
        this(tag);
        this.children = children.dup;
    }

    ///
    unittest
    {
        XmlNode("Foo", [XmlNode("Bar")]).toString.should.be(
            `<Foo><Bar/></Foo>`
        );
    }

    /// Create an XML node with a tag and a set of attributes.
    public this(const string tag, const string[string] attributes) nothrow pure @safe
    {
        this(tag);
        this.attributes = Attributes(attributes.byKeyValue.map!(a => Attribute(a.key, a.value)));
    }

    ///
    unittest
    {
        XmlNode("Foo", ["bar": "baz"]).toString.should.be(
            `<Foo bar="baz"/>`
        );
    }

    /// Create an XML node with a tag, a set of attributes and a list of children.
    public this(const string tag, const string[string] attributes, XmlNode[] children) nothrow pure @safe
    {
        this(tag, attributes);
        this.children = children.dup;
    }

    ///
    unittest
    {
        XmlNode("Foo", ["bar": "baz"], [XmlNode("Fob")]).toString.should.be(
            `<Foo bar="baz"><Fob/></Foo>`
        );
    }

    public this(const Type type, const string tag, XmlNode[] children = null, Attributes attributes = Attributes.init)
    nothrow pure @safe
    {
        this.type_ = type;
        this.tag_ = tag;
        this.children = children.dup;
        this.attributes = attributes;
    }

    /// Get the tag of the XML node.
    public @property string tag() const @nogc nothrow pure @safe
    {
        return this.tag_;
    }

    public @property Type type() const @nogc nothrow pure @safe
    {
        return this.type_;
    }

    /// Find all direct children of the XML node whose tag matches the parameter.
    public auto findChildren(string tag) @nogc pure @safe
    {
        import std.traits : CopyConstness, Unqual;

        static struct FindChildrenRange(T)
        if (is(Unqual!T == XmlNode))
        {
            private T[] children;

            private string tag;

            @disable this();

            public this(T[] children, string tag)
            {
                this.children = children;
                this.tag = tag;
                prime;
            }

            public @property bool empty() const @nogc nothrow pure @safe
            {
                return this.children.empty;
            }

            public void popFront() @nogc nothrow pure @safe
            {
                this.children.popFront;
                prime;
            }

            public @property T front() @nogc nothrow pure @safe
            in (!empty)
            {
                return this.children.front;
            }

            public @property auto save() const @nogc nothrow pure @safe
            {
                return FindChildrenRange!(CopyConstness!(typeof(this), T))(children, tag);
            }

            private void prime() @nogc nothrow pure @safe
            {
                while (!empty && (front.type_ != Type.element || front.tag_ != this.tag))
                {
                    this.children.popFront;
                }
            }
        }

        return FindChildrenRange!XmlNode(this.children, tag);
    }

    ///
    unittest
    {
        auto node = XmlNode("Foo", [
            XmlNode("Bar"),
            XmlNode("Baz"),
        ]);

        node.findChildren("Baz").should.be([XmlNode("Baz")]);
    }

    /**
     * Find the first child of the XML node with the given tag.
     * Returns Nullable.null if no such child was found.
     */
    public Nullable!XmlNode findChild(const string tag) @nogc pure @safe
    {
        auto result = findChildren(tag);

        return result.empty ? typeof(return)() : nullable(result.front);
    }

    ///
    unittest
    {
        auto node = XmlNode("Foo", [
            XmlNode("Bar", ["a": "1"]),
            XmlNode("Bar", ["a": "2"]),
        ]);

        node.findChild("Bar").should.be(XmlNode("Bar", ["a": "1"]).nullable);
        node.findChild("Baz").should.be(Nullable!XmlNode());

    }

    /**
     * Remove all direct children of the XML node with the given tag.
     */
    public void removeChildren(const string tag) nothrow pure @safe
    {
        this.children = this.children.filter!(a => a.tag != tag).array;
    }

    ///
    unittest
    {
        auto node = XmlNode("Foo", [XmlNode("Bar"), XmlNode("Baz")]);

        node.removeChildren("Bar");
        node.should.be(XmlNode("Foo", [XmlNode("Baz")]));
    }


    /**
     * Remove the direct child of the XML node with a given tag.
     * An error is thrown if there is more than one.
     */
    public void removeChild(const string tag) nothrow pure @safe
    in (this.children.count!(a => a.tag == tag) <= 1)
    {
        removeChildren(tag);
    }

    /**
     * Replace the direct child of the XML node with a given tag, with a new XML node.
     * An error is thrown if there is more than one.
     */
    public void replaceChild(const string tag, XmlNode replacement) nothrow pure @safe
    in (this.children.count!(a => a.tag == tag) == 1)
    {
        this.children = this.children.map!(a => (a.tag == tag) ? replacement : a).array;
    }

    ///
    unittest
    {
        auto node = XmlNode("Foo", [XmlNode("Bar"), XmlNode("Baz")]);

        node.replaceChild("Bar", XmlNode("Fob"));
        node.should.be(XmlNode("Foo", [XmlNode("Fob"), XmlNode("Baz")]));
    }

    /**
     * Get the 'plain text' representation of this XML node.
     * That is, the textual contents of the XML tree,
     * children included in depth-first order, without tags.
     */
    public @property string text() const pure @safe
    {
        if (this.type == Type.text)
        {
            return this.tag;
        }
        return this.children.map!(child => child.text).join;
    }

    /**
     * Get the XML text representation of this XML node.
     */
    public string toString() const
    {
        auto sink = appender!string();
        auto writer = customXmlWriter!(No.pretty)(sink);

        writer.write(this);
        return sink.data;
    }

    ///
    public void toString(scope void delegate(const(char)[]) sink) const
    {
        auto writer = customXmlWriter!(No.pretty)(sink);

        writer.write(this);
    }

    /// Add an attribute to this XML node.
    public XmlNode addAttribute(string name, string value)
    {
        this.attributes.attributes ~= Attribute(name, value);
        return this;
    }

    ///
    unittest
    {
        auto node = XmlNode("Foo");

        node.addAttribute("bar", "baz");
        node.toString.should.be(
            `<Foo bar="baz"/>`
        );
    }

    /**
     * Manually free the memory claimed by this XML node and its children.
     * This can be used when the GC is "being stupid about it".
     * Note that you *must* ensure no external references to the node remain!
     */
    public void free()
    {
        import core.memory : GC;

        this.children.each!"a.free";
        GC.free(this.children.ptr);
        this.attributes.free;
    }
}

alias Attribute = Tuple!(string, "name", string, "value");

/**
 * This struct holds a list of XML attributes as name/value pairs.
 */
struct Attributes
{
    private Attribute[] attributes;

    private alias lookup = (Attribute attr, string name) => attr.name == name;

    public this(R)(R range)
    if (isInputRange!R && is(ElementType!R == Attribute))
    {
        this = range;
    }

    public typeof(this) opAssign(R)(R range)
    if (isInputRange!R && is(ElementType!R == Attribute))
    {
        this.attributes = range.array;
        return this;
    }

    public inout(Attribute)[] opIndex() inout @nogc nothrow pure @safe
    {
        return this.attributes;
    }

    public string opIndex(string name) nothrow pure @safe
    in (!this.attributes.find!lookup(name).empty, "Attribute not found")
    {
        return this.attributes.find!lookup(name).front.value;
    }

    public ref string opIndexAssign(string value, string name) pure @safe
    {
        auto result = this.attributes.find!lookup(name);

        if (result.empty)
        {
            this.attributes ~= Attribute(name, value);
            return this.attributes.back.value;
        }
        return result.front.value = value;
    }

    public bool opBinaryRight(string op : "in")(string name) const
    {
        return this.attributes.canFind!lookup(name);
    }

    public void free()
    {
        import core.memory : GC;

        GC.free(this.attributes.ptr);
    }
}
