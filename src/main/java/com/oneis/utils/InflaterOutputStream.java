/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.utils;

import java.io.*;
import java.util.zip.Inflater;

/**
 * Stream which inflates data as it's output.
 */
public class InflaterOutputStream extends OutputStream {
    OutputStream output;
    private Inflater inflater;
    private byte[] decompBuffer;

    final int DECOMP_BUFFER_SIZE = 4096;

    /**
     * Constructor
     *
     * @param out The stream for outputing the inflated data.
     */
    public InflaterOutputStream(OutputStream out) {
        output = out;
        inflater = new Inflater();
        decompBuffer = null;
    }

    protected void finalize() throws Throwable {
        if(decompBuffer != null) {
            close();
        }
        super.finalize();
    }

    public void close() throws IOException {
        decompBuffer = null;
        inflater.end();
        output.close();
    }

    public void flush() throws IOException {
        output.flush();
    }

    public void write(byte[] b) throws IOException {
        inflater.setInput(b);
        writeAllDecompressed();
    }

    public void write(byte[] b, int off, int len) throws IOException {
        inflater.setInput(b, off, len);
        writeAllDecompressed();
    }

    public void write(int b) throws IOException {
        byte[] a = new byte[1];
        a[0] = (byte)b;
        inflater.setInput(a);
        writeAllDecompressed();
    }

    // Function to write underlying data
    private void writeAllDecompressed() throws IOException {
        if(decompBuffer == null) {
            decompBuffer = new byte[DECOMP_BUFFER_SIZE];
        }

        try {
            int b = 0;
            while((b = inflater.inflate(decompBuffer)) != 0) {
                output.write(decompBuffer, 0, b);
            }
        } catch(java.util.zip.DataFormatException e) {
            // Convert this to an IOException
            throw new IOException("java.util.zip.DataFormatException in KInflaterOutputStream");
        }
    }
}
