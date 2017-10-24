/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.util;

import org.mozilla.javascript.*;
import java.util.HashMap;
import java.util.ArrayList;

import org.haplo.javascript.Runtime;
import org.haplo.jsinterface.KObject;

public class KRefKeyDictionaryHierarchical extends KRefKeyDictionary {
    private HashMap<Integer, Object> childDictionary;
    private HashMap<Integer, Object> allHierarchicalDictionary;

    public KRefKeyDictionaryHierarchical() {
    }

    public String getClassName() {
        return "$RefKeyDictionaryHierarchical";
    }

    public void jsConstructor(Function constructorFn, int sizeHint) {
        super.jsConstructor(constructorFn, sizeHint);
    }

    // --------------------------------------------------------------------------------------------------------------
    public Object jsFunction_get(Object keyObject) {
        Integer id = keyObjectToId(keyObject);
        // In the 'cache' of child objects? Might be a null value stored, so use containsKey() to check.
        if((this.childDictionary != null) && this.childDictionary.containsKey(id)) {
            return returnableValue(this.childDictionary.get(id));
        }
        // See if the underlying dictionary has the exact key set
        Object value = getValueByIdWithoutConstructorCall(id);
        if(value != null) {
            return value;
        }
        // Try the object's path, storing any found results
        // Search backwards, ignoring the last Id which is the ID of the initial query
        Integer path[] = KObject.getObjectHierarchyIdPath(id);
        for(int x = path.length - 1; x >= 0; --x) {
            Integer parentId = path[x];
            value = getValueByIdWithoutConstructorCall(parentId);
            if(value != null) {
                break;
            }
        }
        // Otherwise get the underlying dictionary to do a normal lookup
        if(value == null) {
            value = getValue(keyObject);
        }
        // Store the returned value, regardless of whether it's null or not, to avoid database lookups of the path
        if(this.childDictionary == null) {
            this.childDictionary = new HashMap<Integer, Object>();
        }
        this.childDictionary.put(id, value);
        return returnableValue(value);
    }

    public Object jsFunction_getWithoutHierarchy(Object keyObject) {
        invalidateCachedLookups();  // because get() uses caches, and constructor functions may set this value
        return getValue(keyObject);
    }

    public Object jsFunction_getAllInHierarchy(Object keyObject) {
        Integer id = keyObjectToId(keyObject);
        // Create cache, or check to see if the object is in it.
        if(this.allHierarchicalDictionary == null) {
            this.allHierarchicalDictionary = new HashMap<Integer, Object>();
        } else {
            Object cachedArray = this.allHierarchicalDictionary.get(id); // ConsString is checked
            if(cachedArray != null) {
                return cachedArray;
            }
        }
        // Find the list of values
        Integer path[] = KObject.getObjectHierarchyIdPath(id);
        ArrayList<Object> allValues = new ArrayList<Object>(path.length);
        for(Integer pathId : path) {
            Object value = getValueByIdWithoutConstructorCall(pathId);
            if(value != null) {
                allValues.add(returnableValue(value));
            }
        }
        // Create and cache a sealed array
        Runtime runtime = Runtime.getCurrentRuntime();
        Object array = runtime.getContext().newArray(runtime.getJavaScriptScope(), allValues.toArray());
        ((ScriptableObject)array).sealObject();
        this.allHierarchicalDictionary.put(id, array);
        return array;
    }

    public Object jsFunction_set(Object keyObject, Object value) {
        invalidateCachedLookups();
        return super.jsFunction_set(keyObject, value);
    }

    public Object jsFunction_remove(Object keyObject) {
        invalidateCachedLookups();
        return super.jsFunction_remove(keyObject);
    }

    // --------------------------------------------------------------------------------------------------------------

    private void invalidateCachedLookups() {
        this.childDictionary = null;
        this.allHierarchicalDictionary = null;
    }

    @Override
    protected void haveUsedValueConstructorFn() {
        // Constructing a value means the hierachical cache will be invalid
        this.allHierarchicalDictionary = null;
        super.haveUsedValueConstructorFn();
    }
}
