/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface;

import com.oneis.common.utils.KRandom;

public class KSecurityRandom extends KScriptable {
    static final int DEFAULT_HEX_LENGTH = 24;
    static final int DEFAULT_BASE64_LENGTH = 32;
    static final int DEFAULT_API_KEY_LENGTH = 33; // From lib/common/krandom.rb

    // --------------------------------------------------------------------------------------------------------------
    public KSecurityRandom() {
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$SecurityRandom";
    }

    // --------------------------------------------------------------------------------------------------------------
    // Return a double, as JavaScript doesn't do integers, and int is only 31 bits
    public static double jsStaticFunction_int32() {
        return KRandom.randomInt32();
    }

    // Even if Integer is used as an argument, it'll be 0 if an argument isn't passed in the JS call.
    // Just compare against 0 to avoid having to write wrapper functions in JavaScript.
    public static String jsStaticFunction_hex(int length) {
        return KRandom.randomHex(length != 0 ? length : DEFAULT_HEX_LENGTH);
    }

    public static String jsStaticFunction_base64(int length) {
        return KRandom.randomBase64(length != 0 ? length : DEFAULT_BASE64_LENGTH);
    }

    public static String jsStaticFunction_identifier(int length) {
        return KRandom.randomAPIKey(length != 0 ? length : DEFAULT_API_KEY_LENGTH);
    }

}
