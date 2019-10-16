/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.template;

import org.mozilla.javascript.Scriptable;

import org.haplo.template.driver.rhinojs.JSPlatformIntegration;
import org.haplo.template.html.Driver;
import org.haplo.javascript.Runtime;
import org.haplo.jsinterface.KHost;


public class TemplateTextTranslatorFactory implements JSPlatformIntegration.JSTextTranslatorFactory {
    public Driver.TextTranslator getTextTranslator(Scriptable owner, String category) {
        Object pluginName = owner.get("pluginName", owner); // ConsString is checked
        if(!(pluginName instanceof CharSequence)) {
            throw new RuntimeException("Template owner does not appear to be a plugin");
        }
        KHost host = Runtime.getCurrentRuntime().getHost();
        // TODO: More efficient way of getting current locale and lookup object in Template text translation?
        String locale = host.jsFunction_i18n_getCurrentLocaleId();
        Scriptable lookup = host.jsFunction_i18n_getRuntimeStringsForPlugin(pluginName.toString(), locale, category);
        return new PluginTextTranslator(lookup);
    }

    // ----------------------------------------------------------------------

    private static class PluginTextTranslator implements Driver.TextTranslator {
        private Scriptable lookup;

        PluginTextTranslator(Scriptable lookup) {
            this.lookup = lookup;
        }

        public String getLocaleId() {
            // TODO: More efficient way of getting current locale in Template text translation?
            return Runtime.getCurrentRuntime().getHost().jsFunction_i18n_getCurrentLocaleId();
        }

        public String translate(String category, String text) {
            // Ignore category, as the JS interface will only call it with the category given in the JSPlatformIntegration factory
            return (String)this.lookup.get(text, this.lookup); // ConsString is checked
        }
    }
}
