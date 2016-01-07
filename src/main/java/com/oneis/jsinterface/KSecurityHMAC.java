/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import com.oneis.utils.StringUtils;

import com.oneis.javascript.OAPIException;

public class KSecurityHMAC extends KScriptable {
    public KSecurityHMAC() {
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$SecurityHMAC";
    }

    // --------------------------------------------------------------------------------------------------------------
    public static String jsStaticFunction_sign(String algorithm, String secret, String input) {
        // Convert and check algorithm name
        String hmacAlgorithm = null;
        if("MD5".equals(algorithm)) {
            hmacAlgorithm = "HmacMD5";
        } else if("SHA1".equals(algorithm)) {
            hmacAlgorithm = "HmacSHA1";
        } else if("SHA256".equals(algorithm)) {
            hmacAlgorithm = "HmacSHA256";
        } else {
            throw new OAPIException("Unknown algorithm passed to O.security.hmac.sign()");
        }

        // Secret must be a decent length, to make sure there's some point to signing.
        if(secret.length() < 32) {
            throw new OAPIException("Secret passed to O.security.hmac.sign() must be at least 32 characters long");
        }

        // Do signing, converting strings to UTF-8 bytes
        byte[] signature = null;
        try {
            Mac mac = Mac.getInstance(hmacAlgorithm);
            mac.init(new SecretKeySpec(secret.getBytes("UTF-8"), hmacAlgorithm));
            signature = mac.doFinal(input.getBytes("UTF-8"));
        } catch(Exception e) {
            throw new OAPIException("Error generating HMAC signature");
        }

        if(signature == null || signature.length < 16) {
            throw new RuntimeException("Bad HMAC signature generated");
        }

        return StringUtils.bytesToHex(signature);
    }

}
