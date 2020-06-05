module text.xml.XmlException;

import std.exception;

/**
 * Thrown on an XML well-formedness or validity violation.
 */
class XmlException : Exception
{

    mixin basicExceptionCtors;

}
