/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;

public class KMessageBusPlatformSupport extends KScriptable {
    public KMessageBusPlatformSupport() { }
    public void jsConstructor() { }
    public String getClassName() {
        return "$KMessageBusPlatformSupport";
    }

    // ----------------------------------------------------------------------

    public static void jsStaticFunction_setBusPlatformConfig(Object json) {
        if(!(json instanceof CharSequence)) { throw new OAPIException("Bad bus setup"); }
        rubyInterface.setBusPlatformConfig(json.toString());
    }

    public static String jsStaticFunction_queryKeychain(Object name) {
        Runtime.privilegeRequired("pMessageBusRemote", "use configured remote message bus");
        if(!(name instanceof CharSequence)) {
            throw new OAPIException("Bad keychain name for message bus");
        }
        return rubyInterface.queryKeychain(name.toString());
    }

    public static void jsStaticFunction_sendMessageToBus(String busKind, int busId, String busName, String busSecret, int reliability, String body) {
        Runtime.privilegeRequired("pMessageBusRemote", "send message on message bus");
        rubyInterface.sendMessageToBus(busKind, busId, busName, busSecret, reliability, body);
    }

    // ----------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        void setBusPlatformConfig(String json);
        String queryKeychain(String name);
        void sendMessageToBus(String busKind, int busId, String busName, String busSecret, int reliability, String body);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }

}
