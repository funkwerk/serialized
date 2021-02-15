# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.1] - 2021-02-15
### Fixed
- Fix that decoding of nested object in array from JSONValue with alias this would drop every second value.

## [1.3.0] - 2021-02-08
### Added
- Support `@(Xml.Element)`/`@(Xml.Attribute)` without a name.
  For `Xml.Element`, the name of the type is used.
  For `Xml.Attribute`, the name of the field is used.

### Fixed
- When encountering a JSON decoding compile error, log the sequence of types that led to the error.

## [1.2.2] - 2021-01-25
### Fixed
- json: Throw `JSONException` when attempting to decode non-object as object.

## [1.2.1] - 2021-01-13
### Fixed
- Improve error handling in `text.json.Enum`.

## [1.2.0] - 2021-01-13
### Added
- add `text.json.Enum` with helper functions to encode and decode enums into JSON-style "SCREAMING_SNAKE_CASE" strings.

## [1.1.9] - 2020-11-25
### Fixed
- fix depreation for 2.094.1

## [1.1.8] - 2020-10-28
### Fixed
- Allow decoding of immutable associative arrays.

## [1.1.7] - 2020-10-01
### Fixed
- Revert 1.1.3
- Implement different solution: remove problematic `foreach (...; readArray)`.

## [1.1.6] - 2020-09-30
### Fixed
- Support `decode!(const JSONValue)`.

## [1.1.5] - 2020-09-29
### Fixed
- Fix typo in `text.json.Encode`.

## [1.1.4] - 2020-09-29
### Fixed
- Fix JSON encoding of classes.

## [1.1.3] - 2020-09-29
### Fixed
- Remove pointless `@disable this(this)` that was breaking array-of-struct decoding.

## [1.1.2] - 2020-09-24
### Fixed
- Remove file that was breaking LDC build via https://github.com/ldc-developers/ldc/issues/3344 .

## [1.1.1] - 2020-09-24
### Fixed
- Include a copy of std_data_json and taggedalgebraic directly. Work around DMD bug 21235 by hacking opEquals
  to be non-templated.
  This change should be reverted once the upstream issues are fixed. (Hah. Right.)

## [1.1.0] - 2020-09-01
### Added
- Allow loading any type with a `fromString` static method from a string, such as an XML attribute.

## [1.0.1] - 2020-07-27
### Fixed
- Remember to pop stream for numbers when decoding JSONValue.

## [1.0.0] - 2020-07-27
### Added
- Initial version: move text.xml, text.json over from internal Utilities repo; switch json decoding to stdx_data_json.
