using Toybox.Application;
using Toybox.WatchUi;
using Toybox.System;

class SolisWidgetDelegate extends WatchUi.BehaviorDelegate {
    var notify;

    // Handle menu button press
    function onMenu() {
        System.println("SolisWidgetDelegate:onMenu");
        notify.invoke(DOWEBREQUEST);
        return true;
    }

    // TODO: Add support for refresh and the use of up/down keys.
    //  function onKey(keyEvent) {
    //      System.println("onkey: " + keyEvent.getKey());
    //      return true;
    //  }

    function onSelect() {
        System.println("SolisWidgetDelegate:onSelect");
        // TODO: Add support for refresh and the use of up/down keys.
        //RefreshPage();
        NextPage();
        return true;
    }

    function onNextPage() {
        System.println("SolisWidgetDelegate:onNextPage");
        NextPage();
        return true;
    }

    function onPreviousPage() {
        System.println("SolisWidgetDelegate:onPreviousPage");
        PreviousPage();
        return true;
    }

    function onSwipe(evt) {
        System.println("SolisWidgetDelegate:onSwipe");
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
        System.println("SolisWidgetDelegate:initialize");
        WatchUi.BehaviorDelegate.initialize();
        notify = handler;
    }
}