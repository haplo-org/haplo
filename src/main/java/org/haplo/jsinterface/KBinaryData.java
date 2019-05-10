/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.haplo.javascript.OAPIException;
import org.haplo.javascript.Runtime;

import org.haplo.utils.StringUtils;

import org.haplo.jsinterface.app.*;

import org.mozilla.javascript.Scriptable;

import java.nio.charset.Charset;
import java.security.MessageDigest;

/*
 * A base class for implementing JS objects representing binary data.
 * It can't be abstract because Rhino needs to instantiate one of these base class objects.
 *
 * To implement another binary data class,
 *  - Derive another class from KBinaryData
 *  - When adding it to Runtime.java, make sure you map inheritance
 *  - Implement jsGet_filename(), jsGet_mimeType()
 *  - If the data is always available in memory as a byte[], implement getDataAsBytes() and isAvailableInMemoryForResponse() { return true;}
 *        See KBinaryDataInMemory as a simple example
 *  - If not, implement as many methods as possible.
 *        See KUploadedFile for an implementation backed by a temporary file
 *        If backed by a file, you'll need to carefully cope with moving it into the file store
 */

public class KBinaryData extends KScriptable {
    private String digest;
    protected String filename;
    protected String mimeType;

    public KBinaryData() {
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$BinaryData";
    }

    // --------------------------------------------------------------------------------------------------------------
    protected String getConsoleClassName() {
        return "BinaryData";    // display same console log for all subclasses
    }

    protected String getConsoleData() {
        try {
            return this.jsGet_filename()+", "+this.jsGet_fileSize()+" bytes, "+this.jsGet_mimeType();
        } catch(Exception e) {
            return "?";
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    public String jsGet_filename() {
        checkAvailable();
        return this.filename;
    }

    public void jsSet_filename(String filename) {
        checkAvailable();
        this.filename = filename;
    }

    public String jsGet_mimeType() {
        checkAvailable();
        return this.mimeType;
    }

    public void jsSet_mimeType(String mimeType) {
        checkAvailable();
        this.mimeType = mimeType;
    }

    public String jsGet_digest() {
        if(this.digest == null) {
            try {
                MessageDigest md = MessageDigest.getInstance("SHA-256");
                this.digest = StringUtils.bytesToHex(md.digest(_checkedGetDataAsBytes()));
            } catch(Exception e) {
                throw new OAPIException("Error generating digest");
            }
        }
        return this.digest;
    }

    public long jsGet_fileSize() {
        return _checkedGetDataAsBytes().length;
    }

    final public String jsFunction_readAsString(String charsetName) {
        return convertToString(StringUtils.charsetFromStringWithJSChecking(charsetName));
    }

    final public Object jsFunction_readAsJSON() {
        String json = convertToString(StringUtils.charsetFromStringWithJSChecking("UTF-8"));
        try {
            return Runtime.getCurrentRuntime().makeJsonParser().parseValue(json);
        } catch(org.mozilla.javascript.json.JsonParser.ParseException e) {
            throw new OAPIException("Couldn't JSON decode BinaryData "+jsGet_filename(), e);
        }
    }

    protected String convertToString(Charset charset) {
        return new String(_checkedGetDataAsBytes(), charset);
    }

    public Scriptable jsFunction__createStoredFileFromData() {
        return KStoredFile.newStoredFileFromData(_checkedGetDataAsBytes(), jsGet_filename(), jsGet_mimeType());
    }

    final private byte[] _checkedGetDataAsBytes() {
        byte[] bytes = getDataAsBytes();
        if(bytes == null) {
            throw new OAPIException("Data not available");
        }
        return bytes;
    }

    // --------------------------------------------------------------------------------------------------------------
    protected void checkAvailable() {
    }

    public boolean isAvailableInMemoryForResponse() {
        throw new OAPIException("Attempt to use base class");
    }

    // May not necessarily be implemented
    protected byte[] getDataAsBytes() {
        throw new OAPIException("Attempt to use base class");
    }

    public byte[] getInMemoryByteArray() {
        return getInMemoryByteArrayForResponse();
    }

    public byte[] getInMemoryByteArrayForResponse() {
        return getDataAsBytes();
    }

    public String getDiskPathname() {
        return this.getDiskPathnameForResponse();
    }

    public String getDiskPathnameForResponse() {
        throw new OAPIException("Attempt to use base class");
    }
}
