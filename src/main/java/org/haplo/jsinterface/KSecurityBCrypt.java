/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.haplo.common.utils.BCrypt;

import org.haplo.javascript.OAPIException;

public class KSecurityBCrypt extends KScriptable {
    public KSecurityBCrypt() {
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$SecurityBCrypt";
    }

    // --------------------------------------------------------------------------------------------------------------
    // Use Object as an argument so it can be checked strictly
    public static String jsStaticFunction_create(Object password) {
        if(password == null || !(password instanceof CharSequence) || password.equals("")) {
            throw new OAPIException("Bad password passed to O.security.bcrypt.create()");
        }
        return BCrypt.hashpw(((CharSequence)password).toString(), BCrypt.gensalt());
    }

    // Use Object as an argument so it can be checked strictly
    public static boolean jsStaticFunction_verify(Object password, Object encoded) {
        // Check password - but return false if it's not acceptable rather than throwing an exception.
        // This'll make it easier to use as you don't have to check the password is valid before calling.
        if(password == null || !(password instanceof CharSequence) || password.equals("")) {
            return false;
        }
        if(encoded == null || !(encoded instanceof CharSequence) || encoded.equals("")) {
            throw new OAPIException("Bad encoded password passed to O.security.bcrypt.verify()");
        }
        try {
            return BCrypt.checkpw(((CharSequence)password).toString(), ((CharSequence)encoded).toString());
        } catch(IllegalArgumentException e) {
            // Turn BCrypt errors into a helpful message for JavaScript API
            throw new OAPIException("Bad encoded password passed to O.security.bcrypt.verify()");
        }
    }

}
