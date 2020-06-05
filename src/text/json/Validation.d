module text.json.Validation;

import std.conv;
import std.datetime;
import std.json;
import std.string;
import std.traits;
import std.typecons;
import text.time.Convert;

/**
 * This value object represents a JSON object of name/value pairs.
 * It is named `JSONObject` rather than `JsonObject` to comply with the naming of `JSONValue`.
 * Its main purpose is to avoid conflicts with the `require` function introduced in D 2.082.0.
 */
public struct JSONObject
{
    public JSONValue[string] attributes;

    alias attributes this;

    /**
    * Throws: JSONException when the name is no attribute of the object.
    */
    public inout(JSONValue) require(string name) inout pure @safe
    {
        if (name !in this.attributes)
        {
            throw new JSONException(format!`"%s" value required`(name));
        }
        return this.attributes[name];
    }

    /**
    * Throws: JSONException when the name is no attribute of the object
    * or when the value is not of the required type.
    */
    public inout(T) require(T)(string name) inout
    {
        JSONValue value = require(name);

        try
        {
            return value.require!T;
        }
        catch (JSONException exception)
        {
            throw new JSONException(format!`"%s" value: %s`(name, exception.msg));
        }
    }

    /**
    * Throws: JSONException when the name is an attribute of the object but the value is not of the required type.
    */
    public inout(T) require(T)(string name, lazy T fallback) inout
    {
        if (name !in this.attributes)
        {
            return fallback;
        }
        try
        {
            return this.attributes[name].require!T;
        }
        catch (JSONException exception)
        {
            throw new JSONException(format!`"%s" value: %s`(name, exception.msg));
        }
    }

    /**
    * Throws: JSONException when the name is an attribute of the object but the value is not of the required type.
    */
    public inout(Nullable!T) require(U : Nullable!T, T)(string name) inout
    {
        if (name !in this.attributes)
        {
            return Nullable!T();
        }
        try
        {
            return Nullable!T(this.attributes[name].require!T);
        }
        catch (JSONException exception)
        {
            throw new JSONException(format!`"%s" value: %s`(name, exception.msg));
        }
    }
}

/**
 * Throws: JSONException when the value is not a JSON object.
 */
public JSONObject requireObject(JSONValue value)
{
    if (value.type != JSONType.object)
    {
        throw new JSONException(format!"object required but got %s"(value));
    }
    return JSONObject(value.object);
}

/**
 * Throws: JSONException when the value is not a JSON object with values of the required type.
 */
public T[string] requireObject(T)(JSONValue object)
{
    T[string] array = null;

    foreach (name, value; object.requireObject)
    {
        array[name] = value.require!T;
    }

    return array;
}

/**
 * Throws: JSONException when the value is not a JSON array.
 */
public JSONValue[] requireArray(JSONValue value)
{
    if (value.type != JSONType.array)
    {
        throw new JSONException(format!"array required but got %s"(value));
    }
    return value.array;
}

/**
 * Throws: JSONException when the value is not a JSON array with elements of the required type.
 */
public T[] requireArray(T)(JSONValue value)
{
    T[] array = null;

    foreach (element; value.requireArray)
    {
        array ~= element.require!T;
    }
    return array;
}

/**
 * Throws: JSONException when the value is not a boolean.
 */
public T require(T)(JSONValue value)
    if (is(T == bool))
{
    if (value.type != JSONType.true_ && value.type != JSONType.false_)
    {
        throw new JSONException(format!"boolean required but got %s"(value));
    }
    return value.type == JSONType.true_;
}

/**
 * Throws: JSONException when the value is not a number or when the number is not of the required type.
 */
public T require(T)(JSONValue value)
    if (isIntegral!T && !is(T == enum))
{
    try
    {
        switch (value.type)
        {
            case JSONType.integer:
                return value.integer.to!T;
            case JSONType.uinteger:
                return value.uinteger.to!T;
            default:
                throw new JSONException(format!"integral value required but got %s"(value));
        }
    }
    catch (ConvException)
    {
        throw new JSONException(format!"%s is not a valid value of type %s"(value, T.stringof));
    }
}

/**
 * Throws: JSONException when the value is not of the required float type.
 */
public T require(T)(JSONValue value)
    if (isFloatingPoint!T)
{
    switch (value.type)
    {
        case JSONType.integer:
            return value.integer.to!T;
        case JSONType.uinteger:
            return value.uinteger.to!T;
        case JSONType.float_:
            return value.floating.to!T;
        default:
            throw new JSONException(format!"numeric value required but got %s"(value));
    }
}

/**
 * Throws: JSONException when the value is not a string.
 */
public T require(T : string)(JSONValue value)
    if (!is(T == enum))
{
    if (value.type != JSONType.string)
    {
        throw new JSONException(format!"string required but got %s"(value));
    }
    return value.str;
}

/**
 * Throws: JSONException when the value is not a member of the required enumeration.
 */
public T require(T)(JSONValue value)
    if (is(T == enum) && !is(T : bool))
{
    try
    {
        return value.require!string.to!T;
    }
    catch (ConvException)
    {
        throw new JSONException(format!"%s required but got %s"(T.stringof, value));
    }
}

/**
 * Throws: JSONException when the value is not a boolean.
 */
public T require(T)(JSONValue value)
    // Flag!"Name" is enum Flag : bool
    if (is(T == enum) && is(T : bool))
{
    return value.require!bool ? T.yes : T.no;
}

/**
 * Throws: JSONException when the value is not of the required date-time type.
 */
public T require(T)(JSONValue value)
    if (is(T == Date) || is(T == Duration) || is(T == SysTime) || is(T == TimeOfDay))
{
    try
    {
        return Convert.to!T(value.require!string);
    }
    catch (DateTimeException exception)
    {
        throw new JSONException(exception.msg);
    }
}
