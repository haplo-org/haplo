/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * (c) Avalara 2022
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.db;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;
import org.haplo.javascript.JsGet;
import org.haplo.jsinterface.KScriptable;
import org.mozilla.javascript.*;

import java.util.ArrayList;
import java.sql.PreparedStatement;

import org.haplo.jsinterface.KUser; // For some User related utility methods

public class JdSelectClause extends KScriptable {
    private JdSelectClause parentClause;
    protected JdTable table;
    private ArrayList<WhereClause> whereClauses;
    private boolean isAndClause;

    private static final String[] ACCEPTABLE_WHERE_COMPARISION = {"=", "<", ">", "<=", ">=", "<>", "LIKE"}; // also != is translated to <>

    public JdSelectClause() {
        this.isAndClause = true;
    }

    public String getClassName() {
        return "$DbSelectClause";
    }

    public void setParentClause(JdSelectClause parentClause) {
        this.parentClause = parentClause;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor(JdTable table, boolean isAndClause) {
        this.table = table;
        this.isAndClause = isAndClause;
    }

    // --------------------------------------------------------------------------------------------------------------
    // API for describing queries
    public Scriptable jsFunction_where(String qualifiedFieldName, String comparison, Object value) {
        return whereImpl(qualifiedFieldName, null, comparison, value);
    }

    // TODO: Add JSON property indexing so whereJSONProperty() is fast (currently should only be used if you've done other where() clauses)
    // TODO: Better and generic API for whereJSONProperty(), eg q.where(q.fn("json:property", "field", "property"))
    public Scriptable jsFunction_whereJSONProperty(String qualifiedFieldName, String jsonProperty, String comparison, Object value) {
        return whereImpl(qualifiedFieldName, jsonProperty, comparison, value);
    }

    private Scriptable whereImpl(String qualifiedFieldName, String jsonProperty, String comparison, Object value) {
        checkNotExecutedYet();

        // Be paranoid about String types
        if((value != null) && (value instanceof CharSequence)) {
            value = ((CharSequence)value).toString();
        }

        // Decoded info
        // 1) The field & table which is being compared (value field)
        String fieldName = null;
        JdTable fieldTable = null;
        JdTable.Field field = null;
        // 2) The field in this.table which is use for the join (join field)
        String joinFieldName = null;
        JdTable.LinkField joinField = null;

        // Does this require a join?
        int fieldNameDotIndex = qualifiedFieldName.indexOf('.');
        if(fieldNameDotIndex != -1) {
            // Split into join field and value field
            joinFieldName = qualifiedFieldName.substring(0, fieldNameDotIndex);
            fieldName = qualifiedFieldName.substring(fieldNameDotIndex + 1);
            // Look up and check
            JdTable.Field f = this.table.getField(joinFieldName);
            if(f == null || !(f instanceof JdTable.LinkField)) {
                throw new OAPIException("No link field '" + joinFieldName + "' in table '" + table.jsGet_name() + "' for where clause on " + qualifiedFieldName);
            }
            joinField = (JdTable.LinkField)f;
            // Look up the value field in the table of the value field
            fieldTable = this.table.getNamespace().getTable(joinField.getOtherTableName());
            // Make sure the table is included when this query is generated
            addIncludedTable(joinField);
        } else {
            fieldTable = this.table;
            fieldName = qualifiedFieldName;
        }

        // Validate the field name
        field = fieldTable.getFieldOrGenericIdField(fieldName);
        if(field == null) {
            throw new OAPIException("Bad field '" + fieldName + "' for table '" + fieldTable.jsGet_name() + "'");
        }
        if((jsonProperty != null) && !(field.isJSONCompatible())) {
            throw new OAPIException("Cannot extract JSON property from '" + fieldName + "' for table '" + fieldTable.jsGet_name() + "'");
        }

        // Validate the comparison operator
        boolean comparisonOK = false;
        for(String operator : ACCEPTABLE_WHERE_COMPARISION) {
            if(operator.equals(comparison)) {
                comparisonOK = true;
                break;
            }
        }
        if(!comparisonOK) {
            if(comparison.equals("!=")) {
                comparison = "<>";
            } else if(comparison.equals("PERMIT READ") && field instanceof JdTable.LabelListField) {
                field = ((JdTable.LabelListField)field).fieldForPermitReadComparison();
            } else if((comparison.equals("CONTAINS ALL") || comparison.equals("CONTAINS SOME")) && field instanceof JdTable.LabelListField) {
                field = ((JdTable.LabelListField)field).fieldForContainsComparison();
            } else {
                throw new OAPIException("Bad comparison operator '" + comparison + "'");
            }
        }

        // If the value is a row of a database table, check it and convert it to the id value if possible
        if(field instanceof JdTable.LinkField) {
            JdTable.LinkField linkField = (JdTable.LinkField)field;
            if(value instanceof Scriptable) {
                // Obtain the table from the prototype of the object
                JdTable objectTable = (JdTable)JsGet.objectOfClass("$table", ((Scriptable)value).getPrototype(), JdTable.class);
                if(objectTable != null) {
                    if(!objectTable.jsGet_name().equals(linkField.getOtherTableName())) {
                        throw new OAPIException("Database row object from the wrong table passed to where() - should be "
                                + linkField.getOtherTableName());
                    }
                    // Looks good, get the id
                    Number id = JsGet.number("id", (Scriptable)value);
                    if(id == null) {
                        throw new OAPIException("Database row object hasn't be saved and can't be used in a where() clause.");
                    }
                    // Replace the value with this id.
                    value = id;
                }
            }
        }

        // Value need to be transformed in SQL?
        JdTable.ValueTransformer valueTransformer = null;
        if(jsonProperty != null) {
            valueTransformer = new JdTable.ValueTransformer() {
                public String transform(String sqlValue) {
                    return "json_extract_path_text(("+sqlValue+")::json,?)";
                }
                public int setWhereValue(JdTable.Field field, int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
                    statement.setString(parameterIndex, jsonProperty);
                    return field.setWhereValue(parameterIndex+1, statement, value);
                }
            };
        }

        // Validate the value
        if(!(field.jsObjectIsCompatibleForWhereClause(value, valueTransformer))) {
            throw new OAPIException("Comparison value for field '" + fieldName + "' "
                    + ((value == null) ? "must not be null as this field is not marked as nullable" : "is not a compatible data type."));
        }
        if(value != null) {
            field.checkNonNullJsObjectForComparison(value, comparison);
        }

        // Add the clause to the list
        addWhereClause(new WhereClause(joinField, field, valueTransformer, comparison, value));

        return this;
    }

    public Scriptable jsFunction_whereMemberOfGroup(String fieldName, int groupId) {
        // TODO: Support whereMemberOfGroup on joined fields in JS database API

        // Checks on input
        checkNotExecutedYet();
        JdTable.Field field = this.table.getField(fieldName);
        if(field == null) {
            throw new OAPIException("Bad field '" + fieldName + "' for table '" + table.jsGet_name() + "'");
        }
        if(!(field instanceof JdTable.UserField)) {
            throw new OAPIException("Field '" + fieldName + "' is not of type user for whereMemberOfGroup query on table '" + table.jsGet_name() + "'");
        }

        // Add the clause to the list
        addWhereClause(new WhereUserIsMemberOfClause(field, groupId));

        return this;
    }

    public Scriptable jsFunction_and(Object arg) {
        return doWhereSubClause(arg, true /* is AND clause */);
    }

    public Scriptable jsFunction_or(Object arg) {
        return doWhereSubClause(arg, false /* not AND clause */);
    }

    protected Scriptable doWhereSubClause(Object arg, boolean isAndClause) {
        checkNotExecutedYet();
        // Make the subclause and add it to the list
        Runtime runtime = Runtime.getCurrentRuntime();
        JdSelectClause subClause = (JdSelectClause)runtime.createHostObject("$DbSelectClause", this.table, isAndClause);
        subClause.setParentClause(this);
        addWhereClause(new WhereSubClauseClause(subClause));
        // Either pass it to a function given in the args, or return it
        if((arg != null) && (arg instanceof Function)) {
            Function subClauseCompleter = (Function)arg;
            subClauseCompleter.call(runtime.getContext(), subClauseCompleter, subClauseCompleter, new Object[]{subClause});
            // If called with the function argument, return this for chaining
            return this;
        } else {
            // If it's not called with a function argument, return the subclause
            return subClause;
        }
    }

    protected void addWhereClause(WhereClause clause) {
        if(whereClauses == null) {
            whereClauses = new ArrayList<WhereClause>(4);
        }
        whereClauses.add(clause);
    }

    // --------------------------------------------------------------------------------------------------------------
    // API for JdTable
    protected String generateWhereSql(String tableAlias) {
        if(this.whereClauses == null) {
            return null; // No WHERE clause in the query
        }

        StringBuilder where = new StringBuilder();
        appendWhereSql(where, tableAlias);
        return where.toString();
    }

    protected void appendWhereSql(StringBuilder where, String tableAlias) {
        boolean first = true;
        for(WhereClause w : this.whereClauses) {
            if(first) {
                first = false;
            } else {
                where.append(this.isAndClause ? " AND " : " OR ");
            }

            w.appendWhereSql(where, tableAlias);
        }
    }

    protected void setWhereValues(PreparedStatement statement) throws java.sql.SQLException {
        if(this.whereClauses == null) {
            return;
        }

        setWhereValues2(1, statement);
    }

    protected int setWhereValues2(int parameterIndex, PreparedStatement statement) throws java.sql.SQLException {
        for(WhereClause w : this.whereClauses) {
            parameterIndex = w.setWhereValue(parameterIndex, statement);
        }
        return parameterIndex;
    }

    // --------------------------------------------------------------------------------------------------------------
    protected void checkNotExecutedYet() {
        if(this.parentClause != null) {
            this.parentClause.checkNotExecutedYet();
        }
    }

    protected void addIncludedTable(JdTable.LinkField field) {
        if(this.parentClause != null) {
            this.parentClause.addIncludedTable(field);
        } else {
            throw new RuntimeException("Internal error: Parent clause not set");
        }
    }

    protected boolean hasNoWhereClauses() {
        return (this.whereClauses == null) || (this.whereClauses.size() == 0);
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class WhereClause {
        public final JdTable.LinkField joinField;
        public final JdTable.Field field;
        public final JdTable.ValueTransformer valueTransformer;
        public final String comparison;
        public final Object value;

        WhereClause(JdTable.LinkField joinField, JdTable.Field field, JdTable.ValueTransformer valueTransformer, String comparison, Object value) {
            this.joinField = joinField;
            this.field = field;
            this.valueTransformer = valueTransformer;
            this.comparison = comparison;
            this.value = value;
        }

        public void appendWhereSql(StringBuilder where, String tableAlias) {
            // If this is in a joined table, use the alias for that join, not the main table alias
            String ta = (this.joinField != null) ? this.joinField.getNameForQueryAlias() : tableAlias;
            this.field.appendWhereSql(where, ta, this.comparison, this.value, this.valueTransformer);
        }

        public int setWhereValue(int parameterIndex, PreparedStatement statement) throws java.sql.SQLException {
            if(this.valueTransformer != null) {
                return valueTransformer.setWhereValue(this.field, parameterIndex, statement, this.value);
            } else {
                return this.field.setWhereValue(parameterIndex, statement, this.value);
            }
        }
    }

    private static class WhereSubClauseClause extends WhereClause {
        private JdSelectClause subClause;

        WhereSubClauseClause(JdSelectClause subClause) {
            super(null, null, null, null, null);
            this.subClause = subClause;
        }

        @Override
        public void appendWhereSql(StringBuilder where, String tableAlias) {
            if(this.subClause.hasNoWhereClauses()) {
                throw new OAPIException("Sub-clauses must have at least one where() clause.");
            }
            where.append("(");
            this.subClause.appendWhereSql(where, tableAlias);
            where.append(")");
        }

        public int setWhereValue(int parameterIndex, PreparedStatement statement) throws java.sql.SQLException {
            return this.subClause.setWhereValues2(parameterIndex, statement);
        }
    }

    private static class WhereUserIsMemberOfClause extends WhereClause {
        public final int groupId;

        WhereUserIsMemberOfClause(JdTable.Field field, int groupId) {
            super(null, field, null, null, null);
            this.groupId = groupId;
        }

        @Override
        public void appendWhereSql(StringBuilder where, String tableAlias) {
            // Ask the Ruby code to make the required SQL, via the KUser class
            where.append(KUser.makeWhereClauseForIsMemberOf(tableAlias + "." + this.field.getDbName(), this.groupId));
        }

        @Override
        public int setWhereValue(int parameterIndex, PreparedStatement statement) throws java.sql.SQLException {
            return parameterIndex;
        }
    }
}
