/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.mozilla.javascript.Scriptable;
import org.mozilla.javascript.json.JsonParser;

import java.util.HashMap;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;

public class KPlatformGenericInterface extends KScriptable {
    public KPlatformGenericInterface() {
    }

    public void jsConstructor() {
    }

    public String getClassName() {
        return "$PlatformGenericInterface";
    }

    public static Object jsStaticFunction_callWithJSON(String name, Object arg) throws JsonParser.ParseException {
        if(name == null) { throw new OAPIException("No name provided"); }
        FnInfo info = functions.get(name);
        if(info == null) { throw new OAPIException("Generic platform interface function not known: "+name); }
        Runtime.privilegeRequired(info.privilege, "call generic platform interface function "+name);
        Runtime runtime = Runtime.getCurrentRuntime();
        String r = info.fn.callPlatform(runtime.jsonStringify(arg));
        if(r == null) { return null; }
        return runtime.makeJsonParser().parseValue(r);
    }

    // ----------------------------------------------------------------------

    public interface PlatformFunction {
        public String callPlatform(String arg);
    };

    public static void registerFunction(String name, String privilege, PlatformFunction fn) {
        FnInfo info = new FnInfo();
        info.name = name;
        info.privilege = privilege;
        info.fn = fn;
        functions.put(name, info);
    }

    // ----------------------------------------------------------------------

    private static class FnInfo {
        public String name;
        public String privilege;
        public PlatformFunction fn;
    };

    private static HashMap<String, FnInfo> functions = new HashMap<String, FnInfo>();
}
