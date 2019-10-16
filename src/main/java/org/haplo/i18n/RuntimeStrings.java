/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.i18n;

import java.util.Map;

// All the strings for a runtime for a single locale
public class RuntimeStrings {
    private Map<String,PluginStrings> plugins;
    private PluginStrings pluginWithoutLocals;

    protected RuntimeStrings(Map<String,PluginStrings> plugins, PluginStrings pluginWithoutLocals) {
        this.plugins = plugins;
        this.pluginWithoutLocals = pluginWithoutLocals;
    }

    public PluginStrings stringsForPlugin(String pluginName) {
        PluginStrings ps = this.plugins.get(pluginName);
        if(ps != null) { return ps; }
        return this.pluginWithoutLocals;
    }
}
