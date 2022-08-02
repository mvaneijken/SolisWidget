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
var showRefrsh as Boolean = false;
var showErr as Boolean = false;
var errStr1 as String = "";
var errStr2 as String = "";
var errStr3 as String = "";
var errStr4 as String = "";

// vars to remember
var curr as Float;
var today as Float;
var thisMonth as Float;
var thisYear as Float;
var total as Float;
var lastUpdTmLocal as String;
var lastUpdDtLocal as String;
var lstUpd as String;
var baseUrl as String = "https://apic-cdn.solarman.cn";
var uid as Number; //c_user_id variable received when authenticating to the API
var plantid as Number; //plant_id variable received when retrieving the plants.
var glanceName as String;
var glanceVal as String;
var fUpdt as Boolean = false;

// Settings
var currPage as Number;
var usr as String = "";
var pwrd as String = "";

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

    function makeReq() {
        //System.println("SolisWidgetView:makeReq");

        fUpdt = false;
        if(uid == null || uid == -1){
            // Show refreshing page
            showErr=false; // turn off an error screen (if any)
            showRefrsh=true; // make sure refreshingscreen is shown when updating the UI.

            if(usr == null || usr.length() == 0 || pwrd == null || pwrd.length() == 0 ){
                showErr=true;
                errStr1=WatchUi.loadResource(Rez.Strings.I1);
                errStr2=WatchUi.loadResource(Rez.Strings.A2);
                errStr3=WatchUi.loadResource(Rez.Strings.A3);
                errStr4="";
                WatchUi.requestUpdate();
            }
            else{
                WatchUi.requestUpdate();
                var url as String =  baseUrl+"/v/ap.2.0/cust/user/login?user_id=" + usr + "&user_pass=" + pwrd + "&terminate=android&push_sn=11007f002bc2b3ebc16db92898f5d3ea&timezone=1&lan=en&country=CN&cust=006";

                // Make the authentication request
                //System.println("makeReq url:"+url);
                Communications.makeWebRequest(url,{},{
                        :method => 1, //Communications.HTTP_REQUEST_METHOD_GET
                        :responseType => 0 //Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
                },method(:onRec));
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
        showErr = procRespCode(rspCode,data);

        if(showErr){
            WatchUi.requestUpdate();
        }
        else{
            WatchUi.requestUpdate();
            uid = data["uid"];
            Application.getApp().setProperty("PUI",uid);
            //System.println(data["uid"]);
            //System.println("uid set:"+uid);
            makeReqPlantId();
        }
    }

    function makeReqPlantId() {
        //System.println("SolisWidgetView:makeReqPlantId");

        if(plantid == null || plantid == -1){
            // Show refreshing page
            showErr=false; // turn off an error screen (if any)
            showRefrsh=true; // make sure refreshingscreen is shown when updating the UI.
            //WatchUi.requestUpdate();
            var url as String =  baseUrl+"/v/ap.2.0/plant/find_plant_list?uid=" + uid + "&sel_scope=1&sort_type=1";

            //System.println("makeReqPlantId url:"+url);
            Communications.makeWebRequest(url,{},{
                :method => 1, //Communications.HTTP_REQUEST_METHOD_GET
                :responseType => 0 //Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },method(:onRecPlantId));
        }
        else{
            //PlantId allready known, go ahead and request data.
            makeReqPlantOv();
        }
    }

    function onRecPlantId(rspCode, data)
    {
        //System.println("SolisWidgetView:onRecPlantId");

        showErr = procRespCode(rspCode,data);
        if(showErr){
            WatchUi.requestUpdate();
        }
        else{
            showErr=false;
            plantid = data["list"][0]["plant_id"];
            Application.getApp().setProperty("PPI",plantid);
            //System.println("plantid set:"+plantid);
            makeReqPlantOv();
        }
    }

    function makeReqPlantOv()
    {
        //System.println("SolisWidgetView:makeReqPlantOv");

        // Show refreshing page
        showErr=false; // turn off an error screen (if any)
        showRefrsh=true; // make sure refreshingscreen is shown when updating the UI.
        //WatchUi.requestUpdate();
        //System.println("makeReq uid:"+uid);
        var dateToday as Moment = Gregorian.info(Time.now(), 0); //Time.FORMAT_SHORT
        var dateTodayString as String = Lang.format("$1$-$2$-$3$",[
            dateToday.year.format("%02u"),
            dateToday.month.format("%02u"),
            dateToday.day.format("%02u")
            ]
        );
        var url as String =  baseUrl+"/v/ap.2.0/plant/get_plant_powerout_statics_day?date=" + dateTodayString + "&uid=" + uid.toString() + "&plant_id=" + plantid.toString();

        //System.println("makeReq url:"+url);
        Communications.makeWebRequest(url,{},{
                    :method => 1, //Communications.HTTP_REQUEST_METHOD_GET
                    :responseType => 0 //Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        },method(:onRecPlantOv));
    }

    function onRecPlantOv(rspCode, data)
    {
        //System.println("SolisWidgetView:onRecPlantOv");

        showErr = procRespCode(rspCode,data);
        if(showErr){
            WatchUi.requestUpdate();
        }
        else{
            WatchUi.requestUpdate();
            if (data instanceof Dictionary)
            {
                // Format curr pwr
                if (data["current"] <1)
                {
                    curr=data["current"] + " W";
                } else {
                    curr=data["current"].format("%.2f") + " W";
                }
                //System.println("curr_pwr: "+pwr + " curr: "+ curr);

                // Format today
                today=frmtEnergy(data["energy"]);
                //System.println("today_energy: "+pwr + " today :"+today);

                // Format Last Update
                var i as Time = Gregorian.info(Time.now(), 0); //Time.FORMAT_SHORT
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
        showErr=false; // turn off an error screen (if any)
        showRefrsh=true; // make sure refreshingscreen is shown when updating the UI.
        //WatchUi.requestUpdate();
        //System.println("makeReq uid:"+uid);
        var dateToday as Moment = Gregorian.info(Time.now(), 0); //Time.FORMAT_SHORT
        var dateTodayString as String = Lang.format("$1$-$2$-$3$",[
            dateToday.year,
            dateToday.month,
            dateToday.day
            ]
        );
        var url as String =  baseUrl+"/v/ap.2.0/plant/get_plant_powerout_statics_month2?date=" + dateTodayString + "&uid=" + uid.toString() + "&plant_id=" + plantid.toString();

        // Make the authentication request
        //System.println("makeReq url:"+url);
        Communications.makeWebRequest(url,{},{
                    :method => 1, //Communications.HTTP_REQUEST_METHOD_GET
                    :responseType => 0 //Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        },method(:onRecPlantMonthStats));
    }

    function onRecPlantMonthStats(rspCode, data)
    {
        //System.println("SolisWidgetView:onRecPlantMonthStats");

        showErr = procRespCode(rspCode,data);
        if(showErr){
            WatchUi.requestUpdate();
        }
        else{
            WatchUi.requestUpdate();
            if (data instanceof Dictionary)
            {
                var pwr as Float = 0;
                for(var i=0;i<(data["list"]).size();i++) {
                    //System.println("day "+ data["list"][i]["month"] +"="+ data["list"][i]["energy"]);
                    pwr = pwr + data["list"][i]["energy"];
                }
                thisMonth= frmtEnergy(pwr);
                //System.println("thisMonth: " + thisMonth);
                data=null;
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
        showErr=false; // turn off an error screen (if any)
        showRefrsh=true; // make sure refreshingscreen is shown when updating the UI.
        //WatchUi.requestUpdate();
        //System.println("makeReq uid:"+uid);
        var dateToday = Gregorian.info(Time.now(), 0); //Time.FORMAT_SHORT
        var dateTodayString = Lang.format("$1$-$2$-$3$",[
            dateToday.year.format("%02u"),
            dateToday.month.format("%02u"),
            dateToday.day.format("%02u")
            ]
        );

        var url as String =  baseUrl+"/v/ap.2.0/plant/get_plant_powerout_statics_year?date=" + dateTodayString + "&uid=" + uid.toString() + "&plant_id=" + plantid.toString();

        // Make the authentication request
        //System.println("makeReq url:"+url);
        Communications.makeWebRequest(url,{},{
                    :method => 1, //Communications.HTTP_REQUEST_METHOD_GET
                    :responseType => 0 //Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        },method(:onRecPlantYrStats));
    }

    function onRecPlantYrStats(rspCode, data)
    {
        //System.println("SolisWidgetView:onRecPlantYrStats");

        showErr = procRespCode(rspCode, data);
        if(showErr){
            WatchUi.requestUpdate();
        }
        else{
            WatchUi.requestUpdate();

            // Format total
            total= frmtEnergy(data["total"]);
            //System.println("total_energy: "+pwr + " total: " + total);

            if (data instanceof Dictionary)
            {
                var pwr as Float = 0;
                for(var i as Number =0;i<(data["list"]).size();i++) {
                    //System.println("year "+ data["list"][i]["year"] +"="+ data["list"][i]["energy"]);
                    pwr = pwr + data["list"][i]["energy"];
                }
                thisYear= frmtEnergy(pwr);
                //System.println("yearly_energy: "+pwr + " thisYear: " + thisYear);
                data=null;
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