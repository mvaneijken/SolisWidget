using Toybox.Application;
using Toybox.WatchUi;

var gSettingsChanged = true;

class SolisWidgetApp extends Application.AppBase {
    hidden var mView;

    function initialize() {
        //System.println("SolisWidgetApp:initialize");
        AppBase.initialize();

    }

    // onStart() is called on application start up
    function onStart(state) {
        //System.println("SolisWidgetApp:onStart");
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
        //System.println("SolisWidgetApp:onStop");

    }

    // New app settings have been received so trigger a UI update
    function onSettingsChanged() {
        //System.println("SolisWidgetApp:onSettingsChanged");
        $.gSettingsChanged = true;
        WatchUi.requestUpdate();
    }


    // Return the initial view of your application here
    function getInitialView() {
        //System.println("SolisWidgetApp:getInitialView");
        mView = new SolisWidgetView();
        return [mView, new SolisWidgetDelegate(mView.method(:HandleCommand))];
    }

    (:glance)
    function getGlanceView() {
        //System.println("SolisWidgetApp:getGlanceView");
        return [ new SolisWidgetGlanceView() ];
    }

}