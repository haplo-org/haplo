/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.haplo.javascript.Runtime;

import org.mozilla.javascript.*;

// NOTE: Potential race conditions when multiple runtimes start modifying different values in the store and gettting unlucky with read and writes of the JSON of all values.
public abstract class JSONBackedKeyValueStore extends KScriptable {
    private Scriptable store;

    public JSONBackedKeyValueStore() {
    }

    public void clearCache() {
        this.store = null;
    }

    // --------------------------------------------------------------------------------------------------------------
    protected abstract boolean isPrototypeObject();

    protected abstract String getJSON();

    protected abstract void setJSON(String json);

    protected abstract String nameOfStoreForException();

    // --------------------------------------------------------------------------------------------------------------
    @Override
    public boolean has(int index, Scriptable start) {
        throw new JavaScriptException("Numeric indices cannot be used with " + nameOfStoreForException(), "stored_data", -1);
    }

    @Override
    public void put(int index, Scriptable start, Object value) {
        throw new JavaScriptException("Numeric indices cannot be used with " + nameOfStoreForException(), "stored_data", -1);
    }

    @Override
    public void delete(int index) {
        throw new JavaScriptException("Numeric indices cannot be used with " + nameOfStoreForException(), "stored_data", -1);
    }

    @Override
    public boolean has(String name, Scriptable start) {
        // If this is the prototype object, delegate to the super class
        if(isPrototypeObject()) {
            return super.has(name, start);
        }

        // Otherwise check the underlying store ScriptableObject
        ensureStoreLoaded();
        return this.store.has(name, this.store);
    }

    @Override
    public void put(String name, Scriptable start, Object value) {
        // put() will be called a few times when the prototype object is created
        if(isPrototypeObject()) {
            super.put(name, start, value);
            return;
        }

        ensureStoreLoaded();    // must load it before put(), otherwise the other value could be lost if there wasn't a get first.
        this.store.put(name, this.store, value);
        writeStore();
    }

    @Override
    public Object get(String name, Scriptable start) {
        // If this is the prototype object, delegate to the super class
        if(isPrototypeObject()) {
            return super.get(name, start);
        } // ConsString is checked

        // Otherwise read from the underlying store ScriptableObject
        ensureStoreLoaded();
        return this.store.get(name, this.store);
    }

    @Override
    public void delete(String name) {
        // If this is the prototype object, delegate to the super class
        if(isPrototypeObject()) {
            super.delete(name);
            return;
        }

        // Otherwise delete from the underlying store ScriptableObject, then write back
        ensureStoreLoaded();
        this.store.delete(name);
        writeStore();
    }

    // --------------------------------------------------------------------------------------------------------------
    private void ensureStoreLoaded() {
        // Nothing to do if the store has been loaded, or it's the prototype object
        if(this.store != null || isPrototypeObject()) {
            return;
        }

        Runtime runtime = Runtime.getCurrentRuntime();

        // Try to get some JSON encoded data from the Ruby runtime.
        String json = getJSON();
        if(json != null && json.length() > 0) {
            // Decode JSON
            Object decoded = null;
            try {
                decoded = runtime.makeJsonParser().parseValue(json);
            } catch(org.mozilla.javascript.json.JsonParser.ParseException e) {
                // Ignore
            }
            if(decoded != null && decoded instanceof Scriptable) {
                this.store = (Scriptable)decoded;
            }
        }

        // If it wasn't possible to load the data, create an empty object
        if(this.store == null) {
            this.store = runtime.createHostObject("Object");
        }
    }

    private void writeStore() {
        Runtime runtime = Runtime.getCurrentRuntime();
        setJSON(runtime.jsonStringify(this.store));
    }
}
