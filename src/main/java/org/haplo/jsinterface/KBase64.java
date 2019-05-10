/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import java.util.Base64;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.FileInputStream;
import java.io.UnsupportedEncodingException;

import org.apache.commons.io.IOUtils;

import org.mozilla.javascript.Scriptable;

import org.haplo.javascript.OAPIException;
import org.haplo.javascript.Runtime;
import org.haplo.javascript.JsGet;
import org.haplo.jsinterface.KBinaryData;
import org.haplo.jsinterface.KStoredFile;
import org.haplo.jsinterface.KBinaryDataInMemory;


public class KBase64 extends KScriptable {
    public KBase64() {
    }

    // ----------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$Base64";
    }

    // ----------------------------------------------------------------------

    public static String jsStaticFunction_encode(Object input, Object option) throws IOException {
        Base64.Encoder encoder = null;
        switch(checkedOption(option)) {
            case "mime": encoder = Base64.getMimeEncoder(); break;
            case "url":  encoder = Base64.getUrlEncoder().
                                         withoutPadding();  break; // URL encoders can't use padding as = is a special character
            default:     encoder = Base64.getEncoder();     break;
        }

        InputStream in = inputToInputStream(input, "O.base64.encode()");

        ByteArrayOutputStream encoded = new ByteArrayOutputStream();
        OutputStream encoding = encoder.wrap(encoded);
        IOUtils.copy(in, encoding);
        encoding.close();
        String r = null;
        try {
            r = encoded.toString("UTF-8");
        } catch(UnsupportedEncodingException e) { /* UTF-8 always supported */ }
        return r;
    }

    // ----------------------------------------------------------------------

    public static Scriptable jsStaticFunction_decode(Object input, Object option, Object binaryDataOptions) throws IOException {
        Base64.Decoder decoder = null;
        switch(checkedOption(option)) {
            case "mime": decoder = Base64.getMimeDecoder(); break;
            case "url":  decoder = Base64.getUrlDecoder();  break;
            default:     decoder = Base64.getDecoder();     break;
        }

        InputStream in = inputToInputStream(input, "O.base64.decode()");

        ByteArrayOutputStream decoded = new ByteArrayOutputStream();
        InputStream decoding = decoder.wrap(in);
        IOUtils.copy(decoding, decoded);
        decoding.close();

        String filename = JsGet.stringMaybeWithDefault("filename", binaryDataOptions, "data.bin");
        String mimeType = JsGet.stringMaybeWithDefault("mimeType", binaryDataOptions, "application/octet-stream");

        KBinaryDataInMemory data = (KBinaryDataInMemory)Runtime.createHostObjectInCurrentRuntime(
            "$BinaryDataInMemory", false, null, null, filename, mimeType
        );
        data.setBinaryData(decoded.toByteArray());

        return data;
    }

    // ----------------------------------------------------------------------

    private static String checkedOption(Object option) {
        if(option == null || option instanceof org.mozilla.javascript.Undefined) {
            return "default";
        }
        if(!(option instanceof CharSequence)) {
            throw new OAPIException("Bad Base64 option");
        }
        String o = option.toString();
        if(o.equals("mime") || o.equals("url")) {
            return o;
        } else {
            throw new OAPIException("Bad Base64 option: "+o);
        }
    }

    private static InputStream inputToInputStream(Object input, String fnname) throws IOException {
        byte[] bytes = null;
        String pathname = null;

        if(input instanceof CharSequence) {
            try {
                bytes = input.toString().getBytes("UTF-8");
            } catch(UnsupportedEncodingException e) { /* UTF-8 always supported */ }
        } else if(input instanceof KBinaryData) {
            KBinaryData binaryData = (KBinaryData)input;
            if(binaryData.isAvailableInMemoryForResponse()) {
                bytes = binaryData.getInMemoryByteArray();
            } else {
                pathname = binaryData.getDiskPathname();
            }
        } else if(input instanceof KStoredFile) {
            pathname = ((KStoredFile)input).getDiskPathname();
        } else {
            throw new OAPIException("Unsupported input type passed to "+fnname);
        }

        if(bytes != null) {
            return new ByteArrayInputStream(bytes);
        } else if(pathname != null) {
            return new FileInputStream(pathname);
        } else {
            throw new OAPIException("Bad input to "+fnname);
        }
    }

}
