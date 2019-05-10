/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import java.io.File;

import org.mozilla.javascript.Scriptable;

import org.haplo.javascript.OAPIException;

import org.haplo.utils.StringUtils;

import org.haplo.jsinterface.app.AppStoredFile;
import org.haplo.jsinterface.KStoredFile;

import org.haplo.appserver.FileUploads;

import java.nio.charset.Charset;

public class KBinaryDataTempFile extends KBinaryData {

    private String tempPathname;
    private String digest;
    private Scriptable storedFile;

    public KBinaryDataTempFile() {
    }

    void setTempFile(String tempPathname, String filename, String mimeType) {
        this.tempPathname = tempPathname;
        this.filename = filename;
        this.mimeType = mimeType;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$BinaryDataTempFile";
    }

    // --------------------------------------------------------------------------------------------------------------

    @Override
    public String jsGet_digest() {
        checkAvailable();
        if(this.digest == null) {
            this.digest = rubyInterface.fileHexDigest(this.tempPathname);
        }
        return this.digest;
    }

    @Override
    public long jsGet_fileSize() {
        checkAvailable();
        return new File(this.tempPathname).length();
    }

    // --------------------------------------------------------------------------------------------------------------
    @Override
    protected String convertToString(Charset charset) {
        return StringUtils.readFileAsStringWithJSChecking(this.tempPathname, charset);
    }

    // --------------------------------------------------------------------------------------------------------------
    public Scriptable jsFunction__createStoredFileFromData() {
        if(this.storedFile != null) {
            return this.storedFile;
        }
        checkAvailable();
        AppStoredFile appStoredFile = rubyInterface.storedFileFrom(this.tempPathname, this.filename, this.mimeType);
        this.storedFile = KStoredFile.fromAppStoredFile(appStoredFile);
        return this.storedFile;
    }

    // --------------------------------------------------------------------------------------------------------------

    @Override
    protected void checkAvailable() {
        if(this.tempPathname == null) {
            throw new OAPIException("File not available");
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    public boolean isAvailableInMemoryForResponse() {
        return false;
    }

    public String getDiskPathname() {
        return this.tempPathname;
    }

    public String getDiskPathnameForResponse() {
        // Temporary file will have been deleted by the time it would be opened for responding
        throw new OAPIException("Responding with temporary file not supported");
    }

    // --------------------------------------------------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        public String fileHexDigest(String tempPathname);
        public AppStoredFile storedFileFrom(String tempPathname, String filename, String mimeType);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }

}
