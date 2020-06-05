module meta.attributesOrNothing;

template attributesOrNothing(T)
{
    import std.meta : AliasSeq;

    static if (__traits(compiles, __traits(getAttributes, T)))
    {
        alias attributesOrNothing = AliasSeq!(__traits(getAttributes, T));
    }
    else
    {
        alias attributesOrNothing = AliasSeq!();
    }
}
