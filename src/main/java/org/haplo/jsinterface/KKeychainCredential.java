/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.mozilla.javascript.Scriptable;
import org.mozilla.javascript.json.JsonParser.ParseException;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;
import org.haplo.javascript.JsJavaInterface;

import org.haplo.jsinterface.app.AppKeychainCredential;


public class KKeychainCredential extends KScriptable {
    private AppKeychainCredential credential;
    private Object account;
    private Object secret;

    public KKeychainCredential() {
    }

    public void setKeychainCredential(AppKeychainCredential credential) {
        this.credential = credential;
    }

    // ---------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$KeychainCredential";
    }

    @Override
    protected String getConsoleData() {
        return (this.credential != null) ? this.credential.name() : null;
    }

    // ---------------------------------------------------------------------
    static public Scriptable fromAppKeychainCredential(AppKeychainCredential appObj) {
        KKeychainCredential kc = (KKeychainCredential)Runtime.getCurrentRuntime().createHostObject("$KeychainCredential");
        kc.setKeychainCredential(appObj);
        return kc;
    }

    // ---------------------------------------------------------------------
    public long jsGet_id() {
        return this.credential.id();
    }

    public String jsGet_name() {
        return this.credential.name();
    }

    public String jsGet_kind() {
        return this.credential.kind();
    }

    public String jsGet_instanceKind() {
        return this.credential.instance_kind();
    }

    public Object jsGet_account() throws ParseException {
        Runtime.privilegeRequired("pKeychainRead", "read account property of a KeychainCredential object");
        if(this.account == null) { this.account = Runtime.getCurrentRuntime().makeJsonParser().parseValue(this.credential.account_json()); }
        return this.account;
    }

    public Object jsGet_secret() throws ParseException {
        Runtime.privilegeRequired("pKeychainReadSecret", "read secret property of a KeychainCredential object");
        if(this.secret == null) { this.secret = Runtime.getCurrentRuntime().makeJsonParser().parseValue(this.credential.secret_json()); }
        return this.secret;
    }

    // ---------------------------------------------------------------------
    public String jsFunction_encode(String encoding) {
        Runtime.privilegeRequired("pKeychainReadSecret", "call encode() on a KeychainCredential object");
        return rubyInterface.encode(this.credential, encoding);
    }

    // ---------------------------------------------------------------------
    public static String jsStaticFunction_query(Object kindQuery) {
        Runtime.privilegeRequired("pKeychainRead", "call O.keychain.query()");
        String kind = null;
        if(kindQuery instanceof org.mozilla.javascript.Undefined) { kindQuery = null; }
        if(kindQuery instanceof CharSequence) {
            kind = kindQuery.toString();
        } else if(kindQuery != null) {
            throw new OAPIException("Argument to O.keychain.query() must be a string");
        }
        return rubyInterface.query(kind);
    }

    public static Scriptable jsStaticFunction_load(Object identifier) {
        Runtime.privilegeRequired("pKeychainRead", "call O.keychain.credential()");
        long id = -1;
        String name = null;
        if(identifier instanceof Number) {
            id = ((Number)identifier).longValue();
        } else if(identifier instanceof CharSequence) {
            name = identifier.toString();
        } else {
            throw new OAPIException("Can only load KeychainCredentials by id or name");
        }
        AppKeychainCredential credential = rubyInterface.load(id, name);
        if(credential == null) {
            throw new OAPIException("Credential not found: "+JsJavaInterface.jsValueToString(identifier));
        }
        return fromAppKeychainCredential(credential);
    }

    // ---------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        String query(String kind);
        AppKeychainCredential load(long id, String name);
        String encode(AppKeychainCredential credential, String encoding);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }

}
