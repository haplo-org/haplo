/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.mozilla.javascript.*;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;

public class KObjectAttributeExtension extends KScriptable {
    private int desc;
    private int groupId;

    public KObjectAttributeExtension() {
    }

    public void jsConstructor() {
    }

    public String getClassName() {
        return "$StoreObjectAttributeExtension";
    }

    public String getConsoleData() {
        return "("+this.desc+","+this.groupId+")";
    }

    protected void setValues(int desc, int groupId) {
        this.desc = desc;
        this.groupId = groupId;
    }

    protected int getDesc()     { return this.desc; }
    protected int getGroupId()  { return this.groupId; }

    // ----------------------------------------------------------------------

    public int jsGet_desc() {
        return this.desc;
    }

    public int jsGet_groupId() {
        return this.groupId;
    }

}
