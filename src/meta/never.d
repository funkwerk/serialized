module meta.never;

/**
 * A function that fails when called with any argument.
 */
template never(T)
if (false)
{
    alias never = (T arg) => arg;
}

unittest
{
    static assert(
        !__traits(compiles, never(5)));
}
