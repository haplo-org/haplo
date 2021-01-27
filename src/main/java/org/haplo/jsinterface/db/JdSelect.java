/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.db;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;
import org.haplo.jsinterface.KScriptable;
import org.mozilla.javascript.*;

import java.util.ArrayList;
import java.util.HashMap;

public class JdSelect extends JdSelectClause {
    private Scriptable[] results;
    private boolean stableOrder;
    private ArrayList<Ordering> orderBy;
    private ArrayList<JdTable.LinkField> includes;
    private int limit;
    private int offset;

    private static final int NO_LIMIT = -1;

    private static final String GENERIC_SQL_ERROR = "Couldn't execute SQL (does the underlying database table need migrating?) - ";

    private static final String GROUP_BY_FIELD_WRONG_TYPE_MSG = "Group by field name must be a String or an Array of Strings";

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
        JdTable.Field field = this.table.getFieldOrGenericIdField(fieldName);
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
    public Object jsFunction_count() {
        try {
            return this.table.executeSingleValueExpressionUsingTrustedSQL(this, "COUNT(*)", JdTable.SingleValueKind.BIGINT, java.sql.Types.BIGINT, null);
        } catch(java.sql.SQLException e) {
            throw new OAPIException(GENERIC_SQL_ERROR + e.getMessage(), e);
        }
    }

    // Calculates an aggregate function
    public Object jsFunction_aggregate(String functionName, String fieldName, Object groupByFieldNames) {
        if(functionName == null || fieldName == null) {
            throw new OAPIException("Must pass function and field names to aggregate()");
        }
        if(groupByFieldNames instanceof Undefined) {
            groupByFieldNames = null;
        }
        // Security: Validate field and function names
        JdTable.Field field = this.table.getFieldOrGenericIdField(fieldName);
        if(field == null) {
            throw new OAPIException("Unknown field '"+fieldName+"' passed to aggregate()");
        }
        JdTable.SingleValueKind valueKind = ALLOWED_AGGREGATE_FNS.get(functionName);
        if(valueKind == null) {
            throw new OAPIException("Unknown aggregate function '"+functionName+"' passed to aggregate(). Function names are all caps.");
        }
        // Now safe to generate SQL expression
        String sqlExpression = functionName+"("+field.getDbName()+")";
        // Group by?
        Object[] fieldNameElements = null;

        if(groupByFieldNames instanceof CharSequence) {
            fieldNameElements = new Object[] { groupByFieldNames };
        } else if(groupByFieldNames instanceof Scriptable) {
            Scriptable groupsAsScriptable = (Scriptable)groupByFieldNames;
            fieldNameElements = Runtime.getCurrentRuntime().getContext().getElements(groupsAsScriptable);
            if(fieldNameElements.length == 0) {
                throw new OAPIException(GROUP_BY_FIELD_WRONG_TYPE_MSG);
            }
        } else if(groupByFieldNames != null) {
            throw new OAPIException(GROUP_BY_FIELD_WRONG_TYPE_MSG);
        }

        JdTable.Field groupByFields[] = null;

        if(fieldNameElements != null) {
            groupByFields = new JdTable.Field[fieldNameElements.length];
            int elementIndex = 0;
            for(Object element : fieldNameElements) {
                if(element instanceof CharSequence) {
                    String groupFieldName = element.toString();
                    JdTable.Field groupByField = this.table.getField(groupFieldName);
                    if(groupByField != null) {
                        if(groupByField.isSingleColumn()) {
                            groupByFields[elementIndex++] = groupByField;
                        } else {
                            throw new OAPIException("Group by field must not be a column of type File");
                        }
                    } else {
                        throw new OAPIException("Unknown group by field "+groupFieldName+" passed to aggregate()");
                    }
                } else {
                    throw new OAPIException(GROUP_BY_FIELD_WRONG_TYPE_MSG);
                }
            }
        }
        // Execute query
        try {
            return this.table.executeSingleValueExpressionUsingTrustedSQL(this, sqlExpression, valueKind, field.jdbcDataType(), groupByFields);
        } catch(java.sql.SQLException e) {
            throw new OAPIException(GENERIC_SQL_ERROR + e.getMessage(), e);
        }
    }

    private static HashMap<String,JdTable.SingleValueKind> ALLOWED_AGGREGATE_FNS = new HashMap<String,JdTable.SingleValueKind>(16) {{
        put("AVG",          JdTable.SingleValueKind.NUMERIC_OR_DOUBLE);
        put("COUNT",        JdTable.SingleValueKind.BIGINT);
        put("MAX",          JdTable.SingleValueKind.NUMERIC_OR_DOUBLE);
        put("MIN",          JdTable.SingleValueKind.NUMERIC_OR_DOUBLE);
        put("SUM",          JdTable.SingleValueKind.NUMERIC_OR_DOUBLE);
        put("STDDEV_POP",   JdTable.SingleValueKind.NUMERIC_OR_DOUBLE);
        put("STDDEV_SAMP",  JdTable.SingleValueKind.NUMERIC_OR_DOUBLE);
        put("VAR_POP",      JdTable.SingleValueKind.NUMERIC_OR_DOUBLE);
        put("VAR_SAMP",     JdTable.SingleValueKind.NUMERIC_OR_DOUBLE);
    }};

    // --------------------------------------------------------------------------------------------------------------
    // Updating rows
    public int jsFunction_update(Scriptable values) {
        try {
            // Run the values through the JS row constructor, so values checked and are the correct type for the column
            Scriptable row = this.table.jsFunction_create(values);
            Scriptable rowValues = (Scriptable)Runtime.createHostObjectInCurrentRuntime("Object");
            Scriptable transformedValues = (Scriptable)row.get("$values", row);
            for(Object fieldId : values.getIds()) {
                if(fieldId instanceof String) { // ConsString is checked
                    String fieldName = (String)fieldId; // ConsString is checked
                    JdTable.Field field = this.table.getField(fieldName);
                    if(field == null) {
                        throw new OAPIException("Bad field '" + fieldName + "' for table '" + this.table.jsGet_name() + "'");
                    }
                    rowValues.put(fieldName, rowValues, transformedValues.get(fieldName, transformedValues));
                }
            }
            return this.table.executeUpdate(this, rowValues);
        } catch(java.sql.SQLException e) {
            throw new OAPIException(GENERIC_SQL_ERROR + e.getMessage(), e);
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    // Deleting rows
    public int jsFunction_deleteAll() {
        try {
            return this.table.executeDelete(this);
        } catch(java.sql.SQLException e) {
            throw new OAPIException(GENERIC_SQL_ERROR + e.getMessage(), e);
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
                throw new OAPIException(GENERIC_SQL_ERROR + e.getMessage(), e);
            }
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    // API for JdTable
    protected JdTable.LinkField[] getIncludes() {
        return (this.includes == null) ? null : this.includes.toArray(new JdTable.LinkField[this.includes.size()]);
    }

    protected String generateOrderSql(String tableAlias) {
        // The behaviour of silently ignoring use of stableOrder() if order() used as well
        // is relied upon by several consumers of this API, in particular std_workflow.
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
