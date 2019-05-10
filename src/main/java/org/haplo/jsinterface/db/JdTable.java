/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.db;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;
import org.haplo.javascript.JsGet;
import org.haplo.jsinterface.KScriptable;
import org.mozilla.javascript.*;

import java.math.BigDecimal;

import java.util.HashMap;
import java.util.HashSet;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;

import java.sql.Connection;
import java.sql.Statement;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

// JS host objects for field types
import org.haplo.jsinterface.KObjRef;
import org.haplo.jsinterface.KUser;
import org.haplo.jsinterface.KStoredFile;
import org.haplo.jsinterface.KLabelList;
import org.haplo.jsinterface.util.JsBigDecimal;

// TODO: Handle java.sql.SQLException exceptions? Or use a global method of turning exceptions into something presentable to the JS code?
public class JdTable extends KScriptable {
    private String dbName;
    private String jsName;
    private Function factory;
    private Field[] fields;
    private JdNamespace namespace;
    private String databaseTableName;

    public JdTable() {
    }

    public String getClassName() {
        return "$DbTable";
    }

    public void setNamespace(JdNamespace namespace) {
        this.namespace = namespace;
    }

    public JdNamespace getNamespace() {
        return this.namespace;
    }

    // --------------------------------------------------------------------------------------------------------------
    private String getDatabaseTableName() {
        if(databaseTableName == null) {
            if(this.dbName == null || this.namespace == null) {
                throw new RuntimeException("JdTable not set up correctly");
            }
            databaseTableName = ("j_" + this.namespace.getName() + "_" + this.dbName).toLowerCase();
        }
        return databaseTableName;
    }

    protected Field getField(String fieldName) {
        for(Field field : fields) {
            if(field.getJsName().equals(fieldName)) {
                return field;
            }
        }
        return null;
    }

    // where() and order() allow use of "id" as well as defined field names
    protected Field getFieldOrGenericIdField(String fieldName) {
        Field field = getField(fieldName);  // Try first so common path doesn't have "id" comparison
        if((field == null) && ("id".equals(fieldName))) {
            if(genericIdField == null) {
                genericIdField = new GenericIdField();
            }
            field = genericIdField;
        }
        return field;
    }
    // Use a shared generic id field definition for all tables
    private static GenericIdField genericIdField;

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor(String name, Scriptable fields, Scriptable methods) {
        Runtime runtime = Runtime.getCurrentRuntime();

        JdNamespace.checkNameIsAllowed(name);
        this.put("tableName", this, name);
        this.dbName = name.toLowerCase();
        this.jsName = name;

        // Run through the fields, creating the field objects
        ArrayList<Field> fieldList = new ArrayList<Field>(20);
        HashSet<String> nameChecks = new HashSet<String>();
        Object[] fieldNames = fields.getIds();
        int linkAliasNumber = 0;    // used for generating the alias names for linked fields, used in queries
        for(Object fieldId : fieldNames) {
            if(fieldId instanceof String) // ConsString is checked
            {
                String fieldName = (String)fieldId; // ConsString is checked
                // Check name is allowed and doesn't duplicate any other name
                JdNamespace.checkNameIsAllowed(fieldName);
                String fieldNameLower = fieldName.toLowerCase();
                if(nameChecks.contains(fieldNameLower)) {
                    throw new OAPIException("Field name " + name + "." + fieldName + " differs from another field name by case only.");
                }
                nameChecks.add(fieldNameLower);
                if(fieldNameLower.equals("id")) {
                    throw new OAPIException("'id' is not allowed as field name.");
                }

                // Extract field definition
                Scriptable defn = JsGet.scriptable(fieldName, fields);
                if(defn == null) {
                    throw new OAPIException("Bad field definition " + name + "." + fieldName);
                }
                String fieldType = JsGet.string("type", defn);
                if(fieldType == null) {
                    throw new OAPIException("Bad type in field definition for " + name + "." + fieldName);
                }
                // Create the field object
                Field field = null;
                switch(fieldType) {
                    case "text":        field = new TextField(fieldName, defn); break;
                    case "datetime":    field = new DateTimeField(fieldName, defn); break;
                    case "date":        field = new DateField(fieldName, defn); break;
                    case "time":        field = new TimeField(fieldName, defn); break;
                    case "boolean":     field = new BooleanField(fieldName, defn); break;
                    case "smallint":    field = new SmallIntField(fieldName, defn); break;
                    case "int":         field = new IntField(fieldName, defn); break;
                    case "bigint":      field = new BigIntField(fieldName, defn); break;
                    case "float":       field = new FloatField(fieldName, defn); break;
                    case "numeric":     field = new NumericField(fieldName, defn); break;
                    case "ref":         field = new ObjRefField(fieldName, defn); break;
                    case "file":        field = new FileField(fieldName, defn); break;
                    case "user":        field = new UserField(fieldName, defn); break;
                    case "labelList":   field = new LabelListField(fieldName, defn); break;
                    case "json":        field = new JsonField(fieldName, defn); break;
                    case "link":
                        field = new LinkField(fieldName, defn, "i" + linkAliasNumber);
                        linkAliasNumber++;
                        break;
                    default:
                        throw new OAPIException("Unknown data type '" + fieldType + "' in field definition for " + name + "." + fieldName);
                }
                fieldList.add(field);
            }
        }

        // Convert list to normal Java array
        this.fields = fieldList.toArray(new Field[fieldList.size()]);

        // Create the JavaScript object factory function
        Scriptable mainScope = runtime.getJavaScriptScope();
        Scriptable sharedScope = runtime.getSharedJavaScriptScope();
        Scriptable dbObject = (Scriptable)sharedScope.get("$DbObject", mainScope); // ConsString is checked
        Function jsClassConstructor = (Function)dbObject.get("$makeFactoryFunction", dbObject);
        this.factory = (Function)jsClassConstructor.call(runtime.getContext(), dbObject, jsClassConstructor, new Object[]{this, fields, methods});
    }

    // --------------------------------------------------------------------------------------------------------------
    public String jsGet_name() {
        return jsName;
    }

    public Scriptable jsGet_namespace() {
        return this.namespace;
    }

    // --------------------------------------------------------------------------------------------------------------
    public Scriptable jsFunction_create(Scriptable initialValues) {
        Runtime runtime = Runtime.getCurrentRuntime();
        return (Scriptable)this.factory.call(runtime.getContext(), this.factory, this.factory, new Object[]{initialValues});
    }

    public Scriptable jsFunction_load(int id) throws java.sql.SQLException {
        ParameterIndicies indicies = makeParameterIndicies();
        Connection db = Runtime.currentRuntimeHost().getSupportRoot().getJdbcConnection();
        Statement statement = db.createStatement();
        Scriptable object = null;
        try {
            StringBuilder select = new StringBuilder("SELECT ");
            this.appendColumnNamesForSelect(1, this.getDatabaseTableName(), select, indicies);
            select.append(" FROM ");
            select.append(this.getDatabaseTableName());
            select.append(" WHERE id=" + id);
            ResultSet results = statement.executeQuery(select.toString());
            ArrayList<Scriptable> objects = jsObjectsFromResultsSet(results, 1 /* results size hint */, indicies, null /* no includes */);
            if(objects.size() == 1) {
                object = objects.get(0);
            } else if(objects.size() != 0) {
                throw new OAPIException("Expectations not met; database returns more than one object");
            }
            results.close();
        } finally {
            statement.close();
        }

        return object;
    }

    public Scriptable jsFunction_select() {
        return Runtime.createHostObjectInCurrentRuntime("$DbSelect", this);
    }

    public void jsFunction_createNewRow(Scriptable row) throws java.sql.SQLException {
        StringBuilder sql = new StringBuilder("INSERT INTO ");
        sql.append(this.getDatabaseTableName());
        sql.append(" (");
        // Find the last field
        Field lastField = null;
        if(this.fields.length > 0) {
            lastField = this.fields[this.fields.length - 1];
        }
        // Build the insert fields
        for(Field field : fields) {
            field.appendInsertColumnName(sql);
            if(field != lastField) {
                sql.append(',');
            }
        }
        sql.append(") VALUES(");
        for(Field field : fields) {
            field.appendInsertMarker(sql);
            if(field != lastField) {
                sql.append(',');
            }
        }
        sql.append(") RETURNING id");

        Scriptable rowValues = (Scriptable)row.get("$values", row);

        // Run the SQL
        Connection db = Runtime.currentRuntimeHost().getSupportRoot().getJdbcConnection();
        PreparedStatement statement = db.prepareStatement(sql.toString());
        try {
            int parameterIndex = 1;
            for(Field field : fields) {
                parameterIndex = field.setStatementField(parameterIndex, statement, rowValues);
            }
            ResultSet results = statement.executeQuery();
            if(!results.next()) {
                throw new OAPIException("Create row didn't return an id");
            }
            int id = results.getInt(1);

            // Store the id in the row object
            row.put("id", row, new Integer(id));
        } finally {
            statement.close();
        }
    }

    public void jsFunction_saveChangesToRow(int id, Scriptable row) throws java.sql.SQLException {
        if(id <= 0) {
            throw new OAPIException("Bad id value for updating row");
        }

        // Get the changed values from the row object
        Object rowValuesO = row.get("$changes", row); // ConsString is checked
        if(rowValuesO == Scriptable.NOT_FOUND) {
            // Nothing has been changed, so just return silently.
            return;
        }
        Scriptable rowValues = (Scriptable)rowValuesO;

        // Build the SQL to update it
        StringBuilder update = new StringBuilder("UPDATE ");
        update.append(this.getDatabaseTableName());
        update.append(" SET ");
        boolean needsComma = false;
        int parameterIndex = 1;
        ParameterIndicies indicies = makeParameterIndicies();
        for(Field field : this.fields) {
            int nextParameterIndex = field.appendUpdateSQL(update, needsComma, rowValues, parameterIndex, indicies);
            if(nextParameterIndex != parameterIndex) {
                parameterIndex = nextParameterIndex;
                needsComma = true;
            }
        }
        update.append(" WHERE id=");
        update.append(id);

        // Execute the SQL
        Connection db = Runtime.currentRuntimeHost().getSupportRoot().getJdbcConnection();
        PreparedStatement statement = db.prepareStatement(update.toString());
        try {
            for(Field field : this.fields) {
                field.setUpdateField(statement, rowValues, indicies);
            }
            statement.execute();
        } finally {
            statement.close();
        }
    }

    public boolean jsFunction_deleteRow(int id) throws java.sql.SQLException {
        if(id <= 0) {
            throw new OAPIException("Bad id value for deleting row");
        }

        // Update database
        boolean wasDeleted = false;
        Connection db = Runtime.currentRuntimeHost().getSupportRoot().getJdbcConnection();
        Statement statement = db.createStatement();
        try {
            int count = statement.executeUpdate("DELETE FROM " + this.getDatabaseTableName() + " WHERE id=" + id);
            if(count == 1) {
                wasDeleted = true;
            } else if(count != 0) {
                throw new RuntimeException("Logic error - more than one row deleted");
            }
        } finally {
            statement.close();
        }

        return wasDeleted;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void setupStorage(Connection db) throws java.sql.SQLException {
        String postgresSchema = this.namespace.getPostgresSchemaName();
        String databaseTableName = this.getDatabaseTableName();

        // Does this table exist?
        boolean tableExists = false;
        int indexIndex = 0;
        HashMap<String,String> existingFields = new HashMap<String,String>();
        Statement checkStatement = db.createStatement();
        try {
            // Check existence of the table by getting the list of columns and their types
            // OK to generate the SQL like this - schema name is internally generated, and table name is checked
            String getColumnsSql = "SELECT column_name,data_type FROM information_schema.columns WHERE table_schema='" +
                    postgresSchema +"' AND table_name='" + databaseTableName + "'";
            ResultSet columnResults = checkStatement.executeQuery(getColumnsSql);
            while(columnResults.next()) {
                existingFields.put(columnResults.getString(1).toLowerCase(), columnResults.getString(2));
            }
            tableExists = !(existingFields.isEmpty());
            columnResults.close();
            // If the table exists work out the maximum indexIndex currently defined
            if(tableExists) {
                String getIndexIndexSql = "SELECT COALESCE(MAX(substring(indexname from '[0-9]+$')::int),-1)+1 FROM pg_catalog.pg_indexes WHERE schemaname='" +
                        postgresSchema + "' AND tablename='" + databaseTableName + "' AND indexname ~ '_i[0-9]+$'";
                ResultSet indexIndexResults = checkStatement.executeQuery(getIndexIndexSql);
                if(indexIndexResults.next()) {
                    indexIndex = indexIndexResults.getInt(1);
                }
                indexIndexResults.close();
            }
        } finally {
            checkStatement.close();
        }

        ArrayList<String> sqlStatements = new ArrayList<String>(16);

        if(tableExists) {
            // Support limited migration by generating SQL for new columns
            StringBuilder alter = new StringBuilder("ALTER TABLE ");
            alter.append(postgresSchema);
            alter.append(".");
            alter.append(databaseTableName);
            boolean firstColumn = true;
            boolean needsAlter = false;
            for(Field field : fields) {
                if(!existingFields.containsKey(field.getDbNameForExistenceTest())) {
                    if(!field.isNullable()) {
                        throw new OAPIException(
                            "Cannot automatically migrate table definition: in plugin "+this.namespace.getPluginName()+
                            ", table "+this.jsName+
                            ", column "+field.getJsName()+
                            " is not nullable");
                    }
                    if(firstColumn) { firstColumn = false; } else { alter.append(","); }
                    alter.append("\nADD COLUMN ");
                    alter.append(field.generateSqlDefinition(this));
                    needsAlter = true;
                }
            }
            if(needsAlter) {
                sqlStatements.add(alter.toString());
            }
        } else {
            // Generate the SQL for the table and indicies
            StringBuilder create = new StringBuilder("CREATE TABLE ");
            create.append(postgresSchema);
            create.append('.');
            create.append(databaseTableName);
            create.append(" (\nid SERIAL PRIMARY KEY");
            for(Field field : fields) {
                create.append(",\n");
                create.append(field.generateSqlDefinition(this));
            }
            create.append("\n);");
            sqlStatements.add(create.toString());
        }

        // Generate the index creation SQL for fields which haven't yet been defined
        for(Field field : fields) {
            if(!existingFields.containsKey(field.getDbNameForExistenceTest())) {
                String indexSql = field.generateIndexSqlDefinition(this, indexIndex++);
                if(indexSql != null) {
                    sqlStatements.add(indexSql);
                }
            }
        }

        // Run the creation/migration SQL in a transaction
        if(sqlStatements.size() > 0) {
            Statement createStatement = db.createStatement();
            try {
                createStatement.executeUpdate("BEGIN");
                for(String sql : sqlStatements) {
                    createStatement.executeUpdate(sql);
                }
                createStatement.executeUpdate("COMMIT");
            } finally {
                createStatement.close();
            }
        }

        this.postSetupStorage(!tableExists, sqlStatements.size() > 0);
    }

    protected void postSetupStorage(boolean didCreate, boolean didChangeDatabase) {
    }

    // --------------------------------------------------------------------------------------------------------------

    // Execute a query returning rows of data
    public Scriptable[] executeQuery(JdSelect query) throws java.sql.SQLException {
        return (Scriptable[])buildAndExecuteQuery(query, new QueryExecution() {
            public int appendOutputExpressions(StringBuilder select, ParameterIndicies indicies) {
                return appendColumnNamesForSelect(1, "m", select, indicies);
            }
            public int appendOutputExpressionsForLinkedTable(JdTable otherTable, int parameterIndexStart, String tableAlias, StringBuilder select, ParameterIndicies indicies) {
                select.append(',');
                return otherTable.appendColumnNamesForSelect(parameterIndexStart, tableAlias, select, indicies);
            }
            public void appendGroupAndOrder(StringBuilder select) {
                String order = query.generateOrderSql("m");
                if(order != null) {
                    select.append(" ORDER BY ");
                    select.append(order);
                }
            }
            public Object createResultObject(ResultSet results, ParameterIndicies indicies, IncludedTable[] includes) throws java.sql.SQLException {
                ArrayList<Scriptable> objects = jsObjectsFromResultsSet(results, 100 /* results size hint */, indicies, includes);
                return objects.toArray(new Scriptable[objects.size()]);
            }
        });
    }

    // How to interpret values returned by the database in executeSingleValueExpression()
    public enum SingleValueKind {
        BIGINT() {
            public Object get(ResultSet results, int expectedJdbcType) throws java.sql.SQLException { return (Long)results.getLong(1); }
            public Object valueForNoResult(int expectedJdbcType) { return (Integer)0; }
        },
        NUMERIC_OR_DOUBLE() {
            public Object get(ResultSet results, int expectedJdbcType) throws java.sql.SQLException {
                if(expectedJdbcType == java.sql.Types.NUMERIC) {
                    BigDecimal d = results.getBigDecimal(1);
                    return (d == null) ? null : JsBigDecimal.fromBigDecimal(d);
                } else {
                    return results.getDouble(1);
                }
            }
            public Object valueForNoResult(int expectedJdbcType) {
                if(expectedJdbcType == java.sql.Types.NUMERIC) {
                    return JsBigDecimal.fromBigDecimal(BigDecimal.ZERO);
                } else {
                    return (Double)0.0;
                }
            }
        };
        public abstract Object get(ResultSet results, int expectedJdbcType) throws java.sql.SQLException;
        public abstract Object valueForNoResult(int expectedJdbcType);
    }

    // Execute a query which returns a single value from a *trusted* SQL expression
    public Object executeSingleValueExpressionUsingTrustedSQL(JdSelect query, String sqlExpression, SingleValueKind kind, int expectedJdbcType, Field[] groupByFields) throws java.sql.SQLException {
        // WARNING: sqlExpression is added into the SQL statement directly

        String groupByExpression = groupByFields != null ?
                    String.join(",", Arrays.asList(groupByFields).stream().map(Field::getDbName).toArray(String[]::new)) :
                    null;

        return buildAndExecuteQuery(query, new QueryExecution() {
            public int appendOutputExpressions(StringBuilder select, ParameterIndicies indicies) {
                select.append(sqlExpression);
                if(groupByFields != null) {
                    select.append(',');
                    select.append(groupByExpression);
                }
                select.append(' ');
                return 0;
            }
            public int appendOutputExpressionsForLinkedTable(JdTable otherTable, int parameterIndexStart, String tableAlias, StringBuilder select, ParameterIndicies indicies) {
                return parameterIndexStart;
            };
            public void appendGroupAndOrder(StringBuilder select) {
                if(groupByFields != null) {
                    select.append(" GROUP BY ");
                    select.append(groupByExpression);
                    select.append(" ORDER BY ");
                    select.append(groupByExpression);
                }
            }
            public Object createResultObject(ResultSet results, ParameterIndicies indicies, IncludedTable[] includes) throws java.sql.SQLException {
                if(groupByFields != null) {
                    // Build a JS Array of {value:sqlExpressionValue, group:groupValue}
                    Runtime runtime = Runtime.getCurrentRuntime();
                    ArrayList<Scriptable> groups = new ArrayList<Scriptable>();
                    ParameterIndicies readGroupValueIndicies = new ParameterIndicies(groupByFields.length);
                    int groupByFieldIndex = 2; // Value picked up by Field is second
                    for(Field groupByField : groupByFields) {
                        readGroupValueIndicies.set(groupByFieldIndex++);
                    }
                    while(results.next()) {
                        Scriptable entry = runtime.createHostObject("Object");
                        groups.add(entry);
                        // Result of SQL expression
                        entry.put("value", entry, kind.get(results, expectedJdbcType));
                        // Group value
                        readGroupValueIndicies.nextRow();
                        Scriptable groupsEntry = runtime.createHostObject("Object");
                        for(Field groupByField : groupByFields) {
                            Object groupValue = groupByField.getValueFromResultSet(results, readGroupValueIndicies);
                            if(results.wasNull()) { groupValue = null; }
                            groupsEntry.put(groupByField.getDbName(), groupsEntry, groupValue);
                            if(groupByFields.length == 1) {
                                //Group property is set for backwards compatibility
                                entry.put("group", entry, groupValue);
                            }
                        }
                        entry.put("groups", entry, groupsEntry);
                    }
                    return runtime.getContext().newArray(runtime.getJavaScriptScope(), groups.toArray(new Object[groups.size()]));
                } else {
                    // Just a single value
                    return results.next() ? kind.get(results, expectedJdbcType) : kind.valueForNoResult(expectedJdbcType);
                }
            }
        });
    }

    // Generate parts of the SQL & interpret the results
    private interface QueryExecution {
        int appendOutputExpressions(StringBuilder select, ParameterIndicies indicies);
        int appendOutputExpressionsForLinkedTable(JdTable otherTable, int parameterIndexStart, String tableAlias, StringBuilder select, ParameterIndicies indicies);
        void appendGroupAndOrder(StringBuilder select);
        Object createResultObject(ResultSet results, ParameterIndicies indicies, IncludedTable[] includes) throws java.sql.SQLException;
    }

    private Object buildAndExecuteQuery(JdSelect query, QueryExecution execution) throws java.sql.SQLException {
        ParameterIndicies indicies = makeParameterIndicies();
        Connection db = Runtime.currentRuntimeHost().getSupportRoot().getJdbcConnection();
        // Build SELECT statement
        String from = this.getDatabaseTableName() + " AS m";
        StringBuilder select = new StringBuilder("SELECT ");
        int parameterIndexStart = execution.appendOutputExpressions(select, indicies);
        // Load other tables at the same time?
        JdTable.LinkField[] includeFields = query.getIncludes();
        IncludedTable includes[] = null;
        if(includeFields != null) {
            includes = new IncludedTable[includeFields.length];
            // Go through each of the fields
            for(int includeIndex = 0; includeIndex < includeFields.length; ++includeIndex) {
                // Get info about included tables
                JdTable.LinkField field = includeFields[includeIndex];
                JdTable otherTable = this.namespace.getTable(field.getOtherTableName());
                String otherAlias = field.getNameForQueryAlias();
                ParameterIndicies otherIndicies = otherTable.makeParameterIndicies();
                includes[includeIndex] = new IncludedTable(otherTable, field, otherIndicies);
                // Ask all the other tables to add their fields?
                parameterIndexStart = execution.appendOutputExpressionsForLinkedTable(otherTable, parameterIndexStart, otherAlias, select, otherIndicies);
                // Adjust the FROM statement
                from = "(" + from + " LEFT JOIN " + otherTable.getDatabaseTableName() + " AS " + otherAlias + " ON m." + field.getDbName() + "=" + otherAlias + ".id)";
            }
        }
        // FROM
        select.append(" FROM ");
        select.append(from);
        // WHERE
        String where = query.generateWhereSql("m");
        if(where != null) {
            select.append(" WHERE ");
            select.append(where);
        }
        // GROUP BY, ORDER BY, etc
        execution.appendGroupAndOrder(select);
        // LIMIT
        String limit = query.generateLimitAndOffsetSql();
        if(limit != null) {
            select.append(limit);
        }

        // Run the query
        Object output = null;
        try ( PreparedStatement statement = db.prepareStatement(select.toString()) ) {
            if(where != null) {
                query.setWhereValues(statement);
            }
            try ( ResultSet results = statement.executeQuery() ) {
                output = execution.createResultObject(results, indicies, includes);
            }
        }

        return output;
    }

    // --------------------------------------------------------------------------------------------------------------
    public int executeDelete(JdSelect query) throws java.sql.SQLException {
        if(null != query.getIncludes()) {
            throw new OAPIException("deleteAll() cannot use selects which include other tables, or where clauses which refer to a field in another table via a link field. Remove include() statements and check your where() clauses.");
        }
        ParameterIndicies indicies = makeParameterIndicies();
        Connection db = Runtime.currentRuntimeHost().getSupportRoot().getJdbcConnection();
        int numberDeleted = 0;
        // Build DELETE statement
        StringBuilder del = new StringBuilder("DELETE FROM ");
        String tableName = this.getDatabaseTableName();
        del.append(tableName);
        String where = query.generateWhereSql(tableName);
        if(where != null) {
            del.append(" WHERE ");
            del.append(where);
        }
        // Run the query
        PreparedStatement statement = db.prepareStatement(del.toString());
        try {
            if(where != null) {
                query.setWhereValues(statement);
            }
            numberDeleted = statement.executeUpdate();
        } finally {
            statement.close();
        }
        return numberDeleted;
    }

    // --------------------------------------------------------------------------------------------------------------
    private int appendColumnNamesForSelect(int parameterIndexStart, String tableAlias, StringBuilder builder, ParameterIndicies indicies) {
        int parameterIndex = parameterIndexStart;
        // id column goes first, store the parameter index for the read later on
        indicies.set(parameterIndex++);
        builder.append(tableAlias);
        builder.append(".id");

        // Append column names
        for(Field field : fields) {
            builder.append(',');
            parameterIndex = field.appendColumnNamesForSelect(parameterIndex, tableAlias, builder, indicies);
        }

        return parameterIndex;
    }

    private ArrayList<Scriptable> jsObjectsFromResultsSet(ResultSet results, int capacityHint, ParameterIndicies indicies, IncludedTable[] includes)
            throws java.sql.SQLException {
        Runtime runtime = Runtime.getCurrentRuntime();
        Context context = runtime.getContext();
        Scriptable scope = runtime.getJavaScriptScope();
        ArrayList<Scriptable> objects = new ArrayList<Scriptable>(capacityHint);

        // Turn the rows into a list of JavaScript objects
        while(results.next()) {
            Scriptable o = readJsObjectFromResultSet(results, indicies, scope, context);
            if(o == null) {
                throw new RuntimeException("logic error, no results when results expected");
            }
            // Read other objects included in this SELECT statement
            if(includes != null) {
                // Objects should be added to the $values object with a suffix on the field name
                Scriptable oValues = (Scriptable)o.get("$values", o);
                for(IncludedTable include : includes) {
                    Scriptable i = include.table.readJsObjectFromResultSet(results, include.indicies, scope, context);
                    if(i != null) {
                        oValues.put(include.valueKey, oValues, i);
                    }
                }
            }
            objects.add(o);
        }

        return objects;
    }

    private Scriptable readJsObjectFromResultSet(ResultSet results, ParameterIndicies indicies, Scriptable scope, Context context)
            throws java.sql.SQLException {
        indicies.nextRow();
        int id = results.getInt(indicies.get());

        // Check to see there was actually an object there (might be an null column for an includes)
        if(results.wasNull()) {
            return null;
        }

        Scriptable o = (Scriptable)this.factory.call(context, this.factory, this.factory, new Object[]{});
        o.put("id", o, id);
        Scriptable oValues = (Scriptable)o.get("$values", o);

        for(Field field : this.fields) {
            field.setValueInJsObjectFromResultSet(results, oValues, scope, indicies);
        }

        return o;
    }

    private static final class IncludedTable {
        public final JdTable table;
        public final Field field;
        public final ParameterIndicies indicies;
        public final String valueKey; // for the $values array

        IncludedTable(JdTable table, Field field, ParameterIndicies indicies) {
            this.table = table;
            this.field = field;
            this.indicies = indicies;
            this.valueKey = field.getJsName() + "_obj";
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    // Store the parameter indicies for the table fields in SQL statements
    private static final class ParameterIndicies {
        private int[] indicies;
        private int setPos;
        private int getPos;

        ParameterIndicies(int length) {
            this.indicies = new int[length];
            this.setPos = 0;
            this.getPos = 0;
        }

        public void set(int index) {
            this.indicies[this.setPos++] = index;
        }

        public int get() {
            return this.indicies[this.getPos++];
        }

        public void nextRow() {
            this.getPos = 0;
        }
    }

    private ParameterIndicies makeParameterIndicies() {
        // Each field needs an entry, plus one for the id field.
        return new ParameterIndicies(1 + this.fields.length);
    }

    // --------------------------------------------------------------------------------------------------------------
    protected static interface ValueTransformer {
        String transform(String sqlValue);
        int setWhereValue(JdTable.Field field, int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException;
    }

    // --------------------------------------------------------------------------------------------------------------
    protected static abstract class Field {
        protected String dbName;  // name in the database
        protected String jsName;  // name in the javascript
        protected boolean nullable;
        protected boolean indexed;
        protected boolean uniqueIndex;
        protected String[] otherIndexFields;

        protected Field(String name) {
            this.dbName = name.toLowerCase();
            if(PostgresqlReservedWords.isReserved(this.dbName)) {
                this.dbName = "_" + this.dbName;   // _ prefix ensures that it won't clash with reserved words
            }
            this.jsName = name;
        }

        public Field(String name, Scriptable defn) {
            this(name);
            this.nullable = JsGet.booleanWithDefault("nullable", defn, false);
            this.indexed = JsGet.booleanWithDefault("indexed", defn, false);
            this.uniqueIndex = JsGet.booleanWithDefault("uniqueIndex", defn, false);
            // Read, check and convert list of fields this is indexed with
            Scriptable indexedWithArray = JsGet.scriptable("indexedWith", defn);
            if(indexedWithArray != null) {
                this.indexed = true;
                Object[] elements = Runtime.getCurrentRuntime().getContext().getElements(indexedWithArray);
                this.otherIndexFields = new String[elements.length];
                int i = 0;
                for(Object element : elements) {
                    if(!(element instanceof CharSequence)) {
                        throw new OAPIException("Field " + jsName + " has bad field name in indexedWith array");
                    }
                    String elementName = ((CharSequence)element).toString();
                    JdNamespace.checkNameIsAllowed(elementName);    // paranoid, will also be checked implicity with getField call later
                    this.otherIndexFields[i++] = elementName;
                }
            }
        }

        public String getJsName() {
            return jsName;
        }

        public String getDbName() {
            return dbName;
        }

        public String getDbNameForExistenceTest() {
            return this.getDbName();
        }

        public abstract String sqlDataType();

        public abstract int jdbcDataType();

        public boolean isNullable() {
            return nullable;
        }

        public boolean isSingleColumn() {
            return true;
        }

        public abstract boolean jsNonNullObjectIsCompatible(Object object, ValueTransformer valueTransformer);

        public boolean isJSONCompatible() {
            return false;
        }

        public boolean jsObjectIsCompatible(Object object, ValueTransformer valueTransformer) {
            if(object == null) {
                return this.nullable ? true : false;
            }
            return jsNonNullObjectIsCompatible(object, valueTransformer);
        }

        public boolean jsObjectIsCompatibleForWhereClause(Object object, ValueTransformer valueTransformer) {
            return jsObjectIsCompatible(object, valueTransformer);
        }

        public void checkNonNullJsObjectForComparison(Object object, String comparison) {
            // Subclasses should throw an exception if they don't like the value
        }

        protected void checkForForbiddenNullValue(Object object) {
            if(object == null && !(this.nullable)) {
                throw new OAPIException(this.jsName + " cannot be null");
            }
        }

        public String generateSqlDefinition(JdTable table) {
            StringBuilder defn = new StringBuilder(this.dbName);
            defn.append(" ");
            defn.append(this.sqlDataType());
            if(!this.nullable) {
                defn.append(" NOT NULL");
            }
            return defn.toString();
        }

        public String generateIndexSqlDefinition(JdTable table, int indexIndex) {
            if(!this.indexed) {
                return null;
            }

            StringBuilder create = new StringBuilder(this.uniqueIndex ? "CREATE UNIQUE INDEX " : "CREATE INDEX ");
            create.append(table.getDatabaseTableName());
            create.append("_i" + indexIndex);
            create.append(" ON ");
            create.append(table.getDatabaseTableName());
            create.append("(");
            create.append(this.generateIndexSqlDefinitionFields());
            if(this.otherIndexFields != null) {
                for(String fieldName : this.otherIndexFields) {
                    // Check the field actually exists
                    Field otherField = table.getField(fieldName);
                    if(otherField == null) {
                        throw new OAPIException("Field " + fieldName + " was requested in index for field " + jsName + " but does not exist in table");
                    }
                    create.append(',');
                    create.append(otherField.generateIndexSqlDefinitionFields());
                }
            }
            create.append(");");
            return create.toString();
        }

        public String generateIndexSqlDefinitionFields() {
            return getDbName();
        }

        // INSERT
        public void appendInsertColumnName(StringBuilder builder) {
            builder.append(this.dbName);
        }

        public void appendInsertMarker(StringBuilder builder) {
            builder.append('?');
        }

        public abstract int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException;

        // UPDATE
        public int appendUpdateSQL(StringBuilder builder, boolean needsComma, Scriptable values, int parameterIndex, ParameterIndicies indicies) {
            Object value = values.get(jsName, values); // ConsString is checked
            if(value == Scriptable.NOT_FOUND) {
                indicies.set(-1);   // mark as not being updated in this update
                return parameterIndex;
            } else {
                indicies.set(parameterIndex);   // store location for setUpdateField
                if(needsComma) {
                    builder.append(',');
                }
                builder.append(dbName);
                builder.append("=?");
                return parameterIndex + 1;
            }
        }

        public void setUpdateField(PreparedStatement statement, Scriptable values, ParameterIndicies indicies) throws java.sql.SQLException {
            int updateColumnIndex = indicies.get();
            if(updateColumnIndex != -1) {
                setStatementField(updateColumnIndex, statement, values);
            }
        }

        // SELECT
        public int appendColumnNamesForSelect(int parameterIndex, String tableAlias, StringBuilder builder, ParameterIndicies indicies) {
            builder.append(tableAlias);
            builder.append('.');
            builder.append(dbName);
            // Store read column index for later and return the next index
            indicies.set(parameterIndex);
            return parameterIndex + 1;
        }

        public void appendWhereSql(StringBuilder where, String tableAlias, String comparison, Object value, ValueTransformer valueTransformer) {
            if(valueTransformer == null) {
                appendWhereSqlFieldName(where, tableAlias);
            } else {
                StringBuilder sqlValue = new StringBuilder();
                appendWhereSqlFieldName(sqlValue, tableAlias);
                where.append(valueTransformer.transform(sqlValue.toString()));
            }
            where.append(' ');
            if(value == null) {
                if(comparison.equals("=")) {
                    where.append("IS NULL");
                } else if(comparison.equals("<>")) {
                    where.append("IS NOT NULL");
                } else {
                    throw new OAPIException("Can't use a comparison other than = for a null value (in field " + jsName + ")");
                }
            } else {
                where.append(comparison);
                where.append(" ");
                appendWhereSqlValueMarker(where);
            }
        }

        public void appendWhereSqlFieldName(StringBuilder where, String tableAlias) {
            where.append(tableAlias);
            where.append('.');
            where.append(dbName);
        }

        public void appendWhereSqlValueMarker(StringBuilder where) {
            where.append("?");
        }

        public void appendOrderSql(StringBuilder clause, String tableAlias, boolean descending) {
            clause.append(tableAlias);
            clause.append('.');
            clause.append(dbName);
            if(descending) {
                clause.append(" DESC");
            }
        }

        public abstract void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException;

        public int setWhereValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            if(value == null) {
                return parameterIndex;
            } else {
                this.setWhereNotNullValue(parameterIndex, statement, value);
                return parameterIndex + 1;
            }
        }

        // READING RESULTS
        public void setValueInJsObjectFromResultSet(ResultSet results, Scriptable values, Scriptable scope, ParameterIndicies indicies)
                throws java.sql.SQLException {
            Object value = getValueFromResultSet(results, indicies);
            if(value == null || (nullable && results.wasNull())) {
                values.put(jsName, values, null);
            } else {
                values.put(jsName, values, value);
            }
        }

        protected abstract Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException;
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class TextField extends Field {
        private boolean isCaseInsensitive;

        public TextField(String name, Scriptable defn) {
            super(name, defn);
            this.isCaseInsensitive = JsGet.booleanWithDefault("caseInsensitive", defn, false);
        }

        @Override
        public String sqlDataType() {
            return "TEXT";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.CHAR;
        }

        @Override
        public boolean isJSONCompatible() {
            return true;
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object, ValueTransformer valueTransformer) {
            return object instanceof CharSequence;
        }

        @Override
        public void checkNonNullJsObjectForComparison(Object object, String comparison) {
            // LIKE operator has extra constraints
            if(comparison.equals("LIKE")) {
                String string = ((CharSequence)object).toString(); // know this works because of jsNonNullObjectIsCompatible() check
                if(string.length() < 1) {
                    throw new OAPIException("Value for a LIKE where clause must be at least one character long.");
                }
                char firstChar = string.charAt(0);
                if(firstChar == '_' || firstChar == '%') {
                    throw new OAPIException("Value for a LIKE clause may not have a wildcard as the first character.");
                }
            }
        }

        @Override
        public String generateIndexSqlDefinitionFields() {
            return this.isCaseInsensitive ? "lower(" + super.getDbName() + ")" : super.getDbName();
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            String s = JsGet.string(this.jsName, values);
            checkForForbiddenNullValue(s);
            statement.setString(parameterIndex, s);
            return parameterIndex + 1;
        }

        @Override
        public void appendWhereSqlFieldName(StringBuilder where, String tableAlias) {
            if(this.isCaseInsensitive) {
                where.append("lower(");
            }
            super.appendWhereSqlFieldName(where, tableAlias);
            if(this.isCaseInsensitive) {
                where.append(")");
            }
        }

        @Override
        public void appendWhereSqlValueMarker(StringBuilder where) {
            where.append(this.isCaseInsensitive ? "lower(?)" : "?");
        }

        @Override
        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            statement.setString(parameterIndex, ((CharSequence)value).toString());
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            return results.getString(indicies.get()); // ConsString is checked (indicies is not a ScriptableObject)
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class DateTimeField extends Field {
        public DateTimeField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public String sqlDataType() {
            return "TIMESTAMP";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.TIMESTAMP;
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object, ValueTransformer valueTransformer) {
            return Runtime.getCurrentRuntime().isAcceptedJavaScriptDateObject(object);
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            Date d = JsGet.date(this.jsName, values);
            checkForForbiddenNullValue(d);
            statement.setTimestamp(parameterIndex, (d == null) ? null : (new java.sql.Timestamp(d.getTime())));
            return parameterIndex + 1;
        }

        @Override
        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            value = Runtime.getCurrentRuntime().convertIfJavaScriptLibraryDate(value); // support various JavaScript libraries
            Date d = (Date)Context.jsToJava(value, ScriptRuntime.DateClass);
            statement.setTimestamp(parameterIndex, new java.sql.Timestamp(d.getTime()));
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            java.sql.Timestamp timestamp = results.getTimestamp(indicies.get());
            // Need to create a JavaScript object - automatic conversion doesn't work for these
            return (timestamp == null) ? null : Runtime.createHostObjectInCurrentRuntime("Date", timestamp.getTime());
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class DateField extends DateTimeField {
        public DateField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public String sqlDataType() {
            return "DATE";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.DATE;
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class TimeField extends Field {
        public TimeField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public String sqlDataType() {
            return "TIME WITHOUT TIME ZONE";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.TIME;
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object, ValueTransformer valueTransformer) {
            // A simple, and not entirely accurate test. But good enough for these purposes.
            if(!(object instanceof Scriptable)) {
                return false;
            }
            Scriptable prototype = ((Scriptable)object).getPrototype();
            return (prototype.get("$is_dbtime", prototype) instanceof CharSequence);
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            Scriptable dbtime = JsGet.scriptable(this.jsName, values);
            checkForForbiddenNullValue(dbtime);
            java.sql.Time t = TimeField.convertDBTime(dbtime);
            if(t == null) {
                statement.setNull(parameterIndex, java.sql.Types.TIME);
            } else {
                statement.setTime(parameterIndex, t);
            }
            return parameterIndex + 1;
        }

        @Override
        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            statement.setTime(parameterIndex, convertDBTime((Scriptable)value));
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            java.sql.Time t = results.getTime(indicies.get());
            if(t == null || results.wasNull()) {
                return null;
            }
            return Runtime.createHostObjectInCurrentRuntime("DBTime", t.getHours(), t.getMinutes(), t.getSeconds());
        }

        static java.sql.Time convertDBTime(Scriptable dbtime) {
            if(dbtime == null) {
                return null;
            }
            long milliseconds = 0;
            Object hours = dbtime.get("$hours", dbtime); // ConsString is checked
            Object minutes = dbtime.get("$minutes", dbtime); // ConsString is checked
            Object seconds = dbtime.get("$seconds", dbtime); // ConsString is checked
            if(hours instanceof Number) {
                milliseconds += ((Number)hours).longValue() * (60 * 60 * 1000);
            } else {
                return null;
            }   // should at least have an hour
            if(minutes instanceof Number) {
                milliseconds += ((Number)minutes).longValue() * (60 * 1000);
            }
            if(seconds instanceof Number) {
                milliseconds += ((Number)seconds).longValue() * (1000);
            }
            return new java.sql.Time(milliseconds);
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class BooleanField extends Field {
        public BooleanField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public String sqlDataType() {
            return "BOOLEAN";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.BOOLEAN;
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object, ValueTransformer valueTransformer) {
            return object instanceof Boolean;
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            Boolean b = JsGet.booleanObject(this.jsName, values);
            checkForForbiddenNullValue(b);
            if(b == null) {
                statement.setNull(parameterIndex, java.sql.Types.BOOLEAN);
            } else {
                statement.setBoolean(parameterIndex, b);
            }
            return parameterIndex + 1;
        }

        @Override
        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            statement.setBoolean(parameterIndex, (Boolean)value);
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            return results.getBoolean(indicies.get());
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class SmallIntField extends Field {
        public SmallIntField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public String sqlDataType() {
            return "SMALLINT";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.SMALLINT;
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object, ValueTransformer valueTransformer) {
            return object instanceof Number;
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            Number d = JsGet.number(this.jsName, values);
            checkForForbiddenNullValue(d);
            if(d == null) {
                statement.setNull(parameterIndex, java.sql.Types.SMALLINT);
            } else {
                statement.setShort(parameterIndex, d.shortValue());
            }
            return parameterIndex + 1;
        }

        @Override
        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            statement.setShort(parameterIndex, ((Number)value).shortValue());
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            return results.getInt(indicies.get());
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class IntField extends Field {
        private IntField(String name) {
            super(name);
        }

        public IntField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public String sqlDataType() {
            return "INT";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.INTEGER;
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object, ValueTransformer valueTransformer) {
            return object instanceof Number;
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            Number d = JsGet.number(this.jsName, values);
            checkForForbiddenNullValue(d);
            if(d == null) {
                statement.setNull(parameterIndex, java.sql.Types.INTEGER);
            } else {
                statement.setInt(parameterIndex, d.intValue());
            }
            return parameterIndex + 1;
        }

        @Override
        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            statement.setInt(parameterIndex, ((Number)value).intValue());
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            return results.getInt(indicies.get());
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class GenericIdField extends IntField {
        GenericIdField() {
            super("id");
            this.dbName = "id";
            this.jsName = "id";
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class BigIntField extends Field {
        public BigIntField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public String sqlDataType() {
            return "BIGINT";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.BIGINT;
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object, ValueTransformer valueTransformer) {
            return object instanceof Number;
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            Number d = JsGet.number(this.jsName, values);
            checkForForbiddenNullValue(d);
            if(d == null) {
                statement.setNull(parameterIndex, java.sql.Types.BIGINT);
            } else {
                statement.setLong(parameterIndex, d.longValue());
            }
            return parameterIndex + 1;
        }

        @Override
        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            statement.setLong(parameterIndex, ((Number)value).longValue());
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            return results.getLong(indicies.get());
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class FloatField extends Field {
        public FloatField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public String sqlDataType() {
            return "DOUBLE PRECISION";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.DOUBLE;
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object, ValueTransformer valueTransformer) {
            return object instanceof Number;
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            Number d = JsGet.number(this.jsName, values);
            checkForForbiddenNullValue(d);
            if(d == null) {
                statement.setNull(parameterIndex, java.sql.Types.DOUBLE);
            } else {
                statement.setDouble(parameterIndex, d.doubleValue());
            }
            return parameterIndex + 1;
        }

        @Override
        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            statement.setDouble(parameterIndex, ((Number)value).doubleValue());
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            return results.getDouble(indicies.get());
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class NumericField extends Field {
        private int precision = -1;
        private int scale = -1;

        public NumericField(String name, Scriptable defn) {
            super(name, defn);
            Object precision = defn.get("precision", defn); // ConsString is checked
            Object scale = defn.get("scale", defn); // ConsString is checked
            if(precision != null && !(precision instanceof org.mozilla.javascript.UniqueTag)) {
                if(!(precision instanceof Number)) { throw new OAPIException("Bad precision"); }
                this.precision = ((Number)precision).intValue();
                if(this.precision < 1) { throw new OAPIException("precision must be >= 1"); }
                if(scale != null && !(scale instanceof org.mozilla.javascript.UniqueTag)) {
                    if(!(scale instanceof Number)) { throw new OAPIException("Bad scale"); }
                    this.scale = ((Number)scale).intValue();
                    if(this.scale < 0) { throw new OAPIException("scale must be >= 0"); }
                }
            } else if(scale != null && !(scale instanceof org.mozilla.javascript.UniqueTag)) {
                throw new OAPIException("Scale cannot be specified without a precision");
            }
        }

        @Override
        public String sqlDataType() {
            if(precision < 0 && scale < 0) { return "NUMERIC"; }
            if(scale < 0) { return "NUMERIC("+precision+")"; }
            return "NUMERIC("+precision+","+scale+")";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.NUMERIC;
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object, ValueTransformer valueTransformer) {
            return object instanceof JsBigDecimal;
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            JsBigDecimal d = (JsBigDecimal)JsGet.objectOfClass(this.jsName, values, JsBigDecimal.class);
            checkForForbiddenNullValue(d);
            if(d == null) {
                statement.setNull(parameterIndex, java.sql.Types.NUMERIC);
            } else {
                statement.setBigDecimal(parameterIndex, d.toBigDecimal());
            }
            return parameterIndex + 1;
        }

        @Override
        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            statement.setBigDecimal(parameterIndex, ((JsBigDecimal)value).toBigDecimal());
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            return JsBigDecimal.fromBigDecimal(results.getBigDecimal(indicies.get()));
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class ObjRefField extends Field {
        public ObjRefField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public String sqlDataType() {
            return "INT";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.INTEGER;
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object, ValueTransformer valueTransformer) {
            return object instanceof KObjRef;
        }

        public void appendWhereSql(StringBuilder where, String tableAlias, String comparison, Object value, ValueTransformer valueTransformer) {
            if(!(comparison.equals("=") || comparison.equals("<>"))) {
                throw new OAPIException("Can't use a comparison other than = for a ref field in a where() clause");
            }
            super.appendWhereSql(where, tableAlias, comparison, value, valueTransformer);
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            KObjRef ref = (KObjRef)JsGet.objectOfClass(this.jsName, values, KObjRef.class);
            checkForForbiddenNullValue(ref);
            if(ref == null) {
                statement.setNull(parameterIndex, java.sql.Types.INTEGER);
            } else {
                statement.setInt(parameterIndex, ref.jsGet_objId());
            }
            return parameterIndex + 1;
        }

        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            statement.setInt(parameterIndex, ((KObjRef)value).jsGet_objId());
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            int readColumnIndex = indicies.get();
            int objId = results.getInt(readColumnIndex);
            if(results.wasNull()) {
                return null;
            }
            return Runtime.createHostObjectInCurrentRuntime("$Ref", objId);
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    protected static class LinkField extends IntField {
        // LinkFields include the name used in query aliases so the name is easily available in the query generation process,
        // especially for when the value being compared is in a joined table. Can't use the field name as the alias, because
        // it might clash with the name used for the alias of the queried table.
        private String nameForQueryAlias;
        private String otherTableName;

        public LinkField(String name, Scriptable defn, String nameForQueryAlias) {
            super(name, defn);
            this.nameForQueryAlias = nameForQueryAlias;
            String linkedTable = JsGet.string("linkedTable", defn);
            this.otherTableName = (linkedTable != null) ? linkedTable : name;
            JdNamespace.checkNameIsAllowed(this.otherTableName);
        }

        public String getOtherTableName() {
            return this.otherTableName;
        }

        public String getNameForQueryAlias() {
            return this.nameForQueryAlias;
        }

        @Override
        public String generateSqlDefinition(JdTable table) {
            JdTable otherTable = table.getNamespace().getTable(this.otherTableName);
            if(otherTable == null) {
                throw new OAPIException("Table name " + this.otherTableName + " has not been defined yet.");
            }
            StringBuilder defn = new StringBuilder(super.generateSqlDefinition(table));
            defn.append(" REFERENCES ");
            defn.append(otherTable.getDatabaseTableName());
            defn.append("(id)");
            return defn.toString();
        }

        @Override
        public void appendWhereSql(StringBuilder where, String tableAlias, String comparison, Object value, ValueTransformer valueTransformer) {
            if(!(comparison.equals("=") || comparison.equals("<>"))) {
                throw new OAPIException("Link fields can only use the = and <> comparisons in where clauses.");
            }
            super.appendWhereSql(where, tableAlias, comparison, value, valueTransformer);
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    protected static class UserField extends IntField {
        public UserField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object, ValueTransformer valueTransformer) {
            return object instanceof KUser;
        }

        @Override
        public void appendWhereSql(StringBuilder where, String tableAlias, String comparison, Object value, ValueTransformer valueTransformer) {
            if(!(comparison.equals("=") || comparison.equals("<>"))) {
                throw new OAPIException("User fields can only use the = and <> comparisons in where clauses.");
            }
            super.appendWhereSql(where, tableAlias, comparison, value, valueTransformer);
        }

        @Override
        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            statement.setInt(parameterIndex, ((KUser)value).jsGet_id());
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class FileField extends Field {
        public FileField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public String getDbNameForExistenceTest() {
            return this.getDbName()+"_d";   // just check the digest column exists
        }

        @Override
        public boolean isSingleColumn() {
            return false;
        }

        @Override
        public String sqlDataType() {
            throw new RuntimeException("shouldn't call sqlDataType for FileField");
        }

        @Override
        public int jdbcDataType() {
            throw new RuntimeException("shouldn't call jdbcDataType for FileField");
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object, ValueTransformer valueTransformer) {
            return object instanceof KStoredFile;
        }

        @Override
        public String generateSqlDefinition(JdTable table) {
            StringBuilder defn = new StringBuilder(this.dbName);
            defn.append("_d TEXT"); // digest
            if(!this.nullable) {
                defn.append(" NOT NULL");
            }
            defn.append(", ");
            defn.append(this.dbName);
            defn.append("_s BIGINT"); // size
            if(!this.nullable) {
                defn.append(" NOT NULL");
            }
            return defn.toString();
        }

        @Override
        public String generateIndexSqlDefinitionFields() {
            return String.format("%1$s_d,%1$s_s", this.dbName);
        }

        // INSERT
        @Override
        public void appendInsertColumnName(StringBuilder builder) {
            builder.append(this.dbName);
            builder.append("_d,");
            builder.append(this.dbName);
            builder.append("_s");
        }

        @Override
        public void appendInsertMarker(StringBuilder builder) {
            builder.append("?,?");
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            KStoredFile file = (KStoredFile)JsGet.objectOfClass(this.jsName, values, KStoredFile.class);
            if(file == null) {
                statement.setNull(parameterIndex, java.sql.Types.CHAR);
                statement.setNull(parameterIndex + 1, java.sql.Types.INTEGER);
            } else {

                statement.setString(parameterIndex, file.jsGet_digest());
                statement.setLong(parameterIndex + 1, file.jsGet_fileSize());
            }
            return parameterIndex + 2;
        }

        // UPDATE
        @Override
        public int appendUpdateSQL(StringBuilder builder, boolean needsComma, Scriptable values, int parameterIndex, ParameterIndicies indicies) {
            Object value = values.get(jsName, values); // ConsString is checked
            if(value == Scriptable.NOT_FOUND) {
                indicies.set(-1);   // not in this update
                return parameterIndex;
            } else {
                indicies.set(parameterIndex);   // in this update
                if(needsComma) {
                    builder.append(',');
                }
                builder.append(dbName);
                builder.append("_d=?,");
                builder.append(dbName);
                builder.append("_s=?");
                return parameterIndex + 2;
            }
        }

        // SELECT
        @Override
        public int appendColumnNamesForSelect(int parameterIndex, String tableAlias, StringBuilder builder, ParameterIndicies indicies) {
            builder.append(tableAlias);
            builder.append('.');
            builder.append(dbName);
            builder.append("_d,");
            builder.append(tableAlias);
            builder.append('.');
            builder.append(dbName);
            builder.append("_s");
            // Store read column index for later and return the next index
            indicies.set(parameterIndex);
            return parameterIndex + 2;
        }

        public void appendWhereSql(StringBuilder where, String tableAlias, String comparison, Object value, ValueTransformer valueTransformer) {
            boolean isEqualComparison = comparison.equals("=");
            if(!(isEqualComparison || comparison.equals("<>"))) {
                throw new OAPIException("Can't use a comparison other than = for a file field in a where() clause");
            }
            if(value == null) {
                if(isEqualComparison) {
                    where.append(String.format("%1$s.%2$s_d IS NULL", tableAlias, dbName));
                } else {
                    where.append(String.format("%1$s.%2$s_d IS NOT NULL", tableAlias, dbName));
                }
            } else {
                where.append(String.format("(%1$s.%2$s_d %3$s ? AND %1$s.%2$s_s %3$s ?)", tableAlias, dbName, comparison));
            }
        }

        @Override
        public void appendOrderSql(StringBuilder clause, String tableAlias, boolean descending) {
            // Ordering on file doesn't really make sense, but there you go
            clause.append(tableAlias);
            clause.append('.');
            clause.append(dbName);
            clause.append("_d");
            if(descending) {
                clause.append(" DESC");
            }
            clause.append(',');
            clause.append(tableAlias);
            clause.append('.');
            clause.append(dbName);
            clause.append("_s");
            if(descending) {
                clause.append(" DESC");
            }
        }

        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            throw new RuntimeException("logic error");
        }

        public int setWhereValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            if(value == null) {
                // Do nothing - using IS NULL comparisons
                return parameterIndex;
            } else {
                statement.setString(parameterIndex, ((KStoredFile)value).jsGet_digest());
                statement.setLong(parameterIndex + 1, ((KStoredFile)value).jsGet_fileSize());
                return parameterIndex + 2;
            }
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            int readColumnIndex = indicies.get();
            String digest = results.getString(readColumnIndex);
            if(results.wasNull()) {
                return null;
            }
            long fileSize = results.getLong(readColumnIndex + 1);
            return KStoredFile.fromDigestAndSize(digest, fileSize);
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    protected static class LabelListField extends Field {
        public LabelListField(String name, Scriptable defn) {
            super(name, defn);
        }

        protected LabelListField(String name) {
            super(name);
        }

        @Override
        public String sqlDataType() {
            return "int[]";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.ARRAY;
        }

        public Field fieldForPermitReadComparison() {
            return new LabelListFieldForPermitReadComparison(this.dbName);
        }

        public String generateIndexSqlDefinition(JdTable table, int indexIndex) {
            if(!this.indexed) {
                return null;
            }
            if(this.uniqueIndex) {
                throw new OAPIException("labelList database fields cannot use unique index");
            }
            if(this.otherIndexFields != null) {
                throw new OAPIException("labelList database fields cannot be indexed with other fields");
            }
            StringBuilder create = new StringBuilder("CREATE INDEX ");
            create.append(table.getDatabaseTableName());
            create.append("_i" + indexIndex);
            create.append(" ON ");
            create.append(table.getDatabaseTableName());
            // Special index for intarray labels
            create.append(" using gin (");
            create.append(this.generateIndexSqlDefinitionFields());
            create.append(" gin__int_ops);");
            return create.toString();
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object, ValueTransformer valueTransformer) {
            return object instanceof KLabelList;
        }

        @Override
        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            KLabelList labelList = (KLabelList)value;
            setValueInStatement(parameterIndex, statement, labelList);
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            KLabelList labelList = (KLabelList)JsGet.objectOfClass(this.jsName, values, KLabelList.class);
            checkForForbiddenNullValue(labelList);
            if(labelList == null) {
                statement.setNull(parameterIndex, java.sql.Types.ARRAY);
            } else {
                setValueInStatement(parameterIndex, statement, labelList);
            }
            return parameterIndex + 1;
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            java.sql.Array array = results.getArray(indicies.get());
            if(array == null) { return null; }
            Integer ints[] = (Integer[])array.getArray();
            int[] labels = new int[ints.length];
            for(int l = 0; l < ints.length; ++l) {
                labels[l] = ints[l];
            }
            return KLabelList.fromIntArray(labels);
        }

        private void setValueInStatement(int parameterIndex, PreparedStatement statement, KLabelList labelList) throws java.sql.SQLException {
            int[] labels = labelList.getLabels();
            Integer ints[] = new Integer[labels.length];
            for(int l = 0; l < labels.length; ++l) {
                ints[l] = labels[l];
            }
            statement.setArray(parameterIndex, 
                statement.getConnection().createArrayOf("integer", ints));
        }
    }

    // A pseudo field definition used for the PERMIT READ comparison in WHERE clauses
    private static class LabelListFieldForPermitReadComparison extends LabelListField {
        LabelListFieldForPermitReadComparison(String name) {
            super(name);
        }

        @Override
        public boolean jsObjectIsCompatible(Object object, ValueTransformer valueTransformer) {
            if(object == null) {
                throw new OAPIException("Can't use a null value for PERMIT READ comparison in a where() clause.");
            }
            return object instanceof KUser;
        }

        @Override
        public int setWhereValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            return parameterIndex;  // Embeds everything in generated SQL WHERE clause
        }

        public void appendWhereSql(StringBuilder where, String tableAlias, String comparison, Object value, ValueTransformer valueTransformer) {
            KUser user = (KUser)value;
            where.append(user.makeWhereClauseForPermitRead(String.format("%1$s.%2$s", tableAlias, dbName)));
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class JsonField extends Field {
        public JsonField(String name, Scriptable defn) {
            super(name, defn);
            if(this.indexed) {
                throw new OAPIException("json fields cannot be indexed");
            }
        }

        // NOTE: database.js handles all the JSON serialisation and deserialisation
        // Might be nice to use postgresql jsonb at some point in the future?

        @Override
        public String sqlDataType() {
            return "TEXT";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.CHAR;
        }

        @Override
        public boolean isJSONCompatible() {
            return true;
        }

        @Override
        public boolean jsObjectIsCompatibleForWhereClause(Object object, ValueTransformer valueTransformer) {
            if((object != null) && (valueTransformer == null)) {
                throw new OAPIException("json columns cannot be used in where clauses, except as a comparison to null.");
            }
            return super.jsObjectIsCompatibleForWhereClause(object, valueTransformer);
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object, ValueTransformer valueTransformer) {
            return object instanceof CharSequence; // serialised
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            String serialised = JsGet.string(this.jsName, values);
            checkForForbiddenNullValue(serialised);
            if(serialised == null) {
                statement.setNull(parameterIndex, java.sql.Types.CHAR);
            } else {
                statement.setString(parameterIndex, serialised);
            }
            return parameterIndex + 1;
        }

        @Override
        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            statement.setString(parameterIndex, ((CharSequence)value).toString());
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            return results.getString(indicies.get());   // ConsString is checked
        }
    }
}
