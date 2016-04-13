/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.appserver;

import java.io.*;
import org.apache.commons.io.IOUtils;

/**
 * Response object which writes the contents of a file.
 *
 * Use the setHeader() in the base class to set the MIME type and other headers.
 */
public class FileResponse extends Response {
    private File file;

    /**
     * Constructor
     *
     * @param pathname Pathname of the file to send
     */
    public FileResponse(String pathname) {
        this.file = new File(pathname);
    }

    public long getContentLength() {
        return file.length();
    }

    public boolean supportsRanges() {
        return true;
    }

    public void writeToOutputStream(OutputStream stream) throws IOException {
        InputStream in = new FileInputStream(file);
        try {
            IOUtils.copy(in, stream);
        } finally {
            IOUtils.closeQuietly(in);
        }
    }

    public void writeRangeToOutputStream(OutputStream stream, long offset, long length) throws IOException {
        if(length == 0) {
            return;
        }
        FileInputStream in = new FileInputStream(file);
        try {
            in.skip(offset);
            byte[] buffer = new byte[4096];
            long count = 0;
            int n = 0;
            while(count < length && (-1 != (n = in.read(buffer, 0, (int)(((length - count) > 4096) ? 4096 : (length - count)))))) {
                stream.write(buffer, 0, n);
                count += n;
            }
        } finally {
            IOUtils.closeQuietly(in);
        }
    }
}
