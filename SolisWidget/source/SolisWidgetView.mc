import Toybox.WatchUi;
import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Communications;
import Toybox.System;


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
var uid; //c_user_id variable received when authenticating to the API
var plantid; //plant_id variable received when retrieving the plants.
var glanceName;
var glanceVal;
var fUpdt = false;

// Settings
var currPage;
var usr = "";
var pwrd = "";

function NextPage()
{
    //Sys.println("SolisWidgetView:NextPage");
    // Next Page pressed, increase the pagenumber
    currPage++;

    // Rotate is last page = met
    if (currPage>6) {
        currPage=1;
    }

    // refresh the screen
    WatchUi.requestUpdate();
}

function PreviousPage()
{
    //Sys.println("SolisWidgetView:PreviousPage");

    // Previous Page pressed, decrease the pagenumber
    currPage--;

    // Rotate is last page = met
    if (currPage<1) {
        currPage=6;
    }

    // refresh the screen
    WatchUi.requestUpdate();
}

function RefreshPage()
{
    //Sys.println("SolisWidgetView:RefreshPage");
    WatchUi.requestUpdate();
    fUpdt = true;
}

class SolisWidgetView extends WatchUi.View {

    //var icon as BitmapResource;
    //var logo as BitmapResource;

    function initialize() {
        //System.println("SolisWidgetView:initialize");
        //System.println("getDevPartNr: " + System.getDeviceSettings().partNumber;
        retrieveSettings();
        View.initialize();
        //logo = WatchUi.loadResource(Rez.Drawables.logo);
        //icon = WatchUi.loadResource(Rez.Drawables.icon);
    }

function retrieveSettings() {
        //System.println("SolisWidgetView:retrieveSettings");
        // Get Username From settings
        usr = Application.getApp().getProperty("PUN");
        //System.println("Username: " + Username);

        // Get Password from Settings
        pwrd = Application.getApp().getProperty("PPS");

        // Get curr Page From settings
        currPage= Application.getApp().getProperty("PSP");
        if(currPage == null){currPage=1;}

        // Get the UID
        uid=Application.getApp().getProperty("PUI");
        if(uid == null){uid = -1;}
        if(uid instanceof String){uid = -1;}

        // Get the plantid
        plantid=Application.getApp().getProperty("PPI");
        if(plantid == null){plantid = -1;}
        if(plantid instanceof String){plantid = -1;}

        //Allow to update credentials (gSettingsChanged will be set to true which calls this function twice)
        if(Application.getApp().getProperty("currUsr") != "" && usr != Application.getApp().getProperty("currUsr")){uid = -1;plantid = -1;}
        if(Application.getApp().getProperty("currPwrd") != "" && pwrd != Application.getApp().getProperty("currPwrd")){uid = -1;plantid = -1;}

        // Set initial glanceVal
        glanceName = Application.getApp().getProperty("AppName");
        glanceVal = "";
    }

   function toMoment(string)
   {
        //System.println(string);
        return Gregorian.moment({
            :year   => string.toString().substring(0,4).toNumber(),
            :month  => string.toString().substring(5,7).toNumber(),
            :day    => string.toString().substring(8,10).toNumber(),
            :hour   => string.toString().substring(11,13).toNumber(),
            :minute => string.toString().substring(14,16).toNumber(),
            :second => string.toString().substring(17,19).toNumber()
        });
   }

    function frmtEnergy(pwr)
    {
        //System.println("SolisWidgetView:frmtEnergy");
        try{
            pwr = pwr.toFloat();
        }
        catch(ex){
            pwr = null;
        }

        if(pwr != null){
            if (pwr<1)
            {
            // Less than 1 kWh Present in Wh
                return (pwr * 1000).toNumber() + " Wh";
            }
            else
            {
                // > more than kWh, so present in in kWh
                return pwr.format("%.1f") + " kWh";
            }
        }
        else{
            return "No data received";
        }
    }

    function procRespCode(rspCode  as Number, data as Dictionary or String or Null) as Boolean{
        //System.println("SolisWidgetView:procRespCode");

        // Turn off refreshpage
        showRefrsh=false;
        showErr=false;
        //System.println(rspCode);
        //System.println(data);

        if (rspCode==200)
        {
            // Make sure no error is shown
            showErr=false;
            if(data["result"] == null || data["result"].toNumber() != 1)
            {
                // Reset values to reinitiate login
                showErr=true;
                uid = -1;
                plantid = -1;
                Application.getApp().setProperty("PUI",0);
                Application.getApp().setProperty("PPI",0);
                errStr1="API Error: "+ data["result"];
                if(data["result"].toNumber() == 5 || data["result"].toNumber() == 11){
                    errStr2=WatchUi.loadResource(Rez.Strings.A1);
                    errStr3=WatchUi.loadResource(Rez.Strings.A2);
                    errStr4=WatchUi.loadResource(Rez.Strings.A3);
                }
                else{
                    errStr2=WatchUi.loadResource(Rez.Strings.I1);
                    errStr3=WatchUi.loadResource(Rez.Strings.I2);
                    errStr4=WatchUi.loadResource(Rez.Strings.I3);
                }
                data=null;
            }
        }
        else if (rspCode==-104) //Communications.BLE_CONNECTION_UNAVAILABLE
        {
            // bluetooth connection issue
            showErr = true;
            errStr1=WatchUi.loadResource(Rez.Strings.B1);
            errStr2=WatchUi.loadResource(Rez.Strings.B2);
            errStr3=WatchUi.loadResource(Rez.Strings.B3);
            data=null;
        }
        else if (rspCode==-400) //Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE
        {
            // Invalid API key
            showErr = true;
            errStr1=WatchUi.loadResource(Rez.Strings.I1);
            errStr2=WatchUi.loadResource(Rez.Strings.I2);
            errStr3=WatchUi.loadResource(Rez.Strings.I3);
            data=null;
        }
        else if (rspCode==-300) //Communications.NETWORK_REQUEST_TIMED_OUT
        {
            // No Internet
            showErr = true;
            errStr1=WatchUi.loadResource(Rez.Strings.N1);
            errStr2=WatchUi.loadResource(Rez.Strings.N2);
            errStr3=WatchUi.loadResource(Rez.Strings.N3);
            data=null;
        }
        else
        {
            // general Error
            showErr = true;
            errStr1="Error "+rspCode;
            errStr2=WatchUi.loadResource(Rez.Strings.E1);
            errStr3=WatchUi.loadResource(Rez.Strings.E2);
            errStr4=WatchUi.loadResource(Rez.Strings.E3);
        }
        WatchUi.requestUpdate();
        return showErr;
    }

    function frmtScrLines(ln1val,ln2val,ln3val,ln4val,ln5val,lines,dc){
        //System.println("SolisWidgetView:frmtScrLines");

        var lnSpaceL = 2;
        var lnSpaceM = 2.6;
        var scrnDev = lines - 1;
        var ln1Font = Graphics.FONT_SYSTEM_LARGE;
        var ln2Font = 0;
        var ln3Font = 0;
        var ln4Font = 0;
        var ln5Font = 0;
        if(lines == 1 || lines == 2){
            scrnDev = 2;
        }
        if(lines >= 2){
            ln1Font = Graphics.FONT_SYSTEM_LARGE;
            ln2Font = Graphics.FONT_SYSTEM_LARGE;
        }
        if(lines >= 3){
            ln1Font = Graphics.FONT_SYSTEM_LARGE;
            ln2Font = Graphics.FONT_SYSTEM_LARGE;
            ln3Font = Graphics.FONT_SMALL;
        }
        if(lines >= 4){
            ln1Font = Graphics.FONT_SYSTEM_LARGE;
            ln2Font = Graphics.FONT_SYSTEM_LARGE;
            ln3Font = Graphics.FONT_SMALL;
            ln4Font  = Graphics.FONT_SMALL;
        }
        if(lines >= 5){
            ln1Font = Graphics.FONT_MEDIUM;
            ln2Font = Graphics.FONT_MEDIUM;
            ln3Font = Graphics.FONT_MEDIUM;
            ln4Font  = Graphics.FONT_MEDIUM;
            ln5Font = Graphics.FONT_MEDIUM;
            lnSpaceL = 2.6;
        }
        var ln1PosY = dc.getHeight() / scrnDev;
        var ln2PosY = ln1PosY + ((Graphics.getFontHeight(ln1Font) / lnSpaceM) + (Graphics.getFontHeight(ln1Font) / lnSpaceM));
        var ln3PosY = ln2PosY + ((Graphics.getFontHeight(ln2Font) / lnSpaceL) + (Graphics.getFontHeight(ln2Font) / lnSpaceL));
        var ln4PosY = ln3PosY + ((Graphics.getFontHeight(ln3Font) / lnSpaceM) + (Graphics.getFontHeight(ln3Font) / lnSpaceM));
        var ln5PosY = ln4PosY + ((Graphics.getFontHeight(ln4Font) / lnSpaceM) + (Graphics.getFontHeight(ln4Font) / lnSpaceM));

        dc.drawText(
            dc.getWidth() / 2,
            ln1PosY,
            ln1Font,
            ln1val,
            1 //Graphics.TEXT_JUSTIFY_CENTER
        );
        if(lines >= 2){
            dc.drawText(
                dc.getWidth() / 2,
                ln2PosY,
                ln2Font,
                ln2val,
                1 //Graphics.TEXT_JUSTIFY_CENTER
            );
        }
        if(lines >= 3){
            dc.drawText(
                dc.getWidth() / 2,
                ln3PosY,
                ln3Font,
                ln3val,
                1 //Graphics.TEXT_JUSTIFY_CENTER
            );
        }
        if(lines >= 4){
            dc.drawText(
                dc.getWidth() / 2,
                ln4PosY,
                ln4Font,
                ln4val,
                1 //Graphics.TEXT_JUSTIFY_CENTER
            );
        }
        if(lines >= 5){
            dc.drawText(
                dc.getWidth() / 2,
                ln5PosY,
                ln5Font,
                ln5val,
                1 //Graphics.TEXT_JUSTIFY_CENTER
            );
        }
    }

    function setNotParsable()
    {
        //Sys.println("SolisWidgetView:setNotParsable");

        // not parsable
        curr = null;
        today = null;
        thisMonth = null;
        thisYear = null;
        total = null;
        lstUpd = null;
        lastUpdTmLocal = null;
        lastUpdDtLocal = null;
    }

    // Handle Command from Delegate view
    function HandleCommand (data)
    {
        //Sys.println("SolisWidgetView:HandleCommand");

        // update of data requested
        if (data==DOWEBREQUEST)
        {
            //System.println("HandleCommand: makeReq");
            makeReq();
        }
    }

    function makeReq() as Void  {
        //System.println("SolisWidgetView:makeReq");

        fUpdt = false;
        WatchUi.requestUpdate();
        var path = "/v1/api/userStationList";
        var url =  baseUrl+path;

        // Created using Powershell:
        //$Json = '{
        //    "pageNo": 1,
        //    "pageSize": 10
        //}'
        //$Bytes = [System.Text.Encoding]::UTF8.GetBytes($Json)
        //[convert]::ToBase64String($Bytes)
        var base64Body = "ewogICAgInBhZ2VObyI6IDEsCiAgICAicGFnZVNpemUiOiAxMAp9";
        var body = Conversion.Base64StringToString(base64Body);

        // hash body to MD5
        var body_byte_array = Conversion.StringToByteArray(body);
        var md5hash = Hash.NewMd5HashObject();
        var md5hash_bytes = Hash.ComputeHash(md5hash,body_byte_array);
        var contentMd5 = Conversion.ByteArrayToBase64String(md5hash_bytes);

        var date = DateTime.GetDateUTCString();
        var contentType = "application/json";

        // authorization
        var key = usr;
        var secret = Conversion.StringToByteArray(pwrd);
        var message = "POST\n" + contentMd5 + "\napplication/json\n" + date + "\n" + path;
        //var auth_byte_array = Conversion.StringToByteArray(message);
        var sha1hash_string = Hash.generateSaltedSHA1(message,secret);
        //var sha1hash = Hash.NewSha1HashBasedMessageAuthenticationCodeObject(secret);
        //var sha1hash_bytes = Hash.ComputeHash(sha1hash,auth_byte_array);
        //var hmacSha1Base64 = Conversion.ByteArrayToBase64String(sha1hash_bytes);
        var hmacSha1Base64 = Conversion.StringToBase64String(sha1hash_string);
        var authorization = "API " + key + ":" + hmacSha1Base64;

        var headers = {
            "Content-Type" => "application/json",
            "Authorization" => authorization,
            "Content-MD5" => contentMd5,
            "Date" => date
        };

        // Make the authentication request
        //System.println("makeReq url:"+url);
        Communications.makeWebRequest(url,body,{
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
                :headers => headers
        },method(:onRec));
    }

    // Receive the data from the web request
    function onRec(rspCode  as Number, data as Dictionary or String or Null) as Void
    {
        //System.println("SolisWidgetView:onRecPlantId");
        showErr = procRespCode(rspCode,data);
        if(showErr){
            WatchUi.requestUpdate();
        }
        else{
            showErr=false;
            try{
                plantid = data["data"]["page"]["records"][0]["id"];
                Application.getApp().setProperty("PPI",plantid);

                curr= data["data"]["page"]["records"][0]["power"] + " " + data["data"]["page"]["records"][0]["powerStr"];
                today= data["data"]["page"]["records"][0]["dayPowerGeneration"] + " " + data["data"]["page"]["records"][0]["dayEnergyStr"];
                thisMonth= data["data"]["page"]["records"][0]["monthEnergy"] + " " + data["data"]["page"]["records"][0]["monthEnergyStr"];
                thisYear = data["data"]["page"]["records"][0]["yearEnergy"] + " " + data["data"]["page"]["records"][0]["yearEnergyStr"];
                data=null;

                // Format Last Update
                var i = Time.Gregorian.Info(Time.now(), 0); //Time.FORMAT_SHORT
                lastUpdTmLocal = (Lang.format("$1$:$2$:$3$", [
                    i.hour.format("%02u"),
                    i.min.format("%02u"),
                    i.sec.format("%02u")
                ]));
                lastUpdDtLocal = (Lang.format("$1$-$2$-$3$", [
                    i.year.format("%04u"),
                    i.month.format("%02u"),
                    i.day.format("%02u")
                ]));
                data=null;
            }
            catch (ex) {
                showErr=true;
                plantid = null;
                errStr1=WatchUi.loadResource(Rez.Strings.E4);
                errStr2=WatchUi.loadResource(Rez.Strings.E5);
                errStr3=WatchUi.loadResource(Rez.Strings.E6);
                errStr4="";
                WatchUi.requestUpdate();
            }
        }
    }

    // Load your resources here
    function onLayout(dc) {
        //Sys.println("SolisWidgetView:onLayout");
        setLayout(Rez.Layouts.MainLayout(dc));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
        //Sys.println("SolisWidgetView:onShow");

        //  Load saved data
        curr = Application.getApp().getProperty("curr");
        today = Application.getApp().getProperty("today");
        thisMonth = Application.getApp().getProperty("thisMonth");
        thisYear = Application.getApp().getProperty("thisYear");
        total = Application.getApp().getProperty("total");
        lstUpd= Application.getApp().getProperty("lstUpd");
        lastUpdTmLocal = Application.getApp().getProperty("lastUpdTmLocal");
        lastUpdDtLocal = Application.getApp().getProperty("lastUpdDtLocal");
        makeReq();
    }

    // Update the view
    function onUpdate(dc) {
        //Sys.println("SolisWidgetView:onUpdate");

        //Sys.println("Screen heigth: " + dc.getHeight());
        //Sys.println("Screen width: " + dc.getWidth());

        if ($.gSettingsChanged) {
            $.gSettingsChanged = false;
            retrieveSettings();
        }

        // Call the parent onUpdate function to redraw the layout
        // View.onUpdate(dc);
        dc.setColor(0x000000,0x000000); //(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(0xFFFFFF,-1); //(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        // Draw logo
        //var logowidth = logo.getWidth();
        //var logoPosX = (dc.getWidth() - logowidth) / 2;
        //var logoPosY = (dc.getHeight() - logowidth) / 5;
        ////Sys.println("logowidth: " + logowidth + " logoHeight: " + logo.getHeight());
        //dc.drawBitmap((dc.getWidth() - logowidth) / 2, logoPosY,logo);

        if (showErr) {
           // Show Error
            frmtScrLines(
                errStr1,
                errStr2,
                errStr3,
                errStr4,
                "",
                5,
                dc
            );
        }
        else  if (showRefrsh) {
            frmtScrLines(
                WatchUi.loadResource(Rez.Strings.UP),
                "",
                "",
                "",
                "",
                1,
                dc
            );
        }
        else {
            // Show status page
                if(currPage==1){
                    // curr pwr
                    frmtScrLines(
                        WatchUi.loadResource(Rez.Strings.O1),
                        curr,
                        lastUpdTmLocal,
                        lastUpdDtLocal,
                        "",
                        4,
                        dc
                    );
                    glanceName = WatchUi.loadResource(Rez.Strings.O1);
                    glanceVal = curr;
                }
                if(currPage==2){
                    // today
                    frmtScrLines(
                        WatchUi.loadResource(Rez.Strings.O2),
                        today,
                        lastUpdTmLocal,
                        lastUpdDtLocal,
                        "",
                        4,
                        dc
                    );
                    glanceName = WatchUi.loadResource(Rez.Strings.O2);
                    glanceVal = today;
                }
                if(currPage==3){
                    // This Month
                    frmtScrLines(
                        WatchUi.loadResource(Rez.Strings.O3),
                        thisMonth,
                        lastUpdTmLocal,
                        lastUpdDtLocal,
                        "",
                        4,
                        dc
                    );
                    glanceName = WatchUi.loadResource(Rez.Strings.O3);
                    glanceVal = thisMonth;
                }
                if(currPage==4){
                    // This Year
                    frmtScrLines(
                        WatchUi.loadResource(Rez.Strings.O4),
                        thisYear,
                        lastUpdTmLocal,
                        lastUpdDtLocal,
                        "",
                        4,
                        dc
                    );
                    glanceName = WatchUi.loadResource(Rez.Strings.O4);
                    glanceVal = thisYear;
                }
                if(currPage==5){
                    // total
                    frmtScrLines(
                        WatchUi.loadResource(Rez.Strings.O5),
                        total,
                        lastUpdTmLocal,
                        lastUpdDtLocal,
                        "",
                        4,
                        dc
                    );
                    glanceName = WatchUi.loadResource(Rez.Strings.O5);
                    glanceVal = total;
                }
                if(currPage==6){
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

            //System.println("glanceVal: " + glanceVal + ", glanceName: " + glanceName );

            if(fUpdt == true){
                //System.println("fUpdt = " + fUpdt);
                makeReq();
            }
        }
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from memory.
    function onHide() {
        //Sys.println("SolisWidgetView:onHide");

        // Save data for later
        Application.getApp().setProperty("curr",curr);
        Application.getApp().setProperty("today", today);
        Application.getApp().setProperty("thisMonth", thisMonth);
        Application.getApp().setProperty("thisYear", thisYear);
        Application.getApp().setProperty("total",total);
        Application.getApp().setProperty("lstUpd", lstUpd);
        Application.getApp().setProperty("lastUpdTmLocal", lastUpdTmLocal);
        Application.getApp().setProperty("lastUpdDtLocal", lastUpdDtLocal);
        if(glanceVal != null and glanceName != null){
            Application.getApp().setProperty("glanceName", glanceName);
            Application.getApp().setProperty("glanceVal", glanceVal);
        }
        Application.getApp().setProperty("currUsr", usr);
        Application.getApp().setProperty("currPwrd", pwrd);
    }
}