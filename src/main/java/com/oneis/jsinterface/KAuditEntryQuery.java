/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface;

import com.oneis.javascript.Runtime;
import com.oneis.javascript.OAPIException;
import org.mozilla.javascript.*;
import com.oneis.javascript.JsConvert;

import java.util.Date;

public class KAuditEntryQuery extends KScriptable {
    private Integer limit;
    private String[] auditEntryTypes;
    private String sortField;
    private boolean sortDesc;
    private Integer objId;
    private Integer entityId;
    private Integer userId;
    private Integer authenticatedUserId;
    private Boolean displayable;
    private Date fromDate;
    private Date toDate;

    private KAuditEntry[] results;
    private boolean executedForFirstResult;

    public KAuditEntryQuery() {
        this.executedForFirstResult = false;
        this.limit = 1000;
        this.displayable = true;
        this.sortDesc = true;
    }

    // --------------------------------------------------------------------------------------------------------------
    public String getClassName() {
        return "$AuditEntryQuery";
    }

    // --------------------------------------------------------------------------------------------------------------
    public Scriptable jsFunction_ref(Object value) {
        checkNotExecuted();
        if(value == null) {
            this.objId = null;
        } else if(value instanceof KObjRef) {
            value = (Object)(((KObjRef)value).jsGet_objId());
        }
        if(!(value instanceof Integer)) {
            throw new OAPIException("auditEntryQuery.ref() must be passed an O.ref type.");
        }
        this.objId = (Integer)value;
        return this;
    }

    public Scriptable jsFunction_entityId(Integer value) {
        checkNotExecuted();
        this.entityId = value;
        return this;
    }

    public Scriptable jsFunction_dateRange(Object beginDate, Object endDate) {
        checkNotExecuted();
        this.fromDate = JsConvert.tryConvertJsDate(beginDate);
        this.toDate = JsConvert.tryConvertJsDate(endDate);
        return this;
    }

    public Scriptable jsFunction_sortBy(String fieldName) {
        checkNotExecuted();
        boolean isDesc = true;
        if(fieldName == null) {
            fieldName = "created_at";
        } else {
            String[] parts = fieldName.split("_(?=asc$|desc$)", 2);
            if(parts.length == 2) {
                isDesc = parts[1].equals("desc");
            }
            fieldName = parts[0];
        }
        KAuditEntry.checkValidField(fieldName);
        this.sortField = fieldName;
        this.sortDesc = isDesc;
        return this;
    }

    public Scriptable jsFunction_limit(Integer number) {
        checkNotExecuted();
        if(number < 1) {
            throw new OAPIException("Limit must be a positive number, or null");
        }
        this.limit = number;
        return this;
    }

    public Scriptable jsFunction_userId(Object value) {
        checkNotExecuted();
        this.userId = valueToUserIdNullAllowed(value, "userId");
        return this;
    }

    public Scriptable jsFunction_authenticatedUserId(Object value) {
        checkNotExecuted();
        this.authenticatedUserId = valueToUserIdNullAllowed(value, "authenticatedUserId");
        return this;
    }

    public static Scriptable jsFunction_auditEntryType(Context cx, Scriptable thisObj, Object[] args, Function funObj) {
        return ((KAuditEntryQuery)thisObj).auditEntryType(args);
    }

    private Scriptable auditEntryType(Object[] auditEntryTypes) {
        checkNotExecuted();
        this.auditEntryTypes = new String[auditEntryTypes.length];
        for(int i = 0; i < auditEntryTypes.length; i++) {
            this.auditEntryTypes[i] = (auditEntryTypes[i] == null) ? null : auditEntryTypes[i].toString();
        }
        return this;
    }

    public Scriptable jsFunction_displayable(Object value) {
        checkNotExecuted();
        if(value == null) {
            this.displayable = null;
        } else {
            if(!(value instanceof Boolean)) {
                throw new OAPIException("auditEntryQuery displayable method must be null or boolean type");
            }
            this.displayable = (Boolean)value;
        }
        return this;
    }

    // --------------------------------------------------------------------------------------------------------------
    public int jsGet_length() {
        executeQueryIfRequired(false);
        return this.results.length;
    }

    @Override
    public boolean has(int index, Scriptable start) {
        executeQueryIfRequired(false);
        return (index >= 0 && index < this.results.length);
    }

    @Override
    public Object get(int index, Scriptable start) {
        executeQueryIfRequired(false);
        if(index < 0 || index >= this.results.length) {
            return Context.getUndefinedValue();
        }
        return this.results[index];
    }

    public KAuditEntry jsFunction_latest() {
        executeQueryIfRequired(true);
        return (results.length < 1) ? null : results[0];
    }

    public KAuditEntry jsFunction_first() // alias of JS latest()
    {
        return jsFunction_latest();
    }

    public static Scriptable jsFunction_table(Context cx, Scriptable thisObj, Object[] args, Function funObj) {
        return ((KAuditEntryQuery)thisObj).table(args);
    }

    // --------------------------------------------------------------------------------------------------------------
    private Scriptable table(Object[] fields) {
        if(fields.length == 0) {
            throw new OAPIException("Must specify at least one field for the table.");
        }
        return KAuditEntry.executeTable(this, fields);
    }

    // --------------------------------------------------------------------------------------------------------------
    private void checkNotExecuted() {
        if(results != null) {
            throw new OAPIException("Audit entry query has already been executed.");
        }
    }

    private void executeQueryIfRequired(boolean firstResultOnly) {
        if(results != null && !(this.executedForFirstResult)) {
            return;
        }
        if(results != null && (firstResultOnly == this.executedForFirstResult)) {
            return;
        }
        results = KAuditEntry.executeQuery(this, firstResultOnly);
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
                throw new OAPIException("Bad type of argument for audit entry query criteria " + propertyName);
            }
        }
        return null;
    }

    // --------------------------------------------------------------------------------------------------------------
    public Integer getLimit() {
        return limit;
    }

    public String[] getAuditEntryTypes() {
        return auditEntryTypes;
    }

    public String getSortField() {
        return sortField;
    }

    public boolean getSortDesc() {
        return sortDesc;
    }

    public Boolean getDisplayable() {
        return displayable;
    }

    public Integer getObjId() {
        return objId;
    }

    public Integer getEntityId() {
        return entityId;
    }

    public Integer getUserId() {
        return userId;
    }

    public Integer getAuthenticatedUserId() {
        return authenticatedUserId;
    }

    public Date getFromDate() {
        return fromDate;
    }

    public Date getToDate() {
        return toDate;
    }

}
