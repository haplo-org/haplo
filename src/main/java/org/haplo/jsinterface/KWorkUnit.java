/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;
import org.haplo.javascript.JsJavaInterface;
import org.haplo.javascript.JsConvert;
import org.haplo.jsinterface.util.HstoreBackedTags;
import org.mozilla.javascript.*;

import org.haplo.jsinterface.app.*;

import java.util.Date;

public class KWorkUnit extends KScriptable {
    private AppWorkUnit workUnit;
    private boolean gotData;    // whether this.data is valid (either by setting, or by loading it from the Ruby side)
    private Object data;        // JSON-encodable data
    private boolean gotTags;
    private HstoreBackedTags tags;

    public KWorkUnit() {
        this.gotData = false;
        this.gotTags = false;
    }

    public void setWorkUnit(AppWorkUnit workUnit) {
        this.workUnit = workUnit;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$WorkUnit";
    }

    // --------------------------------------------------------------------------------------------------------------
    /* 
        The storeJSObject flag exists specifically for the hPreWorkUnitSave hook. As jsFunction_save() stores the data and
        tags before calling workUnit.save, the hook needs to be able to call the update function itself, to allow the hook to change
        the data or the tags. This requires the ruby object to have access to the JS object.
    */
    static public KWorkUnit fromAppWorkUnit(AppWorkUnit workUnit, boolean storeJSObject) {
        KWorkUnit w = (KWorkUnit)Runtime.createHostObjectInCurrentRuntime("$WorkUnit");
        w.setWorkUnit(workUnit);
        if(storeJSObject) {
            workUnit.jsStoreJSObject(w);
        }
        return w;
    }

    // --------------------------------------------------------------------------------------------------------------
    public static KWorkUnit jsStaticFunction_constructNew(String workType) {
        return KWorkUnit.fromAppWorkUnit(rubyInterface.constructWorkUnit(workType), false);
    }

    public static KWorkUnit jsStaticFunction_load(int id) {
        return KWorkUnit.fromAppWorkUnit(rubyInterface.loadWorkUnit(id), false);
    }

    // --------------------------------------------------------------------------------------------------------------
    public Integer jsGet_id() {
        Integer id = this.workUnit.id();
        if(id == null) {
            throw new OAPIException("WorkUnit has not been saved yet.");
        }
        return id;
    }

    public boolean jsGet_isSaved() {
        return this.workUnit.persisted();
    }

    public String jsGet_workType() {
        return this.workUnit.work_type();
    }

    // ---- visibility
    public boolean jsGet_visible() {
        return this.workUnit.visible();
    }

    public void jsSet_visible(boolean visible) {
        this.workUnit.setVisible(visible);
    }

    public boolean jsGet_autoVisible() {
        return this.workUnit.auto_visible();
    }

    public void jsSet_autoVisible(boolean autoVisible) {
        this.workUnit.setAutoVisible(autoVisible);
    }

    // ---- createdAt
    public Object jsGet_createdAt() {
        return JsConvert.millisecondsToJsDate(this.workUnit.created_at_milliseconds());
    }

    public void jsSet_createdAt(Object dummy) {
        throw new OAPIException("createdAt is a read only property");
    }

    // ---- openedAt
    public Object jsGet_openedAt() {
        return JsConvert.millisecondsToJsDate(this.workUnit.opened_at_milliseconds());
    }

    public void jsSet_openedAt(Object date) {
        this.workUnit.opened_at_milliseconds_set(convertAndCheckDate(date, true, "openedAt"));
    }

    // ---- deadline
    public Object jsGet_deadline() {
        return JsConvert.millisecondsToJsDate(this.workUnit.deadline_milliseconds());
    }

    public void jsSet_deadline(Object date) {
        this.workUnit.deadline_milliseconds_set(convertAndCheckDate(date, false, "deadline"));
    }

    // ---- closing (and reopening)
    public Object jsGet_closedAt() {
        return JsConvert.millisecondsToJsDate(this.workUnit.closed_at_milliseconds());
    }

    public void jsSet_closedAt(Object date) {
        throw new OAPIException("closedAt is a read only property - call close() instead");
    }

    public Scriptable jsFunction_close(Object value) {
        if(value == null || !(value instanceof KUser)) {
            throw new OAPIException("must pass a user object to work unit close()");
        }
        this.workUnit.set_as_closed_by(((KUser)value).toRubyObject());
        return this;
    }

    public boolean jsGet_closed() {
        return this.workUnit.closed_at_milliseconds() != null;
    }

    public Scriptable jsFunction_reopen() {
        this.workUnit.set_as_not_closed();
        return this;
    }

    // ---- createdBy
    public Scriptable jsGet_createdBy() {
        Integer id = this.workUnit.created_by_id();
        return (id == null) ? null : KUser.jsStaticFunction_getUserById(id);
    }

    public void jsSet_createdBy(Object value) {
        this.workUnit.setCreatedById(valueToRequiredUserId(value, "createdBy"));
    }

    // ---- actionableBy
    public Scriptable jsGet_actionableBy() {
        Integer id = this.workUnit.actionable_by_id();
        return (id == null) ? null : KUser.jsStaticFunction_getUserById(id);
    }

    public void jsSet_actionableBy(Object value) {
        this.workUnit.setActionableById(valueToRequiredUserId(value, "actionableBy"));
    }

    // ---- closedBy
    public Scriptable jsGet_closedBy() {
        Integer id = this.workUnit.closed_by_id();
        return (id == null) ? null : KUser.jsStaticFunction_getUserById(id);
    }

    public void jsSet_closedBy(Object value) {
        throw new OAPIException("closedBy is a read only property - use close() to close a work unit.");
    }

    public Scriptable jsGet_ref() {
        Integer objId = this.workUnit.objref_obj_id();
        if(objId == null) {
            return null;
        }
        return (objId == null) ? null : Runtime.createHostObjectInCurrentRuntime("$Ref", objId);
    }

    public void jsSet_ref(Object value) {
        if(value == null) {
            // Value is null
            this.workUnit.objref_obj_id_set(null);
            return;
        } else if(!(value instanceof KObjRef)) {
            // Not an objref
            throw new OAPIException("Bad type for setting ref property");
        }
        KObjRef ref = (KObjRef)value;
        this.workUnit.objref_obj_id_set(ref.jsGet_objId());
    }

    // ---- data
    public Object jsGet_data() {
        if(!this.gotData) {
            Runtime runtime = Runtime.getCurrentRuntime();
            this.data = runtime.jsonEncodedValueToObject(this.workUnit.data_json(), "work unit data");
            this.gotData = true;
        }
        return this.data;
    }

    public void jsSet_data(Object data) {
        // Store for saving later
        this.data = data;
        this.gotData = true;
    }

    // ---- tags
    public Object jsGet_tags() {
        if(!this.gotTags) {
            Runtime runtime = Runtime.getCurrentRuntime();
            Object decodedTags = runtime.jsonEncodedValueToObject(this.workUnit.jsGetTagsAsJson(), "work unit tags");
            this.tags = HstoreBackedTags.fromScriptable((Scriptable)decodedTags);
            this.gotTags = true;
        }
        return this.tags;
    }

    public void jsSet_tags(Scriptable scriptable) {
        this.tags = HstoreBackedTags.fromScriptable(scriptable);
        this.gotTags = true;
    }

    // --------------------------------------------------------------------------------------------------------------
    public boolean jsFunction_isActionableBy(Object userValue) {
        if(userValue instanceof Number) {
            userValue = KUser.jsStaticFunction_getUserById(((Number)userValue).intValue());
        }
        KUser user = (KUser)userValue;
        return this.workUnit.can_be_actioned_by(user.toRubyObject());
    }

    // --------------------------------------------------------------------------------------------------------------
    public KWorkUnit jsFunction_save() {
        updateWorkUnit(this);
        this.workUnit.save();
        return this;
    }

    public static void updateWorkUnit(KWorkUnit workUnit) {
        if(workUnit.gotData) {
            // Data needs updating
            if(workUnit.data == null) {
                workUnit.workUnit.setDataJson(null);
            } else {
                Runtime runtime = Runtime.getCurrentRuntime();
                workUnit.workUnit.setDataJson(runtime.jsonStringify(workUnit.data));
            }
        }
        if(workUnit.gotTags) {
            // Tags need updating
            if(workUnit.tags == null) {
                workUnit.workUnit.jsSetTagsAsJson(null);
            } else {
                Runtime runtime = Runtime.getCurrentRuntime();
                workUnit.workUnit.jsSetTagsAsJson(runtime.jsonStringify(workUnit.tags));
            }
        }  
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsFunction_deleteObject() {
        this.workUnit.delete();
    }

    // --------------------------------------------------------------------------------------------------------------
    private int valueToRequiredUserId(Object value, String propertyName) {
        Integer id = null;
        if(value != null) {
            id = JsJavaInterface.valueToUserIdNullAllowed(value, propertyName);
        }
        if(id == null) {
            throw new OAPIException("null not allowed for work unit property " + propertyName);
        }
        return id;
    }

    private Long convertAndCheckDate(Object date, boolean required, String property) {
        if(date != null) {
            date = Context.jsToJava(Runtime.getCurrentRuntime().convertIfJavaScriptLibraryDate(date), Date.class);
        }
        if(required && date == null) {
            throw new OAPIException(property + " must be set to a Date");
        }
        return (date == null) ? null : ((Date)date).getTime();
    }

    // --------------------------------------------------------------------------------------------------------------
    protected static KWorkUnit[] executeQuery(KWorkUnitQuery query, boolean firstResultOnly) {
        AppWorkUnit[] units = rubyInterface.executeQuery(query, firstResultOnly);
        if(units == null) {
            return new KWorkUnit[0];
        }

        KWorkUnit[] results = new KWorkUnit[units.length];
        for(int i = 0; i < units.length; ++i) {
            results[i] = KWorkUnit.fromAppWorkUnit(units[i], false);
        }
        return results;
    }

    protected static int executeCount(KWorkUnitQuery query) {
        return rubyInterface.executeCount(query);
    }

    protected static String executeCountByTagsJSON(KWorkUnitQuery query, Object[] tags) {
        return rubyInterface.executeCountByTagsJSON(query, tags);
    }

    // --------------------------------------------------------------------------------------------------------------

    public static String fastWorkUnitRender(AppWorkUnit workUnit, String context) {
        Runtime runtime = Runtime.getCurrentRuntime();
        Object result = runtime.callSharedScopeJSClassFunction("$Plugin", "$fastWorkUnitRender", new Object[] {
            fromAppWorkUnit(workUnit, false), context
        });
        return ((result != null) && (result instanceof CharSequence)) ? result.toString() : null;
    }

    public static String workUnitRenderForEvent(String eventName, AppWorkUnit workUnit) {
        Runtime runtime = Runtime.getCurrentRuntime();
        Object result = runtime.callSharedScopeJSClassFunction("$Plugin", "$workUnitRenderForEvent", new Object[] {
            eventName, fromAppWorkUnit(workUnit, false)
        });
        return ((result != null) && (result instanceof CharSequence)) ? result.toString() : null;
    }

    // --------------------------------------------------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        public AppWorkUnit constructWorkUnit(String workType);

        public AppWorkUnit loadWorkUnit(int id);

        public AppWorkUnit[] executeQuery(KWorkUnitQuery query, boolean firstResultOnly);

        public int executeCount(KWorkUnitQuery query);

        public String executeCountByTagsJSON(KWorkUnitQuery query, Object[] tags);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }
}
