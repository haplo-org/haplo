/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * (c) Avalara, Inc 2021
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;
import org.mozilla.javascript.*;

import org.haplo.jsinterface.app.*;
import org.haplo.javascript.JsConvert;

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

    public Scriptable jsFunction_executeQuery(boolean sparseResults, String sort, boolean deletedOnly, boolean includeArchived) {
        if(!this.getCanExecuteClause()) {
            throw new OAPIException("Can only execute root object store queries");
        }
        return KQueryResults.fromAppQueryResults(rubyInterface.executeQuery(this.toRubyObject(), sparseResults, sort, deletedOnly, includeArchived));
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsFunction_freeText(String text, int desc, boolean hasDesc, int qual, boolean hasQual) {
        this.clause.free_text(text, hasDesc ? desc : null, hasQual ? qual : null);
    }

    public void jsFunction_exactTitle(String title) {
        this.clause.exact_title(title);
    }

    public void jsFunction_link(KObjRef ref, int desc, boolean hasDesc, int qual, boolean hasQual) {
        this.clause.link((AppObjRef)ref.toRubyObject(), hasDesc ? desc : null, hasQual ? qual : null);
    }

    public void jsFunction_linkDirectly(KObjRef ref, int desc, boolean hasDesc, int qual, boolean hasQual) {
        this.clause.link_exact((AppObjRef)ref.toRubyObject(), hasDesc ? desc : null, hasQual ? qual : null);
    }

    public void jsFunction_linkToAny(int desc, int qual, boolean hasQual) {
        this.clause.link_to_any(desc, hasQual ? qual : null);
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
        this.clause.created_by_user_id(userId);
    }

    public void jsFunction_createdWithinDateRange(Object beginDate, Object endDate) {
        this.clause.constrain_to_time_interval(
                JsConvert.convertJavaDateToRuby(JsConvert.tryConvertJsDate(beginDate)),
                JsConvert.convertJavaDateToRuby(JsConvert.tryConvertJsDate(endDate))
        );
    }

    public void jsFunction_lastUpdatedWithinDateRange(Object beginDate, Object endDate) {
        this.clause.constrain_to_updated_time_interval(
                JsConvert.convertJavaDateToRuby(JsConvert.tryConvertJsDate(beginDate)),
                JsConvert.convertJavaDateToRuby(JsConvert.tryConvertJsDate(endDate))
        );
    }

    public void jsFunction_dateRange(Object beginDate, Object endDate, int desc, boolean hasDesc, int qual, boolean hasQual) {
        this.clause.date_range(
                JsConvert.convertJavaDateToRuby(JsConvert.tryConvertJsDate(beginDate)),
                JsConvert.convertJavaDateToRuby(JsConvert.tryConvertJsDate(endDate)),
                hasDesc ? desc : null, hasQual ? qual : null
        );
    }

    public void jsFunction_anyLabel(Object labels) {
        this.clause.any_label(checkedLabelArray(labels));
    }

    public void jsFunction_allLabels(Object labels) {
        this.clause.all_labels(checkedLabelArray(labels));
    }

    private int[] checkedLabelArray(Object labels) {
        if(!(labels instanceof KLabelList)) {
            throw new OAPIException("Must pass a label list when building label queries.");
        }
        int[] labelArray = ((KLabelList)labels).getLabels();
        if(labelArray.length == 0 || labelArray.length > 4096) {
            throw new OAPIException("Bad label list length for query, cannot be empty or very long");
        }
        return labelArray;
    }

    public void jsFunction_matchNothing() {
        this.clause.match_nothing();
    }

    public void jsFunction_limit(int maxResults) {
        this.clause.maximumResults(maxResults);
    }

    public void jsFunction_offset(int offsetStart) {
        this.clause.offset(offsetStart);
    }

    // --------------------------------------------------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        public AppQueryClause constructQuery();

        public AppQueryClause queryFromQueryString(String query);

        public AppQueryResults executeQuery(AppQueryClause clause, boolean sparseResults, String sort, boolean deletedOnly, boolean includeArchived);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }

}
