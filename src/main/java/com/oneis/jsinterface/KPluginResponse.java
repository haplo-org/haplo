/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface;

import org.mozilla.javascript.*;

import com.oneis.javascript.Runtime;

import java.util.ArrayList;

public class KPluginResponse extends KScriptable {
    private boolean stopChain;
    private Fields fields;

    public KPluginResponse() {
        this.stopChain = false;
    }

    public void jsConstructor() {
    }

    public String getClassName() {
        return "$PluginResponse";
    }

    @Override
    protected String getConsoleData() {
        StringBuilder data = new StringBuilder();
        boolean first = true;
        for(FieldDescription field : fields.allFields()) {
            if(first) {
                first = false;
            } else {
                data.append(", ");
            }
            data.append(field.name);
        }
        return data.toString();
    }

    // --------------------------------------------------------------------------------------------------------------
    static public KPluginResponse make(Fields fields) {
        if(!fields.isReady()) {
            throw new RuntimeException("Fields object is not ready when creating KPluginResponse");
        }
        KPluginResponse response = (KPluginResponse)Runtime.createHostObjectInCurrentRuntime("$PluginResponse");
        response.setFields(fields);
        return response;
    }

    private void setFields(Fields fields) {
        this.fields = fields;
    }

    // --------------------------------------------------------------------------------------------------------------
    public boolean jsFunction_shouldStopChain() {
        return this.stopChain;
    }

    public void jsFunction_stopChain() {
        this.stopChain = true;
    }

    public void prepareForUse() {
        // Set all undefined values to null
        for(FieldDescription f : fields.allFields()) {
            if(!this.has(f.name, this)) {
                this.put(f.name, this, null);
            }
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    public void put(String name, Scriptable start, Object value) {
        if(fields == null) {
            // When defining the object, Rhino will set various values to create the object prototype
        } else {
            FieldDescription field = fields.getField(name);
            if(field == null) {
                throw new RuntimeException("Property " + name + " cannot be set on this response.");
            } else {
                if(!field.checkValue(value)) {
                    throw new RuntimeException("Not a valid kind of value for property " + name);
                }
            }
        }
        super.put(name, start, value);
    }

    public Object get(String name, Scriptable start) {
        FieldDescription field = null;
        if(fields == null) {
            // Prototype object
        } else {
            // Check it's an allowed name
            field = fields.getField(name);
            if(field == null && !(name.equals("stopChain") || name.equals("shouldStopChain"))) {
                throw new RuntimeException("Property " + name + " does not exist on this response.");
            }
        }
        Object value = super.get(name, start); // ConsString is checked
        if(field != null && value != null) {
            value = field.convertValue(value);
        }
        return value;
    }

    // For the Ruby side
    public void putR(String name, Object value) {
        put(name, this, value);
    }

    public void putConstructedJSObject(String name, String jsClassName) {
        put(name, this, Runtime.createHostObjectInCurrentRuntime(jsClassName));
    }

    public Object getR(String name) {
        return has(name, this) ? get(name, this) : null;
    }

    public Object getRJSON(String name) {
        if(!has(name, this)) {
            return null;
        }
        // Call runtime's JSON.stringify() function
        Runtime runtime = Runtime.getCurrentRuntime();
        Scriptable sharedScope = runtime.getSharedJavaScriptScope();
        Scriptable json = (Scriptable)sharedScope.get("JSON", sharedScope);
        Function stringify = (Function)json.get("stringify", json);
        Object result = stringify.call(runtime.getContext(), stringify, stringify, new Object[]{get(name, this)}); // ConsString is checked
        return ((CharSequence)result).toString();
    }

    // --------------------------------------------------------------------------------------------------------------
    static public class Fields {
        private ArrayList<FieldDescription> fieldsBuild;
        private FieldDescription[] fields;

        public Fields() {
            this.fieldsBuild = new ArrayList<FieldDescription>(8);
        }

        public FieldDescription getField(String name) {
            for(FieldDescription f : fields) {
                if(f.name.equals(name)) {
                    return f;
                }
            }
            return null;
        }

        public FieldDescription[] allFields() {
            return fields;
        }

        public boolean isReady() {
            return fields != null;
        }

        // --------------------------------------------------------------------------------------------------------------
        // Build the description
        public void stringField(String name, boolean isRubySymbol) {
            fieldsBuild.add(new StringFieldDescription(name, isRubySymbol));
        }

        public void integerField(String name) {
            fieldsBuild.add(new IntegerFieldDescription(name));
        }

        public void kobjectField(String name) {
            fieldsBuild.add(new KObjectFieldDescription(name));
        }

        public void labelChangesField(String name) {
            fieldsBuild.add(new KLabelChangesFieldDescription(name));
        }

        public void labelStatementsField(String name) {
            fieldsBuild.add(new KLabelStatementsFieldDescription(name));
        }

        public void booleanField(String name) {
            fieldsBuild.add(new BooleanFieldDescription(name));
        }

        public void arrayField(String name) {
            fieldsBuild.add(new ArrayFieldDescription(name));
        }

        public void hashField(String name) {
            fieldsBuild.add(new HashFieldDescription(name));
        }

        // Finish the description
        public void finishDescription() {
            fields = fieldsBuild.toArray(new FieldDescription[fieldsBuild.size()]);
            fieldsBuild = null;
        }

    }

    // --------------------------------------------------------------------------------------------------------------
    static abstract private class FieldDescription {
        public String name;

        public FieldDescription(String name) {
            this.name = name;
        }

        public abstract boolean checkValue(Object value);

        public Object convertValue(Object value) {
            return value;
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    static private class StringFieldDescription extends FieldDescription {
        private boolean isRubySymbol;

        public StringFieldDescription(String name, boolean isRubySymbol) {
            super(name);
            this.isRubySymbol = isRubySymbol;
        }

        public boolean checkValue(Object value) {
            return (value == null) || (value instanceof CharSequence);
        }

        public Object convertValue(Object value) {
            return ((CharSequence)value).toString();
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    static private class IntegerFieldDescription extends FieldDescription {
        public IntegerFieldDescription(String name) {
            super(name);
        }

        public boolean checkValue(Object value) {
            return (value == null) || (value instanceof Number);
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    static private class KObjectFieldDescription extends FieldDescription {
        public KObjectFieldDescription(String name) {
            super(name);
        }

        public boolean checkValue(Object value) {
            return (value == null) || (value instanceof KObject);
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    static private class KLabelChangesFieldDescription extends FieldDescription {
        public KLabelChangesFieldDescription(String name) {
            super(name);
        }

        public boolean checkValue(Object value) {
            return (value == null) || (value instanceof KLabelChanges);
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    static private class KLabelStatementsFieldDescription extends FieldDescription {
        public KLabelStatementsFieldDescription(String name) {
            super(name);
        }

        public boolean checkValue(Object value) {
            return (value == null) || (value instanceof KLabelStatements);
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    static private class BooleanFieldDescription extends FieldDescription {
        public BooleanFieldDescription(String name) {
            super(name);
        }

        public boolean checkValue(Object value) {
            return (value == null) || (value instanceof Boolean);
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    static private class ArrayFieldDescription extends FieldDescription {
        public ArrayFieldDescription(String name) {
            super(name);
        }

        public boolean checkValue(Object value) {
            return (value == null) || (value instanceof NativeArray);
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    static private class HashFieldDescription extends FieldDescription {
        public HashFieldDescription(String name) {
            super(name);
        }

        public boolean checkValue(Object value) {
            return (value == null) || (value instanceof NativeObject);
        }
    }

}
