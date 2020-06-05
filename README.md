# serialized

[![Build Status](https://github.com/funkwerk/serialized/workflows/CI/badge.svg)](https://github.com/funkwerk/serialized/actions?query=workflow%3ACI)
[![License](https://img.shields.io/badge/license-BSL_1.0-blue.svg)](https://raw.githubusercontent.com/funkwerk/serialized/master/LICENSE)
[![Dub Version](https://img.shields.io/dub/v/serialized.svg)](https://code.dlang.org/packages/serialized)

Serialized is a library that automates encoding and decoding of D data types to JSON and XML.

It heavily relies on `boilerplate` to extract information about struct/class type layouts; as such
automatic encoding/decoding can only be used with types that have a `boilerplate` constructor.

This library forks from Funkwerk's internal Utilities library. Hence while it is extensively tested, it
also contains a moderate amount of legacy code. The important packages for automatic encoding and decoding are
`text.xml/json.Encode/Decode`.

Serialized uses `dxml` for XML encoding/decoding and `stdx_data_json` for JSON encoding/decoding.

# Basic usage: XML

```
import text.xml.Xml;

@(Xml.Element("Root"))
struct Element
{
  @(Xml.Attribute("attribute"))
  string attribute;

  mixin(GenerateThis);
}

...

import text.xml.Decode;

const xmlText = `<Root attribute="Hello World"/>`;
const value = decode!Element(xmlText);

assert(value == Element("Hello World"));
```

# Basic usage: JSON

```
import text.xml.Xml;

struct Element
{
  string attribute;

  mixin(GenerateThis);
}

...

import text.json.Decode;

const jsonText = `{ "attribute": "Hello World" }`;
const value = decode!Element(jsonText);

assert(value == Element("Hello World"));
```

# License

This project is made available under the Boost Software License 1.0.

# Useful links

- [Changelog](CHANGELOG.md)
- [License](LICENSE).
