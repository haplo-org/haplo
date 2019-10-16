/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.i18n;

import java.util.Map;

// Translation of string to string
public interface StringTranslate {
    public String get(String input, Fallback fallback);

    public interface Fallback {
        public String fallback(String input);
    }
}
