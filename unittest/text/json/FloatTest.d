module text.json.FloatTest;

import dshould;
import text.json.Decode;
import text.json.Encode;

@("reencode float")
unittest
{
    const original = "9.307716369628906";
    const roundtrip = original.decode!float.encode!float;

    roundtrip.should.be(original);
}

@("reencode double")
unittest
{
    const original = "9.307716369628906";
    const roundtrip = original.decode!double.encode!double;

    roundtrip.should.be(original);
}

@("redecode float")
unittest
{
    const original = "9.307716369628906".decode!float;
    const roundtrip = original.encode!float.decode!float;

    roundtrip.should.be(original);
}

@("redecode double")
unittest
{
    const original = "9.307716369628906".decode!double;
    const roundtrip = original.encode!double.decode!double;

    roundtrip.should.be(original);
}
