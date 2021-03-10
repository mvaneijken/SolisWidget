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
var BaseUrl = "https://api.omnikportal.com/v1"; //Source: https://github.com/jbouwh/omnikdatalogger
var appid = "10038"; //Source: https://github.com/jbouwh/omnikdatalogger
var appkey = "Ox7yu3Eivicheinguth9ef9kohngo9oo"; //Source: https://github.com/jbouwh/omnikdatalogger
var uid = ""; //c_user_id variable received when authenticating to the API
var plantid = ""; //plant_id variable received when retrieving the plants. 
var glancesName = "";
var glancesValue = "";
var forceUpdate = false; 

// Settings
var CurrentPage; 
var Username = "-";
var Password = "-";

// Constants
var UpdateInterval=5; // in Minutes

function NextPage()
{
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
	WatchUi.requestUpdate();
	forceUpdate = true;
} 

class OmnikWidgetView extends WatchUi.View {
    
    function initialize() {
		System.println("getDevicePartNumber: " + getDevicePartNumber());
        retrieveSettings();  
        View.initialize();
        
        var omnikicon = WatchUi.loadResource(Rez.Drawables.omnikicon);
        System.println("icon imagewidth: " + omnikicon.getHeight() + " imageHeight: " + omnikicon.getWidth());
    }
    
	function getDevicePartNumber() {
		var deviceSettings = System.getDeviceSettings();
		// device part numbers come from ${SDKROOT}/bin/devices.xml
		var partNumber = deviceSettings.partNumber;
		return partNumber;
	}

	function retrieveSettings() {
      	// Get Username From settings
		Username = Application.getApp().getProperty("PROP_USERNAME");
		System.println("Username: " + Username);

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
		System.println(string.toString());
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
		System.println(string.toString());
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
		System.println(string.toString());
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
		var DateText = info.year+"-"+info.month+"-"+info.day+" "+info.hour+":"+info.min+":"+info.sec;
		return DateText;
	}
	
	function StringFromMoment(moment)
	{
		var info=Gregorian.info(moment,Time.FORMAT_MEDIUM);
		return StringFromInfo(info);
	}
		
    // function to convert date in string format to moment object
	function DetermineNextUpdateFromLastUpdate() 
	{
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
        // update of data requested
        if (data==DOWEBREQUEST) 
        {
            makeRequest();
        }
    }
    
	function makeRequest() {
		System.println("makeRequest");
		System.println("makeRequest uid:"+uid);
    
		forceUpdate = false;
		if(uid.toString().length() <3 ){
			// Show refreshing page
			ShowError=false; // turn off an error screen (if any)
			ShowRefreshing=true; // make sure refreshingscreen is shown when updating the UI.
			WatchUi.requestUpdate();
			var url = BaseUrl+"/user/account_validate";
			var options = {                                           
					:method => Communications.HTTP_REQUEST_METHOD_POST,      
					:headers => {                                           
							"Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED,
							"uid" => "-1",
							"appid" => appid.toString(),
							"appkey" => appkey.toString()
					},
					:responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
			};
			
			// only retrieve the settings if they've actually changed
			// Get Username From settings
			var params = {                                              // set the parameters
					"user_email" => Username,
					"user_password" => Password,
					"user_type" => 1
				};
			
			// Make the authentication request
			System.println("makeRequest url:"+url);
			System.println("makeRequest params:"+params);
			System.println("makeRequest options:"+options);
			Communications.makeWebRequest(url,params,options,method(:onReceive));	
		}
		else{
			//Go and check the plantid when the uid is allready set.
			System.println("makeRequest");
			makeRequestPlantId();
		}
    }

    // Receive the data from the web request
	function onReceive(responseCode, data) 
	{
		System.println("onReceive");
	
		// Turn off refreshpage
		ShowRefreshing=false;
		System.println(responseCode);
		System.println(data);
			
		// Check responsecode
		if (responseCode==200)
		{
			// Make sure no error is shown	
			ShowError=false;
			if(data["error_msg"].length() > 0)
			{
				// Reset values to reinitiate login
				ShowError=true;
				uid = "";
				plantid = "";
				Application.getApp().setProperty("PROP_UID","");
				Application.getApp().setProperty("PROP_PLANTID","");
			
				Errortext1="API Error:"+ data["error_code"];
				Errortext2=WatchUi.loadResource(Rez.Strings.APIERRORTEXT2);
				Errortext3=WatchUi.loadResource(Rez.Strings.APIERRORTEXT3);
			}
			else 
			{
				ShowError=false;
				uid = data["data"]["c_user_id"];
				Application.getApp().setProperty("PROP_UID",uid);
				System.println(data["data"]["c_user_id"]);
				System.println("uid set:"+uid);
				makeRequestPlantId();
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
			Errortext2="Configure settings in";
			Errortext3="Garmin Connect or Express";
		}
		WatchUi.requestUpdate();
	}
	
	function makeRequestPlantId() {
		System.println("makeRequestPlantId");
    
		if(plantid.toString().length() < 3 ){
	        // Show refreshing page
	        ShowError=false; // turn off an error screen (if any)
	        ShowRefreshing=true; // make sure refreshingscreen is shown when updating the UI.
			WatchUi.requestUpdate();
			var url = BaseUrl+"/plant/list";
			var headers = {
				"Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED,
				"uid" => uid.toString(),
				"appid" => appid.toString(),
				"appkey" => appkey.toString()
			};
			System.println("makeRequestPlantId headers:"+headers);
        
		
			var options = {                                           
				:method => Communications.HTTP_REQUEST_METHOD_GET,      
				:headers => headers,
				:responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
			};

			// Make the authentication request
			System.println("makeRequestPlantId url:"+url);
			System.println("makeRequestPlantId options:"+options);
			Communications.makeWebRequest(url,{},options,method(:onReceivePlantId));	
		}
		else{
			//PlantId allready known, go ahead and request data.
			makeRequestData();
		}
    }
    
	function onReceivePlantId(responseCode, data) 
	{
		System.println("onReceivePlantId ");
	
		// Turn off refreshpage
		ShowRefreshing=false;
		System.println(responseCode);
		System.println(data);
			
		// Check responsecode
		if (responseCode==200)
		{
			// Make sure no error is shown	
			ShowError=false;
			if(data["error_msg"].length() > 0)
			{
				// Reset values to reinitiate login
				ShowError=true;
				uid = "";
				plantid = "";
				Application.getApp().setProperty("PROP_UID","");
				Application.getApp().setProperty("PROP_PLANTID","");
			
				Errortext1="Error:"+ data["error_code"] + ", " + data["error_msg"];
				Errortext2="If needed check Omnik credentials in";
				Errortext3="Garmin Connect or Express";
			}
			else 
			{
				ShowError=false;
				plantid = data["data"]["plants"][0]["plant_id"];
				Application.getApp().setProperty("PROP_PLANTID",plantid);
				System.println("plantid set:"+plantid);
				makeRequestData();
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
			Errortext2="Configure settings in";
			Errortext3="Garmin Connect or Express";
		}
		WatchUi.requestUpdate();
	}    
    
    function makeRequestData() 
	{
		System.println("makeRequestData");
    
        // Show refreshing page
        ShowError=false; // turn off an error screen (if any)
        ShowRefreshing=true; // make sure refreshingscreen is shown when updating the UI.
        WatchUi.requestUpdate();
        System.println("makeRequest uid:"+uid);
		var url = BaseUrl+"/plant/data?plant_id="+plantid;
		var headers = {
			"Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED,
			"uid" => uid.toString(),
			"appid" => appid.toString(),
			"appkey" => appkey.toString()
		};
        System.println("makeRequestData headers:"+headers);
		
		var options = {                                           
				:method => Communications.HTTP_REQUEST_METHOD_GET,      
				:headers => headers,
				:responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
		};

		// Make the authentication request
		System.println("makeRequestData url:"+url);
		System.println("makeRequestData options:"+options);
		Communications.makeWebRequest(url,{},options,method(:onReceiveData));	
    }
    
    function onReceiveData(responseCode, data) 
	{
		System.println("onReceiveData");
	
		// Turn off refreshpage
		ShowRefreshing=false;
		System.println(responseCode);
		System.println(data);
		//System.println(data["data"]["c_user_id"]);
		//System.println(data["error_msg"].length());
			
		// Check responsecode
		if (responseCode==200)
		{
			// Make sure no error is shown	
			ShowError=false;
			if(data["error_msg"].length() > 0)
			{
				// Reset values to reinitiate login
				ShowError=true;
				uid = "";
				plantid = "";
				Application.getApp().setProperty("PROP_UID","");
				Application.getApp().setProperty("PROP_PLANTID","");
			
				Errortext1="Error:"+ data["error_code"] + ", " + data["error_msg"];
				Errortext2="If needed check Omnik credentials in";
				Errortext3="Garmin Connect or Express";
			}
			else
			{
				ShowError=false;
				if (data instanceof Dictionary) 
				{
					var power=0.0; // init variable
					
					// Format Current Power
					power = data["data"]["current_power"].toFloat();
					if (power<1)
					{
						Current=(power * 1000).toNumber() + " W";
					} else {
						Current=power.format("%.2f") + " kW";
					}
					System.println("current_power: "+power + " Current: "+ Current); 
					
					// Format Today
					power = data["data"]["today_energy"].toFloat();
					if (power<1) 
					{
						// Less than 1 kWh Present in Wh
						Today=(power * 1000).toNumber() + " Wh";
					} 
					else 
					{
						// > more than kWh, so present in in kWh
						// Current=Lang.format("$1$ kWh",power/1000);
						Today = power.format("%.2f") + " kWh";
					}
					System.println("today_energy: "+power + " Today :"+Today);   
					
					// Format This Month
					power = data["data"]["monthly_energy"].toFloat();
					if (power<1) 
					{
						// Less than 1 kWh Present in Wh
						ThisMonth=(power * 1000).toNumber() + " Wh";
					} 
					else 
					{
						// > more than kWh, so present in in kWh
						// Current=Lang.format("$1$ kWh",power/1000);
						ThisMonth= power.format("%.1f") + " kWh";
					}
					System.println("monthly_energy: "+power + " ThisMonth: " + ThisMonth);   
					
					// Format This Year
					power = data["data"]["yearly_energy"].toFloat();
					if (power<1) 
					{
						// Less than 1 kWh Present in Wh
						ThisYear=(power * 1000).toNumber() + " Wh";
					} 
					else if (power<1000) 
					{
						// > more than kWh, so present in in kWh
						ThisYear= power.format("%.1f") + " kWh";
					} 
					else 
					{
						ThisYear= (power/1000).format("%.2f") + " MWh";
					}
					System.println("yearly_energy: "+power + " ThisYear: " + ThisYear);
		
					// Format Total
					power = data["data"]["total_energy"].toFloat();
					if (power<1) 
					{
						// Less than 1 kWh Present in Wh
						Total=(power * 1000).toNumber() + " Wh";
					} 
					else if (power<1000) 
					{
						// > more than kWh, so present in in kWh
						Total= power.format("%.1f") + " kWh";
					} 
					else 
					{
						Total= (power/1000).format("%.2f") + " MWh";
					}
					System.println("total_energy: "+power + " Total: " + Total);
					
					// Format Last Update
					LastUpdate=data["data"]["last_update_time"]; 
					var a = DetermineNextUpdateFromLastUpdate();
					lastUpdateLocalized = formatDateTimeFromRFC3339(LastUpdate);
					lastUpdateTimeLocalized = formatTimeFromRFC3339(LastUpdate);
					lastUpdateDateLocalized = formatDateFromRFC3339(LastUpdate);
				} 
				else 
				{
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
	}

	// Load your resources here
	function onLayout(dc) {
		setLayout(Rez.Layouts.MainLayout(dc));
	}

	// Called when this View is brought to the foreground. Restore
	// the state of this View and prepare it to be shown. This includes
	// loading resources into memory.
	function onShow() {
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
		System.println("Screen heigth: " + dc.getHeight());
		System.println("Screen width: " + dc.getWidth());
    
        if ($.gSettingsChanged) {
			$.gSettingsChanged = false;
			retrieveSettings();
		}

        // Call the parent onUpdate function to redraw the layout
        // View.onUpdate(dc);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

		var fontSmall = Graphics.FONT_SMALL;
		var fontMedium = Graphics.FONT_MEDIUM;
		var fontLarge = Graphics.FONT_SYSTEM_LARGE;
		var fontHot = Graphics.FONT_SYSTEM_NUMBER_HOT;
		var fontSmallHeight = Graphics.getFontHeight(fontSmall);
		var fontMediumHeight = Graphics.getFontHeight(fontMedium);
		var fontLargeHeight = Graphics.getFontHeight(fontLarge);
		var fontHotHeight = Graphics.getFontHeight(fontHot);
		var height = dc.getHeight();
		var lineOnePosY = height / 3; 
		var lineTwoPosY = lineOnePosY + ((fontLargeHeight/2.6) + (fontLargeHeight/2.6));
		var lineThreePosY = lineTwoPosY + ((fontLargeHeight/2.6) + (fontSmallHeight/2.6));
		var lineFourPosY = 0;
		var lineFivePosY= 0;
		var lineOneValue;
		var lineTwoValue;
		var lineThreeValue;
		var lineFourValue;
		var lineFiveValue;
        
        // Draw logo
        var image = WatchUi.loadResource(Rez.Drawables.omniklogo);
        var imagewidth = image.getWidth();
        System.println("imagewidth: " + imagewidth + " imageHeight: " + image.getHeight());
        var imagePosX = (dc.getWidth() - imagewidth)/2;
        var imagePosY = (dc.getHeight() - imagewidth)/5;
		dc.drawBitmap((dc.getWidth() - imagewidth)/2,imagePosY,image);

        if (ShowError) {
           // Show Error
				lineOnePosY = height / 3; 
				lineTwoPosY = lineOnePosY + ((fontLargeHeight/2.6) + (fontLargeHeight/2.6));
				lineThreePosY = lineTwoPosY + ((fontSmallHeight/2.6) + (fontSmallHeight/2.6));
				lineOneValue = Errortext1;
				lineTwoValue = Errortext2;
				lineThreeValue = Errortext3;
				dc.drawText(dc.getWidth()/2,lineOnePosY,fontMedium,lineOneValue,Graphics.TEXT_JUSTIFY_CENTER);
				dc.drawText(dc.getWidth()/2,lineTwoPosY,fontMedium,lineTwoValue,Graphics.TEXT_JUSTIFY_CENTER);
				dc.drawText(dc.getWidth()/2,lineThreePosY,fontMedium,lineThreeValue,Graphics.TEXT_JUSTIFY_CENTER);
		} 
		else  if (ShowRefreshing) {
				lineOnePosY = height / 2;
				lineOneValue = WatchUi.loadResource(Rez.Strings.UPDATING);
				dc.drawText(dc.getWidth()/2,lineOnePosY,fontLarge,lineOneValue,Graphics.TEXT_JUSTIFY_CENTER);
        } 
		else {
			// Show status page
			if (CurrentPage==1) {
				// Current Power
				lineOnePosY = height / 3; 
				lineTwoPosY = lineOnePosY + ((fontLargeHeight/2.6) + (fontLargeHeight/2.6));
				lineThreePosY = lineTwoPosY + ((fontLargeHeight/2) + (fontLargeHeight/2));
				lineFourPosY = lineThreePosY + ((fontSmallHeight/2.6) + (fontSmallHeight/2.6));
				lineOneValue = WatchUi.loadResource(Rez.Strings.CURRENT);
				lineTwoValue = Current;
				lineThreeValue = lastUpdateTimeLocalized;
				lineFourValue = lastUpdateDateLocalized;					
				dc.drawText(dc.getWidth()/2,lineOnePosY,fontLarge,lineOneValue,Graphics.TEXT_JUSTIFY_CENTER);
				dc.drawText(dc.getWidth()/2,lineTwoPosY,fontLarge,lineTwoValue,Graphics.TEXT_JUSTIFY_CENTER);
				dc.drawText(dc.getWidth()/2,lineThreePosY,fontSmall,lineThreeValue,Graphics.TEXT_JUSTIFY_CENTER);
				dc.drawText(dc.getWidth()/2,lineFourPosY,fontSmall,lineFourValue,Graphics.TEXT_JUSTIFY_CENTER);
				glancesName =  lineOneValue;
				glancesValue = lineTwoValue;
			} 
			else if (CurrentPage==2) {
				// Today
				lineOnePosY = height / 3; 
				lineTwoPosY = lineOnePosY + ((fontLargeHeight/2.6) + (fontLargeHeight/2.6));
				lineThreePosY = lineTwoPosY + ((fontLargeHeight/2) + (fontLargeHeight/2));
				lineFourPosY = lineThreePosY + ((fontSmallHeight/2.6) + (fontSmallHeight/2.6));				
				lineOneValue = WatchUi.loadResource(Rez.Strings.TODAY);
				lineTwoValue = Today;
				lineThreeValue = lastUpdateTimeLocalized;
				lineFourValue = lastUpdateDateLocalized;					
				dc.drawText(dc.getWidth()/2,lineOnePosY,fontLarge,lineOneValue,Graphics.TEXT_JUSTIFY_CENTER);
				dc.drawText(dc.getWidth()/2,lineTwoPosY,fontLarge,lineTwoValue,Graphics.TEXT_JUSTIFY_CENTER);
				dc.drawText(dc.getWidth()/2,lineThreePosY,fontSmall,lineThreeValue,Graphics.TEXT_JUSTIFY_CENTER);
				dc.drawText(dc.getWidth()/2,lineFourPosY,fontSmall,lineFourValue,Graphics.TEXT_JUSTIFY_CENTER);
				glancesName =  lineOneValue;
				glancesValue = lineTwoValue;
			} 
			else if (CurrentPage==3) {
				//  this Week
				lineOnePosY = height / 3; 
				lineTwoPosY = lineOnePosY + ((fontLargeHeight/2.6) + (fontLargeHeight/2.6));
				lineThreePosY = lineTwoPosY + ((fontLargeHeight/2) + (fontLargeHeight/2));
				lineFourPosY = lineThreePosY + ((fontSmallHeight/2.6) + (fontSmallHeight/2.6));				
				lineOneValue = WatchUi.loadResource(Rez.Strings.THISMONTH);
				lineTwoValue = ThisMonth;
				lineThreeValue = lastUpdateTimeLocalized;
				lineFourValue = lastUpdateDateLocalized;					
				dc.drawText(dc.getWidth()/2,lineOnePosY,fontLarge,lineOneValue,Graphics.TEXT_JUSTIFY_CENTER);
				dc.drawText(dc.getWidth()/2,lineTwoPosY,fontLarge,lineTwoValue,Graphics.TEXT_JUSTIFY_CENTER);
				dc.drawText(dc.getWidth()/2,lineThreePosY,fontSmall,lineThreeValue,Graphics.TEXT_JUSTIFY_CENTER);
				dc.drawText(dc.getWidth()/2,lineFourPosY,fontSmall,lineFourValue,Graphics.TEXT_JUSTIFY_CENTER);
				glancesName =  lineOneValue;
				glancesValue = lineTwoValue;	    	    
			} 
			else if (CurrentPage==4) {
				// This Month
				lineOnePosY = height / 3; 
				lineTwoPosY = lineOnePosY + ((fontLargeHeight/2.6) + (fontLargeHeight/2.6));
				lineThreePosY = lineTwoPosY + ((fontLargeHeight/2) + (fontLargeHeight/2));
				lineFourPosY = lineThreePosY + ((fontSmallHeight/2.6) + (fontSmallHeight/2.6));
				lineOneValue = WatchUi.loadResource(Rez.Strings.THISYEAR);
				lineTwoValue = ThisYear;
				lineThreeValue = lastUpdateTimeLocalized;
				lineFourValue = lastUpdateDateLocalized;					
				dc.drawText(dc.getWidth()/2,lineOnePosY,fontLarge,lineOneValue,Graphics.TEXT_JUSTIFY_CENTER);
				dc.drawText(dc.getWidth()/2,lineTwoPosY,fontLarge,lineTwoValue,Graphics.TEXT_JUSTIFY_CENTER);
				dc.drawText(dc.getWidth()/2,lineThreePosY,fontSmall,lineThreeValue,Graphics.TEXT_JUSTIFY_CENTER);
				dc.drawText(dc.getWidth()/2,lineFourPosY,fontSmall,lineFourValue,Graphics.TEXT_JUSTIFY_CENTER);
				glancesName =  lineOneValue;
				glancesValue = lineTwoValue;    	    
			} 
			else if (CurrentPage==5) {
				// Total
				lineOnePosY = height / 3; 
				lineTwoPosY = lineOnePosY + ((fontLargeHeight/2.6) + (fontLargeHeight/2.6));
				lineThreePosY = lineTwoPosY + ((fontLargeHeight/2) + (fontLargeHeight/2));
				lineFourPosY = lineThreePosY + ((fontSmallHeight/2.6) + (fontSmallHeight/2.6));				
				lineOneValue = WatchUi.loadResource(Rez.Strings.TOTAL);
				lineTwoValue = Total;
				lineThreeValue = lastUpdateTimeLocalized;
				lineFourValue = lastUpdateDateLocalized;					
				dc.drawText(dc.getWidth()/2,lineOnePosY,fontLarge,lineOneValue,Graphics.TEXT_JUSTIFY_CENTER);
				dc.drawText(dc.getWidth()/2,lineTwoPosY,fontLarge,lineTwoValue,Graphics.TEXT_JUSTIFY_CENTER);
				dc.drawText(dc.getWidth()/2,lineThreePosY,fontSmall,lineThreeValue,Graphics.TEXT_JUSTIFY_CENTER);
				dc.drawText(dc.getWidth()/2,lineFourPosY,fontSmall,lineFourValue,Graphics.TEXT_JUSTIFY_CENTER);	    	    
				glancesName =  lineOneValue;
				glancesValue = lineTwoValue;    	    
			} 
			else if (CurrentPage==6) {
				lineOnePosY = height / 4; 
				lineTwoPosY = lineOnePosY + ((fontMediumHeight/2.6) + (fontMediumHeight/2.6));
				lineThreePosY = lineTwoPosY + ((fontMediumHeight/2.6) + (fontMediumHeight/2.6));
				lineFourPosY = lineThreePosY + ((fontMediumHeight/2.6) + (fontMediumHeight/2.6));
				lineFivePosY = lineFourPosY + ((fontMediumHeight/2.6) + (fontMediumHeight/2.6)); 
				lineOneValue = WatchUi.loadResource(Rez.Strings.CURRENT)+": "+Current;
				lineTwoValue = WatchUi.loadResource(Rez.Strings.TODAY)+": "+Today;
				lineThreeValue = WatchUi.loadResource(Rez.Strings.THISMONTH)+": "+ThisMonth;
				lineFourValue = WatchUi.loadResource(Rez.Strings.THISYEAR)+": "+ThisYear;	
				lineFiveValue = WatchUi.loadResource(Rez.Strings.TOTAL)+": "+Total;			    	    
				
				dc.drawText(dc.getWidth()/2, lineOnePosY, fontMedium, lineOneValue, Graphics.TEXT_JUSTIFY_CENTER);
				dc.drawText(dc.getWidth()/2, lineTwoPosY, fontMedium, lineTwoValue, Graphics.TEXT_JUSTIFY_CENTER);
				dc.drawText(dc.getWidth()/2, lineThreePosY, fontMedium, lineThreeValue, Graphics.TEXT_JUSTIFY_CENTER);
				dc.drawText(dc.getWidth()/2, lineFourPosY, fontMedium, lineFourValue, Graphics.TEXT_JUSTIFY_CENTER);
				dc.drawText(dc.getWidth()/2, lineFivePosY, fontMedium, lineFiveValue, Graphics.TEXT_JUSTIFY_CENTER);
			}
			System.println("glancesValue: " + glancesValue + ", glancesName: " + glancesName );
			
			if(forceUpdate == true){
				System.println("forceUpdate = " + forceUpdate);
				makeRequest();
			}
		}
	}

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from memory.
    function onHide() {
    
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