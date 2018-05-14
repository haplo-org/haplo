/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.mozilla.javascript.*;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.JsConvert;
import org.haplo.javascript.OAPIException;
import org.haplo.jsinterface.app.*;

import java.util.Date;

public class KObject extends KScriptable {
    private KObjRef ref;
    private AppObject appObject;
    private String descriptiveTitle;
    private boolean isNewObject;
    private boolean isMutable;
    private Scriptable history;

    // --------------------------------------------------------------------------------------------------------------
    public static final Integer A_PARENT = new Integer(201);
    public static final Integer A_TYPE = new Integer(210);
    public static final Integer A_TITLE = new Integer(211);

    // --------------------------------------------------------------------------------------------------------------
    public KObject() {
    }

    public void setAppObject(AppObject appObject, boolean isMutable) {
        if(this.appObject != null) {
            throw new RuntimeException("AppObject already set in KObject");
        }
        this.appObject = appObject;
        this.isMutable = isMutable;
    }

    protected void setIsNewObject() {
        this.isNewObject = true;
    }

    public AppObject toRubyObject() {
        return this.appObject;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$StoreObject";
    }

    @Override
    public String getConsoleClassName() {
        return this.isMutable ? "StoreObjectMutable" : "StoreObject";
    }

    @Override
    public String getConsoleData() {
        return rubyInterface.descriptionForConsole(this.toRubyObject());
    }

    // --------------------------------------------------------------------------------------------------------------
    static public AppObject toHookResponseAppValue(Scriptable object) {
        return (object instanceof KObject) ? ((KObject)object).toRubyObject() : null;
    }

    // --------------------------------------------------------------------------------------------------------------
    static public KObject fromAppObject(AppObject appObj, boolean mutable) {
        Runtime runtime = Runtime.getCurrentRuntime();
        KObject obj = (KObject)runtime.createHostObject("$StoreObject");
        obj.setAppObject(appObj, mutable);
        return obj;
    }

    public static Scriptable jsStaticFunction_constructBlankObject(KLabelList labels) {
        KObject o = KObject.fromAppObject(rubyInterface.constructBlankObject(labels.toRubyObject()), true /* mutable */);
        o.setIsNewObject();
        return o;
    }

    static public Scriptable load(KObjRef ref) {
        AppObject appObject = rubyInterface.readObject(ref.jsGet_objId());
        if(appObject == null) {
            return null;
        }
        return KObject.fromAppObject(appObject, false /* not mutable */);
    }

    // --------------------------------------------------------------------------------------------------------------
    private void withReturnedAppObject(AppObject appObject, boolean forceImmutable) {
        this.appObject = appObject;
        this.isMutable = forceImmutable ? false : !(appObject.frozen());
        this.descriptiveTitle = null;
        this.history = null;
    }

    // --------------------------------------------------------------------------------------------------------------
    public Scriptable jsFunction_mutableCopy() {
        if(this.appObject.restricted()) throw new OAPIException("Restricted objects cannot be made mutable.");
        return KObject.fromAppObject(this.appObject.dup(), true /* mutable */);
    }

    public Scriptable jsFunction_restrictedCopy(Scriptable user) {
        if(this.appObject.restricted()) throw new OAPIException("Restricted objects cannot be restricted again.");
        if(!(user instanceof KUser)) throw new OAPIException("restrictedCopy must be passed a user object");
        return KObject.fromAppObject(((KUser)user).toRubyObject().kobject_dup_restricted(this.appObject),
                                      false /* immutable */);
    }

    // --------------------------------------------------------------------------------------------------------------
    public KObjRef jsGet_ref() {
        if(this.ref == null) {
            AppObjRef objref = this.appObject.objref();
            this.ref = (objref == null) ? null : KObjRef.fromAppObjRef(objref);
        }
        return this.ref;
    }

    public boolean jsFunction_isMutable() {
        return this.isMutable;
    }

    public boolean jsFunction_isRestricted() {
        return this.appObject.restricted();
    }

    public boolean jsFunction_canReadAttribute(Object desc, Scriptable user) {
        KUser kuser = (KUser)user;
        if (kuser.jsGet_isSuperUser()) {
            return true;
        } else {
            AppObjectRestrictedAttributes ra = (kuser.toRubyObject().kobject_restricted_attributes(this.appObject));
            Object result = this.withCheckedArgs("canReadAttribute()", desc, true, null, null, false,
                                                 (d,q,i) ->
                                                 ra.can_read_attribute(d));
            return ((Boolean)result).booleanValue();
        }
    }

    public boolean jsFunction_canModifyAttribute(Object desc, Scriptable user) {
        KUser kuser = (KUser)user;
        if (kuser.jsGet_isSuperUser()) {
            return true;
        } else {
            AppObjectRestrictedAttributes ra = (kuser.toRubyObject().kobject_restricted_attributes(this.appObject));
            Object result = this.withCheckedArgs("canModifyAttribute()", desc, true, null, null, false,
                                                 (d,q,i) ->
                                                 ra.can_modify_attribute(d));
            return ((Boolean)result).booleanValue();
        }
    }

    public KLabelList jsGet_labels() {
        return KLabelList.fromAppLabelList(this.appObject.labels());
    }

    public void jsSet_labels(Object value) {
        throw new OAPIException("labels is a read only property");
    }

    public boolean jsGet_deleted() {
        return this.appObject.deleted();
    }

    public int jsGet_version() {
        return this.appObject.version();
    }

    public int jsGet_creationUid() {
        return this.appObject.creation_user_id();
    }

    public int jsGet_lastModificationUid() {
        return this.appObject.last_modified_user_id();
    }

    public Scriptable jsGet_creationDate() {
        return Runtime.createHostObjectInCurrentRuntime("Date", this.appObject.jsGetCreationDate());
    }

    public Scriptable jsGet_lastModificationDate() {
        return Runtime.createHostObjectInCurrentRuntime("Date", this.appObject.jsGetLastModificationDate());
    }

    // --------------------------------------------------------------------------------------------------------------
    public String jsGet_title() {
        return rubyInterface.objectTitleAsString(this.appObject);
    }

    public String jsGet_shortestTitle() {
        return rubyInterface.objectTitleAsStringShortest(this.appObject);
    }

    public String jsGet_descriptiveTitle() {
        // Cached as a little expensive to generate
        if(this.descriptiveTitle == null) {
            this.descriptiveTitle = rubyInterface.objectDescriptiveTitle(this.appObject);
        }
        return this.descriptiveTitle;
    }

    // --------------------------------------------------------------------------------------------------------------

    public boolean jsGet_willComputeAttributes() {
        return this.appObject.needs_to_compute_attrs();
    }

    public Scriptable jsFunction_computeAttributesIfRequired() {
        this.appObject.jsComputeAttrsIfRequired();
        return this;
    }

    // --------------------------------------------------------------------------------------------------------------
    public Scriptable jsGet_history() {
        if(this.history == null) {
            AppObject[] history = rubyInterface.loadObjectHistory(this.appObject);
            Object jsHistory[] = new Object[history.length];
            for(int i = 0; i < history.length; ++i) {
                jsHistory[i] = KObject.fromAppObject(history[i], false);
            }
            Runtime runtime = Runtime.getCurrentRuntime();
            this.history = runtime.getContext().newArray(runtime.getJavaScriptScope(), jsHistory);
        }
        return this.history;
    }

    // --------------------------------------------------------------------------------------------------------------
    public boolean jsFunction_isKindOf(Object ref) {
        if(ref == null || !(ref instanceof KObjRef)) { return false; }
        return rubyInterface.objectIsKindOf(this.toRubyObject(), ((KObjRef)ref).jsGet_objId());
    }

    public boolean jsFunction_isKindOfTypeAnnotated(String annotation) {
        if(annotation == null) { return false; }
        return rubyInterface.objectIsKindOfTypeAnnotated(this.toRubyObject(), annotation);
    }

    public String jsFunction_url(boolean asFullURL) {
        return rubyInterface.generateObjectURL(this.toRubyObject(), asFullURL);
    }

    public String jsFunction_render(Object jsstyle) {
        String style = "generic";
        if(jsstyle instanceof CharSequence) { style = jsstyle.toString(); }
        // Rendering is performed via the host object to take advantage of controller caching
        return Runtime.getCurrentRuntime().getHost().renderObject(this.appObject, style);
    }

    // --------------------------------------------------------------------------------------------------------------

    interface ThreeArgFn {
        Object fn(Integer desc, Integer qual, Function iterator);
    }

    private boolean caNoArg(Object a) {
        return (a == null) || (a instanceof Undefined);
    }

    private Integer caCheckedDesc(Object a, String jsFnName, String jsArgName) {
        if(a == null) { return null; }
        if(a instanceof Integer) {
            return (Integer)a;
        } else if(!(a instanceof Number)) {
            throw new OAPIException("Invalid "+jsArgName+" passed to StoreObject "+jsFnName);
        } else {
            return ((Number)a).intValue();
        }
    }

    private Object withCheckedArgs(
            String jsFnName,        // for exception messages
            Object desc, boolean descRequired, // desc may be optional
            Object qual,            // qualifer is always optional
            Object iterator, boolean iteratorSupported, // iterator is always optional, but may not be relevant
            ThreeArgFn implementation) {
        if(iteratorSupported) {
            if(caNoArg(iterator) && (qual instanceof Function)) {
                iterator = qual;
                qual = null;
            } else if(caNoArg(iterator) && caNoArg(qual) && (desc instanceof Function)) {
                iterator = desc;
                desc = null;
            }
        }
        // Convert undefined to null
        if(desc instanceof Undefined) { desc = null; }
        if(qual instanceof Undefined) { qual = null; }
        if(iterator instanceof Undefined) { iterator = null; }
        // Check types of arguments and call implementation
        if(descRequired && desc == null) {
            throw new OAPIException("Must pass a desc to StoreObject "+jsFnName);
        }
        if(iterator != null && !(iterator instanceof Function)) {
            throw new OAPIException("Invalid iterator passed to StoreObject "+jsFnName);
        }
        return implementation.fn(
            caCheckedDesc(desc, jsFnName, "descriptor"),
            caCheckedDesc(qual, jsFnName, "qualifier"),
            (iterator != null) ? (Function)iterator : null
        );
    }

    // --------------------------------------------------------------------------------------------------------------

    public Object jsFunction_first(Object desc, Object qual) {
        return withCheckedArgs("first()", desc, true, qual, null, false, (d,q,i) ->
            attrToJs(Runtime.getCurrentRuntime(), this.appObject.first_attr(d,q)));
    }
    public Object jsFunction_firstParent(Object qual) { return this.jsFunction_first(A_PARENT, qual); }
    public Object jsFunction_firstType(Object qual)   { return this.jsFunction_first(A_TYPE, qual); }
    public Object jsFunction_firstTitle(Object qual)  { return this.jsFunction_first(A_TITLE, qual); }

    public Object jsFunction_has(Object value, Object desc, Object qual) {
        Object jsValue = jsToAttr(value);
        if(jsValue == null) { return false; }
        return withCheckedArgs("has()", desc, false, qual, null, false, (d,q,i) ->
            (Boolean)this.appObject.has_attr(jsValue, d, q));
    }

    public Object jsFunction_valuesEqual(Scriptable object, Object desc, Object qual) {
        if(object == null) {
            throw new OAPIException("Object passed to valuesEqual() may not be null or undefined");
        }
        if(!(object instanceof KObject)) {
            throw new OAPIException("Object passed to valuesEqual() is not a StoreObject");
        }
        return withCheckedArgs("valuesEqual()", desc, false, qual, null, false, (d,q,i) -> {
            if(q != null && d == null) {
                throw new OAPIException("Descriptor required if qualifier is specified.");
            }
            return (Boolean)((KObject)object).toRubyObject().values_equal(this.appObject, d, q);
        });
    }

    /**
     * Different forms of calling:
     * A) Iteration with function(value, desc, qual)
     *   every(iterator) - all values
     *   every(desc, iterator) - all desc values
     *   every(desc, qual, iterator) - all desc+qual values
     * B) Returning an array of values
     *   every(desc)
     *   every(desc, qual)
     * null can be passed in place of desc, qual or iterator.
     */
    public Object jsFunction_every(Object desc, Object qual, Object iterator) {
        final Runtime runtime = Runtime.getCurrentRuntime();
        return withCheckedArgs("every()", desc, false, qual, iterator, true, (d,q,i) -> {
            if(i != null) {
                this.appObject.jsEach(d, q, (iValue, iDesc, iQual) -> {
                    i.call(runtime.getContext(), i, i,
                            new Object[]{attrToJs(runtime, iValue), iDesc, iQual});
                    return true;
                });
                return Context.getUndefinedValue();
            } else {
                Object[] attrs = this.appObject.all_attrs(d,q);
                Object[] jsAttrs = new Object[attrs.length];
                for(int x = 0; x < attrs.length; ++x) {
                    jsAttrs[x] = attrToJs(runtime, attrs[x]);
                }
                return runtime.getContext().newArray(runtime.getJavaScriptScope(), jsAttrs);
            }
        });
    }

    // Alias of every() for consistency
    public Object jsFunction_each(Object desc, Object qual, Object iterator) {
        return jsFunction_every(desc, qual, iterator);
    }

    // Don't have an everyParent() function because objects shouldn't have more than one parent.
    public Object jsFunction_everyType(Object qual, Object iterator)   { return this.jsFunction_every(A_TYPE, qual, iterator); }
    public Object jsFunction_everyTitle(Object qual, Object iterator)  { return this.jsFunction_every(A_TITLE, qual, iterator); }

    // --------------------------------------------------------------------------------------------------------------
    protected void mustBeMutableObject(String jsFnName) {
        if(!this.isMutable) {
            throw new OAPIException("StoreObject is not mutable when calling "+jsFnName);
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    public Object jsFunction_append(Object value, int desc, int qual) {
        mustBeMutableObject("append()");
        Object jsValue = jsToAttr(value);
        if(jsValue == null) {
            throw new OAPIException("null and undefined cannot be appended to a StoreObject");
        }
        this.appObject.add_attr(jsValue, desc, qual);
        return this;
    }

    public Object jsFunction_appendWithIntValue(Object value, int desc, int qual) {
        mustBeMutableObject("appendWithIntValue()");
        if(!(value instanceof Number)) {
            throw new OAPIException("Not a numeric type when calling appendWithIntValue()");
        }
        return jsFunction_append(((Number)value).intValue(), desc, qual);
    }

    public Object jsFunction_appendParent(Object value, int qual) { return jsFunction_append(value, A_PARENT, qual); }
    public Object jsFunction_appendType(Object value, int qual) { return jsFunction_append(value, A_TYPE, qual); }
    public Object jsFunction_appendTitle(Object value, int qual) { return jsFunction_append(value, A_TITLE, qual); }

    public Object jsFunction_remove(Object desc, Object qual, Object iterator) {
        mustBeMutableObject("remove()");
        return withCheckedArgs("remove()", desc, true, qual, iterator, true, (d,q,i) -> {
            if(i == null) {
                this.appObject.jsDeleteAttrs(d,q);
            } else {
                final Runtime runtime = Runtime.getCurrentRuntime();
                this.appObject.jsDeleteAttrsIterator(d, q, (iValue, iDesc, iQual) -> {
                    return ScriptRuntime.toBoolean(i.call(runtime.getContext(), i, i,
                        new Object[]{attrToJs(runtime, iValue), iDesc, iQual}));
                });
            }
            return this;
        });
    }

    public boolean jsFunction_deleteObject() {
        withReturnedAppObject(rubyInterface.deleteObject(this.appObject), false /* use object mutability */);
        return true;
    }

    public static void deleteObjectByRef(AppObjRef ref) {
        rubyInterface.deleteObject(ref);
    }

    public Object jsFunction_relabel(Object labelChanges) {
        if(this.jsGet_ref() == null) {
            throw new OAPIException("Cannot call relabel on a storeObject before it has been saved");
        }
        if((labelChanges == null) || !(labelChanges instanceof KLabelChanges)) {
            throw new OAPIException("relabel must be passed an O.labelChanges object");
        }
        if(this.isMutable) {
            throw new OAPIException("relabel() can only be used on immutable objects");
        }
        withReturnedAppObject(
            rubyInterface.relabelObject(this.appObject, ((KLabelChanges)labelChanges).toRubyObject()),
            true /* force immutable */);
        return Context.getUndefinedValue();
    }

    public Scriptable jsFunction_preallocateRef() {
        mustBeMutableObject("preallocateRef()");
        this.ref = KObjRef.fromAppObjRef(rubyInterface.preallocateRef(this.appObject));
        return this.ref;
    }

    public Scriptable jsFunction_save(Object labelChanges) {
        mustBeMutableObject("save()");
        AppLabelChanges appLabelChanges = null;
        if(!((labelChanges == null) || (labelChanges instanceof Undefined))) {
            if(labelChanges instanceof KLabelChanges) {
                appLabelChanges = ((KLabelChanges)labelChanges).toRubyObject();
            } else {
                throw new OAPIException("labelChanges must be an O.labelChanges object");
            }
        }
        AppObject mutated = this.isNewObject ?
            rubyInterface.createObject(this.appObject, appLabelChanges) :
            rubyInterface.updateObject(this.appObject, appLabelChanges);
        withReturnedAppObject(mutated, false /* use object mutability */);
        this.isNewObject = false;
        return this;
    }

    // --------------------------------------------------------------------------------------------------------------

    public Scriptable jsFunction_reindexText() {
        if(this.appObject != null && this.appObject.version() > 0) {
            rubyInterface.reindexText(this.appObject);
        }
        return this;
    }

    // --------------------------------------------------------------------------------------------------------------

    public static boolean jsStaticFunction__clientSideEditorDecode(String encoded, Scriptable object) {
        return rubyInterface.clientSideEditorDecode(encoded, ((KObject)object).toRubyObject());
    }

    public static String jsStaticFunction__clientSideEditorEncode(Scriptable object) {
        return rubyInterface.clientSideEditorEncode(((KObject)object).toRubyObject());
    }

    // --------------------------------------------------------------------------------------------------------------
    static public Object attrToJs(Runtime runtime, Object value) {
        // Whitelist list of classes which will be allowed across the JavaScript boundary
        if(value == null) {
            return null;
        } else if(value instanceof AppObjRef) {
            return runtime.createHostObject("$Ref", ((AppObjRef)value).objId());
        } else if(value instanceof AppText) {
            KText text = (KText)runtime.createHostObject("$KText");
            text.setText((AppText)value);
            return text;
        } else if(value instanceof AppDateTime) {
            return KDateTime.fromAppDateTime((AppDateTime)value);
        } else if(value instanceof java.lang.Number || value instanceof java.lang.Boolean) {
            // NOTE: java.lang.Strings are dropped here, because they should all be KText classes
            return value;
        }
        return null;
    }

    static public Object jsToAttr(Object value) {
        AppObject obj = null;
        if(value == null || value instanceof org.mozilla.javascript.Undefined) {
            return null;
        } else if(value instanceof KObjRef) {
            return ((KObjRef)value).toRubyObject();
        } else if(value instanceof KObject) {
            return ((KObject)value).toRubyObject();
        } else if(value instanceof CharSequence) {
            // Allow java.lang.Strings/CharSequence here, because they'll be converted to KText objects in the Ruby side
            return ((CharSequence)value).toString();
        } else if(value instanceof KText) {
            return ((KText)value).toRubyObject();
        } else if(value instanceof java.lang.Number || value instanceof java.lang.Boolean) {
            return value;
        } else if(value instanceof KDateTime) {
            return ((KDateTime)value).toRubyObject();
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
        return null;
    }

    // --------------------------------------------------------------------------------------------------------------
    static public Integer[] getObjectHierarchyIdPath(Integer objId) {
        return rubyInterface.getObjectHierarchyIdPath(objId);
    }

    // --------------------------------------------------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        public Object attrValueConversionFromJava(Object value);

        public AppObject constructBlankObject(AppLabelList labels);

        public AppObjRef preallocateRef(AppObject object);

        public AppObject createObject(AppObject object, AppLabelChanges labelChanges);

        public AppObject readObject(int objID);

        public AppObject updateObject(AppObject object, AppLabelChanges labelChanges);

        public AppObject deleteObject(Object object);    // AppObject or AppObjRef

        public AppObject relabelObject(Object object, AppLabelChanges labelChanges);

        public void reindexText(AppObject object);

        public boolean objectIsKindOf(AppObject object, int objId);

        public boolean objectIsKindOfTypeAnnotated(AppObject object, String annotation);

        public String objectTitleAsString(AppObject object);

        public String objectTitleAsStringShortest(AppObject object);

        public String objectDescriptiveTitle(AppObject object);

        public String generateObjectURL(AppObject object, boolean asFullURL);

        public String descriptionForConsole(AppObject object);

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
