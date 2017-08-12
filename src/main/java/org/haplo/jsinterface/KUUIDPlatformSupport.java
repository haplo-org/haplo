/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.haplo.javascript.OAPIException;

import java.util.UUID;

public class KUUIDPlatformSupport extends KScriptable {
    public KUUIDPlatformSupport() { }
    public void jsConstructor() { }
    public String getClassName() {
        return "$KUUIDPlatformSupport";
    }

    // ----------------------------------------------------------------------

    public static String jsStaticFunction_randomUUID() {
        return UUID.randomUUID().toString();
    }

    public static boolean jsStaticFunction_isValidUUID(String string) {
        try {
            UUID.fromString(string);
        } catch(IllegalArgumentException e) {
            return false;
        }
        return true;
    }

    public static boolean jsStaticFunction_isEqual(String uuid1str, String uuid2str) {
        UUID uuid1;
        UUID uuid2;
        try {
            uuid1 = UUID.fromString(uuid1str);
            uuid2 = UUID.fromString(uuid2str);
        } catch(IllegalArgumentException e) {
            throw new OAPIException("Invalid UUID");
        }
        return uuid1.equals(uuid2);
    }

}
