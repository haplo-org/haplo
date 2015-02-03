/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

// Interface to the krandom.rb interface
package com.oneis.common.utils;

public class KRandom {
    static public long randomInt32() {
        return rubyInterface.random_int32();
    }

    static public String randomHex(int length) {
        return rubyInterface.random_hex(length);
    }

    static public String randomBase64(int length) {
        return rubyInterface.random_base64(length);
    }

    static public String randomAPIKey(int length) {
        return rubyInterface.random_api_key(length);
    }

    // --------------------------------------------------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        public long random_int32();

        public String random_hex(int length);

        public String random_base64(int length);

        public String random_api_key(int length);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }
}
