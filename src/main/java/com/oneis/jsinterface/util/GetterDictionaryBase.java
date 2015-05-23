/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface.util;

import com.oneis.jsinterface.KScriptable;

import org.mozilla.javascript.*;

public class GetterDictionaryBase extends KScriptable {
    private Function getterFunction;
    private String suffixSeparator;

    public GetterDictionaryBase() {
    }

    public void jsConstructor(Function getterFunction, Object suffixSeparator) {
        this.getterFunction = getterFunction;
        if(suffixSeparator != null && (suffixSeparator instanceof CharSequence)) {
            this.suffixSeparator = suffixSeparator.toString();
        }
    }

    public String getClassName() {
        return "$GetterDictionaryBase";
    }

    protected String getConsoleData() {
        return "...";
    }

    @Override
    public Object get(String name, Scriptable start) {
        // Not the prototype?
        if(this.getterFunction == null) {
            return super.get(name, start);
        }
        // See if it has a suffix
        String queryName = name;
        String suffix = null;
        if(this.suffixSeparator != null) {
            int separatorIndex = name.lastIndexOf(this.suffixSeparator);
            if(separatorIndex != -1) {
                queryName = name.substring(0, separatorIndex);
                suffix = name.substring(separatorIndex + this.suffixSeparator.length());
            }
        }
        // Call the getter function to find the value
        Object value = this.getterFunction.call(
            Context.getCurrentContext(),
            this.getterFunction.getParentScope(),
            start,
            (suffix != null) ? new Object[] {queryName,suffix} : new Object[] {queryName}
        );
        if((value == null) || (value instanceof org.mozilla.javascript.Undefined)) {
            return value;   // don't set value
        }
        // Set the value in the start object so the getter function isn't called next time
        start.put(name, start, value);
        return value;
    }
}
