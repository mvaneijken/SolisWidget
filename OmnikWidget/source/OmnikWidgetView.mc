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
var LastUpdate;
var NextUpdate;
var BaseUrl = "https://api.omnikportal.com/v1";
var uid = "-1";
var appid = "10038";
var appkey = "Ox7yu3Eivicheinguth9ef9kohngo9oo";
var c_user_id;
var plantid;


// Settings
var CurrentPage; 
var UserName;
var Password;

// Constants
var UpdateInterval=15; // in Minutes


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
        retrieveSettings();
    
        View.initialize();
    }
    
   function retrieveSettings() {
	    // Get UserName From settings
	    UserName = App.getApp().getProperty("PROP_UserName");
	    	
	    // Get API Key from Settings
	    Password = App.getApp().getProperty("PROP_Password");		
	    
	    // Get Current Page From settings
    	CurrentPage=App.getApp().getProperty("PROP_STARTPAGE");

		// Get the c_user_id
		c_user_id=App.getApp().getProperty("PROP_C_USER_ID");

		// Get the uid
		uid=App.getApp().getProperty("PROP_UID");
	    
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
    	
    	// There might be a time differnce, so only use the number of minutes from the string, 
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
    
    
    // Receive the data from the web request
        function onReceive(responseCode, data) 
        {
           // Turn of refreshpage
           ShowRefreshing=false;
           
        
           // Check responsecode
           if (responseCode==200)
           {
           		// Make sure no error is shown	
				ShowError=false;

				if(data["error_msg"].length() >= 0){
					// Reset values to reinitiate login
					ShowError=true;
					c_user_id = "";
					uid = "-1";
	       			Errortext1="Error:"+ data["error_code"] + ", " + data["error_msg"];
	       			Errortext2="If needed try to remove the Omnik API User ID and Omnik API Site ID in";
	       			Errortext3="Garmin Connect or Express";
				}
				else if (c_user_id.length == 0){
		            c_user_id = data["c_user_id"].toString();
				}
				else if (uid == "-1 || uid.length == 0){
					uid = data["plants"][0]["plant_id"].toString();
				}
				else{
	          		if (data instanceof Dictionary) {
	       
						var power=0.0; // init variable
						
						// Format Current Power
						power = data["current_power"].toFloat();
						if (power<1000)
						{
							Current=power.toNumber() + " W";
						} else {
							Current=(power/1000).format("%.2f") + " kW";
						}
						
						// Format Today
						power = data["today_energy"].toFloat();
						if (power<1000) {
						// Less than 1 kWh Present in Wh
						Today=power.toNumber() + " Wh";
						} else {
						// > more than kWh, so present in in kWh
						// Current=Lang.format("$1$ kWh",power/1000);
						Today = (power/1000).format("%.2f") + " kWh";
						}   
						
						// Format This Month
						power = data["monthly_energy"].toFloat();
						if (power<1000) {
						// Less than 1 kWh Present in Wh
						ThisMonth=power.toNumber() + " Wh";
						} else {
						// > more than kWh, so present in in kWh
						// Current=Lang.format("$1$ kWh",power/1000);
						ThisMonth= (power/1000).format("%.1f") + " kWh";
						}   
						
						// Format This Year
						power = data["yearly_energy"].toFloat();
						if (power<1000) {
						// Less than 1 kWh Present in Wh
						ThisYear=power.toNumber() + " Wh";
						} else if (power<1000000) {
						// > more than kWh, so present in in kWh
						ThisYear= (power/1000).format("%.1f") + " kWh";
						} else {
						ThisYear= (power/1000000).format("%.2f") + " MWh";
						}
			
						// Format Total
						power = data["today_energy"].toFloat();
						if (power<1000) {
						// Less than 1 kWh Present in Wh
						Total=power.toNumber() + " Wh";
						} else if (power<1000000) {
						// > more than kWh, so present in in kWh
						Total= (power/1000).format("%.1f") + " kWh";
						} else {
						Total= (power/1000000).format("%.2f") + " MWh";
						}
						
						// Format Last Update
						LastUpdate=data["last_update_time"]; 
						var a = DetermineNextUpdateFromLastUpdate();
						
					} else {
							// not parsable
							Current = null;
							Today = null; 
							ThisMonth = null;
							ThisYear = null;
							Total = null;
							LastUpdate = null;
					}
				}
		   } else if (responseCode==Comm.BLE_CONNECTION_UNAVAILABLE) {
		        // bluetooth not connected
		        ShowError = true;
		        Errortext1=Ui.loadResource(Rez.Strings.NOBLUETOOTHERRORTEXT1);
		        Errortext2=Ui.loadResource(Rez.Strings.NOBLUETOOTHERRORTEXT2);
		        Errortext3=Ui.loadResource(Rez.Strings.NOBLUETOOTHERRORTEXT3);
		   } else if (responseCode==Comm.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE) {
	       		// Invalid API key
	       		ShowError = true;
	       		Errortext1=Ui.loadResource(Rez.Strings.INVALIDSETTINGSTEXT1);
	       		Errortext2=Ui.loadResource(Rez.Strings.INVALIDSETTINGSTEXT2);
	       		Errortext3=Ui.loadResource(Rez.Strings.INVALIDSETTINGSTEXT3);		 
		   } else if (responseCode==Comm.NETWORK_REQUEST_TIMED_OUT ) {
	       		// No Internet
	       		ShowError = true;
	       		Errortext1=Ui.loadResource(Rez.Strings.NOINTERNET1);
	       		Errortext2=Ui.loadResource(Rez.Strings.NOINTERNET2);
	       		Errortext3=Ui.loadResource(Rez.Strings.NOINTERNET3);		 
	       				 
	       } else {
	       		// general Error
	       		ShowError = true;
	       		Errortext1="Error "+responseCode;
	       		Errortext2="Configure settings in";
	       		Errortext3="Garmin Connect or Express";
        }
        Ui.requestUpdate();
    }
    
    function onRequest() {
    
        // Show refreshing page
        ShowError=false; // turn off an error screen (if any)
        ShowRefreshing=true; // make sure refreshingscreen is shown when updating the UI.
        Ui.requestUpdate();
        
        // only retrieve the settings if they've actually changed
	    // Get UserName From settings
		var params = {                                              // set the parameters
              "user_email" => username
			  "user_password" => password
			  "user_type" => 1
       		};
		if (c_user_id.length = 0){

			// Setup URL
			var url= BaseUrl+"/user/account_validate";

			//Options Variable
			var options = {                                           
				:method => Communications.HTTP_REQUEST_METHOD_POST,      
				:headers => {                                           
						"Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED},
						"uid" = uid,
						"appid" = appid,
						"appkey" = appkey,
				:responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
			};
		}
		else (uid == "-1" || uid.length = 0) {
			// Need to get the uid of the user
			
			// Setup URL
			var url= BaseUrl+"/plant/list";

			//Options Variable
			var options = {                                           
				:method => Communications.HTTP_REQUEST_METHOD_GET,      
				:headers => {                                           
						"Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED},
						"uid" = uid,
						"appid" = appid,
						"appkey" = appkey,
				:responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
			};
		}
		else{
			// Setup URL
			var url= BaseUrl+"/plant/data?plant_id="+plantid;

			//Options Variable
			var options = {                                           
				:method => Communications.HTTP_REQUEST_METHOD_GET,      
				:headers => {                                           
						"Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED},
						"uid" = uid,
						"appid" = appid,
						"appkey" = appkey,
				:responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
			};
		}
					
			// Make the authentication request
			Comm.makeWebRequest(url,params,options,method(:onReceive));
		}
		
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
        } else  if (ShowRefreshing) {
                // show refreshing page
                dc.drawText(dc.getWidth()/2,dc.getHeight()/2,Graphics.FONT_LARGE,Ui.loadResource(Rez.Strings.UPDATING),Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            // Show status page
	        if (CurrentPage==1) {
	            // Current Power
	        	dc.drawText(dc.getWidth()/2,dc.getHeight()/2-40,Graphics.FONT_LARGE,Ui.loadResource(Rez.Strings.CURRENT),Graphics.TEXT_JUSTIFY_CENTER);
	    	    dc.drawText(dc.getWidth()/2,dc.getHeight()/2,Graphics.FONT_LARGE,Current,Graphics.TEXT_JUSTIFY_CENTER);
	    	    dc.drawText(dc.getWidth()/2,dc.getHeight()/2+40,Graphics.FONT_SMALL,LastUpdate,Graphics.TEXT_JUSTIFY_CENTER);
	        
	    	} else if (CurrentPage==2) {
	    	    // Today
	        	dc.drawText(dc.getWidth()/2,dc.getHeight()/2-40,Graphics.FONT_LARGE,loadResource(Rez.Strings.TODAY),Graphics.TEXT_JUSTIFY_CENTER);
	    	    dc.drawText(dc.getWidth()/2,dc.getHeight()/2,Graphics.FONT_LARGE,Today,Graphics.TEXT_JUSTIFY_CENTER);
	    	    dc.drawText(dc.getWidth()/2,dc.getHeight()/2+40,Graphics.FONT_SMALL,LastUpdate,Graphics.TEXT_JUSTIFY_CENTER);
	    	} else if (CurrentPage==3) {
	    	    //  this Week
	        	dc.drawText(dc.getWidth()/2,dc.getHeight()/2-40,Graphics.FONT_LARGE,loadResource(Rez.Strings.THISMONTH),Graphics.TEXT_JUSTIFY_CENTER);
	    	    dc.drawText(dc.getWidth()/2,dc.getHeight()/2,Graphics.FONT_LARGE,ThisMonth,Graphics.TEXT_JUSTIFY_CENTER);
	    	    dc.drawText(dc.getWidth()/2,dc.getHeight()/2+40,Graphics.FONT_SMALL,LastUpdate,Graphics.TEXT_JUSTIFY_CENTER);
	    	} else if (CurrentPage==4) {
	    	    // This Month
	        	dc.drawText(dc.getWidth()/2,dc.getHeight()/2-40,Graphics.FONT_LARGE,loadResource(Rez.Strings.THISYEAR),Graphics.TEXT_JUSTIFY_CENTER);
	    	    dc.drawText(dc.getWidth()/2,dc.getHeight()/2,Graphics.FONT_LARGE,ThisYear,Graphics.TEXT_JUSTIFY_CENTER);
	    	    dc.drawText(dc.getWidth()/2,dc.getHeight()/2+40,Graphics.FONT_SMALL,LastUpdate,Graphics.TEXT_JUSTIFY_CENTER);
	    	} else if (CurrentPage==5) {
	    	    // Total
	        	dc.drawText(dc.getWidth()/2,dc.getHeight()/2-40,Graphics.FONT_LARGE,loadResource(Rez.Strings.TOTAL),Graphics.TEXT_JUSTIFY_CENTER);
	    	    dc.drawText(dc.getWidth()/2,dc.getHeight()/2,Graphics.FONT_LARGE,Total,Graphics.TEXT_JUSTIFY_CENTER);
	    	    dc.drawText(dc.getWidth()/2,dc.getHeight()/2+40,Graphics.FONT_SMALL,LastUpdate,Graphics.TEXT_JUSTIFY_CENTER);
	    	} else if (CurrentPage==6) {
	    	    // All details
	    	    // create offset for lager displays.
	    	    var offset=0;
	    	    if (dc.getHeight()>180) {
	    	       offset=-10;
	    	    } 
	    	    
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


      
    }
    
    

}
