/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.utils;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.IOException;
import java.util.Arrays;

/**
 * Misc utilities for UTF8 things
 */
public class UTF8Utils {
    private static final byte[] UTF8_BOM = new byte[]{(byte)0xEF, (byte)0xBB, (byte)0xBF};

    public static void rewriteTextFileWithoutUTF8BOMAndFixLineEndings(String inputPathname, String outputPathname) throws IOException {
        File inputFile = new File(inputPathname);
        File outputFile = new File(outputPathname);
        try(
                // Although the buffered streams will call close on the file streams when close() is called,
                // because they all implement Closeable, their close() methods are all idempotent.
                FileInputStream fileInputStream = new FileInputStream(inputFile);
                BufferedInputStream inputStream = new BufferedInputStream(fileInputStream);
                FileOutputStream fileOutputStream = new FileOutputStream(outputFile);
                BufferedOutputStream outputStream = new BufferedOutputStream(fileOutputStream);) {
            // Got a BOM?
            inputStream.mark(16);
            byte[] fileStarts = new byte[UTF8_BOM.length];
            if(inputStream.read(fileStarts) == UTF8_BOM.length) {
                if(!Arrays.equals(fileStarts, UTF8_BOM)) {
                    // No BOM, go back to the beginning of the file
                    inputStream.reset();
                }
            }

            // Copy the input to the output, removing \r characters but ensuring that this doesn't mean there's no line ending.
            // eg "A\r\n\r\nB" => "A\n\nB", "A\r\r\r\B" => "A\nB"
            int c, last = -1;
            boolean needNewLine = false;
            while(-1 != (c = inputStream.read())) {
                if(c == '\r') {
                    if(last != '\n') {
                        needNewLine = true;
                    }
                } else if(c == '\n') {
                    needNewLine = false;
                    outputStream.write('\n');
                    last = '\n';
                } else {
                    if(needNewLine) {
                        outputStream.write('\n');
                        needNewLine = false;
                    }
                    outputStream.write(c);
                    last = c;
                }
            }
        }
    }
}
