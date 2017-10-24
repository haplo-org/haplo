/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.mozilla.javascript.Scriptable;

import org.haplo.javascript.OAPIException;

import org.haplo.utils.StringUtils;

import org.haplo.jsinterface.app.AppStoredFile;
import org.haplo.jsinterface.KStoredFile;

import org.haplo.appserver.FileUploads;

import java.nio.charset.Charset;

public class KUploadedFile extends KBinaryData {

    FileUploads.Upload file;
    Scriptable storedFile;

    public KUploadedFile() {
    }

    void setUpload(FileUploads.Upload file) {
        this.file = file;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$UploadedFile";
    }

    // --------------------------------------------------------------------------------------------------------------
    @Override
    public String jsGet_filename() {
        checkAvailable();
        return this.file.getFilename();
    }

    @Override
    public String jsGet_mimeType() {
        checkAvailable();
        return this.file.getMIMEType();
    }

    @Override
    public String jsGet_digest() {
        checkAvailable();
        if(!("SHA-256".equals(this.file.getDigestName()))) {
            throw new OAPIException("Digest not available");
        }
        return this.file.getDigest();
    }

    @Override
    public long jsGet_fileSize() {
        checkAvailable();
        return this.file.getFileSize();
    }

    // --------------------------------------------------------------------------------------------------------------
    @Override
    protected String convertToString(Charset charset) {
        return StringUtils.readFileAsStringWithJSChecking(this.file.getSavedPathname(), charset);
    }

    // --------------------------------------------------------------------------------------------------------------
    public Scriptable jsFunction__createStoredFileFromData() {
        if(this.storedFile != null) {
            return this.storedFile;
        }
        checkAvailable();
        AppStoredFile appStoredFile = rubyInterface.storedFileFrom(this.file);
        this.storedFile = KStoredFile.fromAppStoredFile(appStoredFile);
        return this.storedFile;
    }

    // --------------------------------------------------------------------------------------------------------------
    private void checkAvailable() {
        if(this.file == null || !this.file.wasUploaded()) {
            throw new OAPIException("File not available");
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    public boolean isAvailableInMemoryForResponse() {
        return false;
    }

    public String getDiskPathname() {
        return this.file.getSavedPathname();
    }

    public String getDiskPathnameForResponse() {
        // Temporary file will have been deleted by the time it would be opened for responding
        throw new OAPIException("Responding with uploaded file not supported");
    }

    // --------------------------------------------------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        public AppStoredFile storedFileFrom(FileUploads.Upload upload);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }

}
