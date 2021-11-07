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

        dc.setColor(0x000000,0x000000); //(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(0xFFFFFF,-1); //(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        var font as Number = 2; //Graphics.FONT_SMALL;
        var fontHeight as Number = Graphics.getFontHeight(font);

        var lineOneValue as String = Application.getApp().getProperty("glanceName");
        var lineTwoValue as String = Application.getApp().getProperty("glanceVal");

        var height as Number = dc.getHeight();
        var lineOnePosY as Number = 0;
        var lineTwoPosY as Number = lineOnePosY + ((fontHeight/2) + (fontHeight/2));

        dc.drawText(dc.getWidth()/2,lineOnePosY,font,lineOneValue,1); //Graphics.TEXT_JUSTIFY_CENTER)
        dc.drawText(dc.getWidth()/2,lineTwoPosY,font,lineTwoValue,1); //Graphics.TEXT_JUSTIFY_CENTER)
    }
}