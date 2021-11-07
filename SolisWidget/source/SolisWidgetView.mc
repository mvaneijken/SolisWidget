using Toybox.WatchUi;
using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Communications;
using Toybox.System;

// Commands from the delegate
var DOWEBREQUEST as Number = 1;

// Status screens vars
var ShowRefrsh as Boolean = false;
var ShowErr as Boolean = false;
var ErrStr1 as String = "";
var ErrStr2 as String = "";
var ErrStr3 as String = "";
var ErrStr4 as String = "";

// vars to remember
var Curr as Float;
var Today as Float;
var ThisMonth as Float;
var ThisYear as Float;
var Total as Float;
var lastUpdTmLocal as String;
var lastUpdDtLocal as String;
var lstUpd as String;
var BaseUrl as String = "https://apic-cdn.solarman.cn";
var uid as String; //c_user_id variable received when authenticating to the API
var plantid as String; //plant_id variable received when retrieving the plants.
var glanceName as String;
var glanceVal as String;
var fUpdt as Boolean = false;

// Settings
var CurrPage as Number;
var Usr as String = "";
var Pwrd as String = "";

function NextPage()
{
    //Sys.println("SolisWidgetView:NextPage");
    // Next Page pressed, increase the pagenumber
    CurrPage++;

    // Rotate is last page = met
    if (CurrPage>6) {
        CurrPage=1;
    }

    // refresh the screen
    WatchUi.requestUpdate();
}

function PreviousPage()
{
    //Sys.println("SolisWidgetView:PreviousPage");

    // Previous Page pressed, decrease the pagenumber
    CurrPage--;

    // Rotate is last page = met
    if (CurrPage<1) {
        CurrPage=6;
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
        Usr = Application.getApp().getProperty("PROP_USERNAME");
        //System.println("Username: " + Username);

        // Get Password from Settings
        Pwrd = Application.getApp().getProperty("PROP_PASSWORD");

        // Get Curr Page From settings
        CurrPage= Application.getApp().getProperty("PROP_STARTPAGE");
        if(CurrPage == null){CurrPage=1;}

        // Get the UID
        uid=Application.getApp().getProperty("PROP_UID");
        if(uid instanceof(Number)){
            uid = uid.toString();
        }

        // Get the plantid
        plantid=Application.getApp().getProperty("PROP_PLANTID");
        if(plantid instanceof(Number)){
            plantid = plantid.toString();
        }

        // Set initial glanceVal
        glanceName = "SolisWidget";
        glanceVal = "";
    }

   function toMoment(string)
   {
        //System.println(string.toString());
        var options as Dictionary ={
            :year   => string.toString().substring(0,4).toNumber(),
            :month  => string.toString().substring(5,7).toNumber(),
            :day    => string.toString().substring(8,10).toNumber(),
            :hour   => string.toString().substring(11,13).toNumber(),
            :minute => string.toString().substring(14,16).toNumber(),
            :second => string.toString().substring(17,19).toNumber()
        };
        return Gregorian.moment(options);
   }

    function frmtDtFromRFC3339 (string)
    {
        //System.println("SolisWidgetView:frmtDtFromRFC3339");
        //System.println(string.toString());
        var i as Time = Gregorian.info(toMoment(string), 0); //Time.FORMAT_SHORT

        return (Lang.format("$1$-$2$-$3$", [
            i.day.format("%01u"),
            i.month.format("%01u"),
            i.year.format("%02u")
        ]));
    }

    function frmtTmFromRFC3339 (string)
    {
        //System.println("SolisWidgetView:frmtTmFromRFC3339");
        //System.println(string.toString());
        var i as Time = Gregorian.info(toMoment(string), 0); //Time.FORMAT_SHORT

        return (Lang.format("$1$:$2$:$3$", [
            i.hour.format("%01u"),
            i.min.format("%02u"),
            i.sec.format("%02u")
        ]));

    }

    function frmtEnergy(pwr)
    {
        //System.println("SolisWidgetView:frmtEnergy");
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

    function procRespCode(rspCode,data){
        //System.println("SolisWidgetView:procRespCode");

        // Turn off refreshpage
        ShowRefrsh=false;
        ShowErr=false;
        //System.println(rspCode);
        //System.println(data);

        if (rspCode==200)
        {
            // Make sure no error is shown
            ShowErr=false;
            var rsltCode as Number = data["result"].toNumber();
            if(rsltCode == null || rsltCode != 1)
            {
                // Reset values to reinitiate login
                ShowErr=true;
                uid = "";
                plantid = "";
                Application.getApp().setProperty("PROP_UID","");
                Application.getApp().setProperty("PROP_PLANTID","");

                ErrStr1="API Error: "+ data["result"];
                ErrStr2=WatchUi.loadResource(Rez.Strings.INVALSETTXT1);
                ErrStr3=WatchUi.loadResource(Rez.Strings.INVALSETTXT2);
                ErrStr4=WatchUi.loadResource(Rez.Strings.INVALSETTXT3);
                data = null;
            }
        }
        else if (rspCode==-104) //Communications.BLE_CONNECTION_UNAVAILABLE
        {
            // bluetooth connection issue
            ShowErr = true;
            ErrStr1=WatchUi.loadResource(Rez.Strings.BLERRSTR1);
            ErrStr2=WatchUi.loadResource(Rez.Strings.BLERRSTR2);
            ErrStr3=WatchUi.loadResource(Rez.Strings.BLERRSTR3);
            data = null;
        }
        else if (rspCode==-400) //Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE
        {
            // Invalid API key
            ShowErr = true;
            ErrStr1=WatchUi.loadResource(Rez.Strings.INVALSETTXT1);
            ErrStr2=WatchUi.loadResource(Rez.Strings.INVALSETTXT2);
            ErrStr3=WatchUi.loadResource(Rez.Strings.INVALSETTXT3);
            data = null;
        }
        else if (rspCode==-300) //Communications.NETWORK_REQUEST_TIMED_OUT
        {
            // No Internet
            ShowErr = true;
            ErrStr1=WatchUi.loadResource(Rez.Strings.NOINET1);
            ErrStr2=WatchUi.loadResource(Rez.Strings.NOINET2);
            ErrStr3=WatchUi.loadResource(Rez.Strings.NOINET3);
            data = null;
        }
        else
        {
            // general Error
            ShowErr = true;
            ErrStr1="Error "+rspCode;
            ErrStr2="Check settings in";
            ErrStr3="Garmin Connect/";
            ErrStr4="Express";
        }
        WatchUi.requestUpdate();
        return ShowErr;
    }

    function frmtScrLines(ln1val,ln2val,ln3val,ln4val,ln5val,lines,dc){
        //System.println("SolisWidgetView:frmtScrLines");

        var lnSpaceL as Number = 2;
        var lnSpaceM as Float = 2.6;
        var scrnDev as Number = lines - 1;
        var ln1Font as Number = 13; //Graphics.FONT_SYSTEM_LARGE;
        var ln2Font as Number = 0;
        var ln3Font as Number = 0;
        var ln4Font as Number = 0;
        var ln5Font as Number = 0;
        if(lines == 1 || lines == 2){
            scrnDev = 2;
        }
        if(lines >= 2){
            ln1Font = 13; //Graphics.FONT_SYSTEM_LARGE;
            ln2Font = 13; //Graphics.FONT_SYSTEM_LARGE;
        }
        if(lines >= 3){
            ln1Font = 13; //Graphics.FONT_SYSTEM_LARGE;
            ln2Font = 13; //Graphics.FONT_SYSTEM_LARGE;
            ln3Font = 2; //Graphics.FONT_SMALL;
        }
        if(lines >= 4){
            ln1Font = 13; //Graphics.FONT_SYSTEM_LARGE;
            ln2Font = 13; //Graphics.FONT_SYSTEM_LARGE;
            ln3Font = 2; //Graphics.FONT_SMALL;
            ln4Font  = 2; //Graphics.FONT_SMALL;
        }
        if(lines >= 5){
            ln1Font = 3; //Graphics.FONT_MEDIUM;
            ln2Font = 3; //Graphics.FONT_MEDIUM;
            ln3Font = 3; //Graphics.FONT_MEDIUM;
            ln4Font  = 3; //Graphics.FONT_MEDIUM;
            ln5Font = 3; //Graphics.FONT_MEDIUM;
            lnSpaceL = 2.6;
        }
        var ln1PosY as Number = dc.getHeight() / scrnDev;
        var ln2PosY as Number = ln1PosY + ((Graphics.getFontHeight(ln1Font) / lnSpaceM) + (Graphics.getFontHeight(ln1Font) / lnSpaceM));
        var ln3PosY as Number = ln2PosY + ((Graphics.getFontHeight(ln2Font) / lnSpaceL) + (Graphics.getFontHeight(ln2Font) / lnSpaceL));
        var ln4PosY as Number = ln3PosY + ((Graphics.getFontHeight(ln3Font) / lnSpaceM) + (Graphics.getFontHeight(ln3Font) / lnSpaceM));
        var ln5PosY as Number = ln4PosY + ((Graphics.getFontHeight(ln4Font) / lnSpaceM) + (Graphics.getFontHeight(ln4Font) / lnSpaceM));

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
        Curr = null;
        Today = null;
        ThisMonth = null;
        ThisYear = null;
        Total = null;
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

    function makeReq() {
        //System.println("SolisWidgetView:makeReq");

        fUpdt = false;
        if(uid == null || uid.length() == 0){
            // Show refreshing page
            ShowErr=false; // turn off an error screen (if any)
            ShowRefrsh=true; // make sure refreshingscreen is shown when updating the UI.

            if(Usr == null || Usr.length() == 0 || Pwrd == null || Pwrd.length() == 0 ){
                ShowErr=true;
                ErrStr1=WatchUi.loadResource(Rez.Strings.INVALSETTXT1);
                ErrStr2=WatchUi.loadResource(Rez.Strings.APIERRTXT2);
                ErrStr3=WatchUi.loadResource(Rez.Strings.APIERRTXT3);
                ErrStr4="";
                WatchUi.requestUpdate();
            }
            else{
                WatchUi.requestUpdate();
                var url as String =  BaseUrl+"/v/ap.2.0/cust/user/login?user_id=" + Usr + "&user_pass=" + Pwrd + "&terminate=android&push_sn=11007f002bc2b3ebc16db92898f5d3ea&timezone=1&lan=en&country=CN&cust=006";
                var options as Dictionary = {
                        :method => 1, //Communications.HTTP_REQUEST_METHOD_GET
                        :responseType => 0 //Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
                };

                // Make the authentication request
                //System.println("makeReq url:"+url);
                //System.println("makeReq options:"+options);
                Communications.makeWebRequest(url,{},options,method(:onRec));
            }
        }
        else{
            //Go and check the plantid when the uid is allready set.
            //System.println("makeReq");
            makeReqPlantId();
        }
    }

    // Receive the data from the web request
    function onRec(rspCode, data)
    {
        //System.println("SolisWidgetView:onRec");
        ShowErr = procRespCode(rspCode,data);

        if(ShowErr){
            WatchUi.requestUpdate();
        }
        else{
            WatchUi.requestUpdate();
            uid = data["uid"];
            Application.getApp().setProperty("PROP_UID",uid);
            //System.println(data["uid"]);
            //System.println("uid set:"+uid);
            makeReqPlantId();
        }
    }

    function makeReqPlantId() {
        //System.println("SolisWidgetView:makeReqPlantId");

        if(plantid == null || plantid.length() == 0){
            // Show refreshing page
            ShowErr=false; // turn off an error screen (if any)
            ShowRefrsh=true; // make sure refreshingscreen is shown when updating the UI.
            //WatchUi.requestUpdate();
            var url as String =  BaseUrl+"/v/ap.2.0/plant/find_plant_list?uid=" + uid + "&sel_scope=1&sort_type=1";

            var options as Dictionary = {
                :method => 1, //Communications.HTTP_REQUEST_METHOD_GET
                :responseType => 0 //Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            };
            //System.println("makeReqPlantId url:"+url);
            //System.println("makeReqPlantId options:"+options);
            Communications.makeWebRequest(url,{},options,method(:onRecPlantId));
        }
        else{
            //PlantId allready known, go ahead and request data.
            makeReqPlantOv();
        }
    }

    function onRecPlantId(rspCode, data)
    {
        //System.println("SolisWidgetView:onRecPlantId");

        ShowErr = procRespCode(rspCode,data);
        if(ShowErr){
            WatchUi.requestUpdate();
        }
        else{
            ShowErr=false;
            plantid = data["list"][0]["plant_id"];
            Application.getApp().setProperty("PROP_PLANTID",plantid);
            //System.println("plantid set:"+plantid);
            makeReqPlantOv();
        }
    }

    function makeReqPlantOv()
    {
        //System.println("SolisWidgetView:makeReqPlantOv");

        // Show refreshing page
        ShowErr=false; // turn off an error screen (if any)
        ShowRefrsh=true; // make sure refreshingscreen is shown when updating the UI.
        //WatchUi.requestUpdate();
        //System.println("makeReq uid:"+uid);
        var url as String =  BaseUrl+"/v/ap.2.0/plant/get_plant_overview?uid=" + uid + "&plant_id=" + plantid;

        var options as Dictionary = {
                    :method => 1, //Communications.HTTP_REQUEST_METHOD_GET
                    :responseType => 0 //Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        //System.println("makeReq url:"+url);
        //System.println("makeReq options:"+options);
        Communications.makeWebRequest(url,{},options,method(:onRecPlantOv));
    }

    function onRecPlantOv(rspCode, data)
    {
        //System.println("SolisWidgetView:onRecPlantOv");

        ShowErr = procRespCode(rspCode,data);
        if(ShowErr){
            WatchUi.requestUpdate();
        }
        else{
            WatchUi.requestUpdate();
            if (data instanceof Dictionary)
            {
                var pwr as String = 0.0; // init variable
                // Format Curr pwr
                pwr = data["power_out"]["power"].toFloat();
                if (pwr<1)
                {
                    Curr= pwr + " W";
                } else {
                    Curr=pwr.format("%.2f") + " W";
                }
                //System.println("Curr_pwr: "+pwr + " Curr: "+ Curr);

                // Format Today
                pwr = data["power_out"]["energy_day"].toFloat();
                Today= frmtEnergy(pwr);
                //System.println("today_energy: "+pwr + " Today :"+Today);

                // Format Total
                pwr = data["power_out"]["energy_accu_real"].toFloat();
                Total= frmtEnergy(pwr);
                //System.println("total_energy: "+pwr + " Total: " + Total);

                // Format Last Update
                lstUpd=data["date"];
                lastUpdTmLocal = frmtTmFromRFC3339(lstUpd);
                lastUpdDtLocal = frmtDtFromRFC3339(lstUpd);
                data = null;
            }
            else
            {
                setNotParsable();
            }
            makeReqPlantMonthStats();
        }
    }

    function makeReqPlantMonthStats()
    {
        //System.println("SolisWidgetView:makeReqPlantMonthStats");

        // Show refreshing page
        ShowErr=false; // turn off an error screen (if any)
        ShowRefrsh=true; // make sure refreshingscreen is shown when updating the UI.
        //WatchUi.requestUpdate();
        //System.println("makeReq uid:"+uid);
        var dateToday as Moment = Gregorian.info(Time.now(), 0); //Time.FORMAT_SHORT
        var dateTodayString as String = Lang.format("$1$-$2$-$3$",[
            dateToday.year,
            dateToday.month,
            dateToday.day
            ]
        );
        var url as String =  BaseUrl+"/v/ap.2.0/plant/get_plant_powerout_statics_month2?date=" + dateTodayString + "&uid=" + uid + "&plant_id=" + plantid;

        var options as Dictionary = {
                    :method => 1, //Communications.HTTP_REQUEST_METHOD_GET
                    :responseType => 0 //Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        // Make the authentication request
        //System.println("makeReq url:"+url);
        //System.println("makeReq options:"+options);
        Communications.makeWebRequest(url,{},options,method(:onRecPlantMonthStats));
    }

    function onRecPlantMonthStats(rspCode, data)
    {
        //System.println("SolisWidgetView:onRecPlantMonthStats");

        ShowErr = procRespCode(rspCode,data);
        if(ShowErr){
            WatchUi.requestUpdate();
        }
        else{
            WatchUi.requestUpdate();
            if (data instanceof Dictionary)
            {
                var list as Dictionary = data["list"];
                var pwr as String = 0;
                for(var i=0;i<list.size();i++) {
                    //System.println("day "+ data["list"][i]["month"] +"="+ data["list"][i]["energy"]);
                    pwr = pwr + data["list"][i]["energy"];
                }
                ThisMonth= frmtEnergy(pwr);
                //System.println("ThisMonth: " + ThisMonth);
                data = null;
            }
            else {
                setNotParsable();
            }
            makeReqPlantYrStats();
        }
    }

    function makeReqPlantYrStats()
    {
        //System.println("SolisWidgetView:makeReqPlantYrStats");

        // Show refreshing page
        ShowErr=false; // turn off an error screen (if any)
        ShowRefrsh=true; // make sure refreshingscreen is shown when updating the UI.
        //WatchUi.requestUpdate();
        //System.println("makeReq uid:"+uid);
        var dateToday = Gregorian.info(Time.now(), 0); //Time.FORMAT_SHORT
        var dateTodayString = Lang.format("$1$-$2$-$3$",[
            dateToday.year,
            dateToday.month,
            dateToday.day
            ]
        );

        var url as String =  BaseUrl+"/v/ap.2.0/plant/get_plant_powerout_statics_year?date=" + dateTodayString + "&uid=" + uid + "&plant_id=" + plantid;

        var options as Dictionary = {
                    :method => 1, //Communications.HTTP_REQUEST_METHOD_GET
                    :responseType => 0 //Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        // Make the authentication request
        //System.println("makeReq url:"+url);
        //System.println("makeReq options:"+options);
        Communications.makeWebRequest(url,{},options,method(:onRecPlantYrStats));
    }

    function onRecPlantYrStats(rspCode, data)
    {
        //System.println("SolisWidgetView:onRecPlantYrStats");

        ShowErr = procRespCode(rspCode, data);
        if(ShowErr){
            WatchUi.requestUpdate();
        }
        else{
            WatchUi.requestUpdate();
            if (data instanceof Dictionary)
            {
                var list as Dictionary = data["list"];
                var pwr as String = 0;
                for(var i as Number =0;i<list.size();i++) {
                    //System.println("year "+ data["list"][i]["year"] +"="+ data["list"][i]["energy"]);
                    pwr = pwr + data["list"][i]["energy"];
                }

                ThisYear= frmtEnergy(pwr);
                //System.println("yearly_energy: "+pwr + " ThisYear: " + ThisYear);
                data = null;
            }
            else
            {
                setNotParsable();
            }
        }
        //WatchUi.requestUpdate();
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
        Curr = Application.getApp().getProperty("Curr");
        Today = Application.getApp().getProperty("Today");
        ThisMonth = Application.getApp().getProperty("ThisMonth");
        ThisYear = Application.getApp().getProperty("ThisYear");
        Total = Application.getApp().getProperty("Total");
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

        if (ShowErr) {
           // Show Error
            frmtScrLines(
                ErrStr1,
                ErrStr2,
                ErrStr3,
                ErrStr4,
                "",
                5,
                dc
            );
        }
        else  if (ShowRefrsh) {
            frmtScrLines(
                WatchUi.loadResource(Rez.Strings.UPDT),
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
                if(CurrPage==1){
                    // Curr pwr
                    frmtScrLines(
                        WatchUi.loadResource(Rez.Strings.CURR),
                        Curr,
                        lastUpdTmLocal,
                        lastUpdDtLocal,
                        "",
                        4,
                        dc
                    );
                    glanceName = WatchUi.loadResource(Rez.Strings.CURR);
                    glanceVal = Curr;
                }
                if(CurrPage==2){
                    // Today
                    frmtScrLines(
                        WatchUi.loadResource(Rez.Strings.TODAY),
                        Today,
                        lastUpdTmLocal,
                        lastUpdDtLocal,
                        "",
                        4,
                        dc
                    );
                    glanceName = WatchUi.loadResource(Rez.Strings.TODAY);
                    glanceVal = Today;
                }
                if(CurrPage==3){
                    // This Month
                    frmtScrLines(
                        WatchUi.loadResource(Rez.Strings.THISMONTH),
                        ThisMonth,
                        lastUpdTmLocal,
                        lastUpdDtLocal,
                        "",
                        4,
                        dc
                    );
                    glanceName = WatchUi.loadResource(Rez.Strings.THISMONTH);
                    glanceVal = ThisMonth;
                }
                if(CurrPage==4){
                    // This Year
                    frmtScrLines(
                        WatchUi.loadResource(Rez.Strings.THISYEAR),
                        ThisYear,
                        lastUpdTmLocal,
                        lastUpdDtLocal,
                        "",
                        4,
                        dc
                    );
                    glanceName = WatchUi.loadResource(Rez.Strings.THISYEAR);
                    glanceVal = ThisYear;
                }
                if(CurrPage==5){
                    // Total
                    frmtScrLines(
                        WatchUi.loadResource(Rez.Strings.TOT),
                        Total,
                        lastUpdTmLocal,
                        lastUpdDtLocal,
                        "",
                        4,
                        dc
                    );
                    glanceName = WatchUi.loadResource(Rez.Strings.TOT);
                    glanceVal = Total;
                }
                if(CurrPage==6){
                    frmtScrLines(
                        WatchUi.loadResource(Rez.Strings.CURR)+": "+Curr,
                        WatchUi.loadResource(Rez.Strings.TODAY)+": "+Today,
                        WatchUi.loadResource(Rez.Strings.THISMONTH)+": "+ThisMonth,
                        WatchUi.loadResource(Rez.Strings.THISYEAR)+": "+ThisYear,
                        WatchUi.loadResource(Rez.Strings.TOT)+": "+Total,
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
        Application.getApp().setProperty("Curr",Curr);
        Application.getApp().setProperty("Today", Today);
        Application.getApp().setProperty("ThisMonth", ThisMonth);
        Application.getApp().setProperty("ThisYear", ThisYear);
        Application.getApp().setProperty("Total",Total);
        Application.getApp().setProperty("lstUpd", lstUpd);
        Application.getApp().setProperty("lastUpdTmLocal", lastUpdTmLocal);
        Application.getApp().setProperty("lastUpdDtLocal", lastUpdDtLocal);
        Application.getApp().setProperty("glanceName", glanceName);
        Application.getApp().setProperty("glanceVal", glanceVal);
    }
}