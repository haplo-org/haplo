/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface.db;

import com.oneis.javascript.Runtime;
import com.oneis.javascript.OAPIException;
import com.oneis.javascript.JsGet;
import com.oneis.jsinterface.KONEISHost;
import com.oneis.jsinterface.KScriptable;
import org.mozilla.javascript.*;

import java.util.regex.Pattern;
import java.util.ArrayList;

import java.sql.Connection;

public class JdNamespace extends KScriptable {
    private String name;
    private String postgresSchemaName;
    private ArrayList<JdTable> tables;

    public JdNamespace() {
        this.tables = new ArrayList<JdTable>();
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
        // The namespace name isn't passed into any constructor to ensure that only trusted code sets namespace names.
        KONEISHost host = Runtime.currentRuntimeHost();
        String nextNamespace = host.getNextDatabaseNamespace();
        if(nextNamespace == null) {
            throw new RuntimeException("No new database namespace is expected to be created.");
        }
        this.name = nextNamespace;
        this.postgresSchemaName = host.getSupportRoot().getPostgresSchemaName();
    }

    public String getClassName() {
        return "$DbNamespace";
    }

    // --------------------------------------------------------------------------------------------------------------
    public String getName() {
        return name;
    }

    public String getPostgresSchemaName() {
        if(this.postgresSchemaName == null) {
            throw new RuntimeException("No postgresSchemaName set");
        }
        return postgresSchemaName;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsFunction_table(String name, Scriptable fields, Scriptable methods) {
        JdNamespace.checkNameIsAllowed(name);
        if(this.has(name, this)) {
            throw new OAPIException("Database table '"+name+"' has already been declared.");
        }
        JdTable table = (JdTable)Runtime.createHostObjectInCurrentRuntime("$DbTable", name, fields, methods);
        table.setNamespace(this);
        this.tables.add(table);
        this.put(name, this, table);
    }

    // Experimental API for tables which have fields defined at runtime, rather than statically defined
    // when the plugin is written.
    public Scriptable jsFunction__dynamicTable(String name, Scriptable fields, Scriptable methods) {
        Runtime.privilegeRequired("pDatabaseDynamicTable", "use database dynamic tables");
        JdNamespace.checkNameIsAllowed(name);
        JdDynamicTable table = (JdDynamicTable)Runtime.createHostObjectInCurrentRuntime("$DbDynamicTable", name, fields, methods);
        table.setNamespace(this);
        try {
            table.setupStorage(Runtime.currentRuntimeHost().getSupportRoot().getJdbcConnection());
        } catch(java.sql.SQLException e) {
            throw new OAPIException("Couldn't setup SQL storage: " + e.getMessage(), e);
        }
        return table;
    }

    public void setupStorage() {
        try {
            // Get the database
            Connection db = Runtime.currentRuntimeHost().getSupportRoot().getJdbcConnection();

            // Ask each table to make sure it's created
            for(JdTable table : tables) {
                table.setupStorage(db);
            }
        } catch(java.sql.SQLException e) {
            throw new RuntimeException("Couldn't setup SQL storage: " + e.getMessage(), e);
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    public JdTable getTable(String name) {
        return (JdTable)JsGet.objectOfClass(name, this, JdTable.class);
    }

    // --------------------------------------------------------------------------------------------------------------
    // allowedNameRegex must NEVER allow a _ prefix, otherwise field names could clash as _ is added if it's a reserved keyword.
    private static Pattern allowedNameRegex = Pattern.compile("\\A[a-z][a-zA-Z0-9]*\\z");

    static void checkNameIsAllowed(String name) {
        if(!(allowedNameRegex.matcher(name).matches())) {
            throw new OAPIException("Database table or column name '" + name + "' is not allowed. Names must begin with a-z and be composed of a-zA-Z0-9 only.");
        }
    }
}
