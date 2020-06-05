module meta.SafeUnqual;

import std.traits : Unqual;

/**
 * This helper template strips out const or immutable only if implicit conversion is possible.
 */
template SafeUnqual(T)
{
    static if (__traits(compiles, (T t) { Unqual!T ut = t; }))
    {
        alias SafeUnqual = Unqual!T;
    }
    else
    {
        alias SafeUnqual = T;
    }
}

///
unittest
{
    struct S1 { int i; } // no reference
    struct S2 { int[] array; } // reference to mutable data
    struct S3 { immutable(int)[] array; } // no reference to mutable data

    static assert(is(SafeUnqual!(immutable int) == int));
    // can safely unqual S1 because there's no references
    static assert(is(SafeUnqual!(immutable S1) == S1));
    // can't safely unqual S2 because the new type would hold mutable references
    static assert(is(SafeUnqual!(immutable S2) == immutable(S2)));
    // can safely unqual S3 because all references point at immutable data anyway
    static assert(is(SafeUnqual!(immutable S3) == S3));
}
