//
// Copyright 2016 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//
using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.System as System;

class SolarEdgeWidgetDelegate extends Ui.BehaviorDelegate {
    var notify;

    // Handle menu button press
    function onMenu() {
        notify.invoke(DOWEBREQUEST);
        return true;
    }

    function onSelect() {
        NextPage();
        return true;
    }
    
    function onSwipe(evt) {
        var swipe = evt.getDirection();

        if (swipe == SWIPE_UP) {
            PreviousPage();
        } else if (swipe == SWIPE_DOWN) {
            NextPage();
        } 

        return true;
    }
        

    // Set up the callback to the view
    function initialize(handler) {
        Ui.BehaviorDelegate.initialize();
        notify = handler;
    }

    // Receive the data from the web request
    // function onReceive(responseCode, data) {
      //   if (responseCode == 200) {
        //    notify.invoke(data);
        // } else {
         //    notify.invoke("Error");
       //  }
    // }
}