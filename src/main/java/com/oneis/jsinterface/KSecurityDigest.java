/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface;

import java.security.MessageDigest;

import com.oneis.utils.StringUtils;

import com.oneis.javascript.OAPIException;

public class KSecurityDigest extends KScriptable {
    public KSecurityDigest() {
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$SecurityDigest";
    }

    // --------------------------------------------------------------------------------------------------------------
    public static String jsStaticFunction_hexDigestOfString(String algorithm, String input) {
        // Fix up algorithm name - upgrade to JRuby 1.7.19 causes SHA256 to be unrecognised
        if(algorithm != null && algorithm.equals("SHA256")) { algorithm = "SHA-256"; }
        // Input converted to UTF-8 bytes
        byte[] digest = null;
        try {
            MessageDigest md = MessageDigest.getInstance(algorithm);
            digest = md.digest(input.getBytes("UTF-8"));
        } catch(Exception e) {
            throw new OAPIException("Error generating digest with algorithm "+algorithm);
        }

        if(digest == null || digest.length < 16) {
            throw new RuntimeException("Bad digest signature generated");
        }

        return StringUtils.bytesToHex(digest);
    }

}
