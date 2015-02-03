/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface.app;

public interface AppUser {
    public int id();

    public int kind();

    public boolean is_group();

    public boolean is_active();

    public String name();

    public String name_first();

    public String name_last();

    public String email();

    public AppObjRef objref();
}
