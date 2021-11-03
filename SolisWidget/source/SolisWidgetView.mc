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
var ShowRefreshing=false;
var ShowError=false;
var Errortext1;
var Errortext2;
var Errortext3;
var Errortext4;

// vars to remember
var Current;
var Today;
var ThisMonth;
var ThisYear;
var Total;
var lastUpdateLocalized;
var lastUpdateTimeLocalized;
var lastUpdateDateLocalized;
var LastUpdate;
var NextUpdate;
var BaseUrl = "https://apic-cdn.solarman.cn";
var uid = ""; //c_user_id variable received when authenticating to the API
var plantid = ""; //plant_id variable received when retrieving the plants.
var glancesName = "";
var glancesValue = "";
var forceUpdate = false;
var resultCode = "";
var dateToday = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
var dateTodayString = Lang.format("$1$-$2$-$3$",[
    dateToday.year,
    dateToday.month,
    dateToday.day
    ]
);

// Settings
var CurrentPage;
var Username = "-";
var Password = "-";

// Constants
var UpdateInterval=5; // in Minutes

function NextPage()
{
    //System.println("SolisWidgetView:NextPage");
    // Next Page pressed, increase the pagenumber
    CurrentPage++;

    // Rotate is last page = met
    if (CurrentPage>6) {
        CurrentPage=1;
    }

    // refresh the screen
    WatchUi.requestUpdate();
}

function PreviousPage()
{
    //System.println("SolisWidgetView:PreviousPage");

    // Previous Page pressed, decrease the pagenumber
    CurrentPage--;

    // Rotate is last page = met
    if (CurrentPage<1) {
        CurrentPage=6;
    }

    // refresh the screen
    WatchUi.requestUpdate();
}

function RefreshPage()
{
    //System.println("SolisWidgetView:RefreshPage");
    WatchUi.requestUpdate();
    forceUpdate = true;
}

class SolisWidgetView extends WatchUi.View {

    //var icon as BitmapResource;
    //var logo as BitmapResource;

    function initialize() {
        //System.println("SolisWidgetView:initialize");
        //System.println("getDevicePartNumber: " + getDevicePartNumber());
        retrieveSettings();
        View.initialize();
        //logo = WatchUi.loadResource(Rez.Drawables.SolisLogo);
        //icon = WatchUi.loadResource(Rez.Drawables.SolisIcon);
    }

    function getDevicePartNumber() {
        //System.println("SolisWidgetView:getDevicePartNumber");
        var deviceSettings = System.getDeviceSettings();
        // device part numbers come from ${SDKROOT}/bin/devices.xml
        var partNumber = deviceSettings.partNumber;
        return partNumber;
    }

    function retrieveSettings() {
        //System.println("SolisWidgetView:retrieveSettings");
        // Get Username From settings
        Username = Application.getApp().getProperty("PROP_USERNAME");
        //System.println("Username: " + Username);

        // Get Password from Settings
        Password = Application.getApp().getProperty("PROP_PASSWORD");

        // Get Current Page From settings
        CurrentPage=Application.getApp().getProperty("PROP_STARTPAGE");

        // Get the UID
        uid=Application.getApp().getProperty("PROP_UID");

        // Get the plantid
        plantid=Application.getApp().getProperty("PROP_PLANTID");

        // Set initial glancesValue
        glancesName = WatchUi.loadResource(Rez.Strings.AppName);
        glancesValue = "";
    }

    function formatDateTimeFromRFC3339 (string)
    {
        //System.println("SolisWidgetView:formatDateTimeFromRFC3339");

        //System.println(string.toString());
        var options ={
            :year   => string.toString().substring(0,4).toNumber(),
            :month  => string.toString().substring(5,7).toNumber(),
            :day    => string.toString().substring(8,10).toNumber(),
            :hour   => string.toString().substring(11,13).toNumber(),
            :minute => string.toString().substring(14,16).toNumber(),
            :second => string.toString().substring(17,19).toNumber()
        };
        var time = Gregorian.moment(options);
        var info;
        info = Gregorian.info(time, Time.FORMAT_SHORT);

        return (Lang.format("$1$-$2$-$3$ $4$:$5$:$6$", [
            info.day.format("%01u"),
            info.month.format("%01u"),
            info.year.format("%02u"),
            info.hour.format("%02u"),
            info.min.format("%02u"),
            info.sec.format("%02u")
        ]));
    }

    function formatDateFromRFC3339 (string)
    {
        //System.println("SolisWidgetView:formatDateFromRFC3339");
        //System.println(string.toString());
        var options ={
            :year   => string.toString().substring(0,4).toNumber(),
            :month  => string.toString().substring(5,7).toNumber(),
            :day    => string.toString().substring(8,10).toNumber(),
            :hour   => string.toString().substring(11,13).toNumber(),
            :minute => string.toString().substring(14,16).toNumber(),
            :second => string.toString().substring(17,19).toNumber()
        };
        var time = Gregorian.moment(options);
        var info;
        info = Gregorian.info(time, Time.FORMAT_SHORT);

        return (Lang.format("$1$-$2$-$3$", [
            info.day.format("%01u"),
            info.month.format("%01u"),
            info.year.format("%02u")
        ]));
    }

    function formatTimeFromRFC3339 (string)
    {
        //System.println("SolisWidgetView:formatTimeFromRFC3339");
        //System.println(string.toString());
        var options ={
            :year   => string.toString().substring(0,4).toNumber(),
            :month  => string.toString().substring(5,7).toNumber(),
            :day    => string.toString().substring(8,10).toNumber(),
            :hour   => string.toString().substring(11,13).toNumber(),
            :minute => string.toString().substring(14,16).toNumber(),
            :second => string.toString().substring(17,19).toNumber()
        };
        var time = Gregorian.moment(options);
        var info;
        info = Gregorian.info(time, Time.FORMAT_SHORT);

        return (Lang.format("$1$:$2$:$3$", [
            info.hour.format("%01u"),
            info.min.format("%02u"),
            info.sec.format("%02u")
        ]));

    }

    function moment_from_info(info)
    {
        //System.println("SolisWidgetView:moment_from_info");
        return Gregorian.moment({
            :year   => info.year,
            :month  => info.month,
            :day    => info.day,
            :hour   => info.hour,
            :minute => info.min,
            :second => info.sec
        });
    }

    function StringFromInfo(info)
    {
        //System.println("SolisWidgetView:StringFromInfo");
        var DateText = info.year+"-"+info.month+"-"+info.day+" "+info.hour+":"+info.min+":"+info.sec;
        return DateText;
    }

    // function StringFromMoment(moment)
    // {
    //     //System.println("SolisWidgetView:StringFromMoment");
    //     var info=Gregorian.info(moment,Time.FORMAT_MEDIUM);
    //     return StringFromInfo(info);
    // }

    function formatEnergy(power)
    {
        //System.println("SolisWidgetView:formatEnergy");
        if (power<1)
        {
        // Less than 1 kWh Present in Wh
            return (power * 1000).toNumber() + " Wh";
        }
        else
        {
            // > more than kWh, so present in in kWh
            return power.format("%.1f") + " kWh";
        }
    }

    function processResponseCode(responseCode,data){
        //System.println("SolisWidgetView:processResponseCode");

        // Turn off refreshpage
        ShowRefreshing=false;
        ShowError=false;
        //System.println(responseCode);
        //System.println(data);

        if (responseCode==200)
        {
            // Make sure no error is shown
            ShowError=false;
            resultCode = data["result"].toString();
            if(resultCode.toNumber() != 1)
            {
                // Reset values to reinitiate login
                ShowError=true;
                uid = "";
                plantid = "";
                Application.getApp().setProperty("PROP_UID","");
                Application.getApp().setProperty("PROP_PLANTID","");

                Errortext1="API Error: "+ data["result"];
                Errortext2=WatchUi.loadResource(Rez.Strings.INVALIDSETTINGSTEXT1);
                Errortext3=WatchUi.loadResource(Rez.Strings.INVALIDSETTINGSTEXT2);
                Errortext4=WatchUi.loadResource(Rez.Strings.INVALIDSETTINGSTEXT3);
            }
        }
        else if (responseCode==Communications.BLE_CONNECTION_UNAVAILABLE)
        {
            // bluetooth connection issue
            ShowError = true;
            Errortext1=WatchUi.loadResource(Rez.Strings.NOBLUETOOTHERRORTEXT1);
            Errortext2=WatchUi.loadResource(Rez.Strings.NOBLUETOOTHERRORTEXT2);
            Errortext3=WatchUi.loadResource(Rez.Strings.NOBLUETOOTHERRORTEXT3);
        }
        else if (responseCode==Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE)
        {
            // Invalid API key
            ShowError = true;
            Errortext1=WatchUi.loadResource(Rez.Strings.INVALIDSETTINGSTEXT1);
            Errortext2=WatchUi.loadResource(Rez.Strings.INVALIDSETTINGSTEXT2);
            Errortext3=WatchUi.loadResource(Rez.Strings.INVALIDSETTINGSTEXT3);
        }
        else if (responseCode==Communications.NETWORK_REQUEST_TIMED_OUT )
        {
            // No Internet
            ShowError = true;
            Errortext1=WatchUi.loadResource(Rez.Strings.NOINTERNET1);
            Errortext2=WatchUi.loadResource(Rez.Strings.NOINTERNET2);
            Errortext3=WatchUi.loadResource(Rez.Strings.NOINTERNET3);
        }
        else
        {
            // general Error
            ShowError = true;
            Errortext1="Error "+responseCode;
            Errortext2="Check settings in";
            Errortext3="Garmin Connect or Express";
        }
        WatchUi.requestUpdate();
        return ShowError;
    }

    function formatScreenLines(value1,value2,value3,value4,value5,lines,dc){
        //System.println("SolisWidgetView:formatScreenLines");

        var height = dc.getHeight();
        var lineSpacingLarge = 2;
        var lineSpacingMedium = 2.6;
        var screenDevider = lines - 1;
        var lineOneFont = Graphics.FONT_SYSTEM_LARGE;
        var lineTwoFont = 0;
        var lineThreeFont = 0;
        var lineFourFont = 0;
        var lineFiveFont = 0;
        if(lines == 1 || lines == 2){
            screenDevider = 2;
        }
        if(lines >= 2){
            lineOneFont = Graphics.FONT_SYSTEM_LARGE;
            lineTwoFont = Graphics.FONT_SYSTEM_LARGE;
        }
        if(lines >= 3){
            lineOneFont = Graphics.FONT_SYSTEM_LARGE;
            lineTwoFont = Graphics.FONT_SYSTEM_LARGE;
            lineThreeFont = Graphics.FONT_SMALL;
        }
        if(lines >= 4){
            lineOneFont = Graphics.FONT_SYSTEM_LARGE;
            lineTwoFont = Graphics.FONT_SYSTEM_LARGE;
            lineThreeFont = Graphics.FONT_SMALL;
            lineFourFont  = Graphics.FONT_SMALL;
        }
        if(lines >= 5){
            lineOneFont = Graphics.FONT_MEDIUM;
            lineTwoFont = Graphics.FONT_MEDIUM;
            lineThreeFont = Graphics.FONT_MEDIUM;
            lineFourFont  = Graphics.FONT_MEDIUM;
            lineFiveFont = Graphics.FONT_MEDIUM;
            lineSpacingLarge = 2.6;
        }
        var lineOnePosY = height / screenDevider;
        var lineTwoPosY = lineOnePosY + ((Graphics.getFontHeight(lineOneFont) / lineSpacingMedium) + (Graphics.getFontHeight(lineOneFont) / lineSpacingMedium));
        var lineThreePosY = lineTwoPosY + ((Graphics.getFontHeight(lineTwoFont) / lineSpacingLarge) + (Graphics.getFontHeight(lineTwoFont) / lineSpacingLarge));
        var lineFourPosY = lineThreePosY + ((Graphics.getFontHeight(lineThreeFont) / lineSpacingMedium) + (Graphics.getFontHeight(lineThreeFont) / lineSpacingMedium));
        var lineFivePosY = lineFourPosY + ((Graphics.getFontHeight(lineFourFont) / lineSpacingMedium) + (Graphics.getFontHeight(lineFourFont) / lineSpacingMedium));

        var lineOneValue = value1;
        var lineTwoValue = value2;
        var lineThreeValue = value3;
        var lineFourValue = value4;
        var lineFiveValue = value5;

        dc.drawText(
            dc.getWidth() / 2,
            lineOnePosY,
            lineOneFont,
            lineOneValue,
            Graphics.TEXT_JUSTIFY_CENTER
        );
        if(lines >= 2){
            dc.drawText(
                dc.getWidth() / 2,
                lineTwoPosY,
                lineTwoFont,
                lineTwoValue,
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }
        if(lines >= 3){
            dc.drawText(
                dc.getWidth() / 2,
                lineThreePosY,
                lineThreeFont,
                lineThreeValue,
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }
        if(lines >= 4){
            dc.drawText(
                dc.getWidth() / 2,
                lineFourPosY,
                lineFourFont,
                lineFourValue,
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }
        if(lines >= 5){
            dc.drawText(
                dc.getWidth() / 2,
                lineFivePosY,
                lineFiveFont,
                lineFiveValue,
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }
    }

    function setNotParsable()
    {
        //System.println("SolisWidgetView:setNotParsable");

        // not parsable
        Current = null;
        Today = null;
        ThisMonth = null;
        ThisYear = null;
        Total = null;
        LastUpdate = null;
        lastUpdateLocalized = null;
        lastUpdateTimeLocalized = null;
        lastUpdateDateLocalized = null;
    }

    // function to convert date in string format to moment object
    function DetermineNextUpdateFromLastUpdate()
    {
        //System.println("SolisWidgetView:DetermineNextUpdateFromLastUpdate");

        // There might be a time difference, so only use the number of minutes from the string,
        // and derive the lastupdate time from the current time)

        // Determine minute number from lastupdate string
        var LastUpdateMinute=LastUpdate.substring(14, 16).toNumber();

        // derive offset from GetClockTime object.
        var myTime = System.getClockTime(); // ClockTime object
        var timeZoneOffset = new Time.Moment(myTime.timeZoneOffset);

        // get current time as moment to calculate with
        var CurrentMoment=Time.now().value();

        // correct current hour if 12'o clock sign has passed after last update
        if (myTime.min<LastUpdateMinute)
        {
            // hour has passed, so make sure the we are in the previous hour.
            CurrentMoment=CurrentMoment-Gregorian.SECONDS_PER_HOUR;
        }

        // Create the gregorian info object for the previous update moment (Current time, where minute number is changed to the minute number of the reported last update)
        var gpreviousupdate = Gregorian.info(new Time.Moment(CurrentMoment), Time.FORMAT_MEDIUM);
        gpreviousupdate.min=LastUpdateMinute;

        // Calculate Next Update Moment (=previousupdate+UpdateInterval-offset to correct timezone)
        NextUpdate=moment_from_info(gpreviousupdate).value()+UpdateInterval*Gregorian.SECONDS_PER_MINUTE-myTime.timeZoneOffset;
        return NextUpdate;
    }

    // Handle Command from Delegate view
    function HandleCommand (data)
    {
        //System.println("SolisWidgetView:HandleCommand");

        // update of data requested
        if (data==DOWEBREQUEST)
        {
            //System.println("HandleCommand: makeRequest");
            makeRequest();
        }
    }

    function makeRequest() {
        //System.println("SolisWidgetView:makeRequest");

        forceUpdate = false;
        if(uid.toString().length() <3 ){
            // Show refreshing page
            ShowError=false; // turn off an error screen (if any)
            ShowRefreshing=true; // make sure refreshingscreen is shown when updating the UI.

            if(Username.toString().length == 0 || Password.toString().length == 0){
                ShowError=true;
                Errortext1=WatchUi.loadResource(Rez.Strings.INVALIDSETTINGSTEXT1);
                Errortext2=WatchUi.loadResource(Rez.Strings.APIERRORTEXT2);
                Errortext3=WatchUi.loadResource(Rez.Strings.APIERRORTEXT3);
                Errortext4="";
                WatchUi.requestUpdate();
            }
            else{
                WatchUi.requestUpdate();
                var url = BaseUrl+"/v/ap.2.0/cust/user/login?user_id=" + Username + "&user_pass=" + Password + "&terminate=android&push_sn=11007f002bc2b3ebc16db92898f5d3ea&timezone=1&lan=en&country=CN&cust=006";
                var options = {
                        :method => Communications.HTTP_REQUEST_METHOD_GET,
                        :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
                };

                // only retrieve the settings if they've actually changed

                // Make the authentication request
                //System.println("makeRequest url:"+url);
                //System.println("makeRequest options:"+options);
                Communications.makeWebRequest(url,{},options,method(:onReceive));
            }
        }
        else{
            //Go and check the plantid when the uid is allready set.
            //System.println("makeRequest");
            makeRequestPlantId();
        }
    }

    // Receive the data from the web request
    function onReceive(responseCode, data)
    {
        //System.println("SolisWidgetView:onReceive");
        ShowError = processResponseCode(responseCode,data);

        if(ShowError){
            WatchUi.requestUpdate();
        }
        else{
            uid = data["uid"];
            Application.getApp().setProperty("PROP_UID",uid);
            //System.println(data["uid"]);
            //System.println("uid set:"+uid);
            makeRequestPlantId();
        }
    }

    function makeRequestPlantId() {
        //System.println("SolisWidgetView:makeRequestPlantId");

        if(plantid.toString().length() < 3 ){
            // Show refreshing page
            ShowError=false; // turn off an error screen (if any)
            ShowRefreshing=true; // make sure refreshingscreen is shown when updating the UI.
            //WatchUi.requestUpdate();
            var url = BaseUrl+"/v/ap.2.0/plant/find_plant_list?uid=" + uid.toString() + "&sel_scope=1&sort_type=1";

            var options = {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            };

            // Make the authentication request
            //System.println("makeRequestPlantId url:"+url);
            //System.println("makeRequestPlantId options:"+options);
            Communications.makeWebRequest(url,{},options,method(:onReceivePlantId));
        }
        else{
            //PlantId allready known, go ahead and request data.
            makeRequestPlantOverview();
        }
    }

    function onReceivePlantId(responseCode, data)
    {
        //System.println("SolisWidgetView:onReceivePlantId");

        ShowError = processResponseCode(responseCode,data);
        if(ShowError){
            WatchUi.requestUpdate();
        }
        else{
            ShowError=false;
            plantid = data["list"][0]["plant_id"];
            Application.getApp().setProperty("PROP_PLANTID",plantid);
            //System.println("plantid set:"+plantid);
            makeRequestPlantOverview();
        }
    }

    function makeRequestPlantOverview()
    {
        //System.println("SolisWidgetView:makeRequestPlantOverview");

        // Show refreshing page
        ShowError=false; // turn off an error screen (if any)
        ShowRefreshing=true; // make sure refreshingscreen is shown when updating the UI.
        //WatchUi.requestUpdate();
        //System.println("makeRequest uid:"+uid);
        var url = BaseUrl+"/v/ap.2.0/plant/get_plant_overview?uid=" + uid.toString() + "&plant_id=" + plantid.toString();

        var options = {
                    :method => Communications.HTTP_REQUEST_METHOD_GET,
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        // Make the authentication request
        //System.println("makeRequest url:"+url);
        //System.println("makeRequest options:"+options);
        Communications.makeWebRequest(url,{},options,method(:onReceivePlantOverview));
    }

    function onReceivePlantOverview(responseCode, data)
    {
        //System.println("SolisWidgetView:onReceivePlantOverview");

        ShowError = processResponseCode(responseCode,data);
        if(ShowError){
            WatchUi.requestUpdate();
        }
        else{
            if (data instanceof Dictionary)
            {
                var power = 0.0; // init variable
                // Format Current Power
                power = data["power_out"]["power"].toFloat();
                if (power<1)
                {
                    Current=(power).toNumber() + " W";
                } else {
                    Current=power.format("%.2f") + " W";
                }
                //System.println("current_power: "+power + " Current: "+ Current);

                // Format Today
                power = data["power_out"]["energy_day"].toFloat();
                Today= formatEnergy(power);
                //System.println("today_energy: "+power + " Today :"+Today);

                // Format Total
                power = data["power_out"]["energy_accu_real"].toFloat();
                Total= formatEnergy(power);
                //System.println("total_energy: "+power + " Total: " + Total);

                // Format Last Update
                LastUpdate=data["date"];
                var a = DetermineNextUpdateFromLastUpdate();
                lastUpdateLocalized = formatDateTimeFromRFC3339(LastUpdate);
                lastUpdateTimeLocalized = formatTimeFromRFC3339(LastUpdate);
                lastUpdateDateLocalized = formatDateFromRFC3339(LastUpdate);`
                data = null;
            }
            else
            {
                setNotParsable();
            }
            makeRequestPlantMonthStatistics();
        }
    }

    function makeRequestPlantMonthStatistics()
    {
        //System.println("SolisWidgetView:makeRequestPlantMonthStatistics");

        // Show refreshing page
        ShowError=false; // turn off an error screen (if any)
        ShowRefreshing=true; // make sure refreshingscreen is shown when updating the UI.
        //WatchUi.requestUpdate();
        //System.println("makeRequest uid:"+uid);
        var url = BaseUrl+"/v/ap.2.0/plant/get_plant_powerout_statics_month2?date=" + dateTodayString + "&uid=" + uid.toString() + "&plant_id=" + plantid.toString();

        var options = {
                    :method => Communications.HTTP_REQUEST_METHOD_GET,
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        // Make the authentication request
        //System.println("makeRequest url:"+url);
        //System.println("makeRequest options:"+options);
        Communications.makeWebRequest(url,{},options,method(:onReceivePlantMonthStatistics));
    }

    function onReceivePlantMonthStatistics(responseCode, data)
    {
        //System.println("SolisWidgetView:onReceivePlantMonthStatistics");

        ShowError = processResponseCode(responseCode,data);
        if(ShowError){
            WatchUi.requestUpdate();
        }
        else{
            if (data instanceof Dictionary)
            {
                var list = data["list"];
                var power = 0;
                for(var i=0;i<list.size();i++) {
                    //System.println("day "+ data["list"][i]["month"] +"="+ data["list"][i]["energy"]);
                    power = power + data["list"][i]["energy"];
                }
                ThisMonth= formatEnergy(power);
                //System.println("ThisMonth: " + ThisMonth);
                data = null;
            }
            else {
                setNotParsable();
            }
            makeRequestPlantYearStatistics();
        }
    }

    function makeRequestPlantYearStatistics()
    {
        //System.println("SolisWidgetView:makeRequestPlantYearStatistics");

        // Show refreshing page
        ShowError=false; // turn off an error screen (if any)
        ShowRefreshing=true; // make sure refreshingscreen is shown when updating the UI.
        //WatchUi.requestUpdate();
        //System.println("makeRequest uid:"+uid);
        var url = BaseUrl+"/v/ap.2.0/plant/get_plant_powerout_statics_year?date=" + dateTodayString + "&uid=" + uid.toString() + "&plant_id=" + plantid.toString();

        var options = {
                    :method => Communications.HTTP_REQUEST_METHOD_GET,
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        // Make the authentication request
        //System.println("makeRequest url:"+url);
        //System.println("makeRequest options:"+options);
        Communications.makeWebRequest(url,{},options,method(:onReceivePlantYearStatistics));
    }

    function onReceivePlantYearStatistics(responseCode, data)
    {
        //System.println("SolisWidgetView:onReceivePlantYearStatistics");

        ShowError = processResponseCode(responseCode, data);
        if(ShowError){
            WatchUi.requestUpdate();
        }
        else{
            if (data instanceof Dictionary)
            {
                var list = data["list"];
                var power = 0;
                for(var i=0;i<list.size();i++) {
                    //System.println("year "+ data["list"][i]["year"] +"="+ data["list"][i]["energy"]);
                    power = power + data["list"][i]["energy"];
                }

                ThisYear= formatEnergy(power);
                //System.println("yearly_energy: "+power + " ThisYear: " + ThisYear);
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
        //System.println("SolisWidgetView:onLayout");

        setLayout(Rez.Layouts.MainLayout(dc));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
        //System.println("SolisWidgetView:onShow");

        //  Load saved data
        Current = Application.getApp().getProperty("Current");
        Today = Application.getApp().getProperty("Today");
        ThisMonth = Application.getApp().getProperty("ThisMonth");
        ThisYear = Application.getApp().getProperty("ThisYear");
        Total = Application.getApp().getProperty("Total");
        LastUpdate= Application.getApp().getProperty("LastUpdate");
        NextUpdate = Application.getApp().getProperty("NextUpdate");
        lastUpdateLocalized = Application.getApp().getProperty("LastUpdateLocalized");
        lastUpdateTimeLocalized = Application.getApp().getProperty("lastUpdateTimeLocalized");
        lastUpdateDateLocalized = Application.getApp().getProperty("lastUpdateDateLocalized");

        // Check if autoupdate is needed
        if (NextUpdate==null) {
            // some kind of error in previous session. Do update
            makeRequest();
        } else {
            // var NextUpdate=ParseDateToMoment(LastUpdate).add(UpdateInterval);
            if (Time.now().greaterThan(new Time.Moment(NextUpdate)))
            {
                makeRequest();
            }
        }
    }

    // Update the view
    function onUpdate(dc) {
        //System.println("SolisWidgetView:onUpdate");

        //System.println("Screen heigth: " + dc.getHeight());
        //System.println("Screen width: " + dc.getWidth());

        if ($.gSettingsChanged) {
            $.gSettingsChanged = false;
            retrieveSettings();
        }

        // Call the parent onUpdate function to redraw the layout
        // View.onUpdate(dc);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        // Draw logo
        //var logowidth = logo.getWidth();
        //var logoPosX = (dc.getWidth() - logowidth) / 2;
        //var logoPosY = (dc.getHeight() - logowidth) / 5;
        ////System.println("logowidth: " + logowidth + " logoHeight: " + logo.getHeight());
        //dc.drawBitmap((dc.getWidth() - logowidth) / 2, logoPosY,logo);

        if (ShowError) {
           // Show Error
            formatScreenLines(
                Errortext1,
                Errortext2,
                Errortext3,
                Errortext4,
                "",
                5,
                dc
            );
        }
        else  if (ShowRefreshing) {
            formatScreenLines(
                WatchUi.loadResource(Rez.Strings.UPDATING),
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
            switch (CurrentPage){
                case 1:
                    // Current Power
                    formatScreenLines(
                        WatchUi.loadResource(Rez.Strings.CURRENT),
                        Current,
                        lastUpdateTimeLocalized,
                        lastUpdateDateLocalized,
                        "",
                        4,
                        dc
                    );
                    glancesName = WatchUi.loadResource(Rez.Strings.CURRENT);
                    glancesValue = Current;
                    break;
                case 2:
                    // Today
                    formatScreenLines(
                        WatchUi.loadResource(Rez.Strings.TODAY),
                        Today,
                        lastUpdateTimeLocalized,
                        lastUpdateDateLocalized,
                        "",
                        4,
                        dc
                    );
                    glancesName = WatchUi.loadResource(Rez.Strings.TODAY);
                    glancesValue = Today;
                    break;
                case 3:
                    // This Month
                    formatScreenLines(
                        WatchUi.loadResource(Rez.Strings.THISMONTH),
                        ThisMonth,
                        lastUpdateTimeLocalized,
                        lastUpdateDateLocalized,
                        "",
                        4,
                        dc
                    );
                    glancesName = WatchUi.loadResource(Rez.Strings.THISMONTH);
                    glancesValue = ThisMonth;
                    break;
                case 4:
                    // This Year
                    formatScreenLines(
                        WatchUi.loadResource(Rez.Strings.THISYEAR),
                        ThisYear,
                        lastUpdateTimeLocalized,
                        lastUpdateDateLocalized,
                        "",
                        4,
                        dc
                    );
                    glancesName = WatchUi.loadResource(Rez.Strings.THISYEAR);
                    glancesValue = ThisYear;
                    break;
                case 5:
                    // Total
                    formatScreenLines(
                        WatchUi.loadResource(Rez.Strings.TOTAL),
                        Total,
                        lastUpdateTimeLocalized,
                        lastUpdateDateLocalized,
                        "",
                        4,
                        dc
                    );
                    glancesName = WatchUi.loadResource(Rez.Strings.TOTAL);
                    glancesValue = Total;
                    break;
                case 6:
                    formatScreenLines(
                        WatchUi.loadResource(Rez.Strings.CURRENT)+": "+Current,
                        WatchUi.loadResource(Rez.Strings.TODAY)+": "+Today,
                        WatchUi.loadResource(Rez.Strings.THISMONTH)+": "+ThisMonth,
                        WatchUi.loadResource(Rez.Strings.THISYEAR)+": "+ThisYear,
                        WatchUi.loadResource(Rez.Strings.TOTAL)+": "+Total,
                        5,
                        dc
                    );
                    break;

                default:
                    formatScreenLines(
                            "Unsupported CurrentPage value: " + CurrentPage,
                            "",
                            "",
                            "",
                            "",
                            1,
                            dc
                        );
                    break;
            }
            //System.println("glancesValue: " + glancesValue + ", glancesName: " + glancesName );

            if(forceUpdate == true){
                //System.println("forceUpdate = " + forceUpdate);
                makeRequest();
            }
        }
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from memory.
    function onHide() {
        //System.println("SolisWidgetView:onHide");

        // Save data for later
        Application.getApp().setProperty("Current",Current);
        Application.getApp().setProperty("Today", Today);
        Application.getApp().setProperty("ThisMonth", ThisMonth);
        Application.getApp().setProperty("ThisYear", ThisYear);
        Application.getApp().setProperty("Total",Total);
        Application.getApp().setProperty("LastUpdate", LastUpdate);
        Application.getApp().setProperty("NextUpdate", NextUpdate);
        Application.getApp().setProperty("LastUpdateLocalized", lastUpdateLocalized);
        Application.getApp().setProperty("lastUpdateTimeLocalized", lastUpdateTimeLocalized);
        Application.getApp().setProperty("lastUpdateDateLocalized", lastUpdateDateLocalized);
        Application.getApp().setProperty("glancesName", glancesName);
        Application.getApp().setProperty("glancesValue", glancesValue);
    }
}