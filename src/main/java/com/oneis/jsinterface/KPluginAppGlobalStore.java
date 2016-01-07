/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface;

import org.mozilla.javascript.*;

// NOTE: Potential race conditions when multiple runtimes start modifying different values in the store and gettting unlucky with read and writes of the JSON of all values.
public class KPluginAppGlobalStore extends JSONBackedKeyValueStore {
    private String pluginName;
    private KONEISHost host;

    public KPluginAppGlobalStore() {
    }

    public void setPluginNameAndHost(String name, KONEISHost host) {
        // These are set in a function which is unreachable from JavaScript to make sure the values can be trusted.
        this.pluginName = name;
        this.host = host;
    }

    public void invalidateAllStoredData() {
        this.clearCache();
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$PluginStore";
    }

    // --------------------------------------------------------------------------------------------------------------
    @Override
    protected boolean isPrototypeObject() {
        return this.pluginName == null;
    }

    @Override
    protected String getJSON() {
        return this.host.readPluginAppGlobal(this.pluginName);
    }

    @Override
    protected void setJSON(String json) {
        this.host.savePluginAppGlobal(this.pluginName, json);
    }

    @Override
    protected String nameOfStoreForException() {
        return "the plugin store";
    }
}
