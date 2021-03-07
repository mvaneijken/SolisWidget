using Toybox.Application as App;
using Toybox.WatchUi as Ui;

var gSettingsChanged = true;


class SolarEdgeWidgetApp extends App.AppBase {
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
		Ui.requestUpdate();
	}
    

    // Return the initial view of your application here
    function getInitialView() {
        mView = new SolarEdgeWidgetView();
        return [mView, new SolarEdgeWidgetDelegate(mView.method(:HandleCommand))];
    }

}