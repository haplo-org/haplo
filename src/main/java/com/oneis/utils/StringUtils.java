/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.utils;

import com.oneis.javascript.OAPIException;

import java.nio.charset.Charset;
import java.io.File;
import java.io.FileInputStream;
import java.io.Reader;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.IOException;

/**
 * Misc utilities for java Strings.
 */
public class StringUtils {
    // Maximum size of file which can be converted to a string. Makes it harder to create a DoS
    // vunerability for attackers to upload huge files and create huge strings within the JS runtime.
    public static int MAXIMUM_READ_FILE_AS_STRING_SIZE = (1024 * 1024 * 16);  // 16MB

    // -------------------------------------------------------------------------------------------------------------

    private static final char[] kDigits = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};

    public static String bytesToHex(byte[] raw) {
        int length = raw.length;
        StringBuffer hex = new StringBuffer();
        for(int i = 0; i < length; i++) {
            int value = (raw[i] + 256) % 256;
            int highIndex = value >> 4;
            int lowIndex = value & 0x0f;
            hex.append(kDigits[highIndex]);
            hex.append(kDigits[lowIndex]);
        }
        return hex.toString();
    }

    // -------------------------------------------------------------------------------------------------------------

    public static Charset charsetFromStringWithJSChecking(String charsetName) {
        if(charsetName == null || "undefined".equals(charsetName)) {
            charsetName = "UTF-8";
        }
        Charset charset = null;
        try {
            charset = Charset.forName(charsetName);
        } catch(Exception e) {
            throw new OAPIException("Invalid charset: " + charsetName);
        }
        return charset;
    }

    // -------------------------------------------------------------------------------------------------------------

    public static String readFileAsStringWithJSChecking(String filename, Charset charset) {
        File f = new File(filename);
        if(f.length() > MAXIMUM_READ_FILE_AS_STRING_SIZE) {
            throw new OAPIException("Uploaded data is too big to read into a String");
        }
        try {
            FileInputStream stream = new FileInputStream(f);
            try {
                Reader reader = new BufferedReader(new InputStreamReader(stream, charset));
                StringBuilder builder = new StringBuilder();
                char[] buffer = new char[32768];
                int read;
                while((read = reader.read(buffer, 0, buffer.length)) > 0) {
                    builder.append(buffer, 0, read);
                }
                return builder.toString();
            } finally {
                stream.close();
            }
        } catch(IOException e) {
            throw new OAPIException("Error reading data");
        }
    }
}
