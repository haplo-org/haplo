/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.javascript;

import org.mozilla.javascript.*;

class OSandboxedNativeJavaObject extends NativeJavaObject {
    public OSandboxedNativeJavaObject(Scriptable scope, Object javaObject, Class staticType) {
        super(scope, javaObject, staticType);
    }

    @Override
    public Object get(String name, Scriptable start) {
        // Don't allow access to Java Class classes, because it would allow new instances of Java objects to be created.
        if(name.equals("getClass") || name.equals("class")) {
            return NOT_FOUND;
        }
        return super.get(name, start);
    }
}
