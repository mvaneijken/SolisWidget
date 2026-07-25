using Toybox.Application;
using Toybox.WatchUi;
using Toybox.Communications;
using Toybox.Cryptography;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Lang;
using Toybox.System;

var gSettingsChanged = true;

class SolisWidgetApp extends Application.AppBase {
    hidden var mView;

    function initialize() {
        //System.println("SolisWidgetApp:initialize");
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state) {
        //System.println("SolisWidgetApp:onStart");
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
        //System.println("SolisWidgetApp:onStop");
    }

    // New app settings have been received so trigger a UI update
    function onSettingsChanged() {
        //System.println("SolisWidgetApp:onSettingsChanged");
        $.gSettingsChanged = true;
        WatchUi.requestUpdate();
    }

    // Return the initial view of your application here
    function getInitialView() {
        //System.println("SolisWidgetApp:getInitialView");
        mView = new SolisWidgetView();
        return [mView, new SolisWidgetDelegate(mView.method(:HandleCommand))];
    }

    (:glance)
    function getGlanceView() {
        //System.println("SolisWidgetApp:getGlanceView");
        return [new SolisWidgetGlanceView()];
    }

    // -------------------------------------------------------------------------
    // Settings
    // -------------------------------------------------------------------------

    function retrieveSettings() {
        apiKey = getProperty("PAK");
        if (apiKey == null) {
            apiKey = "";
        }

        apiSecret = getProperty("PSK");
        if (apiSecret == null) {
            apiSecret = "";
        }

        currPage = getProperty("PSP");
        if (currPage == null) {
            currPage = 1;
        }

        stationId = getProperty("PSI");
        if (stationId == null || !(stationId instanceof String)) {
            stationId = "";
        }

        // Reset cached station ID if API credentials have changed
        var storedKey = getProperty("currApiKey");
        var storedSecret = getProperty("currApiSecret");
        if (
            storedKey != null &&
            !storedKey.equals("") &&
            !apiKey.equals(storedKey)
        ) {
            stationId = "";
        }
        if (
            storedSecret != null &&
            !storedSecret.equals("") &&
            !apiSecret.equals(storedSecret)
        ) {
            stationId = "";
        }

        glanceName = getProperty("AppName");
        glanceVal = "";
    }

    // -------------------------------------------------------------------------
    // Crypto / signing helpers
    // -------------------------------------------------------------------------

    // Build an RFC 2822 UTC date string, e.g. "Mon, 01 Jan 2024 12:00:00 GMT"
    // Gregorian.utcInfo() returns UTC calendar fields directly (available since SDK 2.4.0).
    function buildRfc2822Date() {
        var dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        var monNames = [
            "Jan",
            "Feb",
            "Mar",
            "Apr",
            "May",
            "Jun",
            "Jul",
            "Aug",
            "Sep",
            "Oct",
            "Nov",
            "Dec",
        ];

        var t = Gregorian.utcInfo(Time.now(), Time.FORMAT_SHORT);

        // Garmin day_of_week: 1=Sunday ... 7=Saturday
        return Lang.format("$1$, $2$ $3$ $4$ $5$:$6$:$7$ GMT", [
            dayNames[t.day_of_week - 1],
            t.day.format("%02d"),
            monNames[t.month - 1],
            t.year.format("%04d"),
            t.hour.format("%02d"),
            t.min.format("%02d"),
            t.sec.format("%02d"),
        ]);
    }

    // Base64-encode a ByteArray (or Array<Number>) to a String.
    // Handles the small digests produced by MD5 (16 bytes) and SHA1 (20 bytes).
    function base64Encode(data) {
        var chars =
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        var result = "";
        var n = data.size();
        var i = 0;
        while (i < n) {
            var b0 = data[i] & 0xff;
            var b1 = i + 1 < n ? data[i + 1] & 0xff : 0;
            var b2 = i + 2 < n ? data[i + 2] & 0xff : 0;
            var idx0 = (b0 >> 2) & 0x3f;
            var idx1 = ((b0 << 4) | (b1 >> 4)) & 0x3f;
            var idx2 = ((b1 << 2) | (b2 >> 6)) & 0x3f;
            var idx3 = b2 & 0x3f;
            result = result + chars.substring(idx0, idx0 + 1);
            result = result + chars.substring(idx1, idx1 + 1);
            result =
                result + (i + 1 < n ? chars.substring(idx2, idx2 + 1) : "=");
            result =
                result + (i + 2 < n ? chars.substring(idx3, idx3 + 1) : "=");
            i += 3;
        }
        return result;
    }

    // Convert a String to ByteArray (Hash.update requires ByteArray, not Array<Number>).
    function strToBytes(s) {
        var arr = s.toUtf8Array();
        var ba = new [arr.size()]b;
        for (var i = 0; i < arr.size(); i++) {
            ba[i] = arr[i] & 0xff;
        }
        return ba;
    }

    // HMAC-SHA1 implemented manually using Cryptography.Hash (Garmin SDK has no Mac class).
    // keyBytes and msgBytes must be ByteArray.
    // Returns ByteArray (20-byte SHA1 digest).
    function hmacSha1(keyBytes, msgBytes) {
        var blockSize = 64;

        // If key is longer than the block size, hash it first
        if (keyBytes.size() > blockSize) {
            var h = new Cryptography.Hash({
                :algorithm => Cryptography.HASH_SHA1,
            });
            h.update(keyBytes);
            keyBytes = h.digest();
        }

        // Pad key to blockSize with zeros, build ipad and opad as ByteArrays
        var ipad = new [blockSize]b;
        var opad = new [blockSize]b;
        for (var i = 0; i < blockSize; i++) {
            var kb = i < keyBytes.size() ? keyBytes[i] & 0xff : 0;
            ipad[i] = (kb ^ 0x36) & 0xff;
            opad[i] = (kb ^ 0x5c) & 0xff;
        }

        // inner = SHA1(ipad || message)
        var inner = new Cryptography.Hash({
            :algorithm => Cryptography.HASH_SHA1,
        });
        inner.update(ipad);
        inner.update(msgBytes);
        var innerDigest = inner.digest();

        // result = SHA1(opad || inner)
        var outer = new Cryptography.Hash({
            :algorithm => Cryptography.HASH_SHA1,
        });
        outer.update(opad);
        outer.update(innerDigest);
        return outer.digest();
    }

    // Sign and send a POST request to the SolisCloud API.
    // bodyStr is used only for MD5/HMAC computation — must match Garmin's compact JSON serialisation
    // of bodyParams exactly (Garmin serialises Dictionary as compact JSON, insertion-order keys).
    // Signing: Authorization = "API {keyId}:{base64(HMAC-SHA1(secret, stringToSign))}"
    // StringToSign = "POST\n{Content-MD5}\napplication/json\n{Date}\n{path}"
    function makeSignedPostRequest(path, bodyStr, bodyParams, callback) {
        var contentType = Communications.REQUEST_CONTENT_TYPE_JSON; // "application/json"
        var dateStr = buildRfc2822Date();

        // Compute Content-MD5 = base64(MD5(body))
        var md5 = new Cryptography.Hash({
            :algorithm => Cryptography.HASH_MD5,
        });
        md5.update(strToBytes(bodyStr));
        var md5b64 = base64Encode(md5.digest());

        // Build string to sign — must use literal "application/json", not the numeric constant
        var stringToSign =
            "POST\n" + md5b64 + "\napplication/json\n" + dateStr + "\n" + path;

        // Compute HMAC-SHA1 signature using manual implementation
        var signature = base64Encode(
            hmacSha1(strToBytes(apiSecret), strToBytes(stringToSign))
        );

        var Authorization = "API " + apiKey + ":" + signature;
        var headers = {
            "Content-Type" => contentType,
            "Content-MD5" => md5b64,
            "Date" => dateStr,
            "Authorization" => Authorization,
        };

        //System.println("POST " + path);
        //System.println("  Date: " + dateStr);
        //System.println("  MD5:  " + md5b64);
        //System.println("  Sig:  " + signature);
        //System.println("  Body: " + bodyStr);
        Communications.makeWebRequest(
            baseUrl + path,
            bodyParams,
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => headers,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            },
            callback
        );
    }

    // -------------------------------------------------------------------------
    // Response helpers
    // -------------------------------------------------------------------------

    function setNotParsable() {
        curr = null;
        today = null;
        thisMonth = null;
        thisYear = null;
        total = null;
        lstUpd = null;
        lastUpdTmLocal = null;
        lastUpdDtLocal = null;
    }

    function procRespCode(rspCode, data) {
        showRefrsh = false;
        $.showErr = false;

        if (rspCode == 200) {
            $.showErr = false;
            var isOk =
                data != null &&
                data["code"] != null &&
                data["code"].equals("0");
            //System.println(
            //    "HTTP 200  code=" +
            //        (data != null ? data["code"] : "null") +
            //        "  success=" +
            //        (data != null ? data["success"] : "null") +
            //        "  msg=" +
            //        (data != null ? data["msg"] : "null")
            //);
            if (!isOk) {
                $.showErr = true;
                var msg = "";
                if (data != null && data["msg"] != null) {
                    msg = data["msg"].toString();
                }
                errStr1 = "API Err: " + msg;

                if ($.gIsGlance) {
                    // Show shorter error message in glance view
                    errStr2 = "";
                    errStr3 = "";
                    errStr4 = "";
                } else {
                    errStr2 = WatchUi.loadResource(Rez.Strings.A2);
                    errStr3 = WatchUi.loadResource(Rez.Strings.A3);
                    errStr4 = WatchUi.loadResource(Rez.Strings.E6);
                }
                data = null;
            }
        } else if (rspCode == -104) //Communications.BLE_CONNECTION_UNAVAILABLE
        {
            $.showErr = true;
            errStr1 = WatchUi.loadResource(Rez.Strings.B1);

            if ($.gIsGlance) {
                // Show shorter error message in glance view
                errStr2 = "";
                errStr3 = "";
                errStr4 = "";
            } else {
                errStr2 = WatchUi.loadResource(Rez.Strings.B2);
                errStr3 = WatchUi.loadResource(Rez.Strings.B3);
                errStr4 = "";
            }
            data = null;
        } else if (
            rspCode == -400
        ) //Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE
        {
            $.showErr = true;
            errStr1 = WatchUi.loadResource(Rez.Strings.I1);
            if ($.gIsGlance) {
                // Show shorter error message in glance view
                errStr2 = "";
                errStr3 = "";
                errStr4 = "";
            } else {
                errStr2 = WatchUi.loadResource(Rez.Strings.I2);
                errStr3 = WatchUi.loadResource(Rez.Strings.I3);
                errStr4 = "";
            }
            data = null;
        } else if (rspCode == -403) //Communications.NETWORK_RESPONSE_OUT_OF_MEMORY
        {
            if ($.gIsGlance) {
                // Response too large for glance heap — silently show cached data
                showRefrsh = false;
                $.showErr = false;
            } else {
                $.showErr = true;
                errStr1 = "Out of memory";
                errStr2 = WatchUi.loadResource(Rez.Strings.E1);
                errStr3 = WatchUi.loadResource(Rez.Strings.E2);
                errStr4 = WatchUi.loadResource(Rez.Strings.E3);
            }
            data = null;
        } else if (rspCode == -300) //Communications.NETWORK_REQUEST_TIMED_OUT
        {
            $.showErr = true;
            errStr1 = WatchUi.loadResource(Rez.Strings.N1);

            if ($.gIsGlance) {
                // Show shorter error message in glance view
                errStr2 = "";
                errStr3 = "";
                errStr4 = "";
            } else {
                errStr2 = WatchUi.loadResource(Rez.Strings.N2);
                errStr3 = WatchUi.loadResource(Rez.Strings.N3);
                errStr4 = "";
            }
            data = null;
        } else {
            $.showErr = true;
            errStr1 = "Error " + rspCode;
            if ($.gIsGlance) {
                errStr2 = "";
                errStr3 = "";
                errStr4 = "";
            } else {
                errStr2 = WatchUi.loadResource(Rez.Strings.E1);
                errStr3 = WatchUi.loadResource(Rez.Strings.E2);
                errStr4 = WatchUi.loadResource(Rez.Strings.E3);
            }
        }
        WatchUi.requestUpdate();
        return $.showErr;
    }

    // -------------------------------------------------------------------------
    // API request chain
    // -------------------------------------------------------------------------

    // Production build (monkey.jungle excludes :demo): no demo data,
    // continue with the real API request chain
    (:prod)
    function applyDemoData() {
        return false;
    }

    // Demo build (monkey-demo.jungle excludes :prod): show realistic values
    // without any network access. Used to capture store screenshots in CI.
    (:demo)
    function applyDemoData() {
        curr = "3.21 kW";
        today = "18.6 kWh";
        thisMonth = "412.9 kWh";
        thisYear = "4.06 MWh";
        total = "9.85 MWh";

        var i = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        lastUpdTmLocal = Lang.format("$1$:$2$:$3$", [
            i.hour.format("%02u"),
            i.min.format("%02u"),
            i.sec.format("%02u"),
        ]);
        lastUpdDtLocal = Lang.format("$1$-$2$-$3$", [
            i.year.format("%04u"),
            i.month.format("%02u"),
            i.day.format("%02u"),
        ]);

        showRefrsh = false;
        $.showErr = false;
        $.updateGlanceProperties();
        return true;
    }

    // Entry point: route to the correct first uncached step
    function makeReq() {
        fUpdt = false;

        if (applyDemoData()) {
            WatchUi.requestUpdate();
            return;
        }

        if (
            apiKey == null ||
            apiKey.length() == 0 ||
            apiSecret == null ||
            apiSecret.length() == 0
        ) {
            $.showErr = true;
            showRefrsh = false;
            if ($.gIsGlance) {
                errStr1 = WatchUi.loadResource(Rez.Strings.I1);
                errStr2 = "";
                errStr3 = "";
                errStr4 = "";
            } else {
                errStr1 = WatchUi.loadResource(Rez.Strings.I1);
                errStr2 = WatchUi.loadResource(Rez.Strings.A2);
                errStr3 = WatchUi.loadResource(Rez.Strings.A3);
                errStr4 = "";
            }
            WatchUi.requestUpdate();
            return;
        }

        $.showErr = false;
        showRefrsh = true;
        WatchUi.requestUpdate();

        if($.gIsGlance && currPage == 1){
            makeReqInverterList();
        }
        else {
            if (stationId == null || stationId.equals("")) {
                makeReqStationList();
            }
            else {
                makeReqStationDetail();
            }
        }
    }

    // Step 1: Fetch station list to obtain stationId
    function makeReqStationList() {
        makeSignedPostRequest(
            "/v1/api/userStationList",
            "{\"pageNo\":1,\"pageSize\":20}",
            { "pageNo" => 1, "pageSize" => 20 },
            method(:onRecStationList)
        );
    }

    function onRecStationList(rspCode, data) {
        //System.println("onRecStationList rspCode=" + rspCode + " data=" + data);
        $.showErr = procRespCode(rspCode, data);
        if ($.showErr) {
            WatchUi.requestUpdate();
            return;
        }

        try {
            stationId = data["data"]["page"]["records"][0]["id"].toString();
            setProperty("PSI", stationId);
        } catch (ex) {
            $.showErr = true;
            errStr1 = WatchUi.loadResource(Rez.Strings.E4);
            errStr2 = WatchUi.loadResource(Rez.Strings.E5);
            errStr3 = WatchUi.loadResource(Rez.Strings.E6);
            errStr4 = "";
            WatchUi.requestUpdate();
            return;
        }
        makeReqStationDetail();
    }

    // Step 2: Fetch station detail — contains all display metrics
    function makeReqStationDetail() {
        makeSignedPostRequest(
            "/v1/api/stationDetail",
            "{\"id\":\"" + stationId + "\"}",
            { "id" => stationId },
            method(:onRecStationDetail)
        );
    }

    function onRecStationDetail(rspCode, data) {
        $.showErr = procRespCode(rspCode, data);
        if ($.showErr) {
            WatchUi.requestUpdate();
            return;
        }

        if (data instanceof Dictionary) {
            try {
                var d = data["data"];

                // Current power: power is in kW, display as-is with unit from API
                var power = d["power"].toFloat();
                curr = power.format("%.2f") + " " + d["powerStr"];

                // Today's energy
                today =
                    d["dayEnergy"].toFloat().format("%.1f") +
                    " " +
                    d["dayEnergyStr"];

                // Monthly energy
                thisMonth =
                    d["monthEnergy"].toFloat().format("%.1f") +
                    " " +
                    d["monthEnergyStr"];

                // Yearly energy
                thisYear =
                    d["yearEnergy"].toFloat().format("%.1f") +
                    " " +
                    d["yearEnergyStr"];

                // Total energy
                total =
                    d["allEnergy"].toFloat().format("%.1f") +
                    " " +
                    d["allEnergyStr"];

                // Last updated timestamp (local device time)
                var i = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
                lastUpdTmLocal = Lang.format("$1$:$2$:$3$", [
                    i.hour.format("%02u"),
                    i.min.format("%02u"),
                    i.sec.format("%02u"),
                ]);
                lastUpdDtLocal = Lang.format("$1$-$2$-$3$", [
                    i.year.format("%04u"),
                    i.month.format("%02u"),
                    i.day.format("%02u"),
                ]);

                // Record successful fetch time and update glance properties
                lastFetchTime = Time.now().value();
                setProperty("PFT", lastFetchTime);
                $.updateGlanceProperties();
            } catch (ex) {
                setNotParsable();
            }
        } else {
            setNotParsable();
        }
        WatchUi.requestUpdate();
    }


    // Step 2: Fetch inverter list — contains current power for glance
    function makeReqInverterList() {
        makeSignedPostRequest(
            "/v1/api/inverterList",
            "{\"pageNo\":1,\"pageSize\":20}",
            { "pageNo" => 1, "pageSize" => 20 },
            method(:onRecInverterList)
        );
    }

    function onRecInverterList(rspCode, data) {
        $.showErr = procRespCode(rspCode, data);
        if ($.showErr) {
            WatchUi.requestUpdate();
            return;
        }

        if (data instanceof Dictionary) {
            try {
                var d = data["data"]["page"]["records"][0];

                // Current power: power is in kW, display as-is with unit from API
                var power = d["pow1"].toFloat();
                curr = power.format("%.2f") + " " + d["powerStr"];

                // // Last updated timestamp (local device time)
                // var i = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
                // lastUpdTmLocal = Lang.format("$1$:$2$:$3$", [
                //     i.hour.format("%02u"),
                //     i.min.format("%02u"),
                //     i.sec.format("%02u"),
                // ]);
                // lastUpdDtLocal = Lang.format("$1$-$2$-$3$", [
                //     i.year.format("%04u"),
                //     i.month.format("%02u"),
                //     i.day.format("%02u"),
                // ]);

                // Record successful fetch time and update glance properties
                lastFetchTime = Time.now().value();
                setProperty("PFT", lastFetchTime);
                $.updateGlanceProperties();
            } catch (ex) {
                setNotParsable();
            }
        } else {
            setNotParsable();
        }
        WatchUi.requestUpdate();
    }

}
