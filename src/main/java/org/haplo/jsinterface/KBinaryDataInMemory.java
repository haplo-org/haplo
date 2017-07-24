/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.haplo.javascript.OAPIException;
import org.haplo.jsinterface.app.*;

import org.mozilla.javascript.Scriptable;

import java.io.UnsupportedEncodingException;
import java.nio.charset.Charset;

public class KBinaryDataInMemory extends KBinaryData {
    private byte[] data;
    private String filename;
    private String mimeType;

    public KBinaryDataInMemory() {
    }

    // --------------------------------------------------------------------------------------------------------------
    // For now, only supports constructing data from a string
    public void jsConstructor(boolean sourceIsAlreadyAvailable, String source, String charset, String filename, String mimeType) {
        if(sourceIsAlreadyAvailable) {
            try {
                this.data = source.getBytes(charset);
            } catch(UnsupportedEncodingException e) {
                throw new OAPIException("Unknown character set: "+charset);
            }
        } else {
            this.data = null; // It will be filled in later
        }
        this.filename = filename;
        this.mimeType = mimeType;
    }

    public String getClassName() {
        return "$BinaryDataInMemory";
    }

    public void setBinaryData(byte[] source) {
        this.data = source;
    }

    // --------------------------------------------------------------------------------------------------------------
    public String jsGet_filename() {
        return this.filename;
    }

    public String jsGet_mimeType() {
        return this.mimeType;
    }

    @Override
    public boolean isAvailableInMemoryForResponse() {
        return true;
    }

    @Override
    protected byte[] getDataAsBytes() {
        return this.data;
    }
}
