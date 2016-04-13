/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.mozilla.javascript.*;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;
import org.haplo.jsinterface.app.*;

public class KQueryResults extends KScriptable {
    private AppQueryResults results;
    private int length;
    private Scriptable[] objects;

    public KQueryResults() {
    }

    public void jsConstructor() {
    }

    public String getClassName() {
        return "$QueryResults";
    }

    public void setAppQueryResults(AppQueryResults results) {
        if(this.results != null) {
            throw new RuntimeException("AppQueryResults already set in KQueryResults");
        }
        this.results = results;
        this.length = results.length();
        this.objects = new Scriptable[this.length];
    }

    public AppQueryResults toRubyObject() {
        return this.results;
    }

    // --------------------------------------------------------------------------------------------------------------
    static public Scriptable fromAppQueryResults(AppQueryResults appResults) {
        KQueryResults r = (KQueryResults)Runtime.getCurrentRuntime().createHostObject("$QueryResults");
        r.setAppQueryResults(appResults);
        return r;
    }

    // --------------------------------------------------------------------------------------------------------------
    public int jsGet_length() {
        return this.length;
    }

    @Override
    public boolean has(int index, Scriptable start) {
        return (index >= 0 && index < this.length);
    }

    @Override
    public java.lang.Object get(int index, Scriptable start) {
        if(index < 0 || index >= this.length) {
            throw OAPIException.wrappedForScriptableGetMethod("Index out of range for StoreQueryResults (requested index " + index + " for results of length " + this.length + ")");
        }
        if(objects[index] == null) {
            objects[index] = KObject.fromAppObject(this.results.jsGet(index), false /* not mutable */);
        }
        return objects[index];
    }

    // Calls iterator with (obj, index). Stops if iterator returns true.
    public void jsFunction_each(Function iterator) {
        if(iterator == null) {
            throw new OAPIException("Must pass an iterator to each()");
        }
        Runtime runtime = Runtime.getCurrentRuntime();
        for(int i = 0; i < this.length; i++) {
            Object r = iterator.call(runtime.getContext(), iterator, iterator, new Object[]{this.get(i, this), i}); // ConsString is checked
            if(r != null && (r instanceof Boolean) && ((Boolean)r).booleanValue()) {
                // Stop now
                return;
            }
        }
    }

    public void jsFunction_ensureRangeLoaded(int startIndex, int endIndex) {
        this.results.ensureRangeLoaded(startIndex, endIndex);
    }

    // --------------------------------------------------------------------------------------------------------------
}
