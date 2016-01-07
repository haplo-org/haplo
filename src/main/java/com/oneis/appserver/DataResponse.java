/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.appserver;

import java.io.*;

/**
 * Response object which writes data held in memory.
 *
 * Use the setHeader() in the base class to set the MIME type.
 */
public class DataResponse extends Response {
    private byte[] data;
    int responseCode;

    /**
     * Constructor
     *
     * @param data literal data to send in the body of the HTTP response
     */
    public DataResponse(byte[] data) {
        this.data = data;
        this.responseCode = 200;
    }

    /**
     * Constructor
     *
     * @param data literal data to send in the body of the HTTP response
     * @param responseCode HTTP resonse code to send with the request
     */
    public DataResponse(byte[] data, int responseCode) {
        this.data = data;
        this.responseCode = responseCode;
    }

    public int getResponseCode() {
        return responseCode;
    }

    public long getContentLength() {
        return data.length;
    }

    public byte[] getRawBuffer() throws IOException {
        return data;
    }

    public void writeToOutputStream(OutputStream stream) throws IOException {
        stream.write(data);
    }
}
