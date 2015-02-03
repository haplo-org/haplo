/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface;

import org.mozilla.javascript.Scriptable;

import com.oneis.javascript.Runtime;
import com.oneis.javascript.OAPIException;

import com.oneis.jsinterface.app.AppAuditEntry;
import com.oneis.jsinterface.generate.KGeneratedBinaryData;

public class KAuditEntry extends KScriptable {
    private AppAuditEntry auditEntry;
    private String kind;
    private Object data;    // cache of the JSON data

    public KAuditEntry() {
    }

    public void setAuditEntry(AppAuditEntry auditEntry) {
        this.auditEntry = auditEntry;
        // Kind is going to be needed in almost every case, so grab it now
        this.kind = auditEntry.kind();
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$AuditEntry";
    }

    @Override
    protected String getConsoleData() {
        return this.kind;
    }

    // --------------------------------------------------------------------------------------------------------------
    static public Scriptable fromAppAuditEntry(AppAuditEntry appObj) {
        KAuditEntry ae = (KAuditEntry)Runtime.getCurrentRuntime().createHostObject("$AuditEntry");
        ae.setAuditEntry(appObj);
        return ae;
    }

    // --------------------------------------------------------------------------------------------------------------
    public AppAuditEntry toRubyObject() {
        return auditEntry;
    }

    // --------------------------------------------------------------------------------------------------------------
    public int jsGet_id() {
        return this.auditEntry.id();
    }

    public Scriptable jsGet_creationDate() {
        return Runtime.createHostObjectInCurrentRuntime("Date", this.auditEntry.jsGetCreationDate());
    }

    public String jsGet_remoteAddress() {
        return this.auditEntry.remote_addr();
    }

    public Integer jsGet_userId() {
        return this.auditEntry.user_id();
    }

    public Integer jsGet_authenticatedUserId() {
        return this.auditEntry.auth_user_id();
    }

    public Integer jsGet_apiKeyId() {
        return this.auditEntry.api_key_id();
    }

    public String jsGet_auditEntryType() {
        return this.kind;
    }

    public Scriptable jsGet_ref() {
        Integer objId = this.auditEntry.obj_id();
        if(objId == null) {
            return null;
        }
        return Runtime.createHostObjectInCurrentRuntime("$Ref", objId);
    }

    public Integer jsGet_entityId() {
        return this.auditEntry.entity_id();
    }

    public boolean jsGet_displayable() {
        return this.auditEntry.displayable();
    }

    public Object jsGet_data() {
        if(this.data != null) {
            return this.data;
        }
        String json = this.auditEntry.jsGetData();
        if(json == null) {
            return null;
        }
        try {
            this.data = Runtime.getCurrentRuntime().makeJsonParser().parseValue(json);
        } catch(org.mozilla.javascript.json.JsonParser.ParseException e) {
            throw new OAPIException("Couldn't JSON decode data from audit entry", e);
        }
        return this.data;
    }

    public Object jsGet_labels() {
        return KLabelList.fromAppLabelList(this.auditEntry.labels());
    }

    // --------------------------------------------------------------------------------------------------------------
    public static Scriptable jsStaticFunction__write(String json) {
        AppAuditEntry entry = rubyInterface.write(json);
        return (entry == null) ? null : KAuditEntry.fromAppAuditEntry(entry);
    }

    // --------------------------------------------------------------------------------------------------------------
    protected static boolean checkValidField(String fieldName) {
        // Ruby code throws exception if field isn't valid.
        rubyInterface.safeGetColumnFromField(fieldName);
        return true;
    }

    // --------------------------------------------------------------------------------------------------------------
    protected static KAuditEntry[] executeQuery(KAuditEntryQuery query, boolean firstResultOnly) {
        AppAuditEntry[] units = rubyInterface.executeQuery(query, firstResultOnly);
        if(units == null) {
            return new KAuditEntry[0];
        }
        KAuditEntry[] results = new KAuditEntry[units.length];
        for(int i = 0; i < units.length; ++i) {
            results[i] = (KAuditEntry)KAuditEntry.fromAppAuditEntry(units[i]);
        }
        return results;
    }

    protected static KGeneratedBinaryData executeTable(KAuditEntryQuery query, Object[] fields) {
        String fieldNames[] = new String[fields.length];
        for(int i = 0; i < fields.length; ++i) {
            if(!(fields[i] instanceof CharSequence)) {
                throw new OAPIException("All arguments to executeTable must be a String");
            }
            String fieldName = ((CharSequence)fields[i]).toString();
            KAuditEntry.checkValidField(fieldName);
            fieldNames[i] = fieldName;
        }
        return rubyInterface.executeTable(query, fieldNames);
    }

    // --------------------------------------------------------------------------------------------------------------
    // Interface to Ruby functions

    public interface Ruby {
        public AppAuditEntry write(String json);

        public AppAuditEntry[] executeQuery(KAuditEntryQuery query, boolean firstResultOnly);

        public KGeneratedBinaryData executeTable(KAuditEntryQuery query, String[] fields);

        public String safeGetColumnFromField(String fieldName);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }
}
