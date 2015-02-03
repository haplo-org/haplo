/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface.util;

import org.mozilla.javascript.*;
import java.util.HashMap;

import com.oneis.jsinterface.KObject;

public class KRefKeyDictionaryHierarchical extends KRefKeyDictionary {
    private HashMap<Integer, Object> childDictionary;

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

    public Object jsFunction_set(Object keyObject, Object value) {
        childDictionary = null; // invalidate
        return super.jsFunction_set(keyObject, value);
    }

    public Object jsFunction_remove(Object keyObject) {
        childDictionary = null; // invalidate
        return super.jsFunction_remove(keyObject);
    }
}
