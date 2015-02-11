/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface.db;

import com.oneis.javascript.Runtime;
import com.oneis.javascript.OAPIException;
import com.oneis.jsinterface.KScriptable;
import org.mozilla.javascript.*;

import java.util.ArrayList;

public class JdSelect extends JdSelectClause {
    private Scriptable[] results;
    private boolean stableOrder;
    private ArrayList<Ordering> orderBy;
    private ArrayList<JdTable.LinkField> includes;
    private int limit;
    private int offset;

    private static final int NO_LIMIT = -1;

    public JdSelect() {
        this.stableOrder = false;
        this.limit = NO_LIMIT;
        this.offset = NO_LIMIT;
    }

    public String getClassName() {
        return "$DbSelect";
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor(JdTable table) {
        super.jsConstructor(table, true /* is AND clause */);
    }

    // --------------------------------------------------------------------------------------------------------------
    // API for describing queries
    public Scriptable jsFunction_order(String fieldName, boolean descending) {
        checkNotExecutedYet();
        JdTable.Field field = this.table.getField(fieldName);
        if(field == null) {
            throw new OAPIException("Field '" + fieldName + "' given to order() clause doesn't exist in table");
        }
        if(this.orderBy == null) {
            this.orderBy = new ArrayList<Ordering>(4);
        }
        this.orderBy.add(new Ordering(field, descending));
        return this;
    }

    // Return results in a stable ordering (order by id ascending)
    public Scriptable jsFunction_stableOrder() {
        checkNotExecutedYet();
        this.stableOrder = true;
        return this;
    }

    // Limit the number of results
    public Scriptable jsFunction_limit(int limit) {
        checkNotExecutedYet();
        if(limit < 0) {
            throw new OAPIException("Limit cannot be negative");
        }
        this.limit = limit;
        return this;
    }

    // Specify offset for the results
    public Scriptable jsFunction_offset(int offset) {
        checkNotExecutedYet();
        if(offset < 0) {
            throw new OAPIException("Offset cannot be negative");
        }
        this.offset = offset;
        return this;
    }

    // Load references to linked objects in a single query
    public Scriptable jsFunction_include(String fieldName) {
        checkNotExecutedYet();
        JdTable.Field field = this.table.getField(fieldName);
        if(field == null || !(field instanceof JdTable.LinkField)) {
            throw new OAPIException("Field '" + fieldName + "' does not exist or isn't a link field");
        }
        addIncludedTable((JdTable.LinkField)field);
        return this;
    }

    @Override
    protected void addIncludedTable(JdTable.LinkField field) {
        checkNotExecutedYet();
        if(this.includes == null) {
            this.includes = new ArrayList<JdTable.LinkField>(2);
        }
        for(JdTable.LinkField f : this.includes) {
            // Don't include the same field twice
            if(field == f) {
                return;
            }
        }
        this.includes.add(field);
    }

    // --------------------------------------------------------------------------------------------------------------
    // Getting the results
    public int jsGet_length() {
        executeQueryIfRequired();
        return this.results.length;
    }

    @Override
    public boolean has(int index, Scriptable start) {
        // Note: This doesn't trigger query execution to avoid doing the query too soon.
        return this.results != null && (index >= 0 && index < this.results.length);
    }

    @Override
    public Object get(int index, Scriptable start) {
        executeQueryIfRequired();
        if(index < 0 || index >= this.results.length) {
            return Context.getUndefinedValue();
        }
        return this.results[index];
    }

    // Calls the function once for each result with (object, index)
    public Scriptable jsFunction_each(Function iterator) {
        executeQueryIfRequired();
        Context context = Runtime.getCurrentRuntime().getContext();
        int i = 0;
        for(Scriptable result : this.results) {
            iterator.call(context, iterator, iterator, new Object[]{result, i});
            i++;
        }
        return this;
    }

    // Performs a COUNT(*) instead of selecting all the values
    public int jsFunction_count() {
        try {
            return this.table.executeCount(this);
        } catch(java.sql.SQLException e) {
            throw new OAPIException("Couldn't execute SQL query (does the underlying database table need migrating?)", e);
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    // Deleting rows
    public int jsFunction_deleteAll() {
        try {
            return this.table.executeDelete(this);
        } catch(java.sql.SQLException e) {
            throw new OAPIException("Couldn't execute SQL delete", e);
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    // Checking state and running queries
    @Override
    protected void checkNotExecutedYet() {
        if(this.results != null) {
            throw new OAPIException("Query has been executed, and cannot be modified.");
        }
    }

    private void executeQueryIfRequired() {
        if(this.results == null) {
            try {
                this.results = this.table.executeQuery(this);
            } catch(java.sql.SQLException e) {
                throw new OAPIException("Couldn't execute SQL query (does the underlying database table need migrating?)", e);
            }
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    // API for JdTable
    protected JdTable.LinkField[] getIncludes() {
        return (this.includes == null) ? null : this.includes.toArray(new JdTable.LinkField[this.includes.size()]);
    }

    protected String generateOrderSql(String tableAlias) {
        if(this.orderBy != null) {
            StringBuilder clause = new StringBuilder();
            for(Ordering o : this.orderBy) {
                if(clause.length() != 0) {
                    clause.append(',');
                }
                o.field.appendOrderSql(clause, tableAlias, o.descending);
            }
            if(this.stableOrder) {
                clause.append("," + tableAlias + ".id");
            }
            return clause.toString();
        } else if(this.stableOrder) {
            return tableAlias + ".id";
        }
        return null;
    }

    protected String generateLimitAndOffsetSql() {
        if(this.limit == NO_LIMIT && this.offset == NO_LIMIT) {
            return null;
        }
        String fragment = "";
        if(this.limit != NO_LIMIT) {
            fragment += " LIMIT " + this.limit;
        }
        if(this.offset != NO_LIMIT) {
            fragment += " OFFSET " + this.offset;
        }
        return fragment;
    }

    // --------------------------------------------------------------------------------------------------------------
    private static final class Ordering {
        public final JdTable.Field field;
        public final boolean descending;

        Ordering(JdTable.Field field, boolean descending) {
            this.field = field;
            this.descending = descending;
        }
    }
}
