/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.haplo.javascript.OAPIException;
import org.haplo.jsinterface.app.*;

import org.apache.commons.io.IOUtils;
import java.io.FileInputStream;
import java.io.IOException;

public class KBinaryDataStaticFile extends KBinaryData {
    private String diskPathname;

    public KBinaryDataStaticFile() {
    }

    public String getClassName() {
        return "$BinaryDataStaticFile";
    }

    public void setFile(String diskPathname, String filename, String mimeType) {
        this.diskPathname = diskPathname;
        this.filename = filename;
        this.mimeType = mimeType;
    }

    // --------------------------------------------------------------------------------------------------------------
    @Override
    public boolean isAvailableInMemoryForResponse() {
        return false;
    }

    @Override
    protected byte[] getDataAsBytes() {
        try {
            return IOUtils.toByteArray(new FileInputStream(this.diskPathname));
        } catch(IOException e) {
            throw new OAPIException("Could not load file from disk: "+e.getMessage(), e);
        }
    }

    @Override
    public String getDiskPathnameForResponse() {
        return this.diskPathname;
    }
}
