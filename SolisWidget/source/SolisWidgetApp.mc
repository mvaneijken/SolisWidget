using Toybox.Application;
using Toybox.WatchUi;
using Toybox.Lang;


module json {

    var _type_map = {};

    function register_type(type, callback) {
        _type_map[type] = callback;
    }

    function deregister_type(type) {
        _type_map.remove(type);
    }

    //
    // return a JSON string representation of any known key type
    // throws exception if obj is not a valid key type
    //
    function _json_dumps_key(obj) {
        if (obj instanceof Lang.String) {
            return _json_dumps_string(obj);
        }
        else {
            throw new Lang.UnexpectedTypeException("UnexpectedTypeException: Expected String, given null/Boolean/Double/Float/Long/Number/Array/ByteArray/Dictionary/Object", 0, 0);
        }
    }

    //
    // return a JSON string representation of any known value type
    // throws exception if obj is not a known type
    //
    function _json_dumps_val(obj) {
        var keys = _type_map.keys();
        var vals = _type_map.values();

        for (var i = 0, j = keys.size(); i < j; ++i) {
        if (obj instanceof keys) {
            return vals.invoke(obj);
            }
        }

        return _builtin_dumps(obj);
    }

    //
    // return a JSON string representation of the given Lang.Array object
    //
    function _json_dumps_array(obj)
    {
        var n = obj.size();
        if (n == 0) {
            return "[]";
        }

        var r = "[";
            r += _json_dumps_val(obj[0]);

        for (var i = 1; i < n; ++i) {
            r += ",";
            r += _json_dumps_val(obj);
        }

        r += "]";

        return r;
    }

    //
    // return a JSON string representation of the given Lang.Dictionary object
    //
    function _json_dumps_dict(obj)
    {
        var n = obj.size();
        if (n == 0) {
            return "{}";
        }

        var k = obj.keys();
        var v = obj.values();

        var r = "{";
        r += _json_dumps_key(k[0]);
        r += ":";
        r += _json_dumps_val(v[0]);

        for (var i = 1; i < n; ++i) {
            r += ",";
            r += _json_dumps_key(k);
            r += ":";
            r += _json_dumps_val(v);
        }

        r += "}";

    return r;
    }

    //
    // return a JSON string representation of a string
    //
    function _json_dumps_string(obj) {
        return Lang.format("\"$1$\"", [ obj ]);
    }

    //
    // return a JSON string representation of a built-in object type
    //
    function _builtin_dumps(obj) {
        if (obj == null) {
            return "null";
        }
        else if (obj instanceof Lang.Boolean) {
            return obj.toString();
        }
        else if (obj instanceof Lang.Double) {
            return obj.toString();
        }
        else if (obj instanceof Lang.Float) {
            return obj.toString();
        }
        else if (obj instanceof Lang.Long) {
            return obj.toString();
        }
        else if (obj instanceof Lang.Number) {
            return obj.toString();
        }
        else if (obj instanceof Lang.String) {
            return _json_dumps_string(obj);
        }
        else if (obj instanceof Lang.Array) {
            return _json_dumps_array(obj);
        }
        else if (obj instanceof Lang.Dictionary) {
            return _json_dumps_dict(obj);
        }
        else if (obj instanceof Lang.ByteArray) {
            return obj.toString();
        }

        throw new Lang.UnexpectedTypeException("UnexpectedTypeException: Expected null/Boolean/Double/Float/Long/Number/String/Array/ByteArray/Dictionary, given Object", 0, 0);
    }

    //
    // return a JSON string representation of any known type
    //
    function dumps(obj) {
    return _json_dumps_val(obj);
    }
}

var gSettingsChanged = true;

class SolisWidgetApp extends Application.AppBase {
    hidden var mView;
    hidden var _member1;
    hidden var _member2;

    function initialize() {
        //System.println("SolisWidgetApp:initialize");
        AppBase.initialize();
        _member1 = 17;
        _member2 = 31;
    }

    // onStart() is called on application start up
    function onStart(state) {
        //System.println("SolisWidgetApp:onStart");
        json.register_type(SolisWidgetApp, self.method(:dumps));
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
        //System.println("SolisWidgetApp:onStop");
        json.deregister_type(SolisWidgetApp);
    }

    function dumps(obj) {
        var rep = {
            "member1" => _member1,
            "member2" => _member2
        };
        return dumps(rep);
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
        System.println(json.dumps({ "one" => 1, "two" => 2.0d, "three" => [ { "a" => [] } ] }));

        mView = new SolisWidgetView();
        return [mView, new SolisWidgetDelegate(mView.method(:HandleCommand))];
    }

    (:glance)
    function getGlanceView() {
        //System.println("SolisWidgetApp:getGlanceView");
        return [ new SolisWidgetGlanceView() ];
    }
}