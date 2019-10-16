/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.i18n;

import java.util.Map;

// Translation of string to string
class StringTranslateImpl implements StringTranslate {
    private Map<String,String> local;
    private Map<String,String> global;

    protected static final StringTranslate NULL_TRANSLATION = new StringTranslateImpl(null, null);

    protected StringTranslateImpl(Map<String,String> local, Map<String,String> global) {
        this.local = local;
        this.global = global;
    }

    public String get(String input, StringTranslate.Fallback fallback) {
        if(this.local != null) {
            String lv = this.local.get(input);
            if(lv != null) { return lv; }
        }
        if(this.global != null) {
            String gv = this.global.get(input);
            if(gv != null) { return gv; }
        }
        if(fallback != null) {
            String fb = fallback.fallback(input);
            if(fb != null) { return fb; }
        }
        return input;
    }

}
