/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.util;

import org.haplo.jsinterface.KScriptable;
import org.haplo.jsinterface.KObjRef;
import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;

import org.mozilla.javascript.*;

public class WorkUnitTags extends KScriptable {
    private boolean hasTags; // not the prototype

    public WorkUnitTags() {
    }

    public void jsConstructor() {
    }

    public String getClassName() {
        return "$WorkUnitTags";
    }

    protected String getConsoleData() {
        return Runtime.getCurrentRuntime().jsonStringify(this);
    }

    public static WorkUnitTags fromScriptable(Scriptable scriptable) {
        Runtime runtime = Runtime.getCurrentRuntime();
        WorkUnitTags tags = (WorkUnitTags)runtime.createHostObjectInCurrentRuntime("$WorkUnitTags");
        tags.copyDataFrom(scriptable);
        return tags;
    }

    public void copyDataFrom(Scriptable scriptable) {
        if(scriptable != null) {
            for(Object id : scriptable.getIds()) {
                if(id instanceof CharSequence) {
                    this.put(id.toString(), this, scriptable.get(id.toString(), scriptable)); // ConsString is checked
                }
            }
        }
        this.hasTags = true;
    }

    @Override
    public void put(int index, Scriptable start, Object value) {
        if(this.hasTags) {
            throw new OAPIException("WorkUnit tags must have string keys.");
        } else {
            super.put(index, start, value);
        }
    }

    @Override
    public void put(String name, Scriptable start, Object value) {
        if(this.hasTags) {
            if(value == null || value instanceof org.mozilla.javascript.Undefined) {
                this.delete(name);
                return;
            } else if(value instanceof CharSequence) {
                value = value.toString();
            } else if(value instanceof KObjRef) {
                value = ((KObjRef)value).jsFunction_toString();
            } else {
                throw new OAPIException("Only Strings can be set as WorkUnit tags.");
            }
        }
        super.put(name, start, value);
    }
}
