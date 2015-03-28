/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface;

import com.oneis.javascript.Runtime;
import com.oneis.javascript.OAPIException;
import com.oneis.javascript.JsConvert;
import org.mozilla.javascript.*;

import com.oneis.jsinterface.app.*;

public class KUser extends KScriptable {
    private AppUser user;
    private KUserData data;         // data property

    private final static int KIND_GROUP = 1;    // same as app/models/user.rb

    public KUser() {
    }

    public void setUser(AppUser user) {
        this.user = user;
    }

    public AppUser toRubyObject() {
        return this.user;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$User";
    }

    @Override
    protected String getConsoleData() {
        return jsGet_email() + "(" + jsGet_id() + ")";
    }

    // --------------------------------------------------------------------------------------------------------------
    static public Scriptable fromAppUser(AppUser appObj) {
        KUser user = (KUser)Runtime.getCurrentRuntime().createHostObject("$User");
        user.setUser(appObj);
        return user;
    }

    // --------------------------------------------------------------------------------------------------------------
    public static Scriptable jsStaticFunction_getUserById(int id) {
        AppUser user = rubyInterface.getUserById(id);
        return (user == null) ? null : KUser.fromAppUser(user);
    }

    public static Scriptable jsStaticFunction_getUserByEmail(String email) {
        AppUser user = rubyInterface.getUserByEmail(email.toLowerCase().trim());
        return (user == null) ? null : KUser.fromAppUser(user);
    }

    public static Scriptable jsStaticFunction_getAllUsersByEmail(String email) {
        AppUser users[] = rubyInterface.getAllUsersByEmail(email.toLowerCase().trim());
        Scriptable jsUsers = Runtime.getCurrentRuntime().createHostObject("Array", users.length);
        for(int i = 0; i < users.length; ++i) {
            jsUsers.put(i, jsUsers, fromAppUser(users[i]));
        }
        return jsUsers;
    }

    public static Scriptable jsStaticFunction_getUserByRef(KObjRef ref) {
        AppUser user = rubyInterface.getUserByRef(ref.toRubyObject());
        return (user == null) ? null : KUser.fromAppUser(user);
    }

    public static Scriptable jsStaticFunction_getCurrentUser() {
        AppUser user = rubyInterface.getCurrentUser();
        return (user == null) ? null : KUser.fromAppUser(user);
    }

    // --------------------------------------------------------------------------------------------------------------
    public int jsGet_id() {
        return this.user.id();
    }

    public boolean jsGet_isGroup() {
        return this.user.is_group();
    }

    public boolean jsGet_isActive() {
        return this.user.is_active();
    }

    public String jsGet_name() {
        return this.user.name();
    }

    public String jsGet_nameFirst() {
        return this.user.name_first();
    }

    public String jsGet_nameLast() {
        return this.user.name_last();
    }

    public String jsGet_email() {
        return this.user.email();
    }

    public KObjRef jsGet_ref() {
        AppObjRef ar = this.user.objref();
        return (ar != null) ? KObjRef.fromAppObjRef(ar) : null;
    }

    public Scriptable jsGet_groupIds() {
        return JsConvert.integerArrayToJs(rubyInterface.getGroupIds(this.user));
    }

    public Scriptable jsGet_directGroupIds() {
        return JsConvert.integerArrayToJs(rubyInterface.getDirectGroupIds(this.user));
    }

    // --------------------------------------------------------------------------------------------------------------
    public Scriptable jsGet_data() {
        if(this.data == null) {
            // Lazily create the data object
            this.data = (KUserData)Runtime.createHostObjectInCurrentRuntime("$UserData");
            this.data.setUser(this);
        }
        return this.data;
    }

    public String getUserDataJSON() {
        return rubyInterface.getUserDataJSON(this.user);
    }

    public void setUserDataJSON(String json) {
        rubyInterface.setUserDataJSON(this.user, json);
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsFunction_setAsLoggedInUser(Object auditInfo) {
        Runtime.privilegeRequired("pSetLoggedInUser", "call user.setAsLoggedInUser()");
        AppRoot supportRoot = Runtime.currentRuntimeHost().getSupportRoot();
        if((auditInfo == null) || !(auditInfo instanceof CharSequence)) {
            throw new OAPIException("Must pass an explanation of how the user was authenticated as a String to setAsLoggedInUser()");
        }
        rubyInterface.setAsLoggedInUser(this.user, supportRoot.getCurrentlyExecutingPluginName(), auditInfo.toString());
    }

    // --------------------------------------------------------------------------------------------------------------
    private String withAllowedOperationCheck(String operation) {
        if((operation == null) || (!KLabelStatements.getAllowedOperations().contains(operation))) {
            throw new OAPIException("Bad operation '" + operation + "'");
        }
        return operation;
    }

    public boolean jsFunction_can(String operation, Object item) {
        Integer objId = null;
        AppLabelList labelList = null;
        if(item instanceof KObjRef) {
            objId = ((KObjRef)item).jsGet_objId();
        } else if(item instanceof KLabelList) {
            labelList = ((KLabelList)item).toRubyObject();
        } else if(item instanceof Scriptable) {
            KObject storeObject = KObject.unwrap((Scriptable)item);
            if(storeObject != null) {
                // Get Ruby label list, avoiding conversions
                labelList = storeObject.toRubyObject().labels();
            }
        }
        if(objId == null && labelList == null) {
            throw new OAPIException("User can() functions must be passed a Ref, StoreObject or LabelList");
        }
        return rubyInterface.operationPermittedOnObjectOrLabelList(this.user, withAllowedOperationCheck(operation), objId, labelList);
    }

    private boolean labelCheck(String operation, Object ref, boolean allow) {
        if((ref == null) || !(ref instanceof KObjRef)) {
            throw new OAPIException("User labelAllowed() or labelDenied() must be passed a Ref");
        }
        return rubyInterface.labelCheck(this.user, withAllowedOperationCheck(operation), ((KObjRef)ref).jsGet_objId(), allow);
    }

    public boolean jsFunction_labelAllowed(String operation, Object ref) {
        return labelCheck(operation, ref, true /* allow */);
    }

    public boolean jsFunction_labelDenied(String operation, Object ref) {
        return labelCheck(operation, ref, false /* deny */);
    }

    public boolean jsFunction_canRead(Object item) {
        return this.jsFunction_can("read", item);
    }

    public boolean jsFunction_canCreate(Object item) {
        return this.jsFunction_can("create", item);
    }

    public boolean jsFunction_canUpdate(Object item) {
        return this.jsFunction_can("update", item);
    }

    public boolean jsFunction_canRelabel(Object item) {
        return this.jsFunction_can("relabel", item);
    }

    public boolean jsFunction_canDelete(Object item) {
        return this.jsFunction_can("delete", item);
    }

    public boolean jsFunction_canApprove(Object item) {
        return this.jsFunction_can("approve", item);
    }

    // --------------------------------------------------------------------------------------------------------------
    public boolean jsFunction_canCreateObjectOfType(KObjRef objectType) {
        // If undefined or null is passed in, return false now.
        if(objectType == null) {
            return false;
        }
        return rubyInterface.canCreateObjectOfType(this.user, objectType.jsGet_objId());
    }

    // --------------------------------------------------------------------------------------------------------------
    public boolean jsFunction_isMemberOf(int groupId) {
        return rubyInterface.isMemberOf(this.user, groupId);
    }

    public Scriptable jsFunction_loadAllMembers() {
        if(this.user.kind() != KIND_GROUP) {
            throw new OAPIException("Can only call loadAllMembers() on active groups.");
        }
        AppUser users[] = rubyInterface.loadAllMembers(this.user);
        Scriptable array = Runtime.createHostObjectInCurrentRuntime("Array", users.length);
        for(int i = 0; i < users.length; i++) {
            array.put(i, array, KUser.fromAppUser(users[i]));
        }
        return array;
    }

    // --------------------------------------------------------------------------------------------------------------
    // Setup functions
    public void jsSet_ref(Object newRef) {
        Runtime.privilegeRequired("pUserSetRef", "set ref property");
        if(newRef != null && newRef instanceof org.mozilla.javascript.Undefined) {
            newRef = null;
        }
        if((newRef != null) && !(newRef instanceof KObjRef)) {
            throw new OAPIException("The ref property can only be set using a Ref value");
        }
        rubyInterface.setUserRef(this.user, (newRef != null) ? ((KObjRef)newRef).toRubyObject() : null);
    }

    public static Scriptable jsStaticFunction_setup_createUser(String json) {
        Runtime.privilegeRequired("pCreateUser", "call O.setup.createUser()");
        return KUser.fromAppUser(rubyInterface.createUser(json));
    }

    public static Scriptable jsStaticFunction_setup_createGroup(String groupName) {
        Runtime.privilegeRequired("pSetupSystem", "call O.setup.createGroup()");
        return KUser.fromAppUser(rubyInterface.createGroup(groupName));
    }

    public boolean jsFunction_setGroupMemberships(Scriptable groups) {
        Runtime.privilegeRequired("pSetupSystem", "call changeGroupMemberships()");
        Runtime runtime = Runtime.getCurrentRuntime();
        return rubyInterface.setGroupMemberships(this.user, (groups == null) ? null : runtime.jsonStringify(groups));
    }

    public boolean jsFunction_changeGroupMemberships(Scriptable add, Scriptable remove) {
        Runtime.privilegeRequired("pSetupSystem", "call changeGroupMemberships()");
        Runtime runtime = Runtime.getCurrentRuntime();
        return rubyInterface.changeGroupMemberships(this.user,
                (add == null) ? null : runtime.jsonStringify(add),
                (remove == null) ? null : runtime.jsonStringify(remove)
        );
    }

    public boolean jsFunction_setDetails(Scriptable details) {
        Runtime.privilegeRequired("pUserSetDetails", "call setDetails()");
        String json = Runtime.getCurrentRuntime().jsonStringify(details);
        return rubyInterface.setDetails(this.user, json);
    }

    public Scriptable jsFunction_setIsActive(boolean active) {
        Runtime.privilegeRequired("pUserActivation", "call setIsActive()");
        this.user = rubyInterface.setIsActive(this.user, active);
        return this;
    }

    public String jsFunction_generatePasswordRecoveryURL() {
        Runtime.privilegeRequired("pUserPasswordRecovery", "call generatePasswordRecoveryURL()");
        return rubyInterface.generatePasswordRecoveryURL(this.user, false /* not welcome URL */);
    }

    public String jsFunction_generateWelcomeURL() {
        Runtime.privilegeRequired("pUserPasswordRecovery", "call generateWelcomeURL()");
        return rubyInterface.generatePasswordRecoveryURL(this.user, true /* welcome URL */);
    }

    // --------------------------------------------------------------------------------------------------------------
    public static String makeWhereClauseForIsMemberOf(String fieldName, int groupId) {
        return rubyInterface.makeWhereClauseForIsMemberOf(fieldName, groupId);
    }

    // --------------------------------------------------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        public AppUser getUserById(int id);

        public AppUser getUserByEmail(String email);

        public AppUser[] getAllUsersByEmail(String email);

        public AppUser getUserByRef(AppObjRef ref);

        public AppUser getCurrentUser();

        public boolean canCreateObjectOfType(AppUser user, int objId);

        public boolean isMemberOf(AppUser user, int groupId);

        public Integer[] getGroupIds(AppUser user);

        public Integer[] getDirectGroupIds(AppUser user);

        public String getUserDataJSON(AppUser user);

        public void setUserDataJSON(AppUser user, String json);

        public String makeWhereClauseForIsMemberOf(String fieldName, int groupId);

        public AppUser[] loadAllMembers(AppUser group);

        public boolean operationPermittedOnObjectOrLabelList(AppUser user, String operation, Integer objId, AppLabelList labelList);

        public boolean labelCheck(AppUser user, String operation, Integer objId, boolean allow);

        public void setAsLoggedInUser(AppUser user, String provider, String auditInfo);

        public AppUser createUser(String json);

        public boolean setDetails(AppUser user, String json);

        public AppUser createGroup(String groupName);

        public boolean setGroupMemberships(AppUser user, String groupsJSON);

        public boolean changeGroupMemberships(AppUser user, String addJSON, String removeJSON);

        public AppUser setIsActive(AppUser user, boolean active);

        public String generatePasswordRecoveryURL(AppUser user, boolean welcomeURL);

        public void setUserRef(AppUser user, AppObjRef ref);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }
}
