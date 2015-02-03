/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface.remote.app;

public interface AppCollaborationItemList {
    public void where(String propertyName, String comparison, Object value);

    public int getItemCount();

    public int getCurrentPageOffset();

    public int getCurrentPageCount();

    public AppCollaborationItem getItemAtIndex(int index);
}
