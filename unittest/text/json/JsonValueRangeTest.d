module text.json.JsonValueRangeTest;

import dshould;
import funkwerk.stdx.data.json.parser;
import std.algorithm : map;
import std.json;
import std.range : array;
import text.json.JsonValueRange;

@("JsonValueRange encodes JSONValue as stdx.data.json token range")
unittest
{
    with (JSONParserNodeKind)
    {
        JsonValueRange(JSONValue(5)).array.map!(a => a.kind)
            .should.equal([literal]);

        JsonValueRange(JSONValue([
            JSONValue(1),
            JSONValue(2),
            JSONValue(3),
        ])).array.map!(a => a.kind)
            .should.equal([arrayStart, literal, literal, literal, arrayEnd]);

        const input = JSONValue([
            "b": JSONValue(5),
            "c": JSONValue([JSONValue(5)]),
        ]);

        // sorting of AA may differ between compilers
        if (input.objectNoRef.byKey.array == ["b", "c"])
        {
            JsonValueRange(input).array.map!(a => a.kind)
                .should.equal([objectStart, key, literal, key, arrayStart, literal, arrayEnd, objectEnd]);
        }
        else
        {
            JsonValueRange(input).array.map!(a => a.kind)
                .should.equal([objectStart, key, arrayStart, literal, arrayEnd, key, literal, objectEnd]);
        }

        JsonValueRange(JSONValue([
            JSONValue(1),
            JSONValue([JSONValue(2)]),
            JSONValue(3),
        ])).array.map!(a => a.kind)
            .should.equal([arrayStart, literal, arrayStart, literal, arrayEnd, literal, arrayEnd]);
    }
}
