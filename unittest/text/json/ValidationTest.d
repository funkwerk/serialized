module text.json.ValidationTest;

version(unittest) import dshould;
import std.datetime;
import std.json;
import std.typecons;
import text.json.Validation;

@("gets object members")
unittest
{
    // given
    JSONValue[string] members = ["foo": JSONValue("bar")];

    // when
    JSONObject actual = JSONValue(members).requireObject;

    // then
    actual.should.equal(members);
}

@("fails to get object members from non-object")
unittest
{
    // given
    JSONValue[] elements = [JSONValue(2), JSONValue(3)];

    // when/then
    JSONValue(elements).requireObject.should.throwA!JSONException;
}

@("gets object members as associative array")
unittest
{
    // given
    string[string] members = ["foo": "bar"];

    // when
    string[string] actual = JSONValue(members).requireObject!string;

    // then
    actual.should.equal(members);
}

@("gets array elements")
unittest
{
    // given
    JSONValue[] elements = [JSONValue(2), JSONValue(3)];

    // when
    JSONValue[] actual = JSONValue(elements).requireArray;

    // then
    actual.should.equal(elements);
}

@("fails to get array elements from non-array")
unittest
{
    // given
    JSONValue value = JSONValue(["foo": JSONValue("bar")]);

    // when/then
    value.requireArray.should.throwA!JSONException;
}

@("gets array of string elements")
unittest
{
    // given
    JSONValue[] elements = [JSONValue("foo"), JSONValue("bar"), JSONValue("baz")];

    // when
    string[] actual = JSONValue(elements).requireArray!string;

    // then
    actual.should.equal(["foo", "bar", "baz"]);
}

@("fails to get array of string elements from heterogenous array")
unittest
{
    // given
    JSONValue[] elements = [JSONValue("foo"), JSONValue(2)];

    // when/then
    JSONValue(elements).requireArray!string.should.throwA!JSONException;
}

@("gets bool")
@safe unittest
{
    // when
    bool actual = JSONValue(true).require!bool;

    // then
    actual.should.equal(true);
}

@("fails to get bool from number")
unittest
{
    // when/then
    JSONValue(42).require!bool.should.throwA!JSONException;
}

@("gets int")
@safe unittest
{
    // when
    int actual = JSONValue(42).require!int;

    // then
    actual.should.equal(42);
}

@("gets ulong")
@safe unittest
{
    // when
    ulong actual = JSONValue(ulong.max).require!ulong;

    // then
    actual.should.equal(ulong.max);
}

@("fails to get invalid int")
unittest
{
    // when/then
    JSONValue(4.2).require!int.should.throwA!JSONException;
}

@("fails to get byte out of bounds")
unittest
{
    // when/then
    JSONValue(byte.max + 1).require!byte.should.throwA!JSONException;
}

@("gets float")
@safe unittest
{
    // when
    float actual = JSONValue(42.3).require!float;

    // then
    actual.should.be.approximately(42.3, error = 1e-3);
}

@("gets double")
@safe unittest
{
    // when
    double actual = JSONValue(42).require!double;

    // then
    actual.should.be.approximately(42, error = 1e-6);
}

@("gets real")
@safe unittest
{
    // when
    real actual = JSONValue(uint.max).require!real;

    // then
    actual.should.be.approximately(uint.max, error = 1e-6);
}

@("fails to get double from string")
unittest
{
    // when/then
    JSONValue("foo").require!double.should.throwA!JSONException;
}

@("gets string")
@safe unittest
{
    // when
    string actual = JSONValue("foo").require!string;

    // then
    actual.should.equal("foo");
}

@("fails to get string from number")
unittest
{
    // when/then
    JSONValue(42).require!string.should.throwA!JSONException;
}

@("gets enumeration member")
@safe unittest
{
    // given
    enum Enumeration
    {
        VALUE,
    }

    // when
    Enumeration actual = JSONValue("VALUE").require!Enumeration;

    // then
    actual.should.equal(Enumeration.VALUE);
}

@("fails to get invalid enumeration member")
unittest
{
    // given
    enum Enumeration
    {
        VALUE,
    }

    // when/then
    JSONValue("foo").require!Enumeration.should.throwA!JSONException;
}

@("gets flag")
@safe unittest
{
    // given
    alias Answer = Flag!"answer";

    // when
    Answer actual = JSONValue(true).require!Answer;

    // then
    actual.should.equal(Answer.yes);
}

@("gets date")
@safe unittest
{
    // when
    Date actual = JSONValue("2003-02-01").require!Date;

    // then
    actual.should.equal(Date(2003, 2, 1));
}

@("gets duration")
@safe unittest
{
    // when
    Duration actual = JSONValue("PT1H2M3S").require!Duration;

    // then
    actual.should.equal(1.hours + 2.minutes + 3.seconds);
}

@("fails to get invalid duration")
unittest
{
    // when/then
    JSONValue("foo").require!Duration.should.throwA!JSONException;
}

@("gets SysTime")
@safe unittest
{
    // when
    SysTime actual = JSONValue("2003-02-01T11:55:00").require!SysTime;

    // then
    actual.should.equal(SysTime(DateTime(2003, 2, 1, 11, 55)));
}

@("gets time of day")
@safe unittest
{
    // when
    TimeOfDay actual = JSONValue("01:02:03").require!TimeOfDay;

    // then
    actual.should.equal(TimeOfDay(1, 2, 3));
}

@("gets required value")
@safe unittest
{
    // given
    JSONObject object = JSONObject(["foo": JSONValue("bar")]);

    // when
    JSONValue actual = object.require("foo");

    // then
    actual.should.equal(JSONValue("bar"));
}

@("fails to get missing value")
unittest
{
    // given
    JSONObject object = JSONObject(["foo": JSONValue("bar")]);

    // when/then
    object.require("bar").should.throwA!JSONException;
}

@("gets required value instead of fallback")
@safe unittest
{
    // given
    JSONObject object = JSONObject(["foo": JSONValue(-1)]);

    // when
    int actual = object.require!int("foo", 42);

    // then
    actual.should.equal(-1);
}

@("gets fallback when required value is missing")
@safe unittest
{
    // given
    JSONObject object = JSONObject(["foo": JSONValue(-1)]);

    // when
    int actual = object.require!int("bar", 42);

    // then
    actual.should.equal(42);
}

@("fails to get invalid value instead of fallback")
unittest
{
    // given
    JSONObject object = JSONObject(["foo": JSONValue(true)]);

    // when/then
    object.require!int("foo", 42).should.throwA!JSONException;
}

@("gets nullable value")
@safe unittest
{
    // given
    JSONObject object = JSONObject(["foo": JSONValue(-1)]);

    // when
    Nullable!int actual = object.require!(Nullable!int)("foo");

    // then
    actual.isNull.should.equal(false);
    actual.get.should.equal(-1);
}

@("gets null when required value is missing")
@safe unittest
{
    // given
    JSONObject object = JSONObject(["foo": JSONValue(-1)]);

    // when
    Nullable!int actual = object.require!(Nullable!int)("bar");

    // then
    actual.isNull.should.equal(true);
}

@("fails to get invalid nullable value")
unittest
{
    // given
    JSONObject object = JSONObject(["foo": JSONValue(true)]);

    // when/then
    object.require!(Nullable!int)("foo").should.throwA!JSONException;
}
