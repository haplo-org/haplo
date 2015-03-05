/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface;

import com.oneis.javascript.Runtime;
import com.oneis.javascript.OAPIException;
import org.mozilla.javascript.*;

import java.util.Date;

public class KWorkUnitQuery extends KScriptable {
    private String workType;
    private String status;
    private String visibility;
    private Integer createdById;
    private Integer actionableById;
    private Integer closedById;
    private Integer objId;

    private static final String DEFAULT_STATUS = "open";
    private static final String DEFAULT_VISIBILITY = "visible";

    private KWorkUnit[] results;
    private boolean executedForFirstResult;

    public KWorkUnitQuery() {
        this.executedForFirstResult = false;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor(String workType) {
        if(workType.indexOf(':') < 1) {
            throw new OAPIException("Bad workType");
        }
        this.workType = workType;
        this.status = DEFAULT_STATUS;
        this.visibility = DEFAULT_VISIBILITY;
    }

    public String getClassName() {
        return "$WorkUnitQuery";
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

    public Scriptable jsFunction_ref(KObjRef value) {
        checkNotExecuted();
        if(value == null) {
            this.objId = null;
        } else {
            this.objId = value.jsGet_objId();
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

    public KWorkUnit jsFunction_latest() {
        executeQueryIfRequired(true);
        return (results.length < 1) ? null : results[0];
    }

    public KWorkUnit jsFunction_first() // alias of JS latest()
    {
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

}
