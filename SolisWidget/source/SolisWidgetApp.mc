using Toybox.Application;
using Toybox.WatchUi;

var gSettingsChanged = true;

class SolisWidgetApp extends Application.AppBase {
    hidden var mView;

    (:debug)
    function debugMessage(object){
        System.println(object);
    }

    function initialize() {
        debugMessage("SolisWidgetApp:initialize");
        AppBase.initialize();

    }

    // onStart() is called on application start up
    function onStart(state) {
        debugMessage("SolisWidgetApp:onStart");
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
        debugMessage("SolisWidgetApp:onStop");

    }

    // New app settings have been received so trigger a UI update
    function onSettingsChanged() {
        debugMessage("SolisWidgetApp:onSettingsChanged");
        $.gSettingsChanged = true;
        WatchUi.requestUpdate();
    }


    // Return the initial view of your application here
    function getInitialView() {
        debugMessage("SolisWidgetApp:getInitialView");
        mView = new SolisWidgetView();
        return [mView, new SolisWidgetDelegate(mView.method(:HandleCommand))];
    }

    (:glance)
    function getGlanceView() {
        debugMessage("SolisWidgetApp:getGlanceView");
        return [ new SolisWidgetGlanceView() ];
    }

}