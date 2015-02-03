/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface;

import com.oneis.javascript.OAPIException;

import com.oneis.utils.StringUtils;

import com.oneis.jsinterface.app.*;

import java.nio.charset.Charset;

public class KBinaryData extends KScriptable {
    public KBinaryData() {
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$BinaryData";
    }

    // --------------------------------------------------------------------------------------------------------------
    public String jsGet_filename() {
        throw new OAPIException("Attempt to use base class");
    }

    public String jsGet_mimeType() {
        throw new OAPIException("Attempt to use base class");
    }

    public String jsGet_digest() {
        throw new OAPIException("Attempt to use base class");
    }

    public long jsGet_fileSize() {
        throw new OAPIException("Attempt to use base class");
    }

    public String jsFunction_readAsString(String charsetName) {
        return convertToString(StringUtils.charsetFromStringWithJSChecking(charsetName));
    }

    protected String convertToString(Charset charset) {
        // Can't make this abstract because Rhino needs to create one
        throw new OAPIException("Attempt to use base class");
    }
}
