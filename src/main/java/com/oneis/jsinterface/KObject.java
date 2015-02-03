/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface;

import org.mozilla.javascript.*;

import com.oneis.javascript.Runtime;
import com.oneis.javascript.JsConvert;
import com.oneis.javascript.OAPIException;
import com.oneis.jsinterface.app.*;

import java.util.Date;

public class KObject extends KScriptable {
    private AppObject appObject;
    private String descriptiveTitle;

    public KObject() {
    }

    public void jsConstructor() {
    }

    public String getClassName() {
        return "$StoredObjectInterface";
    }

    public void setAppObject(AppObject appObject) {
        if(this.appObject != null) {
            throw new RuntimeException("AppObject already set in KObject");
        }
        this.appObject = appObject;
    }

    public AppObject toRubyObject() {
        return this.appObject;
    }

    // Unwrap from a Scriptable, returning null if it's not a wrapped KObject
    static public KObject unwrap(Scriptable wrapper) {
        if(wrapper == null) {
            return null;
        }
        Object o = wrapper.get("$kobject", wrapper); // ConsString is checked
        if(o != null && o instanceof KObject) {
            return (KObject)o;
        }
        return null;
    }

    // Find the Ruby object via the JavaScript wrapper
    static public AppObject toRubyObjectFromWrapper(Scriptable wrapper) {
        Object o = wrapper.get("$kobject", wrapper); // ConsString is checked
        if(o != null && o instanceof KObject) {
            return ((KObject)o).toRubyObject();
        }
        return null;
    }

    // Test a JavaScript object
    static boolean isWrapperForKObject(Scriptable wrapper) {
        return null != toRubyObjectFromWrapper(wrapper);
    }

    public static Scriptable jsStaticFunction_constructBlankObject(KLabelList labels) {
        return KObject.fromAppObject(rubyInterface.constructBlankObject(labels.toRubyObject()), true /* mutable */);
    }

    // --------------------------------------------------------------------------------------------------------------
    static public Scriptable load(KObjRef ref) {
        AppObject appObject = rubyInterface.readObject(ref.jsGet_objId());
        if(appObject == null) {
            return null;
        }
        return KObject.fromAppObject(appObject, false /* not mutable */);
    }

    static public Scriptable fromAppObject(AppObject appObj, boolean mutable) {
        Runtime runtime = Runtime.getCurrentRuntime();

        // Build the interface object
        KObject obj = (KObject)runtime.createHostObject("$StoredObjectInterface");
        obj.setAppObject(appObj);

        // Make the actual JavaScript object
        ScriptableObject jsObj = (ScriptableObject)runtime.createHostObject(mutable ? "$StoreObjectMutable" : "$StoreObject");
        // Store the underlying object in the object
        jsObj.put("$kobject", jsObj, obj);
        // Store the objref of this object, if it's not the null objref
        AppObjRef ref = appObj.objref();
        if(ref != null && ref.objId() != 0) {
            jsObj.put("ref", jsObj, KObjRef.fromAppObjRef(ref));
        }

        return jsObj;
    }

    // Store operations which mutate an object return a new version, which needs to be turned into a JS object and
    // the $kobject property updated by the JS.
    static KObject mutatedReturn(AppObject appObj) {
        Runtime runtime = Runtime.getCurrentRuntime();
        KObject obj = (KObject)runtime.createHostObject("$StoredObjectInterface");
        obj.setAppObject(appObj);
        return obj;
    }

    // --------------------------------------------------------------------------------------------------------------
    public Scriptable jsFunction_mutableCopy() {
        return KObject.fromAppObject(this.appObject.dup(), true /* mutable */);
    }

    // --------------------------------------------------------------------------------------------------------------
    public KObjRef jsGet_ref() {
        AppObjRef ref = this.appObject.objref();
        return (ref == null) ? null : KObjRef.fromAppObjRef(ref);
    }

    public KLabelList jsFunction_getLabels() {
        return KLabelList.fromAppLabelList(this.appObject.labels());
    }

    public boolean jsFunction_getIsDeleted() {
        return this.appObject.deleted();
    }

    public int jsFunction_getVersion() {
        return this.appObject.version();
    }

    public int jsFunction_getCreatedByUid() {
        return this.appObject.creation_user_id();
    }

    public int jsFunction_getLastModificationUid() {
        return this.appObject.last_modified_user_id();
    }

    public Scriptable jsFunction_getCreationDate() {
        return Runtime.createHostObjectInCurrentRuntime("Date", this.appObject.jsGetCreationDate());
    }

    public Scriptable jsFunction_getLastModificationDate() {
        return Runtime.createHostObjectInCurrentRuntime("Date", this.appObject.jsGetLastModificationDate());
    }

    public boolean jsFunction_isKindOf(KObjRef ref) {
        // If undefined or null is passed in (eg SCHEMA.O_TYPE_SOMETHING_CUSTOM used when type is not defined), return false now.
        if(ref == null) {
            return false;
        }
        // Otherwise use the Ruby code
        return rubyInterface.objectIsKindOf(this.toRubyObject(), ref.jsGet_objId());
    }

    public String jsFunction_generateObjectURL(boolean asFullURL) {
        return rubyInterface.generateObjectURL(this.toRubyObject(), asFullURL);
    }

    public String jsFunction_descriptionForConsole() {
        return rubyInterface.descriptionForConsole(this.toRubyObject());
    }

    // --------------------------------------------------------------------------------------------------------------
    public Object jsFunction_first(int desc, boolean haveQual, int qual) {
        return attrToJs(Runtime.getCurrentRuntime(), this.appObject.first_attr(desc, haveQual ? qual : null));
    }

    public boolean jsFunction_has(Object value, boolean haveDesc, int desc, boolean haveQual, int qual) {
        return this.appObject.has_attr(jsToAttr(value), haveDesc ? desc : null, haveQual ? qual : null);
    }

    public boolean jsFunction_valuesEqual(Scriptable object, boolean haveDesc, int desc, boolean haveQual, int qual) {
        AppObject appobj = toRubyObjectFromWrapper(object);
        if(appobj == null) {
            throw new OAPIException("Object passed to valuesEqual() is not a StoreObject");
        }
        if(haveQual && !haveDesc) {
            throw new OAPIException("Descriptor required if qualifier is specified.");
        }
        return this.appObject.values_equal(appobj, haveDesc ? desc : null, haveQual ? qual : null);
    }

    // Uses the hasDesc and hasQual arguments as JS nulls get converted to 0 Integers by Rhino
    public void jsFunction_each(Integer desc, boolean hasDesc, Integer qual, boolean hasQual, Scriptable iterator) {
        final Function iteratorFn = (Function)iterator;
        final Runtime runtime = Runtime.getCurrentRuntime();
        this.appObject.jsEach((hasDesc ? desc : null), (hasQual ? qual : null), new AppObject.AttrIterator() {
            public boolean attr(Object value, int desc, int qual) {
                iteratorFn.call(runtime.getContext(), iteratorFn, iteratorFn,
                        new Object[]{attrToJs(runtime, value), desc, qual});
                return true;
            }
        });
    }

    public void jsFunction_append(Object value, int desc, int qual) {
        this.appObject.add_attr(jsToAttr(value), desc, qual);
    }

    public void jsFunction_remove(Integer desc, Integer qual, boolean hasQual, Scriptable iterator) {
        if(iterator == null) {
            this.appObject.jsDeleteAttrs(desc, (hasQual ? qual : null));
        } else {
            final Function iteratorFn = (Function)iterator;
            final Runtime runtime = Runtime.getCurrentRuntime();
            this.appObject.jsDeleteAttrsIterator(desc, (hasQual ? qual : null), new AppObject.AttrIterator() {
                public boolean attr(Object value, int desc, int qual) {
                    Boolean result = (Boolean)iteratorFn.call(runtime.getContext(), iteratorFn, iteratorFn,
                            new Object[]{attrToJs(runtime, value), desc, qual});
                    return result;
                }
            });
        }
    }

    public KObject jsFunction_deleteObject() {
        return mutatedReturn(rubyInterface.deleteObject(this.appObject));
    }

    public static void deleteObjectByRef(AppObjRef ref) {
        rubyInterface.deleteObject(ref);
    }

    public KObject jsFunction_relabelObject(KLabelChanges labelChanges) {
        return mutatedReturn(rubyInterface.relabelObject(this.appObject, labelChanges.toRubyObject()));
    }

    public String jsFunction_toViewJSON(String kind, String optionsJSON) {
        return rubyInterface.makeObjectViewJSON(this.appObject, kind, optionsJSON);
    }

    public KObject jsFunction_saveObject(boolean create, KLabelChanges labelChanges) {
        AppLabelChanges appLabelChanges = (labelChanges == null) ? null : labelChanges.toRubyObject();
        AppObject mutated = null;
        if(create) {
            mutated = rubyInterface.createObject(this.toRubyObject(), appLabelChanges);
        } else {
            mutated = rubyInterface.updateObject(this.toRubyObject(), appLabelChanges);
        }
        return KObject.mutatedReturn(mutated);
    }

    // --------------------------------------------------------------------------------------------------------------
    public String getDescriptiveTitle() {
        // Cached as a little expensive to generate
        if(this.descriptiveTitle == null) {
            this.descriptiveTitle = rubyInterface.objectDescriptiveTitle(this.appObject);
        }
        return this.descriptiveTitle;
    }

    public String jsFunction_descriptiveTitle() // function to be consistent with the rest of the object API and to reflect the expensive of calling
    {
        return this.getDescriptiveTitle();
    }

    // --------------------------------------------------------------------------------------------------------------
    // TODO: Better error checking of objects passed in -- unwrap returns null on error.
    public static boolean jsStaticFunction_clientSideEditorDecode(String encoded, Scriptable object) {
        return rubyInterface.clientSideEditorDecode(encoded, KObject.unwrap(object).toRubyObject());
    }

    public static String jsStaticFunction_clientSideEditorEncode(Scriptable object) {
        return rubyInterface.clientSideEditorEncode(KObject.unwrap(object).toRubyObject());
    }

    // --------------------------------------------------------------------------------------------------------------
    static public Object attrToJs(Runtime runtime, Object value) {
        // Whitelist list of classes which will be allowed across the JavaScript boundary
        if(value == null) {
            return null;
        } else if(value instanceof AppObjRef) {
            return runtime.createHostObject("$Ref", ((AppObjRef)value).objId());
        } else if(value instanceof AppText) {
            // Create a string object augmented with an additional property
            KText text = (KText)runtime.createHostObject("$KText");
            text.setText((AppText)value);
            return text;
        } else if(value instanceof AppDateTime) {
            return KDateTime.fromAppDateTime((AppDateTime)value);
        } else if(value instanceof java.lang.Number || value instanceof java.lang.Boolean) {
            // NOTE: java.lang.Strings are dropped here, because they should all be KText classes
            return value;
        } else {
            // Ask the Ruby side for support
/*            Object converted = rubyInterface.attrValueConversionToJava(value);
             if(converted != null)
             {
             if(converted instanceof java.util.Date)
             {
             // Convert the Java Date object into a JavaScript Date object
             return runtime.createHostObject("Date", ((java.util.Date)converted).getTime());
             }
             }*/
        }

        // Drop the value
        return null;
    }

    static public Object jsToAttr(Object value) {
        AppObject obj = null;
        if(value == null) {
            return null;
        } else if(value instanceof KObjRef) {
            return ((KObjRef)value).toRubyObject();
        } else if(value instanceof KObject) {
            // This is actually unlikely to happen, because KObjects are wrapped.
            return ((KObject)value).toRubyObject();
        } else if(value instanceof CharSequence) {
            // Allow java.lang.Strings/CharSequence here, because they'll be converted to KText objects in the Ruby side
            return ((CharSequence)value).toString();
        } else if(value instanceof KText) {
            return ((KText)value).toRubyObject();
        } else if(value instanceof java.lang.Number || value instanceof java.lang.Boolean) {
            return value;
        } else if(value instanceof KDateTime) {
            // Return the wrapped Ruby KDateTime object.
            return ((KDateTime)value).toRubyObject();
        } else if((value instanceof Scriptable) && null != (obj = KObject.toRubyObjectFromWrapper((Scriptable)value))) {
            // Was a wrapped KObject
            return obj;
        } else {
            // First attempt to convert date
            Date d = JsConvert.tryConvertJsDate(value);
            if(d != null) {
                value = d;
            }
            // Then see if the Ruby code will convert it
            Object converted = rubyInterface.attrValueConversionFromJava(value);
            if(converted != null) {
                return converted;
            }
        }

        // Drop the value
        return null;
    }

    // --------------------------------------------------------------------------------------------------------------
    static public void jsStaticFunction__preallocateRef(KObject object) {
        rubyInterface.preallocateRef(object.toRubyObject());
    }

    // --------------------------------------------------------------------------------------------------------------
    static public Scriptable jsStaticFunction_loadHistory(KObject object) {
        AppObject[] history = rubyInterface.loadObjectHistory(object.toRubyObject());
        Object jsHistory[] = new Object[history.length];
        for(int i = 0; i < history.length; ++i) {
            jsHistory[i] = KObject.fromAppObject(history[i], false);
        }
        Runtime runtime = Runtime.getCurrentRuntime();
        return runtime.getContext().newArray(runtime.getJavaScriptScope(), jsHistory);

    }

    // --------------------------------------------------------------------------------------------------------------
    static public Integer[] getObjectHierarchyIdPath(Integer objId) {
        return rubyInterface.getObjectHierarchyIdPath(objId);
    }

    // --------------------------------------------------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        public Object attrValueConversionToJava(Object value);

        public Object attrValueConversionFromJava(Object value);

        public AppObject constructBlankObject(AppLabelList labels);

        public void preallocateRef(AppObject object);

        public AppObject createObject(AppObject object, AppLabelChanges labelChanges);

        public AppObject readObject(int objID);

        public AppObject updateObject(AppObject object, AppLabelChanges labelChanges);

        public AppObject deleteObject(Object object);    // AppObject or AppObjRef

        public AppObject relabelObject(Object object, AppLabelChanges labelChanges);

        public boolean objectIsKindOf(AppObject object, int objId);

        public String objectDescriptiveTitle(AppObject object);

        public String generateObjectURL(AppObject object, boolean asFullURL);

        public String descriptionForConsole(AppObject object);

        public String makeObjectViewJSON(AppObject object, String kind, String optionsJSON);

        public AppObject[] loadObjectHistory(AppObject object);

        public Integer[] getObjectHierarchyIdPath(Integer objId);

        // Client side editor support
        public boolean clientSideEditorDecode(String encoded, AppObject object);

        public String clientSideEditorEncode(AppObject object);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }

}
