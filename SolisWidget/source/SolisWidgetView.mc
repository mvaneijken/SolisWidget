using Toybox.WatchUi;
using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Communications;
using Toybox.System;

// Commands from the delegate
var DOWEBREQUEST=1;

// Status screens vars
var ShowRefrsh=false;
var ShowErr=false;
var ErrStr1;
var ErrStr2;
var ErrStr3;
var ErrStr4;

// vars to remember
var Curr;
var Today;
var ThisMonth;
var ThisYear;
var Total;
var lastUpdLocal;
var lastUpdTmLocal;
var lastUpdDtLocal;
var lstUpd;
var nxtUpdt;
var BaseUrl = "https://apic-cdn.solarman.cn";
var i;
var uid = ""; //c_user_id variable received when authenticating to the API
var plantid = ""; //plant_id variable received when retrieving the plants.
var glanceName = "";
var glanceVal = "";
var fUpdt = false;
var rsltCode = "";
var dateToday = Gregorian.info(Time.now(), 0); //Time.FORMAT_SHORT
var dateTodayString = Lang.format("$1$-$2$-$3$",[
    dateToday.year,
    dateToday.month,
    dateToday.day
    ]
);

// Settings
var CurrPage;
var Usr = "-";
var Pwrd = "-";

// Constants
var UpdateInterval=5; // in Minutes

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
        //logo = WatchUi.loadResource(Rez.Drawables.SolisLogo);
        //icon = WatchUi.loadResource(Rez.Drawables.SolisIcon);
    }

function retrieveSettings() {
        //System.println("SolisWidgetView:retrieveSettings");
        // Get Username From settings
        Usr = Application.getApp().getProperty("PROP_USERNAME");
        //System.println("Username: " + Username);

        // Get Password from Settings
        Pwrd = Application.getApp().getProperty("PROP_PASSWORD");

        // Get Curr Page From settings
        CurrPage=Application.getApp().getProperty("PROP_STARTPAGE");

        // Get the UID
        uid=Application.getApp().getProperty("PROP_UID");

        // Get the plantid
        plantid=Application.getApp().getProperty("PROP_PLANTID");

        // Set initial glanceVal
        glanceName = "SolisWidget";
        glanceVal = "";
    }

    function frmtDtTmFromRFC3339 (string)
    {
        //System.println("SolisWidgetView:frmtDtTmFromRFC3339");
        i = Gregorian.info(toMoment(string), 0); //Time.FORMAT_SHORT

        return (Lang.format("$1$-$2$-$3$ $4$:$5$:$6$", [
            i.day.format("%01u"),
            i.month.format("%01u"),
            i.year.format("%02u"),
            i.hour.format("%02u"),
            i.min.format("%02u"),
            i.sec.format("%02u")
        ]));
    }

   function toMoment(string)
   {
        //System.println(string.toString());
        var options ={
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
        i;
        i = Gregorian.info(toMoment(string), 0); //Time.FORMAT_SHORT

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
        i;
        i = Gregorian.info(toMoment(string), 0); //Time.FORMAT_SHORT

        return (Lang.format("$1$:$2$:$3$", [
            i.hour.format("%01u"),
            i.min.format("%02u"),
            i.sec.format("%02u")
        ]));

    }

    function momentFromDtTm(i)
    {
        //System.println("SolisWidgetView:momentFromDtTm");
        return Gregorian.moment({
            :year   => i.year,
            :month  => i.month,
            :day    => i.day,
            :hour   => i.hour,
            :minute => i.min,
            :second => i.sec
        });
    }

    // function StringFromMoment(moment)
    // {
    //     //System.println("SolisWidgetView:StringFromMoment");
    //     var i=Gregorian.info(moment,Time.FORMAT_MEDIUM);
    //     return i.year+"-"+i.month+"-"+i.day+" "+i.hour+":"+i.min+":"+i.sec;
    // }

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
            rsltCode = data["result"].toString();
            if(rsltCode.toNumber() != 1)
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
            }
        }
        else if (rspCode==-104) //Communications.BLE_CONNECTION_UNAVAILABLE
        {
            // bluetooth connection issue
            ShowErr = true;
            ErrStr1=WatchUi.loadResource(Rez.Strings.BLERRSTR1);
            ErrStr2=WatchUi.loadResource(Rez.Strings.BLERRSTR2);
            ErrStr3=WatchUi.loadResource(Rez.Strings.BLERRSTR3);
        }
        else if (rspCode==-400) //Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE
        {
            // Invalid API key
            ShowErr = true;
            ErrStr1=WatchUi.loadResource(Rez.Strings.INVALSETTXT1);
            ErrStr2=WatchUi.loadResource(Rez.Strings.INVALSETTXT2);
            ErrStr3=WatchUi.loadResource(Rez.Strings.INVALSETTXT3);
        }
        else if (rspCode==-300) //Communications.NETWORK_REQUEST_TIMED_OUT
        {
            // No Internet
            ShowErr = true;
            ErrStr1=WatchUi.loadResource(Rez.Strings.NOINET1);
            ErrStr2=WatchUi.loadResource(Rez.Strings.NOINET2);
            ErrStr3=WatchUi.loadResource(Rez.Strings.NOINET3);
        }
        else
        {
            // general Error
            ShowErr = true;
            ErrStr1="Error "+rspCode;
            ErrStr2="Check settings in";
            ErrStr3="Garmin Connect or Express";
        }
        WatchUi.requestUpdate();
        return ShowErr;
    }

    function frmtScrLines(val1,val2,val3,val4,val5,lines,dc){
        //System.println("SolisWidgetView:frmtScrLines");

        var lnSpaceL = 2;
        var lnSpaceM = 2.6;
        var scrnDev = lines - 1;
        var ln1Font = 13; //Graphics.FONT_SYSTEM_LARGE;
        var ln2Font = 0;
        var ln3Font = 0;
        var ln4Font = 0;
        var ln5Font = 0;
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
        var ln1PosY = dc.getHeight() / scrnDev;
        var ln2PosY = ln1PosY + ((Graphics.getFontHeight(ln1Font) / lnSpaceM) + (Graphics.getFontHeight(ln1Font) / lnSpaceM));
        var ln3PosY = ln2PosY + ((Graphics.getFontHeight(ln2Font) / lnSpaceL) + (Graphics.getFontHeight(ln2Font) / lnSpaceL));
        var ln4PosY = ln3PosY + ((Graphics.getFontHeight(ln3Font) / lnSpaceM) + (Graphics.getFontHeight(ln3Font) / lnSpaceM));
        var ln5PosY = ln4PosY + ((Graphics.getFontHeight(ln4Font) / lnSpaceM) + (Graphics.getFontHeight(ln4Font) / lnSpaceM));

        var ln1val = val1;
        var ln2val = val2;
        var ln3val = val3;
        var ln4val = val4;
        var ln5val = val5;

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
        lastUpdLocal = null;
        lastUpdTmLocal = null;
        lastUpdDtLocal = null;
    }

    // function to convert date in string format to moment object
    function nextUpdate()
    {
        //System.println("SolisWidgetView:nxtUpdt");

        // There might be a time difference, so only use the number of minutes from the string,
        // and derive the lstUpd time from the Curr time)

        // Determine minute number from lstUpd string
        var lstUpdMin=lstUpd.substring(14, 16).toNumber();

        // derive offset from GetClockTime object.
        var myTime = System.getClockTime(); // ClockTime object
        var timeZoneOffset = new Time.Moment(myTime.timeZoneOffset);

        // get Curr time as moment to calculate with
        var CurrMoment=Time.now().value();

        // correct Curr hour if 12'o clock sign has passed after last update
        if (myTime.min<lstUpdMin)
        {
            // hour has passed, so make sure the we are in the previous hour.
            CurrMoment=CurrMoment-3600; //Gregorian.SECONDS_PER_HOUR;
        }

        // Create the gregorian i object for the previous update moment (Curr time, where minute number is changed to the minute number of the reported last update)
        var gPrevUpdt = Gregorian.info(new Time.Moment(CurrMoment), 1); //Time.FORMAT_MEDIUM
        gPrevUpdt.min=lstUpdMin;

        // Calculate Next Update Moment (=previousupdate+UpdateInterval-offset to correct timezone)
        nxtUpdt=momentFromDtTm(gPrevUpdt).value()+UpdateInterval*60-myTime.timeZoneOffset; //Gregorian.SECONDS_PER_MINUTE
        return nxtUpdt;
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
        if(uid.toString().length() <3 ){
            // Show refreshing page
            ShowErr=false; // turn off an error screen (if any)
            ShowRefrsh=true; // make sure refreshingscreen is shown when updating the UI.

            if(Usr.toString().length == 0 || Pwrd.toString().length == 0){
                ShowErr=true;
                ErrStr1=WatchUi.loadResource(Rez.Strings.INVALSETTXT1);
                ErrStr2=WatchUi.loadResource(Rez.Strings.APIERRTXT2);
                ErrStr3=WatchUi.loadResource(Rez.Strings.APIERRTXT3);
                ErrStr4="";
                WatchUi.requestUpdate();
            }
            else{
                WatchUi.requestUpdate();
                var url =  BaseUrl+"/v/ap.2.0/cust/user/login?user_id=" + Usr + "&user_pass=" + Pwrd + "&terminate=android&push_sn=11007f002bc2b3ebc16db92898f5d3ea&timezone=1&lan=en&country=CN&cust=006";
                var options = {
                        :method => 1, //Communications.HTTP_REQUEST_METHOD_GET
                        :responseType => 0 //Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
                };

                // only retrieve the settings if they've actually changed

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

        if(plantid.toString().length() < 3 ){
            // Show refreshing page
            ShowErr=false; // turn off an error screen (if any)
            ShowRefrsh=true; // make sure refreshingscreen is shown when updating the UI.
            //WatchUi.requestUpdate();
            var url =  BaseUrl+"/v/ap.2.0/plant/find_plant_list?uid=" + uid.toString() + "&sel_scope=1&sort_type=1";

            var options = {
                :method => 1, //Communications.HTTP_REQUEST_METHOD_GET
                :responseType => 0 //Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            };

            // Make the authentication request
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
        var url =  BaseUrl+"/v/ap.2.0/plant/get_plant_overview?uid=" + uid.toString() + "&plant_id=" + plantid.toString();

        var options = {
                    :method => 1, //Communications.HTTP_REQUEST_METHOD_GET
                    :responseType => 0 //Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        // Make the authentication request
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
                var pwr = 0.0; // init variable
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
                var a = nextUpdate();
                lastUpdLocal = frmtDtTmFromRFC3339(lstUpd);
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
        var url =  BaseUrl+"/v/ap.2.0/plant/get_plant_powerout_statics_month2?date=" + dateTodayString + "&uid=" + uid.toString() + "&plant_id=" + plantid.toString();

        var options = {
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
                var list = data["list"];
                var pwr = 0;
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
        var url =  BaseUrl+"/v/ap.2.0/plant/get_plant_powerout_statics_year?date=" + dateTodayString + "&uid=" + uid.toString() + "&plant_id=" + plantid.toString();

        var options = {
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
                var list = data["list"];
                var pwr = 0;
                for(var i=0;i<list.size();i++) {
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
        nxtUpdt = Application.getApp().getProperty("nxtUpdt");
        lastUpdLocal = Application.getApp().getProperty("lastUpdLocal");
        lastUpdTmLocal = Application.getApp().getProperty("lastUpdTmLocal");
        lastUpdDtLocal = Application.getApp().getProperty("lastUpdDtLocal");

        // Check if autoupdate is needed
        if (nxtUpdt==null) {
            // some kind of error in previous session. Do update
            makeReq();
        } else {
            // var nxtUpdt=ParseDateToMoment(lstUpd).add(UpdateInterval);
            if (Time.now().greaterThan(new Time.Moment(nxtUpdt)))
            {
                makeReq();
            }
        }
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
        Application.getApp().setProperty("nxtUpdt", nxtUpdt);
        Application.getApp().setProperty("lastUpdLocal", lastUpdLocal);
        Application.getApp().setProperty("lastUpdTmLocal", lastUpdTmLocal);
        Application.getApp().setProperty("lastUpdDtLocal", lastUpdDtLocal);
        Application.getApp().setProperty("glanceName", glanceName);
        Application.getApp().setProperty("glanceVal", glanceVal);
    }
}