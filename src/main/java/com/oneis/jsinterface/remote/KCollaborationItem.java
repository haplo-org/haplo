/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface.remote;

import com.oneis.javascript.Runtime;
import com.oneis.javascript.OAPIException;
import com.oneis.jsinterface.KScriptable;
import org.mozilla.javascript.*;

import com.oneis.jsinterface.remote.app.*;

public class KCollaborationItem extends KScriptable {
    private AppCollaborationItem item;

    public KCollaborationItem() {
    }

    public void setItem(AppCollaborationItem item) {
        this.item = item;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$CollaborationItem";
    }

    // --------------------------------------------------------------------------------------------------------------
    static public Scriptable fromAppCollaborationItem(AppCollaborationItem appObj) {
        KCollaborationItem item = (KCollaborationItem)Runtime.getCurrentRuntime().createHostObject("$CollaborationItem");
        item.setItem(appObj);
        return item;
    }

    // --------------------------------------------------------------------------------------------------------------
    @Override
    public boolean has(String name, Scriptable start) {
        return name.equals("id") || this.item.hasProperty(name);
    }

    @Override
    public Object get(String name, Scriptable start) {
        // The implementation of the AppCollaborationItem interface knows how to convert properties to JavaScript compatible objects
        return name.equals("id") ? this.item.getId() : this.item.getProperty(name);
    }
}
