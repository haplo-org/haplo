/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.haplo.jsinterface.util.WorkUnitTags;
import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;
import org.mozilla.javascript.*;

import java.util.ArrayList;

public class KWorkUnitQuery extends KScriptable {
    private boolean isConstructed;
    private String workType;
    private String status;
    private String visibility;
    private Integer createdById;
    private Integer actionableById;
    private Integer closedById;
    private Integer objId;
    private Integer _temp_refPermitsReadByUserId; // TODO: Remove _temp_refPermitsReadByUserId and/or replace by proper interface
    private ArrayList<TagKeyValue> tagValues;
    private boolean deadlineMissed;

    private static final String DEFAULT_STATUS = "open";
    private static final String DEFAULT_VISIBILITY = "visible";

    private KWorkUnit[] results;
    private boolean executedForFirstResult;

    public KWorkUnitQuery() {
        this.executedForFirstResult = false;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor(Object workTypeObject) {
        String workType = null;
        if(workTypeObject != null) {
            if(workTypeObject instanceof CharSequence) {
                workType = workTypeObject.toString();
                if(workType.indexOf(':') < 1) { throw new OAPIException("Bad workType"); }
            } else {
                throw new OAPIException("workType must be a string");
            }
        }
        this.workType = workType;
        this.status = DEFAULT_STATUS;
        this.visibility = DEFAULT_VISIBILITY;
        this.isConstructed = true;
    }

    public String getClassName() {
        return "$WorkUnitQuery";
    }

    // --------------------------------------------------------------------------------------------------------------
    private boolean isPrototypeObject() {
        return !(this.isConstructed);
    }

    // --------------------------------------------------------------------------------------------------------------
    public Scriptable jsFunction_isClosed() {
        checkNotExecuted();
        this.status = "closed";
        return this;
    }

    public Scriptable jsFunction_isOpen() // default
    {
        checkNotExecuted();
        this.status = "open";
        return this;
    }

    public Scriptable jsFunction_isEitherOpenOrClosed() {
        checkNotExecuted();
        this.status = null;
        return this;
    }

    public Scriptable jsFunction_isVisible() {
        checkNotExecuted();
        this.visibility = "visible";
        return this;
    }

    public Scriptable jsFunction_isNotVisible() {
        checkNotExecuted();
        this.visibility = "not-visible";
        return this;
    }

    public Scriptable jsFunction_anyVisibility() {
        checkNotExecuted();
        this.visibility = null;
        return this;
    }

    public Scriptable jsFunction_createdBy(Object value) {
        checkNotExecuted();
        this.createdById = valueToUserIdNullAllowed(value, "createdBy");
        return this;
    }

    public Scriptable jsFunction_actionableBy(Object value) {
        checkNotExecuted();
        this.actionableById = valueToUserIdNullAllowed(value, "actionableBy");
        return this;
    }

    public Scriptable jsFunction_closedBy(Object value) {
        checkNotExecuted();
        this.closedById = valueToUserIdNullAllowed(value, "closedBy");
        return this;
    }

    public Scriptable jsFunction_ref(Object value) {
        checkNotExecuted();
        if(value == null) {
            this.objId = null;
        } else {
            if(!(value instanceof KObjRef)) {
                throw new OAPIException("Ref object expected as argument to ref()");
            }
            this.objId = ((KObjRef)value).jsGet_objId();
        }
        return this;
    }

    // TODO: Remove _temp_refPermitsReadByUserId and/or replace by proper interface
    public Scriptable jsFunction__temp_refPermitsReadByUser(Object user) {
        if(!(user instanceof KUser)) { throw new OAPIException("User object expected"); }
        this._temp_refPermitsReadByUserId = ((KUser)user).jsGet_id();
        return this;
    }

    public Scriptable jsFunction_tag(String key, Object value) {
        if(value instanceof org.mozilla.javascript.Undefined) {
            throw new OAPIException("undefined cannot be used with WorkUnitQuery tag()");
        }
        String stringValue = WorkUnitTags.valueToTagString(value);
        if((stringValue != null) && (stringValue.length() == 0)) {
            stringValue = null; // empty strings and null handled the same
        }
        if(this.tagValues == null) {
            this.tagValues = new ArrayList<TagKeyValue>();
        }
        TagKeyValue kv = new TagKeyValue();
        kv.key = key;
        kv.value = stringValue;
        this.tagValues.add(kv);
        return this;
    }

    // TODO: Add more flexible deadline query functions?
    public Scriptable jsFunction_deadlineMissed() {
        this.deadlineMissed = true;
        return this;
    }

    // --------------------------------------------------------------------------------------------------------------
    public int jsFunction_count() {
        return KWorkUnit.executeCount(this);
    }

    // Rhino doesn't support variable arguments, and we don't want to allow too many tags anyway
    public Object jsFunction_countByTags(Object tag0, Object tag1, Object tag2, Object tag3) {
        Object[] tags = new Object[]{tag0, tag1, tag2, tag3};
        for(int index = 0; index < tags.length; index++) {
            Object tag = tags[index];
            if(tag == null || tag instanceof org.mozilla.javascript.Undefined) {
                tags[index] = null;
            } else if(tag instanceof CharSequence) {
                tags[index] = ((CharSequence)tag).toString();
            } else {
                tags[index] = null;
            }
        }
        String json = KWorkUnit.executeCountByTagsJSON(this, tags);
        try {
            return (json == null) ? null : Runtime.getCurrentRuntime().makeJsonParser().parseValue(json);
        } catch(org.mozilla.javascript.json.JsonParser.ParseException e) {
            return null;
        }
    }

    public int jsGet_length() {
        executeQueryIfRequired(false);
        return this.results.length;
    }

    @Override
    public boolean has(int index, Scriptable start) {
        if(isPrototypeObject()) { return false; }   // because returning false will search prototype chain
        executeQueryIfRequired(false);
        return (index >= 0 && index < this.results.length);
    }

    @Override
    public Object get(int index, Scriptable start) {
        if(isPrototypeObject()) { return Context.getUndefinedValue(); }
        executeQueryIfRequired(false);
        if(index < 0 || index >= this.results.length) {
            return Context.getUndefinedValue();
        }
        return this.results[index];
    }

    public KWorkUnit jsFunction_latest() {
        executeQueryIfRequired(true);
        return (results.length < 1) ? null : results[0];
    }

    public KWorkUnit jsFunction_first() { // alias of JS latest()
        return jsFunction_latest();
    }

    // --------------------------------------------------------------------------------------------------------------
    private void checkNotExecuted() {
        if(results != null) {
            throw new OAPIException("Work unit query has already been executed.");
        }
    }

    private void executeQueryIfRequired(boolean firstResultOnly) {
        if(results != null && !(this.executedForFirstResult)) {
            return;
        }
        if(results != null && (firstResultOnly == this.executedForFirstResult)) {
            return;
        }

        results = KWorkUnit.executeQuery(this, firstResultOnly);
        this.executedForFirstResult = firstResultOnly;
    }

    // --------------------------------------------------------------------------------------------------------------
    private Integer valueToUserIdNullAllowed(Object value, String propertyName) {
        if(value != null) {
            if(value instanceof Integer) {
                return ((Integer)value == 0) ? null : (Integer)value;
            } else if(value instanceof KUser) {
                return ((KUser)value).jsGet_id();
            } else {
                throw new OAPIException("Bad type of argument for work unit query criteria " + propertyName);
            }
        }
        return null;
    }

    // --------------------------------------------------------------------------------------------------------------

    public static class TagKeyValue {
        public String key;
        public String value;
    }

    // --------------------------------------------------------------------------------------------------------------
    public String getWorkType() {
        return this.workType;
    }

    public String getStatus() {
        return this.status;
    }

    public String getVisibility() {
        return this.visibility;
    }

    public Integer getCreatedById() {
        return this.createdById;
    }

    public Integer getActionableById() {
        return this.actionableById;
    }

    public Integer getClosedById() {
        return this.closedById;
    }

    public Integer getObjId() {
        return this.objId;
    }

    // TODO: Remove _temp_refPermitsReadByUserId and/or replace by proper interface
    public Integer get_temp_refPermitsReadByUserId() {
        return this._temp_refPermitsReadByUserId;
    }

    public TagKeyValue[] getTagValues() {
        if(this.tagValues == null) { return null; }
        return this.tagValues.toArray(new TagKeyValue[this.tagValues.size()]);
    }

    public boolean getDeadlineMissed() {
        return this.deadlineMissed;
    }

}
