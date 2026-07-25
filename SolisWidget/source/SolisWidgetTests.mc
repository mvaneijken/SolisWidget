// Unit tests for SolisWidget using Garmin's "Run No Evil" test framework.
// All code in this file is annotated with (:test) so it is only compiled
// when building with the --unit-test flag and never ships in release builds.
//
// Run locally with:
//   docker run -v $(pwd):/app -w /app/SolisWidget ghcr.io/matco/connectiq-tester:latest fenix7

using Toybox.Test;
using Toybox.Application;
using Toybox.Cryptography;
using Toybox.System;

// NOTE: every (:test) function is executed as a test by the runner, so this
// file deliberately has no shared helper functions.

// -----------------------------------------------------------------------------
// base64Encode
// -----------------------------------------------------------------------------

(:test)
function testBase64EncodeRfc4648Vectors(logger) {
    var app = Application.getApp();

    // RFC 4648 test vectors, covering all three padding cases
    Test.assertEqualMessage(app.base64Encode(app.strToBytes("f")), "Zg==", "base64 of 'f'");
    Test.assertEqualMessage(app.base64Encode(app.strToBytes("fo")), "Zm8=", "base64 of 'fo'");
    Test.assertEqualMessage(app.base64Encode(app.strToBytes("foo")), "Zm9v", "base64 of 'foo'");
    Test.assertEqualMessage(app.base64Encode(app.strToBytes("foob")), "Zm9vYg==", "base64 of 'foob'");
    Test.assertEqualMessage(app.base64Encode(app.strToBytes("fooba")), "Zm9vYmE=", "base64 of 'fooba'");
    Test.assertEqualMessage(app.base64Encode(app.strToBytes("foobar")), "Zm9vYmFy", "base64 of 'foobar'");

    return true;
}

(:test)
function testBase64EncodeDigestSizes(logger) {
    var app = Application.getApp();

    // 16 bytes: the size of an MD5 digest (used for Content-MD5)
    var md5Sized = new [16]b;
    for (var i = 0; i < 16; i++) {
        md5Sized[i] = 0x00;
    }
    Test.assertEqualMessage(
        app.base64Encode(md5Sized),
        "AAAAAAAAAAAAAAAAAAAAAA==",
        "base64 of 16 zero bytes"
    );

    // 20 bytes: the size of a SHA1 digest (used for the request signature)
    var sha1Sized = new [20]b;
    for (var i = 0; i < 20; i++) {
        sha1Sized[i] = 0xff;
    }
    Test.assertEqualMessage(
        app.base64Encode(sha1Sized),
        "//////////////////////////8=",
        "base64 of 20 0xff bytes"
    );

    return true;
}

// -----------------------------------------------------------------------------
// strToBytes
// -----------------------------------------------------------------------------

(:test)
function testStrToBytes(logger) {
    var app = Application.getApp();

    var bytes = app.strToBytes("abc");
    Test.assertEqualMessage(bytes.size(), 3, "strToBytes('abc') size");
    Test.assertEqualMessage(bytes[0], 0x61, "strToBytes 'a'");
    Test.assertEqualMessage(bytes[1], 0x62, "strToBytes 'b'");
    Test.assertEqualMessage(bytes[2], 0x63, "strToBytes 'c'");

    Test.assertEqualMessage(app.strToBytes("").size(), 0, "strToBytes('') is empty");

    return true;
}

// -----------------------------------------------------------------------------
// hmacSha1 (verified against RFC 2202 and well-known test vectors)
// -----------------------------------------------------------------------------

(:test)
function testHmacSha1Rfc2202Jefe(logger) {
    var app = Application.getApp();

    // RFC 2202 test case 2:
    // HMAC-SHA1("Jefe", "what do ya want for nothing?")
    //   = effcdf6ae5eb2fa2d27416d5f184df9c259a7c79
    var digest = app.hmacSha1(
        app.strToBytes("Jefe"),
        app.strToBytes("what do ya want for nothing?")
    );
    Test.assertEqualMessage(digest.size(), 20, "HMAC-SHA1 digest is 20 bytes");
    Test.assertEqualMessage(
        app.base64Encode(digest),
        "7/zfauXrL6LSdBbV8YTfnCWafHk=",
        "RFC 2202 'Jefe' vector"
    );

    return true;
}

(:test)
function testHmacSha1QuickBrownFox(logger) {
    var app = Application.getApp();

    // HMAC-SHA1("key", "The quick brown fox jumps over the lazy dog")
    //   = de7c9b85b8b78aa6bc8a7a36f70a90701c9db4d9
    var digest = app.hmacSha1(
        app.strToBytes("key"),
        app.strToBytes("The quick brown fox jumps over the lazy dog")
    );
    Test.assertEqualMessage(
        app.base64Encode(digest),
        "3nybhbi3iqa8ino29wqQcBydtNk=",
        "'quick brown fox' vector"
    );

    return true;
}

(:test)
function testHmacSha1KeyLongerThanBlockSize(logger) {
    var app = Application.getApp();

    // RFC 2202 test case 6: 80-byte key of 0xaa exercises the
    // "hash the key first when longer than the 64-byte block size" path.
    // HMAC-SHA1 = aa4ae5e15272d00e95705637ce8a3b55ed402112
    var key = new [80]b;
    for (var i = 0; i < 80; i++) {
        key[i] = 0xaa;
    }
    var digest = app.hmacSha1(
        key,
        app.strToBytes("Test Using Larger Than Block-Size Key - Hash Key First")
    );
    Test.assertEqualMessage(
        app.base64Encode(digest),
        "qkrl4VJy0A6VcFY3zoo7Ve1AIRI=",
        "RFC 2202 long-key vector"
    );

    return true;
}

// -----------------------------------------------------------------------------
// Content-MD5 (the signing input used by makeSignedPostRequest)
// -----------------------------------------------------------------------------

(:test)
function testContentMd5OfRequestBodies(logger) {
    var app = Application.getApp();

    // base64(MD5(body)) for the exact userStationList body string
    var md5 = new Cryptography.Hash({ :algorithm => Cryptography.HASH_MD5 });
    md5.update(app.strToBytes("{\"pageNo\":1,\"pageSize\":20}"));
    Test.assertEqualMessage(
        app.base64Encode(md5.digest()),
        "jiion4rNY0nKP5xj4NxZ2w==",
        "Content-MD5 of userStationList body"
    );

    // and for a stationDetail-style body
    var md5b = new Cryptography.Hash({ :algorithm => Cryptography.HASH_MD5 });
    md5b.update(app.strToBytes("{\"id\":\"12345\"}"));
    Test.assertEqualMessage(
        app.base64Encode(md5b.digest()),
        "4LVZ/G41bFfZask8pWzIbw==",
        "Content-MD5 of stationDetail body"
    );

    return true;
}

// -----------------------------------------------------------------------------
// buildRfc2822Date
// -----------------------------------------------------------------------------

(:test)
function testBuildRfc2822DateFormat(logger) {
    var app = Application.getApp();

    // The clock cannot be pinned in the simulator, so validate the structure:
    // "Ddd, DD Mmm YYYY HH:MM:SS GMT" (always 29 characters)
    var date = app.buildRfc2822Date();
    logger.debug("buildRfc2822Date: " + date);

    Test.assertEqualMessage(date.length(), 29, "RFC 2822 date is 29 chars");
    Test.assertEqualMessage(date.substring(3, 5), ", ", "comma+space after day name");
    Test.assertEqualMessage(date.substring(25, 29), " GMT", "ends with ' GMT'");

    var dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    var day = date.substring(0, 3);
    var dayOk = false;
    for (var i = 0; i < dayNames.size(); i++) {
        if (day.equals(dayNames[i])) {
            dayOk = true;
        }
    }
    Test.assertMessage(dayOk, "day name '" + day + "' is valid");

    var monNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    var mon = date.substring(8, 11);
    var monOk = false;
    for (var i = 0; i < monNames.size(); i++) {
        if (mon.equals(monNames[i])) {
            monOk = true;
        }
    }
    Test.assertMessage(monOk, "month name '" + mon + "' is valid");

    // Time separators
    Test.assertEqualMessage(date.substring(19, 20), ":", "colon between hours and minutes");
    Test.assertEqualMessage(date.substring(22, 23), ":", "colon between minutes and seconds");

    return true;
}

// -----------------------------------------------------------------------------
// frmtEnergy (SolisWidgetView)
// -----------------------------------------------------------------------------

(:test)
function testFrmtEnergy(logger) {
    var view = new SolisWidgetView();

    Test.assertEqualMessage(view.frmtEnergy(0.5), "500 Wh", "0.5 kWh shown as Wh");
    Test.assertEqualMessage(view.frmtEnergy(1.5), "1.5 kWh", "1.5 kWh shown as kWh");
    Test.assertEqualMessage(view.frmtEnergy("2.5"), "2.5 kWh", "numeric string input");
    Test.assertEqualMessage(view.frmtEnergy(0), "0 Wh", "zero");
    Test.assertEqualMessage(view.frmtEnergy("abc"), "No data received", "non-numeric input");

    return true;
}

// -----------------------------------------------------------------------------
// Page navigation (NextPage / PreviousPage wrap-around)
// -----------------------------------------------------------------------------

(:test)
function testPageNavigationWrapAround(logger) {
    $.currPage = 1;
    NextPage();
    Test.assertEqualMessage($.currPage, 2, "1 -> 2");

    $.currPage = 6;
    NextPage();
    Test.assertEqualMessage($.currPage, 1, "6 wraps to 1");

    $.currPage = 2;
    PreviousPage();
    Test.assertEqualMessage($.currPage, 1, "2 -> 1");

    $.currPage = 1;
    PreviousPage();
    Test.assertEqualMessage($.currPage, 6, "1 wraps to 6");

    return true;
}
