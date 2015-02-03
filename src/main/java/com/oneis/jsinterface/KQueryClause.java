/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface;

import com.oneis.javascript.Runtime;
import com.oneis.javascript.OAPIException;
import org.mozilla.javascript.*;

import com.oneis.jsinterface.app.*;
import com.oneis.javascript.JsConvert;

public class KQueryClause extends KScriptable {
    private AppQueryClause clause;
    private boolean canExecuteClause;

    public KQueryClause() {
        this.canExecuteClause = false;
    }

    public void setQueryClause(AppQueryClause clause) {
        this.clause = clause;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void setCanExecuteClause(boolean canExecute) {
        this.canExecuteClause = canExecute;
    }

    public boolean getCanExecuteClause() {
        return this.canExecuteClause;
    }

    public boolean jsGet_canExecute() {
        return this.canExecuteClause;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$KQueryClause";
    }

    // --------------------------------------------------------------------------------------------------------------
    static public Scriptable fromAppQueryClause(AppQueryClause appObj, boolean markAsExecutable) {
        Runtime runtime = Runtime.getCurrentRuntime();

        // Build the interface object
        KQueryClause clause = (KQueryClause)runtime.createHostObject("$KQueryClause");
        clause.setQueryClause(appObj);
        clause.setCanExecuteClause(markAsExecutable);

        // Make the actual JavaScript object
        ScriptableObject jsObj = (ScriptableObject)runtime.createHostObject("$StoreQuery");
        // Store the underlying object in the object
        jsObj.put("$kquery", jsObj, clause);

        return jsObj;
    }

    // --------------------------------------------------------------------------------------------------------------
    public AppQueryClause toRubyObject() {
        return clause;
    }

    // --------------------------------------------------------------------------------------------------------------
    public static Scriptable jsStaticFunction_constructQuery() {
        return fromAppQueryClause(rubyInterface.constructQuery(), true /* root clause, can be executed */);
    }

    public static Scriptable jsStaticFunction_queryFromQueryString(String query) {
        return KQueryClause.fromAppQueryClause(rubyInterface.queryFromQueryString(query), true /* root clause, can be executed */);
    }

    public Scriptable jsFunction_executeQuery(boolean sparseResults, String sort, boolean deletedOnly) {
        if(!this.getCanExecuteClause()) {
            throw new OAPIException("Can only execute root object store queries");
        }
        return KQueryResults.fromAppQueryResults(rubyInterface.executeQuery(this.toRubyObject(), sparseResults, sort, deletedOnly));
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsFunction_freeText(String text, int desc, boolean hasDesc, int qual, boolean hasQual) {
        this.clause.freeText(text, hasDesc ? desc : null, hasQual ? qual : null);
    }

    public void jsFunction_link(KObjRef ref, int desc, boolean hasDesc, int qual, boolean hasQual) {
        this.clause.link((AppObjRef)ref.toRubyObject(), hasDesc ? desc : null, hasQual ? qual : null);
    }

    public void jsFunction_linkDirectly(KObjRef ref, int desc, boolean hasDesc, int qual, boolean hasQual) {
        this.clause.linkExact((AppObjRef)ref.toRubyObject(), hasDesc ? desc : null, hasQual ? qual : null);
    }

    public void jsFunction_linkToAny(int desc, int qual, boolean hasQual) {
        this.clause.linkToAny(desc, hasQual ? qual : null);
    }

    public void jsFunction_identifier(Object identifier, int desc, boolean hasDesc, int qual, boolean hasQual) {
        if(!(identifier instanceof KText)) {
            throw new OAPIException("Must pass a identifier Text object to query identifier() function.");
        }
        boolean valid = this.clause.jsIdentifierReturningValidity(((KText)identifier).toRubyObject(), hasDesc ? desc : null, hasQual ? qual : null);
        if(!valid) {
            throw new OAPIException("Must pass a identifier Text object to query identifier() function.");
        }
    }

    public Scriptable jsFunction_makeContainer(String kind) {
        AppQueryClause container = null;
        if(kind.equals("and")) {
            container = this.clause.and();
        } else if(kind.equals("or")) {
            container = this.clause.or();
        } else if(kind.equals("not")) {
            container = this.clause.not();
        } else {
            throw new OAPIException("Bad container kind for KQueryClause");
        }
        return KQueryClause.fromAppQueryClause(container, false /* non-root clauses can't be executed */);
    }

    public Scriptable jsFunction_linkToQuery(boolean hierarchicalLink, int desc, boolean hasDesc, int qual, boolean hasQual) {
        return KQueryClause.fromAppQueryClause(
                this.clause.jsAddLinkedToSubquery(
                        hierarchicalLink,
                        hasDesc ? desc : null,
                        hasQual ? qual : null
                ),
                false /* non-root clauses can't be executed */
        );
    }

    public Scriptable jsFunction_linkFromQuery(int desc, boolean hasDesc, int qual, boolean hasQual) {
        return KQueryClause.fromAppQueryClause(
                this.clause.jsAddLinkedFromSubquery(
                        hasDesc ? desc : null,
                        hasQual ? qual : null
                ),
                false /* non-root clauses can't be executed */
        );
    }

    public void jsFunction_createdByUserId(int userId) {
        this.clause.createdByUserId(userId);
    }

    public void jsFunction_dateRange(Object beginDate, Object endDate, int desc, boolean hasDesc, int qual, boolean hasQual) {
        this.clause.dateRange(
                rubyInterface.convertDate(JsConvert.tryConvertJsDate(beginDate)),
                rubyInterface.convertDate(JsConvert.tryConvertJsDate(endDate)),
                hasDesc ? desc : null, hasQual ? qual : null
        );
    }

    public void jsFunction_limit(int maxResults) {
        this.clause.maximumResults(maxResults);
    }

    // --------------------------------------------------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        public Object convertDate(Object value);

        public AppQueryClause constructQuery();

        public AppQueryClause queryFromQueryString(String query);

        public AppQueryResults executeQuery(AppQueryClause clause, boolean sparseResults, String sort, boolean deletedOnly);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }

}
