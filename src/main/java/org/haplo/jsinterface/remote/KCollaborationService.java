/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.remote;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;
import org.haplo.jsinterface.KScriptable;
import org.mozilla.javascript.*;

import org.haplo.jsinterface.remote.app.*;

public class KCollaborationService extends KScriptable {
    private AppCollaborationService service;

    public KCollaborationService() {
    }

    public void setService(AppCollaborationService service) {
        this.service = service;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$CollaborationService";
    }

    // --------------------------------------------------------------------------------------------------------------
    static public Scriptable fromAppCollaborationService(AppCollaborationService appObj) {
        KCollaborationService service = (KCollaborationService)Runtime.getCurrentRuntime().createHostObject("$CollaborationService");
        service.setService(appObj);
        return service;
    }

    // --------------------------------------------------------------------------------------------------------------
    public static Scriptable jsStaticFunction_findService(boolean searchByName, String serviceName) {
        Runtime.privilegeRequired("pRemoteCollaborationService", "use a collaboration service");

        AppCollaborationService appService = rubyInterface.createServiceObject(searchByName, serviceName);
        if(appService == null) {
            throw new OAPIException("Could not find credentials for collaboration service in application keychain.");
        }
        return fromAppCollaborationService(appService);
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsFunction__connect() {
        this.service.connect();
    }

    public void jsFunction__disconnect() {
        this.service.disconnect();
    }

    // --------------------------------------------------------------------------------------------------------------
    public String jsGet_name() {
        return this.service.getName();
    }

    public boolean jsGet_connected() {
        return this.service.isConnected();
    }

    public void jsFunction_impersonate(Object emailAddress) {
        this.service.impersonate((emailAddress instanceof CharSequence) ? ((CharSequence)emailAddress).toString() : null);
    }

    public Scriptable jsFunction_folderById(String folderId) {
        return KCollaborationFolder.fromAppCollaborationFolder(this.service.folderById(folderId));
    }

    public Scriptable jsFunction_wellKnownFolder(String name) {
        return KCollaborationFolder.fromAppCollaborationFolder(this.service.wellKnownFolder(name));
    }

    // --------------------------------------------------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        public AppCollaborationService createServiceObject(boolean searchByName, String serviceName);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }
}
