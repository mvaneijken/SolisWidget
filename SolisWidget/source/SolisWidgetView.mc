using Toybox.WatchUi;
using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Communications;
using Toybox.System;
using Toybox.Cryptography;

// Commands from the delegate
var DOWEBREQUEST = 1;

// Status screens vars
var showRefrsh = false;
var showErr = false;
var errStr1 = "";
var errStr2 = "";
var errStr3 = "";
var errStr4 = "";

// vars to remember
var curr;
var today;
var thisMonth;
var thisYear;
var total;
var lastUpdTmLocal;
var lastUpdDtLocal;
var lstUpd;
var baseUrl = "https://www.soliscloud.com:13333";
var stationId = ""; // station ID cached from userStationList
var glanceName;
var glanceVal;
var fUpdt = false;

// Settings
var currPage;
var apiKey = "";
var apiSecret = "";

function NextPage()
{
    currPage++;
    if (currPage>6) {
        currPage=1;
    }
    WatchUi.requestUpdate();
}

function PreviousPage()
{
    currPage--;
    if (currPage<1) {
        currPage=6;
    }
    WatchUi.requestUpdate();
}

function RefreshPage()
{
    WatchUi.requestUpdate();
    fUpdt = true;
}

class SolisWidgetView extends WatchUi.View {

    function initialize() {
        retrieveSettings();
        View.initialize();
    }

    function retrieveSettings() {
        apiKey = Application.getApp().getProperty("PAK");
        if(apiKey == null){ apiKey = ""; }

        apiSecret = Application.getApp().getProperty("PSK");
        if(apiSecret == null){ apiSecret = ""; }

        currPage = Application.getApp().getProperty("PSP");
        if(currPage == null){ currPage = 1; }

        stationId = Application.getApp().getProperty("PSI");
        if(stationId == null || !(stationId instanceof String)){ stationId = ""; }

        // Reset cached IDs if API credentials have changed
        var storedKey = Application.getApp().getProperty("currApiKey");
        var storedSecret = Application.getApp().getProperty("currApiSecret");
        if(storedKey != null && !storedKey.equals("") && !apiKey.equals(storedKey)){ stationId = ""; }
        if(storedSecret != null && !storedSecret.equals("") && !apiSecret.equals(storedSecret)){ stationId = ""; }

        glanceName = Application.getApp().getProperty("AppName");
        glanceVal = "";
    }

    // Build an RFC 2822 UTC date string, e.g. "Mon, 01 Jan 2024 12:00:00 GMT"
    // Gregorian.utcInfo() returns UTC calendar fields directly (available since SDK 2.4.0).
    function buildRfc2822Date() {
        var dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        var monNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

        var t = Gregorian.utcInfo(Time.now(), Time.FORMAT_SHORT);

        // Garmin day_of_week: 1=Sunday ... 7=Saturday
        return Lang.format("$1$, $2$ $3$ $4$ $5$:$6$:$7$ GMT", [
            dayNames[t.day_of_week - 1],
            t.day.format("%02d"),
            monNames[t.month - 1],
            t.year.format("%04d"),
            t.hour.format("%02d"),
            t.min.format("%02d"),
            t.sec.format("%02d")
        ]);
    }

    // Base64-encode a ByteArray (or Array<Number>) to a String.
    // Handles the small digests produced by MD5 (16 bytes) and SHA1 (20 bytes).
    function base64Encode(data) {
        var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        var result = "";
        var n = data.size();
        var i = 0;
        while (i < n) {
            var b0 =            data[i]     & 0xFF;
            var b1 = (i+1 < n) ? data[i+1] & 0xFF : 0;
            var b2 = (i+2 < n) ? data[i+2] & 0xFF : 0;
            var idx0 = (b0 >> 2) & 0x3F;
            var idx1 = ((b0 << 4) | (b1 >> 4)) & 0x3F;
            var idx2 = ((b1 << 2) | (b2 >> 6)) & 0x3F;
            var idx3 = b2 & 0x3F;
            result = result + chars.substring(idx0, idx0+1);
            result = result + chars.substring(idx1, idx1+1);
            result = result + ((i+1 < n) ? chars.substring(idx2, idx2+1) : "=");
            result = result + ((i+2 < n) ? chars.substring(idx3, idx3+1) : "=");
            i += 3;
        }
        return result;
    }

    // Convert a String to ByteArray (Hash.update requires ByteArray, not Array<Number>).
    function strToBytes(s) {
        var arr = s.toUtf8Array();
        var ba = new [arr.size()]b;
        for (var i = 0; i < arr.size(); i++) {
            ba[i] = arr[i] & 0xFF;
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
            var h = new Cryptography.Hash({:algorithm => Cryptography.HASH_SHA1});
            h.update(keyBytes);
            keyBytes = h.digest();
        }

        // Pad key to blockSize with zeros, build ipad and opad as ByteArrays
        var ipad = new [blockSize]b;
        var opad = new [blockSize]b;
        for (var i = 0; i < blockSize; i++) {
            var kb = (i < keyBytes.size()) ? (keyBytes[i] & 0xFF) : 0;
            ipad[i] = (kb ^ 0x36) & 0xFF;
            opad[i] = (kb ^ 0x5C) & 0xFF;
        }

        // inner = SHA1(ipad || message)
        var inner = new Cryptography.Hash({:algorithm => Cryptography.HASH_SHA1});
        inner.update(ipad);
        inner.update(msgBytes);
        var innerDigest = inner.digest();

        // result = SHA1(opad || inner)
        var outer = new Cryptography.Hash({:algorithm => Cryptography.HASH_SHA1});
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
        var md5 = new Cryptography.Hash({:algorithm => Cryptography.HASH_MD5});
        md5.update(strToBytes(bodyStr));
        var md5b64 = base64Encode(md5.digest());

        // Build string to sign — must use literal "application/json", not the numeric constant
        var stringToSign = "POST\n" + md5b64 + "\napplication/json\n" + dateStr + "\n" + path;

        // Compute HMAC-SHA1 signature using manual implementation
        var signature = base64Encode(
            hmacSha1(strToBytes(apiSecret), strToBytes(stringToSign))
        );

        var Authorization = "API " + apiKey + ":" + signature;
        var headers = {
            "Content-Type" => contentType,
            "Content-MD5" => md5b64,
            "Date" => dateStr,
            "Authorization" => Authorization
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
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            callback
        );
    }

    function frmtEnergy(pwr)
    {
        try{
            pwr = pwr.toFloat();
        }
        catch(ex){
            pwr = null;
        }

        if(pwr != null){
            if (pwr<1)
            {
                return (pwr * 1000).toNumber() + " Wh";
            }
            else
            {
                return pwr.format("%.1f") + " kWh";
            }
        }
        else{
            return "No data received";
        }
    }

    function procRespCode(rspCode, data){
        showRefrsh = false;
        showErr = false;

        if (rspCode == 200)
        {
            showErr = false;
            // Accept success when either success==true OR code=="0" (API varies)
            var isOk = data != null && data["code"] != null && data["code"].equals("0");
            System.println("HTTP 200  code=" + (data != null ? data["code"] : "null")
                + "  success=" + (data != null ? data["success"] : "null")
                + "  msg=" + (data != null ? data["msg"] : "null"));
            if(!isOk)
            {
                showErr = true;
                var msg = "";
                if(data != null && data["msg"] != null){ msg = data["msg"].toString(); }
                errStr1 = "API Err: " + msg;
                errStr2 = WatchUi.loadResource(Rez.Strings.A2);
                errStr3 = WatchUi.loadResource(Rez.Strings.A3);
                errStr4 = WatchUi.loadResource(Rez.Strings.E6);
                data = null;
            }
        }
        else if (rspCode == -104) //Communications.BLE_CONNECTION_UNAVAILABLE
        {
            showErr = true;
            errStr1 = WatchUi.loadResource(Rez.Strings.B1);
            errStr2 = WatchUi.loadResource(Rez.Strings.B2);
            errStr3 = WatchUi.loadResource(Rez.Strings.B3);
            errStr4 = "";
            data = null;
        }
        else if (rspCode == -400) //Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE
        {
            showErr = true;
            errStr1 = WatchUi.loadResource(Rez.Strings.I1);
            errStr2 = WatchUi.loadResource(Rez.Strings.I2);
            errStr3 = WatchUi.loadResource(Rez.Strings.I3);
            errStr4 = "";
            data = null;
        }
        else if (rspCode == -300) //Communications.NETWORK_REQUEST_TIMED_OUT
        {
            showErr = true;
            errStr1 = WatchUi.loadResource(Rez.Strings.N1);
            errStr2 = WatchUi.loadResource(Rez.Strings.N2);
            errStr3 = WatchUi.loadResource(Rez.Strings.N3);
            errStr4 = "";
            data = null;
        }
        else
        {
            showErr = true;
            errStr1 = "Error " + rspCode;
            errStr2 = WatchUi.loadResource(Rez.Strings.E1);
            errStr3 = WatchUi.loadResource(Rez.Strings.E2);
            errStr4 = WatchUi.loadResource(Rez.Strings.E3);
        }
        WatchUi.requestUpdate();
        return showErr;
    }

    function frmtScrLines(ln1val,ln2val,ln3val,ln4val,ln5val,lines,dc){
        var lnSpaceL = 2;
        var lnSpaceM = 2.6;
        var scrnDev = lines - 1;
        var ln1Font = 13;
        var ln2Font = 0;
        var ln3Font = 0;
        var ln4Font = 0;
        var ln5Font = 0;
        if(lines == 1 || lines == 2){
            scrnDev = 2;
        }
        if(lines >= 2){
            ln1Font = 13;
            ln2Font = 13;
        }
        if(lines >= 3){
            ln1Font = 13;
            ln2Font = 13;
            ln3Font = 2;
        }
        if(lines >= 4){
            ln1Font = 13;
            ln2Font = 13;
            ln3Font = 2;
            ln4Font  = 2;
        }
        if(lines >= 5){
            ln1Font = 3;
            ln2Font = 3;
            ln3Font = 3;
            ln4Font  = 3;
            ln5Font = 3;
            lnSpaceL = 2.6;
        }
        var ln1PosY = dc.getHeight() / scrnDev;
        var ln2PosY = ln1PosY + ((Graphics.getFontHeight(ln1Font) / lnSpaceM) + (Graphics.getFontHeight(ln1Font) / lnSpaceM));
        var ln3PosY = ln2PosY + ((Graphics.getFontHeight(ln2Font) / lnSpaceL) + (Graphics.getFontHeight(ln2Font) / lnSpaceL));
        var ln4PosY = ln3PosY + ((Graphics.getFontHeight(ln3Font) / lnSpaceM) + (Graphics.getFontHeight(ln3Font) / lnSpaceM));
        var ln5PosY = ln4PosY + ((Graphics.getFontHeight(ln4Font) / lnSpaceM) + (Graphics.getFontHeight(ln4Font) / lnSpaceM));

        dc.drawText(dc.getWidth() / 2, ln1PosY, ln1Font, ln1val, 1);
        if(lines >= 2){ dc.drawText(dc.getWidth() / 2, ln2PosY, ln2Font, ln2val, 1); }
        if(lines >= 3){ dc.drawText(dc.getWidth() / 2, ln3PosY, ln3Font, ln3val, 1); }
        if(lines >= 4){ dc.drawText(dc.getWidth() / 2, ln4PosY, ln4Font, ln4val, 1); }
        if(lines >= 5){ dc.drawText(dc.getWidth() / 2, ln5PosY, ln5Font, ln5val, 1); }
    }

    function setNotParsable()
    {
        curr = null;
        today = null;
        thisMonth = null;
        thisYear = null;
        total = null;
        lstUpd = null;
        lastUpdTmLocal = null;
        lastUpdDtLocal = null;
    }

    function HandleCommand(data)
    {
        if (data == DOWEBREQUEST)
        {
            makeReq();
        }
    }

    // Entry point: route to the correct first uncached step
    function makeReq() {
        fUpdt = false;

        if(apiKey == null || apiKey.length() == 0 || apiSecret == null || apiSecret.length() == 0){
            showErr = true;
            showRefrsh = false;
            errStr1 = WatchUi.loadResource(Rez.Strings.I1);
            errStr2 = WatchUi.loadResource(Rez.Strings.A2);
            errStr3 = WatchUi.loadResource(Rez.Strings.A3);
            errStr4 = "";
            WatchUi.requestUpdate();
            return;
        }

        showErr = false;
        showRefrsh = true;
        WatchUi.requestUpdate();

        if(stationId == null || stationId.equals("")){
            makeReqStationList();
        } else if(stationId != null){
            makeReqStationDetail();
        }

    }

    // Step 1: Fetch station list to obtain stationId
    function makeReqStationList() {
        makeSignedPostRequest("/v1/api/userStationList", "{\"pageNo\":1,\"pageSize\":20}", {"pageNo" => 1, "pageSize" => 20}, method(:onRecStationList));
    }

    function onRecStationList(rspCode, data) {
        System.println("onRecStationList rspCode=" + rspCode + " data=" + data);
        showErr = procRespCode(rspCode, data);
        if(showErr){ WatchUi.requestUpdate(); return; }

        try {
            stationId = data["data"]["page"]["records"][0]["id"].toString();
            Application.getApp().setProperty("PSI", stationId);
        } catch(ex) {
            showErr = true;
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
        makeSignedPostRequest("/v1/api/stationDetail", "{\"id\":\"" + stationId + "\"}", {"id" => stationId}, method(:onRecStationDetail));
    }

    function onRecStationDetail(rspCode, data) {
        showErr = procRespCode(rspCode, data);
        if(showErr){ WatchUi.requestUpdate(); return; }

        if(data instanceof Dictionary)
        {
            try {
                var d = data["data"];

                // Current power: power is in kW, display in W (< 1 kW) or kW
                var power = d["power"].toFloat();
                curr = power.format("%.2f") + " " + d["powerStr"];

                // Today's energy
                today = d["dayEnergy"].toFloat().format("%.1f") + " " + d["dayEnergyStr"];

                // Monthly energy
                thisMonth = d["monthEnergy"].toFloat().format("%.1f") + " " + d["monthEnergyStr"];

                // Yearly energy
                thisYear = d["yearEnergy"].toFloat().format("%.1f") + " " + d["yearEnergyStr"];

                // Total energy
                total = d["allEnergy"].toFloat().format("%.1f") + " " + d["allEnergyStr"];

                // Last updated timestamp (local device time)
                var i = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
                lastUpdTmLocal = Lang.format("$1$:$2$:$3$", [
                    i.hour.format("%02u"),
                    i.min.format("%02u"),
                    i.sec.format("%02u")
                ]);
                lastUpdDtLocal = Lang.format("$1$-$2$-$3$", [
                    i.year.format("%04u"),
                    i.month.format("%02u"),
                    i.day.format("%02u")
                ]);
            } catch(ex) {
                setNotParsable();
            }
        }
        else
        {
            setNotParsable();
        }
        WatchUi.requestUpdate();
    }

    function onLayout(dc) {
        setLayout(Rez.Layouts.MainLayout(dc));
    }

    function onShow() {
        curr = Application.getApp().getProperty("curr");
        today = Application.getApp().getProperty("today");
        thisMonth = Application.getApp().getProperty("thisMonth");
        thisYear = Application.getApp().getProperty("thisYear");
        total = Application.getApp().getProperty("total");
        lstUpd = Application.getApp().getProperty("lstUpd");
        lastUpdTmLocal = Application.getApp().getProperty("lastUpdTmLocal");
        lastUpdDtLocal = Application.getApp().getProperty("lastUpdDtLocal");
        makeReq();
    }

    function onUpdate(dc) {
        if ($.gSettingsChanged) {
            $.gSettingsChanged = false;
            retrieveSettings();
        }

        dc.setColor(0x000000, 0x000000);
        dc.clear();
        dc.setColor(0xFFFFFF, -1);

        if (showErr) {
            frmtScrLines(errStr1, errStr2, errStr3, errStr4, "", 5, dc);
        }
        else if (showRefrsh) {
            frmtScrLines(WatchUi.loadResource(Rez.Strings.UP), "", "", "", "", 1, dc);
        }
        else {
            if(currPage == 1){
                frmtScrLines(WatchUi.loadResource(Rez.Strings.O1), curr, lastUpdTmLocal, lastUpdDtLocal, "", 4, dc);
                glanceName = WatchUi.loadResource(Rez.Strings.O1);
                glanceVal = curr;
            }
            if(currPage == 2){
                frmtScrLines(WatchUi.loadResource(Rez.Strings.O2), today, lastUpdTmLocal, lastUpdDtLocal, "", 4, dc);
                glanceName = WatchUi.loadResource(Rez.Strings.O2);
                glanceVal = today;
            }
            if(currPage == 3){
                frmtScrLines(WatchUi.loadResource(Rez.Strings.O3), thisMonth, lastUpdTmLocal, lastUpdDtLocal, "", 4, dc);
                glanceName = WatchUi.loadResource(Rez.Strings.O3);
                glanceVal = thisMonth;
            }
            if(currPage == 4){
                frmtScrLines(WatchUi.loadResource(Rez.Strings.O4), thisYear, lastUpdTmLocal, lastUpdDtLocal, "", 4, dc);
                glanceName = WatchUi.loadResource(Rez.Strings.O4);
                glanceVal = thisYear;
            }
            if(currPage == 5){
                frmtScrLines(WatchUi.loadResource(Rez.Strings.O5), total, lastUpdTmLocal, lastUpdDtLocal, "", 4, dc);
                glanceName = WatchUi.loadResource(Rez.Strings.O5);
                glanceVal = total;
            }
            if(currPage == 6){
                frmtScrLines(
                    WatchUi.loadResource(Rez.Strings.O1)+": "+curr,
                    WatchUi.loadResource(Rez.Strings.O2)+": "+today,
                    WatchUi.loadResource(Rez.Strings.O3)+": "+thisMonth,
                    WatchUi.loadResource(Rez.Strings.O4)+": "+thisYear,
                    WatchUi.loadResource(Rez.Strings.O5)+": "+total,
                    5,
                    dc
                );
            }

            if(fUpdt == true){
                makeReq();
            }
        }
    }

    function onHide() {
        Application.getApp().setProperty("curr", curr);
        Application.getApp().setProperty("today", today);
        Application.getApp().setProperty("thisMonth", thisMonth);
        Application.getApp().setProperty("thisYear", thisYear);
        Application.getApp().setProperty("total", total);
        Application.getApp().setProperty("lstUpd", lstUpd);
        Application.getApp().setProperty("lastUpdTmLocal", lastUpdTmLocal);
        Application.getApp().setProperty("lastUpdDtLocal", lastUpdDtLocal);
        Application.getApp().setProperty("PSI", stationId);
        if(glanceVal != null && glanceName != null){
            Application.getApp().setProperty("glanceName", glanceName);
            Application.getApp().setProperty("glanceVal", glanceVal);
        }
        Application.getApp().setProperty("currApiKey", apiKey);
        Application.getApp().setProperty("currApiSecret", apiSecret);
    }
}
