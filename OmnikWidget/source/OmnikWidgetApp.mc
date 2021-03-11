using Toybox.Application;
using Toybox.WatchUi;

var gSettingsChanged = true;

class OmnikWidgetApp extends Application.AppBase {
    hidden var mView;

    function initialize() {
        AppBase.initialize();

    }

    // onStart() is called on application start up
    function onStart(state) {
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
    }

    // New app settings have been received so trigger a UI update
    function onSettingsChanged() {
        $.gSettingsChanged = true;
        WatchUi.requestUpdate();
    }


    // Return the initial view of your application here
    function getInitialView() {
        mView = new OmnikWidgetView();
        return [mView, new OmnikWidgetDelegate(mView.method(:HandleCommand))];
    }

    (:glance)
    function getGlanceView() {
        return [ new OmnikWidgetGlanceView() ];
    }

}