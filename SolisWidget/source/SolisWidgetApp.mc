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
        apiType = getProperty("PAT");
        if (apiType == null) {
            apiType = 1;
        }
        if (apiType instanceof String) {
            apiType = apiType.toNumber();
        }
        if (apiType != 1 && apiType != 2) {
            apiType = 1;
        }

        apiKey = getProperty("PAK");
        if (apiKey == null) {
            apiKey = "";
        }

        apiSecret = getProperty("PSK");
        if (apiSecret == null) {
            apiSecret = "";
        }

        legacyUser = getProperty("PUN");
        if (legacyUser == null) {
            legacyUser = "";
        }

        legacyPassword = getProperty("PPS");
        if (legacyPassword == null) {
            legacyPassword = "";
        }

        currPage = getProperty("PSP");
        if (currPage == null) {
            currPage = 1;
        }

        stationId = getProperty("PSI");
        if (stationId == null || !(stationId instanceof String)) {
            stationId = "";
        }

        legacyUserId = getProperty("PUI");
        if (legacyUserId == null) {
            legacyUserId = -1;
        } else if (legacyUserId instanceof String) {
            if (legacyUserId.equals("")) {
                legacyUserId = -1;
            } else {
                legacyUserId = legacyUserId.toNumber();
            }
        }

        legacyPlantId = getProperty("PPI");
        if (legacyPlantId == null) {
            legacyPlantId = -1;
        } else if (legacyPlantId instanceof String) {
            if (legacyPlantId.equals("")) {
                legacyPlantId = -1;
            } else {
                legacyPlantId = legacyPlantId.toNumber();
            }
        }

        // Reset cache when API type changes
        var storedApiType = getProperty("currApiType");
        if (storedApiType instanceof String) {
            storedApiType = storedApiType.toNumber();
        }
        if (storedApiType != null && storedApiType != apiType) {
            stationId = "";
            legacyUserId = -1;
            legacyPlantId = -1;
        }

        // Reset cached station ID if API key credentials have changed
        var storedKey = getProperty("currApiKey");
        var storedSecret = getProperty("currApiSecret");
        if (
            !isLegacyApiType() &&
            storedKey != null &&
            !storedKey.equals("") &&
            !apiKey.equals(storedKey)
        ) {
            stationId = "";
        }
        if (
            !isLegacyApiType() &&
            storedSecret != null &&
            !storedSecret.equals("") &&
            !apiSecret.equals(storedSecret)
        ) {
            stationId = "";
        }

        // Reset cached legacy IDs if legacy credentials have changed
        var storedUser = getProperty("currUsr");
        var storedPassword = getProperty("currPwrd");
        if (
            isLegacyApiType() &&
            storedUser != null &&
            !storedUser.equals("") &&
            !legacyUser.equals(storedUser)
        ) {
            legacyUserId = -1;
            legacyPlantId = -1;
        }
        if (
            isLegacyApiType() &&
            storedPassword != null &&
            !storedPassword.equals("") &&
            !legacyPassword.equals(storedPassword)
        ) {
            legacyUserId = -1;
            legacyPlantId = -1;
        }

        glanceName = getProperty("AppName");
        glanceVal = "";
    }

    function isLegacyApiType() {
        return apiType == 2;
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

    function frmtEnergy(pwr) {
        try {
            pwr = pwr.toFloat();
        } catch (ex) {
            pwr = null;
        }

        if (pwr != null) {
            if (pwr < 1) {
                return (pwr * 1000).toNumber() + " Wh";
            }
            return pwr.format("%.1f") + " kWh";
        }
        return "No data received";
    }

    // HMAC-SHA1 implemented manually using Cryptography.Hash (Garmin SDK has no Mac class).
    // keyBytes and msgBytes must be ByteArray.
    // Returns ByteArray (20-byte SHA1 digest).
    function hmacSha1(keyBytes, msgBytes) {
        var blockSize = 64;
        var key = new [keyBytes.size()]b;
        for (var i = 0; i < keyBytes.size(); i++) {
            key[i] = keyBytes[i] & 0xff;
        }

        // If key is longer than the block size, hash it first
        if (key.size() > blockSize) {
            var h = new Cryptography.Hash({
                :algorithm => Cryptography.HASH_SHA1,
            });
            h.update(key);
            key = h.digest();
        }

        // Pad key to blockSize with zeros, build ipad and opad as ByteArrays
        var ipad = new [blockSize]b;
        var opad = new [blockSize]b;
        for (var j = 0; j < blockSize; j++) {
            var kb = j < key.size() ? key[j] & 0xff : 0;
            ipad[j] = (kb ^ 0x36) & 0xff;
            opad[j] = (kb ^ 0x5c) & 0xff;
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

        System.println("POST " + path);
        System.println("  Date: " + dateStr);
        System.println("  MD5:  " + md5b64);
        System.println("  Sig:  " + signature);
        System.println("  Body: " + bodyStr);
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
            var isOk = false;
            var errResultCode = -1;
            var msg = "";
            if (isLegacyApiType()) {
                isOk =
                    data != null &&
                    data["result"] != null &&
                    data["result"].toNumber() == 1;
                errResultCode =
                    data != null && data["result"] != null
                        ? data["result"].toNumber()
                        : -1;
                msg = data != null && data["result"] != null
                    ? data["result"].toString()
                    : "null";
                System.println(
                    "HTTP 200  result=" +
                        (data != null ? data["result"] : "null")
                );
            } else {
                isOk =
                    data != null &&
                    data["code"] != null &&
                    data["code"].equals("0");
                msg = data != null && data["msg"] != null
                    ? data["msg"].toString()
                    : "";
                System.println(
                    "HTTP 200  code=" +
                        (data != null ? data["code"] : "null") +
                        "  success=" +
                        (data != null ? data["success"] : "null") +
                        "  msg=" +
                        (data != null ? data["msg"] : "null")
                );
            }

            if (!isOk) {
                $.showErr = true;
                errStr1 = "API Err: " + msg;

                if (isLegacyApiType()) {
                    legacyUserId = -1;
                    legacyPlantId = -1;
                    setProperty("PUI", "");
                    setProperty("PPI", "");
                }

                if ($.gIsGlance) {
                    // Show shorter error message in glance view
                    errStr2 = "";
                    errStr3 = "";
                    errStr4 = "";
                } else {
                    if (isLegacyApiType() && (errResultCode == 5 || errResultCode == 11)) {
                        errStr2 = WatchUi.loadResource(Rez.Strings.A1);
                        errStr3 = WatchUi.loadResource(Rez.Strings.A2);
                        errStr4 = WatchUi.loadResource(Rez.Strings.A3);
                    } else {
                        errStr2 = WatchUi.loadResource(Rez.Strings.A2);
                        errStr3 = WatchUi.loadResource(Rez.Strings.A3);
                        errStr4 = WatchUi.loadResource(Rez.Strings.E6);
                    }
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

    // Entry point: route to the correct first uncached step
    function makeReq() {
        fUpdt = false;

        var missingCredentials = false;
        if (isLegacyApiType()) {
            missingCredentials =
                legacyUser == null ||
                legacyUser.length() == 0 ||
                legacyPassword == null ||
                legacyPassword.length() == 0;
        } else {
            missingCredentials =
                apiKey == null ||
                apiKey.length() == 0 ||
                apiSecret == null ||
                apiSecret.length() == 0;
        }

        if (missingCredentials) {
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

        setProperty("currApiType", apiType);

        if (isLegacyApiType()) {
            setProperty("currUsr", legacyUser);
            setProperty("currPwrd", legacyPassword);
            if (legacyUserId == null || legacyUserId < 0) {
                makeReqLegacyLogin();
            } else if (legacyPlantId == null || legacyPlantId < 0) {
                makeReqLegacyPlantId();
            } else {
                makeReqLegacyPlantOverview();
            }
            return;
        }

        setProperty("currApiKey", apiKey);
        setProperty("currApiSecret", apiSecret);

        if ($.gIsGlance && currPage == 1) {
            makeReqInverterList();
        } else {
            if (stationId == null || stationId.equals("")) {
                makeReqStationList();
            } else {
                makeReqStationDetail();
            }
        }
    }

    // Legacy API step 1: Login with username/password
    function makeReqLegacyLogin() {
        var path = "/v/ap.2.0/cust/user/login";
        var query =
            "user_id=" +
            legacyUser +
            "&user_pass=" +
            legacyPassword +
            "&terminate=android&push_sn=9601b3865bdabf6ea01a7318ac5cc749&timezone=1&lan=en&country=CN&cust=659";

        Communications.makeWebRequest(
            legacyBaseUrl + path + "?" + query,
            {},
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            },
            method(:onRecLegacyLogin)
        );
    }

    function onRecLegacyLogin(rspCode, data) {
        $.showErr = procRespCode(rspCode, data);
        if ($.showErr) {
            WatchUi.requestUpdate();
            return;
        }

        try {
            legacyUserId = data["uid"].toNumber();
            setProperty("PUI", legacyUserId.toString());
        } catch (ex) {
            $.showErr = true;
            errStr1 = WatchUi.loadResource(Rez.Strings.A1);
            errStr2 = WatchUi.loadResource(Rez.Strings.A2);
            errStr3 = WatchUi.loadResource(Rez.Strings.A3);
            errStr4 = "";
            WatchUi.requestUpdate();
            return;
        }
        makeReqLegacyPlantId();
    }

    // Legacy API step 2: Fetch plant ID for the user
    function makeReqLegacyPlantId() {
        var path = "/v/ap.2.0/plant/find_plant_list";
        var query =
            "uid=" +
            legacyUserId.toString() +
            "&sel_scope=1&sort_type=1";

        Communications.makeWebRequest(
            legacyBaseUrl + path + "?" + query,
            {},
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            },
            method(:onRecLegacyPlantId)
        );
    }

    function onRecLegacyPlantId(rspCode, data) {
        $.showErr = procRespCode(rspCode, data);
        if ($.showErr) {
            WatchUi.requestUpdate();
            return;
        }

        try {
            legacyPlantId = data["list"][0]["plant_id"].toNumber();
            setProperty("PPI", legacyPlantId.toString());
        } catch (ex) {
            $.showErr = true;
            errStr1 = WatchUi.loadResource(Rez.Strings.E4);
            errStr2 = WatchUi.loadResource(Rez.Strings.E5);
            errStr3 = WatchUi.loadResource(Rez.Strings.E6);
            errStr4 = "";
            WatchUi.requestUpdate();
            return;
        }
        makeReqLegacyPlantOverview();
    }

    // Legacy API step 3: Fetch daily overview (current + today)
    function makeReqLegacyPlantOverview() {
        var dateToday = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dateTodayString = Lang.format("$1$-$2$-$3$", [
            dateToday.year.format("%04u"),
            dateToday.month.format("%02u"),
            dateToday.day.format("%02u"),
        ]);
        var path = "/v/ap.2.0/plant/get_plant_powerout_statics_day";
        var query =
            "date=" +
            dateTodayString +
            "&uid=" +
            legacyUserId.toString() +
            "&plant_id=" +
            legacyPlantId.toString();

        Communications.makeWebRequest(
            legacyBaseUrl + path + "?" + query,
            {},
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            },
            method(:onRecLegacyPlantOverview)
        );
    }

    function onRecLegacyPlantOverview(rspCode, data) {
        $.showErr = procRespCode(rspCode, data);
        if ($.showErr) {
            WatchUi.requestUpdate();
            return;
        }

        if (data instanceof Dictionary) {
            try {
                var currentPower = data["current"].toFloat();
                if (currentPower < 1) {
                    curr = currentPower + " W";
                } else {
                    curr = currentPower.format("%.2f") + " W";
                }

                today = frmtEnergy(data["energy"]);

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
            } catch (ex) {
                setNotParsable();
                WatchUi.requestUpdate();
                return;
            }
            makeReqLegacyPlantMonthStats();
        } else {
            setNotParsable();
            WatchUi.requestUpdate();
        }
    }

    // Legacy API step 4: Fetch month totals
    function makeReqLegacyPlantMonthStats() {
        var dateToday = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dateTodayString = Lang.format("$1$-$2$-$3$", [
            dateToday.year.format("%04u"),
            dateToday.month.format("%02u"),
            dateToday.day.format("%02u"),
        ]);
        var path = "/v/ap.2.0/plant/get_plant_powerout_statics_month2";
        var query =
            "date=" +
            dateTodayString +
            "&uid=" +
            legacyUserId.toString() +
            "&plant_id=" +
            legacyPlantId.toString();

        Communications.makeWebRequest(
            legacyBaseUrl + path + "?" + query,
            {},
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            },
            method(:onRecLegacyPlantMonthStats)
        );
    }

    function onRecLegacyPlantMonthStats(rspCode, data) {
        $.showErr = procRespCode(rspCode, data);
        if ($.showErr) {
            WatchUi.requestUpdate();
            return;
        }

        if (data instanceof Dictionary) {
            try {
                var monthPower = 0;
                for (var i = 0; i < data["list"].size(); i++) {
                    monthPower = monthPower + data["list"][i]["energy"];
                }
                thisMonth = frmtEnergy(monthPower);
            } catch (ex) {
                setNotParsable();
                WatchUi.requestUpdate();
                return;
            }
            makeReqLegacyPlantYearStats();
        } else {
            setNotParsable();
            WatchUi.requestUpdate();
        }
    }

    // Legacy API step 5: Fetch year/total and finalize refresh
    function makeReqLegacyPlantYearStats() {
        var dateToday = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dateTodayString = Lang.format("$1$-$2$-$3$", [
            dateToday.year.format("%04u"),
            dateToday.month.format("%02u"),
            dateToday.day.format("%02u"),
        ]);
        var path = "/v/ap.2.0/plant/get_plant_powerout_statics_year";
        var query =
            "date=" +
            dateTodayString +
            "&uid=" +
            legacyUserId.toString() +
            "&plant_id=" +
            legacyPlantId.toString();

        Communications.makeWebRequest(
            legacyBaseUrl + path + "?" + query,
            {},
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            },
            method(:onRecLegacyPlantYearStats)
        );
    }

    function onRecLegacyPlantYearStats(rspCode, data) {
        $.showErr = procRespCode(rspCode, data);
        if ($.showErr) {
            WatchUi.requestUpdate();
            return;
        }

        if (data instanceof Dictionary) {
            try {
                total = frmtEnergy(data["total"]);
                var listSize = data["list"].size();
                if (listSize > 0) {
                    var yearPower = data["list"][listSize - 1]["energy"];
                    thisYear = frmtEnergy(yearPower);
                } else {
                    thisYear = frmtEnergy(0);
                }

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
        System.println("onRecStationList rspCode=" + rspCode + " data=" + data);
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