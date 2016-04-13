/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.mozilla.javascript.*;

import org.haplo.jsinterface.app.*;

public class KUserData extends JSONBackedKeyValueStore {
    private KUser user;

    public KUserData() {
    }

    public void setUser(KUser user) {
        this.user = user;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$UserData";
    }

    // --------------------------------------------------------------------------------------------------------------
    @Override
    public void put(String name, Scriptable start, Object value) {
        if(!isPrototypeObject()) {
            if(name.indexOf(':') < 1) {
                throw new JavaScriptException("Keys for user.data must start with the plugin name followed by a : to avoid collisions.",
                        "user.data", -1);
            }
        }
        super.put(name, start, value);
    }

    // --------------------------------------------------------------------------------------------------------------
    @Override
    protected boolean isPrototypeObject() {
        return this.user == null;
    }

    @Override
    protected String getJSON() {
        return this.user.getUserDataJSON();
    }

    @Override
    protected void setJSON(String json) {
        this.user.setUserDataJSON(json);
    }

    @Override
    protected String nameOfStoreForException() {
        return "user data";
    }
}
