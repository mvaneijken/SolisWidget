//Glances Source Example: https://forums.garmin.com/developer/connect-iq/b/news-announcements/posts/widget-glances---a-new-way-to-present-your-data#:~:text=The%20new%20glances%20carousel%20shows,widget%20in%20full%2Dscreen%20mode.

using Toybox.WatchUi;
using Toybox.Application;
using Toybox.Time;

(:glance)
class SolisWidgetGlanceView extends WatchUi.GlanceView {

    function initialize() {
        //System.println("SolisWidgetGlanceView:initialize");
        GlanceView.initialize();
    }

    function onShow() {
        var app = Application.getApp();
        app.retrieveSettings();
        $.gIsGlance = true;
        var lastFetch = app.getProperty("PFT");
        var now = Time.now().value();
        //TODO: Not working now, needs to be investigated
        // if (lastFetch == null || (now - lastFetch) > 60) {
        //     app.makeReq();
        // }
    }

    function onUpdate(dc) {
        //System.println("SolisWidgetGlanceView:onUpdate");

        dc.setColor(0x000000,0x000000); //(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(0xFFFFFF,-1); //(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        var font = 2; //Graphics.FONT_SMALL;
        var fontHeight = Graphics.getFontHeight(font);

        if($.showErr){
            showRefrsh = false;
        }

        if (showRefrsh) {
            dc.drawText(dc.getWidth()/2, 0, font, WatchUi.loadResource(Rez.Strings.AppName), 1);
            dc.drawText(dc.getWidth()/2, fontHeight, font, WatchUi.loadResource(Rez.Strings.UP), 1);
            return;
        }

        var lineOneValue = Application.getApp().getProperty("glanceName");
        var lineTwoValue = Application.getApp().getProperty("glanceVal");

        if(lineOneValue == null){
            lineOneValue = WatchUi.loadResource(Rez.Strings.AppName);
            lineTwoValue = WatchUi.loadResource(Rez.Strings.GL);
        }

        if($.showErr) {
            lineOneValue = WatchUi.loadResource(Rez.Strings.AppName);
            lineTwoValue = errStr1;
        }

        var lineOnePosY = 0;
        var lineTwoPosY = lineOnePosY + ((fontHeight/2) + (fontHeight/2));

        dc.drawText(dc.getWidth()/2,lineOnePosY,font,lineOneValue,1); //Graphics.TEXT_JUSTIFY_CENTER)
        dc.drawText(dc.getWidth()/2,lineTwoPosY,font,lineTwoValue,1); //Graphics.TEXT_JUSTIFY_CENTER)
    }
}
