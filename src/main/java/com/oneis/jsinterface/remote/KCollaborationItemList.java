/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface.remote;

import com.oneis.javascript.Runtime;
import com.oneis.javascript.OAPIException;
import com.oneis.jsinterface.KScriptable;
import org.mozilla.javascript.*;

import com.oneis.jsinterface.remote.app.*;

public class KCollaborationItemList extends KScriptable {
    private AppCollaborationItemList itemList;

    public KCollaborationItemList() {
    }

    public void setItemList(AppCollaborationItemList itemList) {
        this.itemList = itemList;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$CollaborationItemList";
    }

    // --------------------------------------------------------------------------------------------------------------
    static public Scriptable fromAppCollaborationItemList(AppCollaborationItemList appObj) {
        KCollaborationItemList itemList = (KCollaborationItemList)Runtime.getCurrentRuntime().createHostObject("$CollaborationItemList");
        itemList.setItemList(appObj);
        return itemList;
    }

    // --------------------------------------------------------------------------------------------------------------
    public Scriptable jsFunction_where(String propertyName, String comparison, Object value) {
        if((value != null) && (value instanceof CharSequence)) {
            value = ((CharSequence)value).toString();
        }
        this.itemList.where(propertyName, comparison, value);
        return this; // for chaining
    }

    // --------------------------------------------------------------------------------------------------------------
    public int jsGet_length() {
        return this.itemList.getItemCount();
    }

    public int jsGet_currentPageOffset() {
        return this.itemList.getCurrentPageOffset();
    }

    public int jsGet_currentPageLength() {
        return this.itemList.getCurrentPageCount();
    }

    @Override
    public boolean has(int index, Scriptable start) {
        return (index >= 0 && index < this.itemList.getItemCount());
    }

    @Override
    public Object get(int index, Scriptable start) {
        AppCollaborationItem item = this.itemList.getItemAtIndex(index);
        if(item == null) {
            throw OAPIException.wrappedForScriptableGetMethod("Index out of range when fetching item.");
        }
        return KCollaborationItem.fromAppCollaborationItem(item);
    }
}
