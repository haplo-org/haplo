/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.text.extract;

import java.io.InputStream;
import java.io.FileInputStream;
import java.io.BufferedInputStream;
import java.io.File;
import java.io.IOException;

import com.ibm.icu.text.CharsetDetector;
import com.ibm.icu.text.CharsetMatch;

import com.oneis.text.TextExtractOp;

public class Text extends TextExtractOp {
    public Text(String inputPathname) {
        super(inputPathname);
    }

    protected String extract() throws IOException {
        InputStream originalStream = null;
        InputStream fileStream = getInputStream();

        CharsetMatch match = null;
        String text = null;
        try {
            if(!fileStream.markSupported()) {
                fileStream = new BufferedInputStream(fileStream);
            }

            CharsetDetector detector = new CharsetDetector();
            detector.setText(fileStream);
            match = detector.detect();
            if(match == null) {
                // Give up if the charset isn't detected
                return "";
            }
            // Read and convert the string, which the CharsetMatch has handily converted to Unicode
            text = match.getString();
        } finally {
            fileStream.close();
            if(originalStream != null) {
                originalStream.close();
            }
        }

        return text;
    }
}
