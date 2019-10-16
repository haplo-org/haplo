/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.i18n;

import java.util.Map;

// The strings in categories for a single plugin
public class PluginStrings {
    private Map<String,StringTranslate> locals;
    private Map<String,StringTranslate> globals;

    protected PluginStrings(Map<String,StringTranslate> locals, Map<String,StringTranslate> globals) {
        this.locals = locals;
        this.globals = globals;
    }

    public StringTranslate getCategory(String category) {
        if(this.locals != null) {
            StringTranslate ps = this.locals.get(category);
            if(ps != null) { return ps; }
        }
        if(this.globals != null) {
            StringTranslate gs = this.globals.get(category);
            if(gs != null) { return gs; }
        }
        return StringTranslateImpl.NULL_TRANSLATION;
    }
}
