/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.remote;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;
import org.haplo.jsinterface.KScriptable;
import org.mozilla.javascript.*;

import org.haplo.jsinterface.remote.app.*;

public class KCollaborationFolder extends KScriptable {
    private AppCollaborationFolder folder;

    public KCollaborationFolder() {
    }

    public void setFolder(AppCollaborationFolder folder) {
        this.folder = folder;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$CollaborationFolder";
    }

    // --------------------------------------------------------------------------------------------------------------
    static public Scriptable fromAppCollaborationFolder(AppCollaborationFolder appObj) {
        KCollaborationFolder folder = (KCollaborationFolder)Runtime.getCurrentRuntime().createHostObject("$CollaborationFolder");
        folder.setFolder(appObj);
        return folder;
    }

    // --------------------------------------------------------------------------------------------------------------
    public String jsGet_id() {
        return this.folder.getId();
    }

    public String jsGet_displayName() {
        return this.folder.getDisplayName();
    }

    // --------------------------------------------------------------------------------------------------------------
    public Scriptable jsFunction_find() {
        return KCollaborationItemList.fromAppCollaborationItemList(this.folder.findAllItems());
    }

    public Scriptable jsFunction_findAllItems() {
        return jsFunction_find();   // Because find() returns something which will search for all items by default.
    }
}
