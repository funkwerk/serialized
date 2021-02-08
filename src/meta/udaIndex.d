module meta.udaIndex;

import std.traits : isFunction;

public template udaIndex(alias attr)
{
    alias udaIndex = udaIndexImpl!(appropriateTest!attr);
}

private template udaIndexImpl(alias comparator)
{
    template udaIndexImpl(attributes...)
    {
        mixin(generateUdaIndex!(attributes.length));
    }
}

private enum generateUdaIndex(int length) = generateUdaIndexImpl(0, length);

private string generateUdaIndexImpl(int base, int length)
{
    import std.conv : to;

    if (base == length)
    {
        if (length == 0)
        {
            return "enum udaIndexImpl = -1;";
        }
        return "
{
    enum udaIndexImpl = -1;
}";
    }

    return "static if (comparator!(attributes[" ~ base.to!string ~ "]))
{
    enum udaIndexImpl = " ~ base.to!string ~ ";
}
else " ~ generateUdaIndexImpl(base + 1, length);
}

// lhs that is a template
private template appropriateTest(alias lhs)
if (__traits(isTemplate, lhs))
{
    template appropriateTest(alias rhs)
    {
        static if (__traits(isSame, lhs, rhs))
        {
            enum appropriateTest = true;
        }
        else static if (is(rhs: lhs!Args, Args...))
        {
            enum appropriateTest = true;
        }
        else
        {
            enum appropriateTest = false;
        }
    }
}

// lhs that is a function
private template appropriateTest(alias lhs)
if (isFunction!lhs)
{
    enum appropriateTest(alias rhs) = __traits(isSame, lhs, rhs);
}

// lhs that is a type
private template appropriateTest(alias lhs)
if (__traits(compiles, lhs.init))
{
    template appropriateTest(alias rhs)
    {
        static if (is(typeof(rhs) == lhs))
        {
            enum appropriateTest = true;
        }
        else static if (is(rhs) && is(lhs == rhs))
        {
            enum appropriateTest = true;
        }
        else
        {
            enum appropriateTest = false;
        }
    }
}

// lhs that is a value
private template appropriateTest(alias lhs)
if (__traits(compiles, typeof(lhs)) && !isFunction!lhs)
{
    template appropriateTest(alias rhs)
    {
        static if (__traits(compiles, lhs == rhs))
        {
            static if (lhs == rhs)
            {
                enum appropriateTest = true;
            }
            else
            {
                enum appropriateTest = false;
            }
        }
        else
        {
            enum appropriateTest = false;
        }
    }
}
