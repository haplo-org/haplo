/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.appserver;

import java.io.*;
import java.util.zip.Deflater;
import org.apache.commons.io.FileUtils;

// java.util.zip.GZIPOutputStream doesn't allow the compression level to be set.
import com.oneis.utils.GZIPOutputStreamEx;

/**
 * Response object which sends a static file. Maybe be returned more than once.
 *
 * Use the setHeader() in the base class to set the MIME type.
 */
public class StaticFileResponse extends Response {
    private boolean allowCompression;
    private byte[] uncompressed;
    private byte[] compressed;
    private int responseCode;

    /**
     * Constructor
     *
     * @param pathname Filename of the file to read
     * @param mimeType MIME type of the response
     * @param allowCompression Whether to allow the response to be compressed.
     */
    public StaticFileResponse(String pathname, String mimeType, boolean allowCompression) throws IOException {
        addHeader("Content-Type", mimeType);
        this.allowCompression = allowCompression;
        this.compressed = null;
        this.responseCode = 200;
        // Read file
        this.uncompressed = FileUtils.readFileToByteArray(new File(pathname));
    }

    /**
     * Constructor
     *
     * @param data literal data to send in the body of the HTTP response
     * @param mimeType MIME type of the response
     * @param allowCompression Whether to allow the response to be compressed.
     */
    public StaticFileResponse(byte[] data, String mimeType, boolean allowCompression) throws IOException {
        addHeader("Content-Type", mimeType);
        this.allowCompression = allowCompression;
        this.uncompressed = data;
        this.compressed = null;
        this.responseCode = 200;
    }

    public void setResponseCode(int code) {
        this.responseCode = code;
    }

    public int getResponseCode() {
        return this.responseCode;
    }

    public long getContentLength() {
        return uncompressed.length;
    }

    public boolean getBehavesAsStaticFile() {
        return true;
    }

    public long getContentLengthGzipped() {
        if(allowCompression) {
            if(uncompressed.length < 4) {
                return NOT_GZIPABLE;
            }

            if(compressed == null) {
                try {
                    // Compress the file, and cache it so it's only compressed once
                    ByteArrayOutputStream c = new ByteArrayOutputStream(uncompressed.length / 2);
                    GZIPOutputStreamEx compressor = new GZIPOutputStreamEx(c, uncompressed.length / 2, Deflater.BEST_COMPRESSION);
                    compressor.write(uncompressed);
                    compressor.close();
                    compressed = c.toByteArray();
                } catch(IOException e) {
                    System.out.println("Failed to compress static file");
                    return NOT_GZIPABLE;
                }
            }

            // If it's smaller uncompressed (taking into account headers to say it's compressed), send it uncompressed
            return ((compressed.length + 20) > uncompressed.length) ? NOT_GZIPABLE : compressed.length;
        }

        return NOT_GZIPABLE;
    }

    public byte[] getRawBuffer() throws IOException {
        return uncompressed;
    }

    public byte[] getRawGzippedBuffer() throws IOException {
        return compressed;
    }

    public void writeToOutputStream(OutputStream stream) throws IOException {
        stream.write(uncompressed);
    }

    public void writeToOutputStreamGzipped(OutputStream stream) throws IOException {
        stream.write(compressed);
    }
}
