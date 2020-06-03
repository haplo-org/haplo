/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.app;

public interface AppDateTime {
    public String precision();

    public String timezone();

    public class DTRange {
        public long start;
        public long end;
    }

    public DTRange jsGetRange();

    public boolean jsSpecifiedAsRange();

    public String to_s();

    public String to_html();
}
