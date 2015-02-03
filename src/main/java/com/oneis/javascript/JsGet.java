/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.javascript;

import org.mozilla.javascript.*;

import java.util.Date;

/**
 * Utility class to ease retrieval of values from JavaScript objects
 */
public class JsGet {
    public static String string(String name, Scriptable object) {
        Object value = object.get(name, object); // ConsString is checked
        if(value != null && (value instanceof CharSequence)) {
            return ((CharSequence)value).toString();
        }
        return null;
    }

    public static Date date(String name, Scriptable object) {
        Object value = object.get(name, object); // ConsString is checked
        if(value == null) {
            return null;
        }
        try {
            return (Date)Context.jsToJava(value, ScriptRuntime.DateClass);
        } catch(EvaluatorException e) {
            return null;
        }
    }

    public static Scriptable scriptable(String name, Scriptable object) {
        Object value = object.get(name, object); // ConsString is checked
        if(value != null && value instanceof Scriptable) {
            return (Scriptable)value;
        }
        return null;
    }

    public static Number number(String name, Scriptable object) {
        Object value = object.get(name, object); // ConsString is checked
        if(value != null && value instanceof Number) {
            return (Number)value;
        }
        return null;
    }

    public static Boolean booleanObject(String name, Scriptable object) {
        Object value = object.get(name, object); // ConsString is checked
        if(value != null && value instanceof Boolean) {
            return (Boolean)value;
        }
        return null;
    }

    public static boolean booleanWithDefault(String name, Scriptable object, boolean defaultValue) {
        Object value = object.get(name, object); // ConsString is checked
        if(value != null && value instanceof Boolean) {
            return ((Boolean)value).booleanValue();
        }
        return defaultValue;
    }

    public static Object objectOfClass(String name, Scriptable object, Class requiredClass) {
        Object value = object.get(name, object); // ConsString is checked
        if((value != null) && (value instanceof CharSequence)) {
            value = ((CharSequence)value).toString();
        }
        if(value != null && requiredClass.isInstance(value)) {
            return value;
        }
        return null;
    }
}
