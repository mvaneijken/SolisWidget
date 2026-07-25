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
var lastFetchTime = null; // Unix timestamp (seconds) of last successful API fetch
var gIsGlance = false;    // true when API is triggered from glance context (no resource access)

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

// Update glanceName/glanceVal based on currPage and save to properties.
// Called from onRecStationDetail so the glance always has fresh values
// even when the main widget view is not open.
function updateGlanceProperties() {
    var app = Application.getApp();
    if (currPage == 1) {
        glanceName = WatchUi.loadResource(Rez.Strings.O1);
        glanceVal = curr;
    } else if (currPage == 2) {
        glanceName = WatchUi.loadResource(Rez.Strings.O2);
        glanceVal = today;
    } else if (currPage == 3) {
        glanceName = WatchUi.loadResource(Rez.Strings.O3);
        glanceVal = thisMonth;
    } else if (currPage == 4) {
        glanceName = WatchUi.loadResource(Rez.Strings.O4);
        glanceVal = thisYear;
    } else if (currPage == 5) {
        glanceName = WatchUi.loadResource(Rez.Strings.O5);
        glanceVal = total;
    } else {
        glanceName = WatchUi.loadResource(Rez.Strings.O1);
        glanceVal = curr;
    }
    app.setProperty("glanceName", glanceName);
    app.setProperty("glanceVal", glanceVal);
}

class SolisWidgetView extends WatchUi.View {

    function initialize() {
        Application.getApp().retrieveSettings();
        View.initialize();
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

    function HandleCommand(data)
    {
        if (data == DOWEBREQUEST)
        {
            Application.getApp().makeReq();
        }
    }

    function onLayout(dc) {
        setLayout(Rez.Layouts.MainLayout(dc));
    }

    function onShow() {
        // Leaving glance context: reset so error messages and the request
        // chain use full-widget behaviour again
        $.gIsGlance = false;
        curr = Application.getApp().getProperty("curr");
        today = Application.getApp().getProperty("today");
        thisMonth = Application.getApp().getProperty("thisMonth");
        thisYear = Application.getApp().getProperty("thisYear");
        total = Application.getApp().getProperty("total");
        lstUpd = Application.getApp().getProperty("lstUpd");
        lastUpdTmLocal = Application.getApp().getProperty("lastUpdTmLocal");
        lastUpdDtLocal = Application.getApp().getProperty("lastUpdDtLocal");
        lastFetchTime = Application.getApp().getProperty("PFT");
        Application.getApp().makeReq();
    }

    function onUpdate(dc) {
        if ($.gSettingsChanged) {
            $.gSettingsChanged = false;
            Application.getApp().retrieveSettings();
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
            updateGlanceProperties();
            if(currPage == 1){
                frmtScrLines(WatchUi.loadResource(Rez.Strings.O1), curr, lastUpdTmLocal, lastUpdDtLocal, "", 4, dc);
            }
            if(currPage == 2){
                frmtScrLines(WatchUi.loadResource(Rez.Strings.O2), today, lastUpdTmLocal, lastUpdDtLocal, "", 4, dc);
            }
            if(currPage == 3){
                frmtScrLines(WatchUi.loadResource(Rez.Strings.O3), thisMonth, lastUpdTmLocal, lastUpdDtLocal, "", 4, dc);
            }
            if(currPage == 4){
                frmtScrLines(WatchUi.loadResource(Rez.Strings.O4), thisYear, lastUpdTmLocal, lastUpdDtLocal, "", 4, dc);
            }
            if(currPage == 5){
                frmtScrLines(WatchUi.loadResource(Rez.Strings.O5), total, lastUpdTmLocal, lastUpdDtLocal, "", 4, dc);
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
                Application.getApp().makeReq();
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
