/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface;

import org.mozilla.javascript.JavaScriptException;
import org.mozilla.javascript.Scriptable;

import com.oneis.javascript.Runtime;

public class KSessionStore extends JSONBackedKeyValueStore {
    private boolean isStore;

    public KSessionStore() {
        this.isStore = false;
    }

    public void setIsRealSessionStore() {
        // Needed so it can be distinguished from the prototype object
        this.isStore = true;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$SessionStore";
    }

    // --------------------------------------------------------------------------------------------------------------
    @Override
    public void put(String name, Scriptable start, Object value) {
        if(!isPrototypeObject()) {
            if(name.indexOf(':') < 1) {
                throw new JavaScriptException("Keys for O.session must start with the plugin name followed by a : to avoid collisions.",
                        "O.session", -1);
            }
        }
        super.put(name, start, value);
    }

    // --------------------------------------------------------------------------------------------------------------
    @Override
    protected boolean isPrototypeObject() {
        return !this.isStore;
    }

    @Override
    protected String getJSON() {
        return Runtime.currentRuntimeHost().getSupportRoot().getSessionJSON();
    }

    @Override
    protected void setJSON(String json) {
        Runtime.currentRuntimeHost().getSupportRoot().setSessionJSON(json);
    }

    @Override
    protected String nameOfStoreForException() {
        return "session";
    }
}
