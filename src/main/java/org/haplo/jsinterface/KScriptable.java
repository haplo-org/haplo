/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;

import org.mozilla.javascript.*;

public class KScriptable extends ScriptableObject {

    public String getClassName() {
        return "$KScriptable";
    }

    protected String getConsoleClassName() {
        return this.getClassName();
    }

    protected String getConsoleData() {
        return "";
    }

    public static String jsStaticFunction_forConsole(Scriptable object) {
        String data;
        if(object == null) {
            return null;
        }
        Object consoleFunc;
        try {
            consoleFunc = ScriptableObject.getProperty(object, "$console");
        } // This is a debugging output function, so be generous with catching exceptions
        catch(Exception e) {
            consoleFunc = Scriptable.NOT_FOUND;
        }
        if(consoleFunc != Scriptable.NOT_FOUND) {
            Function func = (Function)consoleFunc;
            Runtime runtime = Runtime.getCurrentRuntime();
            Scriptable jsonOb = runtime.getContext().newObject(runtime.getJavaScriptScope());
            Object result = func.call(runtime.getContext(), runtime.getJavaScriptScope(), object, new Object[0]); //ConsString is checked
            if(!(result instanceof CharSequence)) {
                throw new OAPIException("$getConsoleData must return a string");
            }
            return result.toString();
        } else if(object instanceof KScriptable) {
            data = ((KScriptable)object).getConsoleData();
            String className = ((KScriptable)object).getConsoleClassName();
            if(className.charAt(0) == '$') {
                className = className.substring(1); // remove leading $
            }
            return "[" + className + " " + data + "]";
        }
        return null;
    }
}
