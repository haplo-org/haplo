/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.app;

import java.io.IOException;
import java.util.zip.ZipFile;
import java.util.zip.ZipEntry;

import org.apache.commons.io.IOUtils;

// Java code called by the Ruby FileController
public class FileController {
    public static class ZipFileExtractionResults {
        public byte[] data;
        public String chosenFile;
        public int etagSuggestion;
    }

    public static ZipFileExtractionResults zipFileExtraction(String zipFilePathname, String contentsDefault, String contentsRequested) throws IOException {
        ZipFileExtractionResults results = new ZipFileExtractionResults();

        ZipFile zipFile = new ZipFile(zipFilePathname);
        try {
            // Find the right entry, trying for the requested filename by defaulting back on the default given
            ZipEntry e = zipFile.getEntry(contentsRequested);
            results.chosenFile = contentsRequested;
            if(e == null) {
                e = zipFile.getEntry(contentsDefault);
                results.chosenFile = contentsDefault;
            }
            if(e == null) {
                return null;
            }

            results.data = IOUtils.toByteArray(zipFile.getInputStream(e));
        } finally {
            zipFile.close();
        }

        results.etagSuggestion = results.chosenFile.hashCode() & 0xfffff;

        return results;
    }
}
