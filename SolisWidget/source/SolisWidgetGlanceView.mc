//Glances Source Example: https://forums.garmin.com/developer/connect-iq/b/news-announcements/posts/widget-glances---a-new-way-to-present-your-data#:~:text=The%20new%20glances%20carousel%20shows,widget%20in%20full%2Dscreen%20mode.

using Toybox.WatchUi;
using Toybox.Application;

(:glance)
class SolisWidgetGlanceView extends WatchUi.GlanceView {

    function initialize() {
        //System.println("SolisWidgetGlanceView:initialize");
        GlanceView.initialize();
    }

    function onUpdate(dc) {
        //System.println("SolisWidgetGlanceView:onUpdate");

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        var font  = Graphics.FONT_SMALL;
        var fontHeight  = Graphics.getFontHeight(font);

        var lineOneValue = Application.getApp().getProperty("glanceName");
        var lineTwoValue = Application.getApp().getProperty("glanceVal");

        if(lineOneValue == null){
            lineOneValue = WatchUi.loadResource(Rez.Strings.AppName);
            lineTwoValue = WatchUi.loadResource(Rez.Strings.GL);
        }

        var height  = dc.getHeight();
        var lineOnePosY  = 0;
        var lineTwoPosY  = lineOnePosY + ((fontHeight/2) + (fontHeight/2));

        dc.drawText(dc.getWidth()/2,lineOnePosY,font,lineOneValue,Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(dc.getWidth()/2,lineTwoPosY,font,lineTwoValue,Graphics.TEXT_JUSTIFY_CENTER);
    }
}