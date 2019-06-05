/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.app;

public interface AppObjectAttributeGroups {

    public AppObject ungrouped_attributes();

    public GroupEntry[] groups();

    public interface GroupEntry {
        public int desc();
        public int group_id();
        public AppObject object();
    }
}
