/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.javascript;

import org.mozilla.javascript.*;

import java.util.Date;

/**
 * Utility class to help with conversions
 */
public class JsConvert {
    /**
     * If the jsObject is a JavaScript date, return a Java Date. Otherwise
     * return null.
     */
    public static Date tryConvertJsDate(Object jsObject) {
        if(jsObject == null) {
            return null;
        }

        // Workaround NativeDate visibility
        if(nativeDateClass == null) {
            try {
                nativeDateClass = Class.forName("org.mozilla.javascript.NativeDate");
            } catch(java.lang.ClassNotFoundException e) {
                throw new RuntimeException("Expected class not available", e);
            }
        }

        // If it's a JavaScript date, try to convert it
        if(nativeDateClass.isInstance(jsObject)) {
            Object d = Context.jsToJava(jsObject, Date.class);
            if(d != null && d instanceof Date) {
                return (Date)d;
            }
        }

        return null;
    }

    // Keep a reference to the JS date class because it's not visible outside the package
    private static Class nativeDateClass;


    public static Object convertJavaDateToRuby(Date dateObject) {
        return rubyInterface.convertJavaDateToRuby(dateObject);
    }


    public static Scriptable integerArrayToJs(Integer[] array) {
        Scriptable js = Runtime.getCurrentRuntime().createHostObject("Array", array.length);
        for(int i = 0; i < array.length; ++i) {
            js.put(i, js, array[i]);
        }
        return js;
    }

    // --------------------------------------------------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        public Object convertJavaDateToRuby(Object value);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }
}
