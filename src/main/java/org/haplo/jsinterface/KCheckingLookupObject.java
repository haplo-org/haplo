/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.haplo.javascript.OAPIException;

import org.mozilla.javascript.Scriptable;

// A utiltity class which throws an exception when a user tries to get a value which is not defined.
// Used for the special SCHEMA object.
public class KCheckingLookupObject extends KScriptable {
    private String objectName;

    public void KCheckingLookupObject() {
        this.objectName = "<anonymous>";
    }

    public void jsConstructor(String name) {
        this.objectName = name;
    }

    public String getClassName() {
        return "$CheckingLookupObject";
    }

    public Object get(int index, Scriptable start) {
        Object got = super.get(index, start); // ConsString is checked
        if(got == NOT_FOUND) {
            throw OAPIException.wrappedForScriptableGetMethod("Nothing found when attempting to retrieve index " + index + " in " + this.objectName);
        }
        return got;
    }

    public Object get(java.lang.String name, Scriptable start) {
        Object got = super.get(name, start); // ConsString is checked
        if(got == NOT_FOUND) {
            throw OAPIException.wrappedForScriptableGetMethod("Nothing found when attempting to retrieve property '" + name + "' from " + this.objectName);
        }
        return got;
    }
}
