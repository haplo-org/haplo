/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface.db;

import org.mozilla.javascript.Scriptable;

public class JdDynamicTable extends JdTable {
    private boolean didCreate;
    private boolean didChangeDatabase;

    public JdDynamicTable() {
    }

    public String getClassName() {
        return "$DbDynamicTable";
    }

    public void jsConstructor(String name, Scriptable fields, Scriptable methods) {
        super.jsConstructor(name, fields, methods);
    }

    // --------------------------------------------------------------------------------------------------------------

    @Override
    protected void postSetupStorage(boolean didCreate, boolean didChangeDatabase) {
        this.didCreate = didCreate;
        this.didChangeDatabase = didChangeDatabase;
    }

    public boolean jsGet_wasCreated() {
        return this.didCreate;
    }

    public boolean jsGet_databaseSchemaChanged() {
        return this.didChangeDatabase;
    }
}
