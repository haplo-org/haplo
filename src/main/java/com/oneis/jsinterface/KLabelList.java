/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface;

import org.mozilla.javascript.*;

import com.oneis.javascript.Runtime;
import com.oneis.javascript.OAPIException;
import com.oneis.jsinterface.KScriptable;
import com.oneis.jsinterface.app.*;

import java.util.Arrays;

public class KLabelList extends KScriptable {
    private int[] labels;

    public KLabelList() {
        this.labels = new int[0];
    }

    public void jsConstructor(NativeArray labels) {
        if(labels != null) {
            setLabels(KLabelList.nativeArrayToLabelArray(labels));
        }
    }

    public String getClassName() {
        return "$LabelList";
    }

    @Override
    protected String getConsoleData() {
        return jsFunction_toString();
    }

    public int[] getLabels() {
        return this.labels;
    }

    public void setLabels(int[] labels) {
        this.labels = KLabelList.sortedLabels(labels);
    }

    static public KLabelList fromAppLabelList(AppLabelList appList) {
        KLabelList list = (KLabelList)Runtime.createHostObjectInCurrentRuntime("$LabelList", new Object[]{null});
        list.setLabels(appList._to_internal());
        return list;
    }

    public AppLabelList toRubyObject() {
        return rubyInterface.constructLabelList(this.labels);
    }

    // Java Object equals function
    @Override
    public boolean equals(Object obj) {
        return (obj instanceof KLabelList) && Arrays.equals(this.labels, ((KLabelList)obj).getLabels());
    }

    // Java Object hashCode function
    @Override
    public int hashCode() {
        return Arrays.hashCode(this.labels);
    }

    // ScriptableObject equals function
    protected Object equivalentValues(Object value) {
        return this.equals(value);
    }

    public String jsFunction_toString() {
        String[] items = new String[this.labels.length];
        for(int l = 0; l < this.labels.length; ++l) {
            items[l] = KObjRef.idToString(this.labels[l]);
        }
        return Arrays.toString(items);
    }

    // --------------------------------------------------------------------------------------------------------------
    public boolean jsFunction_includes(Object object) {
        int label = checkedObjectToLabelInt(object);
        for(int l : this.labels) {
            if(l == label) {
                return true;
            }
        }
        return false;
    }

    // --------------------------------------------------------------------------------------------------------------
    public Scriptable jsFunction_filterToLabelsOfType(Object object) {
        if(object == null || !(object instanceof NativeArray)) {
            throw new OAPIException("Must pass an array to filterToLabelsOfType()");
        }
        int[] types = nativeArrayToLabelArray((NativeArray)object);
        if(types.length == 0) {
            throw new OAPIException("Must pass at least one type to filterToLabelsOfType()");
        }
        KLabelList list = (KLabelList)Runtime.createHostObjectInCurrentRuntime("$LabelList", new Object[]{null});
        list.setLabels(rubyInterface.filterToLabelsOfType(this.labels, types));
        return list;
    }

    // --------------------------------------------------------------------------------------------------------------
    public int jsGet_length() {
        return this.labels.length;
    }

    @Override
    public boolean has(int index, Scriptable start) {
        return (index >= 0 && index < this.labels.length);
    }

    @Override
    public Scriptable get(int index, Scriptable start) {
        if(index < 0 || index >= this.labels.length) {
            throw OAPIException.wrappedForScriptableGetMethod("Index out of range for LabelList (requested index " + index + " for list of length " + this.labels.length + ")");
        }
        return (Scriptable)Runtime.createHostObjectInCurrentRuntime("$Ref", this.labels[index]);
    }

    // --------------------------------------------------------------------------------------------------------------
    // Warning: Sorts labels in place
    public static int[] sortedLabels(int[] labels) {
        Arrays.sort(labels);
        return labels;
    }

    public static int checkedObjectToLabelInt(Object object) {
        int n = -1;
        if(object != null && object instanceof Number) {
            Number number = (Number)object;
            if(number.floatValue() != number.intValue()) {
                throw new OAPIException("Bad label value (Not integer)");
            }
            n = number.intValue();
        } else if(object instanceof KObjRef) {
            n = ((KObjRef)object).jsGet_objId();
        } else {
            throw new OAPIException("Bad label value");
        }

        if(n <= 0) {
            throw new OAPIException("Bad label value (<= 0)");
        }
        return n;
    }

    public static int[] nativeArrayToLabelArray(NativeArray array) {
        long numLabels = array.getLength();
        int[] labels = new int[(int)numLabels];
        for(int l = 0; l < (int)numLabels; ++l) {
            labels[l] = checkedObjectToLabelInt(array.get(l, array)); // ConsString is checked
        }
        return sortedLabels(labels);
    }

    // --------------------------------------------------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        public AppLabelList constructLabelList(int[] labels);

        public int[] filterToLabelsOfType(int[] labels, int[] types);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }
}
