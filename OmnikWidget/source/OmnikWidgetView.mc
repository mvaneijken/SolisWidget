using Toybox.WatchUi as Ui;
using Toybox.Application as App;
using Toybox.Lang as Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Communications as Comm;
using Toybox.System as Sys;


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
var LastUpdate;
var NextUpdate;
var BaseUrl = "https://api.omnikportal.com/v1"; //Source: https://github.com/jbouwh/omnikdatalogger
var appid = "10038"; //Source: https://github.com/jbouwh/omnikdatalogger
var appkey = "Ox7yu3Eivicheinguth9ef9kohngo9oo"; //Source: https://github.com/jbouwh/omnikdatalogger
var uid = ""; //c_user_id variable received when authenticating to the API
var plantid = ""; //plant_id variable received when retrieving the plants. 

// Settings
var CurrentPage; 
var Username;
var Password;

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
   Ui.requestUpdate();
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
   Ui.requestUpdate();
} 

class OmnikWidgetView extends Ui.View {
    
    function initialize() {
    	Sys.println("getDevicePartNumber: " + getDevicePartNumber());
        retrieveSettings();  
        View.initialize();
    }
    
	function getDevicePartNumber() {
		var deviceSettings = Sys.getDeviceSettings();
		// device part numbers come from ${SDKROOT}/bin/devices.xml
		var partNumber = deviceSettings.partNumber;
		return partNumber;
	}

   function retrieveSettings() {
      // Get Username From settings
	    Username = App.getApp().getProperty("PROP_USERNAME");
	    Sys.println("Username: "+ Username);

	    // Get Password from Settings
	    Password = App.getApp().getProperty("PROP_PASSWORD");		

	    
	    // Get Current Page From settings
    	CurrentPage=App.getApp().getProperty("PROP_STARTPAGE");

		// Get the UID
		uid=App.getApp().getProperty("PROP_UID");
		
		// Get the plantid
		plantid=App.getApp().getProperty("PROP_PLANTID");

	}
	
	function formatTimeStampRFC3339 (string)
	{
		Sys.println(string.toString());
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
    	// and derive the lastupdate time from the current time (which is alway max 15 mins away i))
    	
    	// Determin minute number from lastupdate string
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
    	
    	// Calculate Next Update Moment (=previousupdate+15mins-offset to correct timezone)
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
		Sys.println("makeRequest");
		Sys.println("makeRequest uid:"+uid);
    
    	if(uid.toString().length() <3 ){
	        // Show refreshing page
	        ShowError=false; // turn off an error screen (if any)
	        ShowRefreshing=true; // make sure refreshingscreen is shown when updating the UI.
	        Ui.requestUpdate();
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
			Sys.println("makeRequest url:"+url);
			Sys.println("makeRequest params:"+params);
			Sys.println("makeRequest options:"+options);
			Comm.makeWebRequest(url,params,options,method(:onReceive));	
		}
		else{
			//Go and check the plantid when the uid is allready set.
			Sys.println("makeRequest");
			makeRequestPlantId();
		}
    }
      
    // Receive the data from the web request
	function onReceive(responseCode, data) 
	{
		Sys.println("onReceive");
	
		// Turn of refreshpage
		ShowRefreshing=false;
		Sys.println(responseCode);
		Sys.println(data);
		Sys.println(data["data"]["c_user_id"]);
		//Sys.println(data["error_msg"].length());
			
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
				App.getApp().setProperty("PROP_UID","");
				App.getApp().setProperty("PROP_PLANTID","");
			
				Errortext1="Error:"+ data["error_code"] + ", " + data["error_msg"];
				Errortext2="If needed check Omnik credentials in";
				Errortext3="Garmin Connect or Express";
			}
			else 
			{
				ShowError=false;
				uid = data["data"]["c_user_id"];
				App.getApp().setProperty("PROP_UID",uid);
				Sys.println("uid set:"+uid);
				makeRequestPlantId();
			}
			
		} 
		else if (responseCode==Comm.BLE_CONNECTION_UNAVAILABLE) 
		{
			// bluetooth not connected
			ShowError = true;
			Errortext1=Ui.loadResource(Rez.Strings.NOBLUETOOTHERRORTEXT1);
			Errortext2=Ui.loadResource(Rez.Strings.NOBLUETOOTHERRORTEXT2);
			Errortext3=Ui.loadResource(Rez.Strings.NOBLUETOOTHERRORTEXT3);
		} 
		else if (responseCode==Comm.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE) 
		{
			// Invalid API key
			ShowError = true;
			Errortext1=Ui.loadResource(Rez.Strings.INVALIDSETTINGSTEXT1);
			Errortext2=Ui.loadResource(Rez.Strings.INVALIDSETTINGSTEXT2);
			Errortext3=Ui.loadResource(Rez.Strings.INVALIDSETTINGSTEXT3);		 
		} 
		else if (responseCode==Comm.NETWORK_REQUEST_TIMED_OUT ) 
		{
			// No Internet
			ShowError = true;
			Errortext1=Ui.loadResource(Rez.Strings.NOINTERNET1);
			Errortext2=Ui.loadResource(Rez.Strings.NOINTERNET2);
			Errortext3=Ui.loadResource(Rez.Strings.NOINTERNET3);       				 
		} 
		else 
		{
			// general Error
			ShowError = true;
			Errortext1="Error "+responseCode;
			Errortext2="Configure settings in";
			Errortext3="Garmin Connect or Express";
		}
		Ui.requestUpdate();
	}
	
	function makeRequestPlantId() {
		Sys.println("makeRequestPlantId");
    
    	if(plantid.toString().length() < 3 ){
	        // Show refreshing page
	        ShowError=false; // turn off an error screen (if any)
	        ShowRefreshing=true; // make sure refreshingscreen is shown when updating the UI.
	        Ui.requestUpdate();
			var url = BaseUrl+"/plant/list";
			var headers = {
				"Content-Type" => Comm.REQUEST_CONTENT_TYPE_URL_ENCODED,
				"uid" => uid.toString(),
				"appid" => appid.toString(),
				"appkey" => appkey.toString()
			};
        	Sys.println("makeRequestPlantId headers:"+headers);
        
		
			var options = {                                           
				:method => Communications.HTTP_REQUEST_METHOD_GET,      
				:headers => headers,
				:responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
			};
	       	
			// Make the authentication request
			Sys.println("makeRequestPlantId url:"+url);
			Sys.println("makeRequestPlantId options:"+options);
			Comm.makeWebRequest(url,{},options,method(:onReceivePlantId));	
		}
		else{
			//PlantId allready known, go ahead and request data.
			makeRequestData();
		}
    }
    
	function onReceivePlantId(responseCode, data) 
	{
		Sys.println("onReceivePlantId ");
	
		// Turn of refreshpage
		ShowRefreshing=false;
		Sys.println(responseCode);
		Sys.println(data);
			
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
				App.getApp().setProperty("PROP_UID","");
				App.getApp().setProperty("PROP_PLANTID","");
			
				Errortext1="Error:"+ data["error_code"] + ", " + data["error_msg"];
				Errortext2="If needed check Omnik credentials in";
				Errortext3="Garmin Connect or Express";
			}
			else 
			{
				ShowError=false;
				plantid = data["data"]["plants"][0]["plant_id"];
				App.getApp().setProperty("PROP_PLANTID",plantid);
				Sys.println("plantid set:"+plantid);
				makeRequestData();
			}
			
		} 
		else if (responseCode==Comm.BLE_CONNECTION_UNAVAILABLE) 
		{
			// bluetooth not connected
			ShowError = true;
			Errortext1=Ui.loadResource(Rez.Strings.NOBLUETOOTHERRORTEXT1);
			Errortext2=Ui.loadResource(Rez.Strings.NOBLUETOOTHERRORTEXT2);
			Errortext3=Ui.loadResource(Rez.Strings.NOBLUETOOTHERRORTEXT3);
		} 
		else if (responseCode==Comm.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE) 
		{
			// Invalid API key
			ShowError = true;
			Errortext1=Ui.loadResource(Rez.Strings.INVALIDSETTINGSTEXT1);
			Errortext2=Ui.loadResource(Rez.Strings.INVALIDSETTINGSTEXT2);
			Errortext3=Ui.loadResource(Rez.Strings.INVALIDSETTINGSTEXT3);		 
		} 
		else if (responseCode==Comm.NETWORK_REQUEST_TIMED_OUT ) 
		{
			// No Internet
			ShowError = true;
			Errortext1=Ui.loadResource(Rez.Strings.NOINTERNET1);
			Errortext2=Ui.loadResource(Rez.Strings.NOINTERNET2);
			Errortext3=Ui.loadResource(Rez.Strings.NOINTERNET3);       				 
		} 
		else 
		{
			// general Error
			ShowError = true;
			Errortext1="Error "+responseCode;
			Errortext2="Configure settings in";
			Errortext3="Garmin Connect or Express";
		}
		Ui.requestUpdate();
	}    
    
    function makeRequestData() 
	{
		Sys.println("makeRequestData");
    
        // Show refreshing page
        ShowError=false; // turn off an error screen (if any)
        ShowRefreshing=true; // make sure refreshingscreen is shown when updating the UI.
        Ui.requestUpdate();
        Sys.println("makeRequest uid:"+uid);
		var url = BaseUrl+"/plant/data?plant_id="+plantid;
		var headers = {
			"Content-Type" => Comm.REQUEST_CONTENT_TYPE_URL_ENCODED,
			"uid" => uid.toString(),
			"appid" => appid.toString(),
			"appkey" => appkey.toString()
		};
        Sys.println("makeRequestData headers:"+headers);
        
		
		var options = {                                           
				:method => Communications.HTTP_REQUEST_METHOD_GET,      
				:headers => headers,
				:responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
		};
       						
		// Make the authentication request
		Sys.println("makeRequestData url:"+url);
		Sys.println("makeRequestData options:"+options);
		Comm.makeWebRequest(url,{},options,method(:onReceiveData));	
    }
    
    function onReceiveData(responseCode, data) 
	{
		Sys.println("onReceiveData");
	
		// Turn of refreshpage
		ShowRefreshing=false;
		Sys.println(responseCode);
		Sys.println(data);
		//Sys.println(data["data"]["c_user_id"]);
		//Sys.println(data["error_msg"].length());
			
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
				App.getApp().setProperty("PROP_UID","");
				App.getApp().setProperty("PROP_PLANTID","");
			
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
					Sys.println("current_power: "+power + " Current: "+ Current); 
					
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
					Sys.println("today_energy: "+power + " Today :"+Today);   
					
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
					Sys.println("monthly_energy: "+power + " ThisMonth: " + ThisMonth);   
					
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
					Sys.println("yearly_energy: "+power + " ThisYear: " + ThisYear);
		
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
					Sys.println("total_energy: "+power + " Total: " + Total);
					
					// Format Last Update
					LastUpdate=data["data"]["last_update_time"]; 
					var a = DetermineNextUpdateFromLastUpdate();
					lastUpdateLocalized = formatTimeStampRFC3339(LastUpdate);					
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
				}
			}
		} 
		else if (responseCode==Comm.BLE_CONNECTION_UNAVAILABLE) 
		{
			// bluetooth not connected
			ShowError = true;
			Errortext1=Ui.loadResource(Rez.Strings.NOBLUETOOTHERRORTEXT1);
			Errortext2=Ui.loadResource(Rez.Strings.NOBLUETOOTHERRORTEXT2);
			Errortext3=Ui.loadResource(Rez.Strings.NOBLUETOOTHERRORTEXT3);
		} 
		else if (responseCode==Comm.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE) 
		{
			// Invalid API key
			ShowError = true;
			Errortext1=Ui.loadResource(Rez.Strings.INVALIDSETTINGSTEXT1);
			Errortext2=Ui.loadResource(Rez.Strings.INVALIDSETTINGSTEXT2);
			Errortext3=Ui.loadResource(Rez.Strings.INVALIDSETTINGSTEXT3);		 
		} 
		else if (responseCode==Comm.NETWORK_REQUEST_TIMED_OUT ) 
		{
			// No Internet
			ShowError = true;
			Errortext1=Ui.loadResource(Rez.Strings.NOINTERNET1);
			Errortext2=Ui.loadResource(Rez.Strings.NOINTERNET2);
			Errortext3=Ui.loadResource(Rez.Strings.NOINTERNET3);       				 
		} 
		else 
		{
			// general Error
			ShowError = true;
			Errortext1="Error "+responseCode;
			Errortext2="Configure settings in";
			Errortext3="Garmin Connect or Express";
		}
		Ui.requestUpdate();
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
       var app=Application.getApp();       
       Current = app.getProperty("Current");       
       Today = app.getProperty("Today"); 
       ThisMonth = app.getProperty("ThisMonth");
       ThisYear = app.getProperty("ThisYear");
       Total = app.getProperty("Total");
       LastUpdate= app.getProperty("LastUpdate");
       NextUpdate = app.getProperty("NextUpdate");
             
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
        var image = Ui.loadResource( Rez.Drawables.omniklogo);
        if (dc.getHeight()>180) {
            // later model: Draw bitmap a bit lower
        	dc.drawBitmap(dc.getWidth()/2-70,25,image);
        } else {
            // eurlier model, draw bitmap a bigh higher
            dc.drawBitmap(dc.getWidth()/2-70,10,image);
        }
             
        if (ShowError) {
           // Show Error
	        	// dc.drawText(dc.getWidth()/2,55,Graphics.FONT_LARGE,"ERROR",Graphics.TEXT_JUSTIFY_CENTER);
	        	dc.drawText(dc.getWidth()/2,dc.getHeight()/2-40,Graphics.FONT_MEDIUM,Errortext1,Graphics.TEXT_JUSTIFY_CENTER);
	        	dc.drawText(dc.getWidth()/2,dc.getHeight()/2,Graphics.FONT_SMALL,Errortext2,Graphics.TEXT_JUSTIFY_CENTER);
	        	dc.drawText(dc.getWidth()/2,dc.getHeight()/2+40,Graphics.FONT_SMALL,Errortext3,Graphics.TEXT_JUSTIFY_CENTER);
        } 
		else  if (ShowRefreshing) {
                // show refreshing page
                dc.drawText(dc.getWidth()/2,dc.getHeight()/2,Graphics.FONT_LARGE,Ui.loadResource(Rez.Strings.UPDATING),Graphics.TEXT_JUSTIFY_CENTER);
        } 
		else {
            // Show status page
	        if (CurrentPage==1) {
	            // Current Power
	        	dc.drawText(dc.getWidth()/2,dc.getHeight()/2-40,Graphics.FONT_LARGE,Ui.loadResource(Rez.Strings.CURRENT),Graphics.TEXT_JUSTIFY_CENTER);
	    	    dc.drawText(dc.getWidth()/2,dc.getHeight()/2,Graphics.FONT_LARGE,Current,Graphics.TEXT_JUSTIFY_CENTER);
	    	    dc.drawText(dc.getWidth()/2,dc.getHeight()/2+40,Graphics.FONT_SMALL,lastUpdateLocalized,Graphics.TEXT_JUSTIFY_CENTER);
	        
	    	} 
			else if (CurrentPage==2) {
	    	    // Today
	        	dc.drawText(dc.getWidth()/2,dc.getHeight()/2-40,Graphics.FONT_LARGE,loadResource(Rez.Strings.TODAY),Graphics.TEXT_JUSTIFY_CENTER);
	    	    dc.drawText(dc.getWidth()/2,dc.getHeight()/2,Graphics.FONT_LARGE,Today,Graphics.TEXT_JUSTIFY_CENTER);
	    	    dc.drawText(dc.getWidth()/2,dc.getHeight()/2+40,Graphics.FONT_SMALL,lastUpdateLocalized,Graphics.TEXT_JUSTIFY_CENTER);
	    	} 
			else if (CurrentPage==3) {
	    	    //  this Week
	        	dc.drawText(dc.getWidth()/2,dc.getHeight()/2-40,Graphics.FONT_LARGE,loadResource(Rez.Strings.THISMONTH),Graphics.TEXT_JUSTIFY_CENTER);
	    	    dc.drawText(dc.getWidth()/2,dc.getHeight()/2,Graphics.FONT_LARGE,ThisMonth,Graphics.TEXT_JUSTIFY_CENTER);
	    	    dc.drawText(dc.getWidth()/2,dc.getHeight()/2+40,Graphics.FONT_SMALL,lastUpdateLocalized,Graphics.TEXT_JUSTIFY_CENTER);
	    	} 
			else if (CurrentPage==4) {
	    	    // This Month
	        	dc.drawText(dc.getWidth()/2,dc.getHeight()/2-40,Graphics.FONT_LARGE,loadResource(Rez.Strings.THISYEAR),Graphics.TEXT_JUSTIFY_CENTER);
	    	    dc.drawText(dc.getWidth()/2,dc.getHeight()/2,Graphics.FONT_LARGE,ThisYear,Graphics.TEXT_JUSTIFY_CENTER);
	    	    dc.drawText(dc.getWidth()/2,dc.getHeight()/2+40,Graphics.FONT_SMALL,lastUpdateLocalized,Graphics.TEXT_JUSTIFY_CENTER);
	    	} 
			else if (CurrentPage==5) {
	    	    // Total
	        	dc.drawText(dc.getWidth()/2,dc.getHeight()/2-40,Graphics.FONT_LARGE,loadResource(Rez.Strings.TOTAL),Graphics.TEXT_JUSTIFY_CENTER);
	    	    dc.drawText(dc.getWidth()/2,dc.getHeight()/2,Graphics.FONT_LARGE,Total,Graphics.TEXT_JUSTIFY_CENTER);
	    	    dc.drawText(dc.getWidth()/2,dc.getHeight()/2+40,Graphics.FONT_SMALL,lastUpdateLocalized,Graphics.TEXT_JUSTIFY_CENTER);
	    	} 
			else if (CurrentPage==6) {
	    	    // All details
	    	    // create offset for lager displays.
	    	    var offset=0;
	    	    if (dc.getHeight()>180) {
	    	       offset=-10;
	    	    }
	    	    Sys.println(dc.getHeight());
	    	    
	        	dc.drawText(dc.getWidth()/2, dc.getHeight()/2-50+offset, Graphics.FONT_MEDIUM, loadResource(Rez.Strings.CURRENT)+": "+Current, Graphics.TEXT_JUSTIFY_CENTER);
	        	dc.drawText(dc.getWidth()/2, dc.getHeight()/2-25+offset, Graphics.FONT_MEDIUM, loadResource(Rez.Strings.TODAY)+": "+Today, Graphics.TEXT_JUSTIFY_CENTER);
	        	dc.drawText(dc.getWidth()/2, dc.getHeight()/2+offset, Graphics.FONT_MEDIUM, loadResource(Rez.Strings.THISMONTH)+": "+ThisMonth, Graphics.TEXT_JUSTIFY_CENTER);
	        	dc.drawText(dc.getWidth()/2, dc.getHeight()/2+25+offset, Graphics.FONT_MEDIUM, loadResource(Rez.Strings.THISYEAR)+": "+ThisYear, Graphics.TEXT_JUSTIFY_CENTER);
	        	dc.drawText(dc.getWidth()/2, dc.getHeight()/2+50+offset, Graphics.FONT_MEDIUM, loadResource(Rez.Strings.TOTAL)+": "+Total, Graphics.TEXT_JUSTIFY_CENTER);
	    	}
    	}
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
    
       // Safe data
       var app=Application.getApp();
       app.setProperty("Current",Current);       
       app.setProperty("Today", Today); 
       app.setProperty("ThisMonth", ThisMonth);
       app.setProperty("ThisYear", ThisYear);
       app.setProperty("Total",Total);
       app.setProperty("LastUpdate", LastUpdate);
       app.setProperty("NextUpdate", NextUpdate);      
       app.setProperty("LastUpdateLocalized", lastUpdateLocalized);
    }
}


