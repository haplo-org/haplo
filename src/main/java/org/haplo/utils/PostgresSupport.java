/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.utils;

// TODO: Automated tests for postgres string escaping
/**
 * Provides some static methods for Ruby code to use Postgres databases more
 * efficiently.
 *
 * Java implementations of functions in fe-exec.c from postgres distribution.
 */
public class PostgresSupport {
    /**
     * Implementation of PQescapeString
     */
    public static byte[] escape_string(byte[] input, boolean doNotEscapeSlashes) {
        // Replaces "'" with "''", and optionally replaces "\" with "\\". (usually required)

        // How much space is required?
        int len = input.length;
        int olen = len;
        for(int l = 0; l < len; l++) {
            byte b = input[l];
            if(b == '\'' || (!doNotEscapeSlashes && b == '\\')) {
                olen += 1;
            }
        }

        // Need to escape anything?
        if(olen == len) {
            return input;
        }

        byte[] output = new byte[olen];
        int o = 0;
        for(int l = 0; l < len; l++) {
            byte b = input[l];
            if(b == '\'' || (!doNotEscapeSlashes && b == '\\')) {
                // Double the character
                output[o++] = b;
                output[o++] = b;
            } else {
                output[o++] = b;
            }
        }

        return output;
    }

}
