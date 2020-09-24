# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2020-09-24
### Fixed
- Include a copy of std_data_json and taggedalgebraic directly. Work around DMD bug 21235 by hacking opEquals to be non-templated.

## [1.1.0] - 2020-09-01
### Added
- Allow loading any type with a `fromString` static method from a string, such as an XML attribute.

## [1.0.1] - 2020-07-27
### Fixed
- Remember to pop stream for numbers when decoding JSONValue.

## [1.0.0] - 2020-07-27
### Added
- Initial version: move text.xml, text.json over from internal Utilities repo; switch json decoding to stdx_data_json.
