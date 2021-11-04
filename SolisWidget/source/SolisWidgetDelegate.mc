using Toybox.Application;
using Toybox.WatchUi;
using Toybox.System;

class SolisWidgetDelegate extends WatchUi.BehaviorDelegate {
    var notify;

    (:debug)
    function debugMessage(object){
        System.println(object);
    }

    // Handle menu button press
    function onMenu() {
        debugMessage("SolisWidgetDelegate:onMenu");
        notify.invoke(DOWEBREQUEST);
        return true;
    }

    // TODO: Add support for refresh and the use of up/down keys.
    //  function onKey(keyEvent) {
    //      debugMessage("onkey: " + keyEvent.getKey());
    //      return true;
    //  }

    function onSelect() {
        debugMessage("SolisWidgetDelegate:onSelect");
        // TODO: Add support for refresh and the use of up/down keys.
        //RefreshPage();
        NextPage();
        return true;
    }

    function onNextPage() {
        debugMessage("SolisWidgetDelegate:onNextPage");
        NextPage();
        return true;
    }

    function onPreviousPage() {
        debugMessage("SolisWidgetDelegate:onPreviousPage");
        PreviousPage();
        return true;
    }

    function onSwipe(evt) {
        debugMessage("SolisWidgetDelegate:onSwipe");
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
        debugMessage("SolisWidgetDelegate:initialize");
        WatchUi.BehaviorDelegate.initialize();
        notify = handler;
    }
}