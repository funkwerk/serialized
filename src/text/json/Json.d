module text.json.Json;

// UDA for text.json.Encode/Decode
struct Json
{
    string name;

    static struct Decode(alias DecodeFunction_)
    {
        alias DecodeFunction = DecodeFunction_;
    }

    static struct Encode(alias EncodeFunction_)
    {
        alias EncodeFunction = EncodeFunction_;
    }
}
