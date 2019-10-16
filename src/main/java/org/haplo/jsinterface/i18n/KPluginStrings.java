/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.i18n;

import org.mozilla.javascript.Scriptable;

import org.haplo.jsinterface.KScriptable;
import org.haplo.i18n.StringTranslate;
import org.haplo.javascript.Runtime;


public class KPluginStrings extends KScriptable implements StringTranslate.Fallback {
    private String plugin;
    private String localeId;
    private String category;
    private StringTranslate translate;
    private boolean haveSetupFallbackTranslate;
    private StringTranslate fallbackTranslate;

    public KPluginStrings() {
    }

    public void jsConstructor() {
    }

    public void setStrings(String plugin, String localeId, String category, StringTranslate translate) {
        this.plugin = plugin;
        this.localeId = localeId;
        this.category = category;
        this.translate = translate;
    }

    public String getClassName() {
        return "$PluginStrings";
    }

    protected String getConsoleData() {
        return "plugin "+this.plugin+", category "+this.category;
    }

    @Override
    public Object get(String name, Scriptable start) {
        if((this.translate == null) || "hasOwnProperty".equals(name)) {
            return super.get(name, start);
        }
        String translated = this.translate.get(name, this); // ConsString is checked
        if(-1 != translated.indexOf("NAME(")) {
            // This string needs NAME() interpolation
            // (don't do this for every string, as it's quite expensive to call into JS)
            String interpolated = Runtime.getCurrentRuntime().interpolateNAMEinString(translated);
            if(interpolated != null) { translated = interpolated; }
        }
        return translated;
    }

    public String fallback(String input) {
        if(!this.haveSetupFallbackTranslate) {
            this.fallbackTranslate = Runtime.getCurrentRuntime().
                getHost().
                i18n_getFallbackStringsForPlugin(this.plugin, this.localeId, this.category);
            this.haveSetupFallbackTranslate = true;
        }
        return this.haveSetupFallbackTranslate ? this.fallbackTranslate.get(input, null) : null;
    }
}
