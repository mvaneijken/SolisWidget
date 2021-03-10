//
// Copyright 2016 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//
using Toybox.Application;
using Toybox.WatchUi;
using Toybox.System;

class OmnikWidgetDelegate extends WatchUi.BehaviorDelegate {
    var notify;

    // Handle menu button press
    function onMenu() {
        notify.invoke(DOWEBREQUEST);
        return true;
    }

    function onSelect() {
        RefreshPage();
        return true;
    }
    
    function onNextPage() {
        NextPage();
        return true;
    }
    
    function onPreviousPage() {
        PreviousPage();
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
        WatchUi.BehaviorDelegate.initialize();
        notify = handler;
    }
}