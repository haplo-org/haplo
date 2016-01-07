/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.template.driver.rhinojs;

import java.util.Map;

import org.haplo.template.html.Driver;
import org.haplo.template.html.Template;
import org.haplo.template.html.Context;
import org.haplo.template.html.RenderException;

import org.mozilla.javascript.Scriptable;
import org.mozilla.javascript.ScriptableObject;
import org.mozilla.javascript.Undefined;
import org.mozilla.javascript.UniqueTag;
import org.mozilla.javascript.ScriptRuntime;

class RhinoJavaScriptDriver extends Driver {
    private Object rootView;

    public RhinoJavaScriptDriver(Object view) {
        this.rootView = view;
    }

    public Object getRootView() {
        return this.rootView;
    }

    public Driver driverWithNewRoot(Object rootView) {
        return new RhinoJavaScriptDriver((Scriptable)rootView);
    }

    public Object getValueFromView(Object view, String[] path) {
        if(view instanceof Scriptable) {
            Scriptable o = (Scriptable)view;
            for(int i = 0; i < path.length; ++i) {
                if(o == null || (o instanceof Undefined)) { return null; }
                Object value = ScriptableObject.getProperty(o, path[i]);
                if(value instanceof Scriptable) {
                    o = (Scriptable)value;
                } else {
                    // Scriptable values can be any Object, allow this in last entry in path
                    if(i == (path.length - 1)) {
                        return hasValue(value) ? value : null;
                    }
                    o = null;
                }
            }
            return hasValue(o) ? o : null;
        } else if(path.length == 0) {
            return view;    // to allow . value to work
        }
        return null;
    }

    public String valueToStringRepresentation(Object value) {
        if(!hasValue(value)) { return null; }
        if((value instanceof Double) && !((Double)value).isInfinite()) {
            // Special handling for Doubles representing Integers
            long valueAsLong = ((Double)value).longValue();
            if((double)valueAsLong == ((Double)value).doubleValue()) {
                return Long.toString(valueAsLong);
            }
        }
        return value.toString();
    }

    public void iterateOverValueAsArray(Object value, ArrayIterator iterator) throws RenderException {
        // Works on any Array-like JS Object
        int length = isArrayLikeScriptableObject(value);
        if(length == -1) { return; }
        Scriptable scriptable = (Scriptable)value;
        for(int i = 0; i < length; ++i) {
            Object entry = scriptable.get(i, scriptable);
            iterator.entry(hasValue(entry) ? entry : null);
        }
    }

    @SuppressWarnings("unchecked")
    public void iterateOverValueAsDictionary(Object value, DictionaryIterator iterator) throws RenderException {
        if(!(value instanceof Map)) { return; }
        for(Map.Entry<Object,Object> entry : ((Map<Object,Object>)value).entrySet()) {
            iterator.entry(entry.getKey().toString(), entry.getValue());
        }
    }

    public boolean valueIsTruthy(Object value) {
        if(value instanceof Scriptable) {
            if(isArrayLikeScriptableObject(value) == 0) {
                return false;   // empty array
            }
            return ScriptRuntime.toBoolean(value);
        } else {
            return super.valueIsTruthy(value);
        }
    }

    // ----------------------------------------------------------------------

    private static boolean hasValue(Object object) {
        return !(
            (object == null) ||
            (object instanceof Undefined) ||
            (object instanceof UniqueTag)
        );
    }

    // Returns -1 if not a JS object which looks like an array, otherwise the length
    private static int isArrayLikeScriptableObject(Object object) {
        if(!(object instanceof Scriptable)) { return -1; }
        Scriptable scriptable = (Scriptable)object;
        Object lengthProperty = scriptable.get("length", scriptable);
        if(!(hasValue(lengthProperty) && (lengthProperty instanceof Number))) { return -1; }
        long lengthL = ((Number)lengthProperty).longValue();
        // JS max array length is actually (2^53)-1, but Rhino uses int
        if(lengthL < 0 || lengthL > Integer.MAX_VALUE) { return -1; }
        return (int)lengthL;
    }
}
