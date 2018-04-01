using Toybox.WatchUi as Ui;
using Toybox.Application as App;
using Toybox.Lang as Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Communications as Comm;
using Toybox.System as Sys;

var DOWEBREQUEST=1;

var ShowError=false;
var Errortext1;
var Errortext2;
var Errortext3;

var ShowRefreshing=false;

var CurrentPage; 
var Current;
var Today; 
var ThisMonth;
var ThisYear;
var Total;
var LastUpdate;
var UpdateInterval=new Time.Duration(15*60);
var TimeDifference=new Time.Duration(2*3600);


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


class SolarEdgeWidgetView extends Ui.View {
    
    function initialize() {
    
    	// Get Current Page From settings
    	CurrentPage=App.getApp().getProperty("PROP_STARTPAGE");

        View.initialize();
    }
    
    // function to convert date in string format to moment object
    function ParseDateToMoment(date) 
    {
    	// 0123456789012345678   positions
    	// 2018-03-25 20:16:18   date format
    	
    	// check if correct field
    	// if (date.length()<19) {
    		//return null;
    	// }
    	
    	var moment = Gregorian.moment({
    		:year	=>	date.substring( 0,  4).toNumber(),
    		:month	=>	date.substring( 5,  7).toNumber(),
    		:day 	=>	date.substring( 8, 10).toNumber(),
    		:hour	=>	date.substring(11, 13).toNumber(),
    		:minute	=>	date.substring(14, 16).toNumber(),
    		:second	=>	date.substring(17, 19).toNumber()
    	});
    	
    	return moment;
    	
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
	           
	           if (data instanceof Dictionary) {
	       
		            var power=0.0; // init variable
		            
		            // Format Current Power
		            power = data["overview"]["currentPower"]["power"].toFloat();
		            if (power<1000)
		            {
		            	Current=power.toNumber() + " W";
		            } else {
		                Current=(power/1000).format("%.2f") + " kW";
		            }
		            
		            // Format Today
		            power = data["overview"]["lastDayData"]["energy"].toFloat();
		            if (power<1000) {
		               // Less than 1 kWh Present in Wh
		               Today=power.toNumber() + " Wh";
		            } else {
		              // > more than kWh, so present in in kWh
		              // Current=Lang.format("$1$ kWh",power/1000);
		              Today = (power/1000).format("%.2f") + " kWh";
		            }   
		            
		            // Format This Month
		            power = data["overview"]["lastMonthData"]["energy"].toFloat();
		            if (power<1000) {
		               // Less than 1 kWh Present in Wh
		               ThisMonth=power.toNumber() + " Wh";
		            } else {
		              // > more than kWh, so present in in kWh
		              // Current=Lang.format("$1$ kWh",power/1000);
		              ThisMonth= (power/1000).format("%.1f") + " kWh";
		            }   
		            
		            // Format This Year
		            power = data["overview"]["lastYearData"]["energy"].toFloat();
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
		            power = data["overview"]["lifeTimeData"]["energy"].toFloat();
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
		            LastUpdate=data["overview"]["lastUpdateTime"]; 
		       } else {
		            // not parsable
					Current = null;
					Today = null; 
					ThisMonth = null;
					ThisYear = null;
					Total = null;
					LastUpdate = null;
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
    
    function makeRequest() {
    
        // Show refreshing page
        ShowError=false;
        ShowRefreshing=true;
        Ui.requestUpdate();
        
    
		// Get SiteID From settings
    	var SiteID = App.getApp().getProperty("PROP_SITEID");
    	
    	// Get API Key from Settings
    	var API_Key = App.getApp().getProperty("PROP_APIKEY");
    	
    	// Setup URL
    	var url="https://monitoringapi.solaredge.com/site/"+SiteID+"/overview.json?api_key="+API_Key;
		
		// Make the request
        Comm.makeWebRequest(
            url,
            {
            },
            {
                "Content-Type" => Comm.REQUEST_CONTENT_TYPE_URL_ENCODED
            },
            method(:onReceive)
        );
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


       /* Auto Update always until timezones fixed
       // Check if autoupdate is needed
       if (LastUpdate==null) {
          // some kind of error in previous session. Do update
          makeRequest("verversen...");
       } else {
	       var NextUpdate=ParseDateToMoment(LastUpdate).add(UpdateInterval);
	       var now = new Time.Moment(Time.now().value()).add(TimeDifference);
	       if (now.greaterThan(NextUpdate))
	       {
	         makeRequest(Current);
	       } else {
	          // Current=now.value();
	       }    
       } */
       
       makeRequest();
    }
    
    // Update the view
    function onUpdate(dc) {
        // Call the parent onUpdate function to redraw the layout
        // View.onUpdate(dc);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        
        // Draw logo
        var image = Ui.loadResource( Rez.Drawables.solaredgelogo);
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
      
    }
    
    

}
