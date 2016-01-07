/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface;

import com.oneis.javascript.Runtime;
import com.oneis.javascript.OAPIException;
import com.oneis.jsinterface.util.WorkUnitTags;
import org.mozilla.javascript.*;

import com.oneis.jsinterface.app.*;

import java.util.Date;

public class KWorkUnit extends KScriptable {
    private AppWorkUnit workUnit;
    private boolean gotData;    // whether this.data is valid (either by setting, or by loading it from the Ruby side)
    private Object data;        // JSON-encodable data
    private boolean gotTags;
    private WorkUnitTags tags;

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
    static public KWorkUnit fromAppWorkUnit(AppWorkUnit workUnit) {
        KWorkUnit w = (KWorkUnit)Runtime.createHostObjectInCurrentRuntime("$WorkUnit");
        w.setWorkUnit(workUnit);
        return w;
    }

    // --------------------------------------------------------------------------------------------------------------
    public static KWorkUnit jsStaticFunction_constructNew(String workType) {
        return KWorkUnit.fromAppWorkUnit(rubyInterface.constructWorkUnit(workType));
    }

    public static KWorkUnit jsStaticFunction_load(int id) {
        return KWorkUnit.fromAppWorkUnit(rubyInterface.loadWorkUnit(id));
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
        this.workUnit.jsset_visible(visible);
    }

    public boolean jsGet_autoVisible() {
        return this.workUnit.auto_visible();
    }

    public void jsSet_autoVisible(boolean autoVisible) {
        this.workUnit.jsset_auto_visible(autoVisible);
    }

    // ---- createdAt
    public Object jsGet_createdAt() {
        Date d = this.workUnit.created_at();
        // Need to create a JavaScript Date object - automatic conversion doesn't work for these
        return (d == null) ? null : Runtime.createHostObjectInCurrentRuntime("Date", d.getTime());
    }

    public void jsSet_createdAt(Object dummy) {
        throw new OAPIException("createdAt is a read only property");
    }

    // ---- openedAt
    public Object jsGet_openedAt() {
        Date d = this.workUnit.opened_at();
        // Need to create a JavaScript Date object - automatic conversion doesn't work for these
        return (d == null) ? null : Runtime.createHostObjectInCurrentRuntime("Date", d.getTime());
    }

    public void jsSet_openedAt(Object date) {
        this.workUnit.jsSetOpenedAt(convertAndCheckDate(date, true, "openedAt"));
    }

    // ---- deadline
    public Object jsGet_deadline() {
        Date d = this.workUnit.deadline();
        // Need to create a JavaScript Date object - automatic conversion doesn't work for these
        return (d == null) ? null : Runtime.createHostObjectInCurrentRuntime("Date", d.getTime());
    }

    public void jsSet_deadline(Object date) {
        this.workUnit.jsSetDeadline(convertAndCheckDate(date, false, "deadline"));
    }

    // ---- closing (and reopening)
    public Object jsGet_closedAt() {
        Date d = this.workUnit.closed_at();
        // Need to create a JavaScript Date object - automatic conversion doesn't work for these
        return (d == null) ? null : Runtime.createHostObjectInCurrentRuntime("Date", d.getTime());
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
        return this.workUnit.closed_at() != null;
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
        this.workUnit.jsset_created_by_id(valueToUserIdNullAllowed(value, "createdBy"));
    }

    // ---- actionableBy
    public Scriptable jsGet_actionableBy() {
        Integer id = this.workUnit.actionable_by_id();
        return (id == null) ? null : KUser.jsStaticFunction_getUserById(id);
    }

    public void jsSet_actionableBy(Object value) {
        this.workUnit.jsset_actionable_by_id(valueToUserIdNullAllowed(value, "actionableBy"));
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
        Integer objId = this.workUnit.obj_id();
        if(objId == null) {
            return null;
        }
        return (objId == null) ? null : Runtime.createHostObjectInCurrentRuntime("$Ref", objId);
    }

    public void jsSet_ref(Object value) {
        if(value == null) {
            // Value is null
            this.workUnit.jsset_obj_id(null);
            return;
        } else if(!(value instanceof KObjRef)) {
            // Not an objref
            throw new OAPIException("Bad type for setting ref property");
        }
        KObjRef ref = (KObjRef)value;
        Integer objId = this.workUnit.obj_id();
        this.workUnit.jsset_obj_id(ref.jsGet_objId());
    }

    // ---- data
    public Object jsGet_data() {
        if(!this.gotData) {
            this.data = jsonEncodedValueToObject(this.workUnit.jsGetDataRaw(), "data");
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
            Object decodedTags = jsonEncodedValueToObject(this.workUnit.jsGetTagsAsJson(), "tags");
            this.tags = WorkUnitTags.fromScriptable((Scriptable)decodedTags);
            this.gotTags = true;
        }
        return this.tags;
    }

    public void jsSet_tags(Scriptable scriptable) {
        this.tags = WorkUnitTags.fromScriptable(scriptable);
        this.gotTags = true;
    }

    // --------------------------------------------------------------------------------------------------------------
    public boolean jsFunction_isActionableBy(Object userValue) {
        if(userValue instanceof Integer) {
            userValue = KUser.jsStaticFunction_getUserById((Integer)userValue);
        }
        KUser user = (KUser)userValue;
        if(user.jsGet_isGroup()) {
            throw new OAPIException("isActionableBy must be passed a User, not a Group");
        }
        return this.workUnit.can_be_actioned_by(user.toRubyObject());
    }

    // --------------------------------------------------------------------------------------------------------------
    public KWorkUnit jsFunction_save() {
        if(this.gotData) {
            // Data needs updating
            if(this.data == null) {
                this.workUnit.jsSetDataRaw(null);
            } else {
                Runtime runtime = Runtime.getCurrentRuntime();
                this.workUnit.jsSetDataRaw(runtime.jsonStringify(this.data));
            }
        }
        if(this.gotTags) {
            // Tags need updating
            if(this.tags == null) {
                this.workUnit.jsSetTagsAsJson(null);
            } else {
                Runtime runtime = Runtime.getCurrentRuntime();
                this.workUnit.jsSetTagsAsJson(runtime.jsonStringify(this.tags));
            }
        }
        if(!this.workUnit.save()) {
            throw new OAPIException("Failed to save work unit");
        }
        return this;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsFunction_deleteObject() {
        this.workUnit.destroy();
    }

    // --------------------------------------------------------------------------------------------------------------
    private int valueToRequiredUserId(Object value, String propertyName) {
        Integer id = null;
        if(value != null) {
            id = valueToUserIdNullAllowed(value, propertyName);
        }
        if(id == null) {
            throw new OAPIException("null not allowed for work unit property " + propertyName);
        }
        return id;
    }

    private Integer valueToUserIdNullAllowed(Object value, String propertyName) {
        if(value != null) {
            if(value instanceof Integer) {
                return ((Integer)value == 0) ? null : (Integer)value;
            } else if(value instanceof KUser) {
                return ((KUser)value).jsGet_id();
            } else {
                throw new OAPIException("Bad type of argument for work unit property " + propertyName);
            }
        }
        return null;
    }

    private Date convertAndCheckDate(Object date, boolean required, String property) {
        if(date != null) {
            date = Context.jsToJava(Runtime.getCurrentRuntime().convertIfJavaScriptLibraryDate(date), Date.class);
        }
        if(required && date == null) {
            throw new OAPIException(property + " must be set to a Date");
        }
        return (date == null) ? null : (Date)date;
    }

    private Object jsonEncodedValueToObject(String jsonEncoded, String kind) {
        if(jsonEncoded != null && jsonEncoded.length() > 0) {
            try {
                return Runtime.getCurrentRuntime().makeJsonParser().parseValue(jsonEncoded);
            } catch(org.mozilla.javascript.json.JsonParser.ParseException e) {
                throw new OAPIException("Couldn't JSON decode work unit "+kind, e);
            }
        } else {
            return Runtime.getCurrentRuntime().createHostObject("Object");
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    protected static KWorkUnit[] executeQuery(KWorkUnitQuery query, boolean firstResultOnly) {
        AppWorkUnit[] units = rubyInterface.executeQuery(query, firstResultOnly);
        if(units == null) {
            return new KWorkUnit[0];
        }

        KWorkUnit[] results = new KWorkUnit[units.length];
        for(int i = 0; i < units.length; ++i) {
            results[i] = KWorkUnit.fromAppWorkUnit(units[i]);
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
            fromAppWorkUnit(workUnit), context
        });
        return ((result != null) && (result instanceof CharSequence)) ? result.toString() : null;
    }

    public static String workUnitRenderForEvent(String eventName, AppWorkUnit workUnit) {
        Runtime runtime = Runtime.getCurrentRuntime();
        Object result = runtime.callSharedScopeJSClassFunction("$Plugin", "$workUnitRenderForEvent", new Object[] {
            eventName, fromAppWorkUnit(workUnit)
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
