/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.util;

import org.mozilla.javascript.*;
import java.util.Map;
import java.util.HashMap;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;
import org.haplo.jsinterface.KScriptable;
import org.haplo.jsinterface.KObjRef;

public class KRefKeyDictionary extends KScriptable {
    private HashMap<Integer, Object> dictionary;
    private Function unknownKeyValueConstructorFn;

    private final int MAX_SIZE_HINT = 2048; // maximum initial size which can be given

    public KRefKeyDictionary() {
    }

    public String getClassName() {
        return "$RefKeyDictionary";
    }

    @Override
    protected String getConsoleData() {
        checkHasBeenConstructed();
        Runtime runtime = Runtime.getCurrentRuntime();

        Scriptable jsonOb = runtime.getContext().newObject(runtime.getJavaScriptScope());

        HashMap<String, String> stringified = new HashMap<String, String>();
        for(Map.Entry<Integer, Object> entry : this.dictionary.entrySet()) {
            String key = KObjRef.idToString(entry.getKey());
            Object value = entry.getValue();
            jsonOb.put(key, jsonOb, value);
        }
        return runtime.jsonStringify(jsonOb);
    }
    // --------------------------------------------------------------------------------------------------------------

    public void jsConstructor(Function constructorFn, int sizeHint) {
        if(sizeHint < 64) {
            sizeHint = 64;
        }
        if(sizeHint > MAX_SIZE_HINT) {
            sizeHint = MAX_SIZE_HINT;
        }
        this.dictionary = new HashMap<Integer, Object>(sizeHint);
        this.unknownKeyValueConstructorFn = constructorFn;
    }

    public int jsGet_length() {
        checkHasBeenConstructed();
        return this.dictionary.size();
    }

    protected Object getValue(Object keyObject) {
        checkHasBeenConstructed();
        Integer key = keyObjectToId(keyObject);
        Object value = this.dictionary.get(key); // ConsString is checked
        if(value == null && unknownKeyValueConstructorFn != null) {
            // Construct a new value for this key
            Runtime runtime = Runtime.getCurrentRuntime();
            value = unknownKeyValueConstructorFn.call(
                    runtime.getContext(), unknownKeyValueConstructorFn, unknownKeyValueConstructorFn,
                    new Object[]{keyObject});
            if(value != null) {
                // If it's not a null value, store it now so the result is consistent next time
                this.dictionary.put(key, value);
            }
            this.haveUsedValueConstructorFn();
        }
        return value;
    }

    protected void haveUsedValueConstructorFn() {
    }

    protected Object getValueByIdWithoutConstructorCall(Integer id) {
        checkHasBeenConstructed();
        return this.dictionary.get(id);
    }

    protected Object returnableValue(Object value) {
        return (value != null) ? value : Runtime.getCurrentRuntime().getContext().getUndefinedValue();
    }

    public Object jsFunction_get(Object keyObject) {
        return returnableValue(getValue(keyObject));
    }

    public Object jsFunction_set(Object keyObject, Object value) {
        if(value == null) {
            throw new OAPIException("Value given to RefKeyDictionary set() must not be null or undefined");
        }
        checkHasBeenConstructed();
        Integer key = keyObjectToId(keyObject);
        this.dictionary.put(key, value);
        return value;
    }

    public Object jsFunction_remove(Object keyObject) {
        checkHasBeenConstructed();
        Integer key = keyObjectToId(keyObject);
        Object value = this.dictionary.remove(key);
        return (value != null) ? value : Runtime.getCurrentRuntime().getContext().getUndefinedValue();
    }

    public void jsFunction_each(Function iterator) {
        checkHasBeenConstructed();
        Context scope = Runtime.getCurrentRuntime().getContext();
        for(Map.Entry<Integer, Object> e : this.dictionary.entrySet()) {
            Object r = iterator.call(scope, iterator, iterator, new Object[]{KObjRef.fromId(e.getKey()), e.getValue()}); // ConsString is checked
            if(r != null && (r instanceof Boolean) && ((Boolean)r).booleanValue()) {
                return;
            }
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private void checkHasBeenConstructed() {
        if(this.dictionary == null) {
            throw new RuntimeException("KRefKeyDictionary has not been constructed");
        }
    }

    protected Integer keyObjectToId(Object keyObject) {
        if(keyObject != null) {
            if(keyObject instanceof KObjRef) {
                return ((KObjRef)keyObject).jsGet_objId();
            }
            if(keyObject instanceof CharSequence) {
                Integer i = KObjRef.stringToId(((CharSequence)keyObject).toString());
                if(i != null) {
                    return i;
                }
            }
        }
        throw new OAPIException("Bad key passed to RefKeyDictionary");
    }

}
