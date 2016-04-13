/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.utils;

import java.io.IOException;
import java.io.OutputStream;
import java.io.FilterOutputStream;

/**
 * Filter to limit the amount of output sent to a OutputStream.
 *
 * An exception is thrown if the limit is exceeded.
 */
public class LimitedFilterOutputStream extends FilterOutputStream {
    private int bytesLimit;
    private int bytesSoFar;

    public class LimitExceededException extends IOException {
    }

    /**
     * Constructor
     *
     * @param out OutputStream to write data
     * @parma limit Maximum number of bytes
     */
    public LimitedFilterOutputStream(OutputStream out, int limit) {
        super(out);
        bytesLimit = limit;
        bytesSoFar = 0;
    }

    public void write(byte[] b) throws IOException {
        super.write(b);
        bytesSoFar += b.length;
        if(bytesSoFar > bytesLimit) {
            throw new LimitExceededException();
        }
    }

    public void write(byte[] b, int off, int len) throws IOException {
        super.write(b, off, len);
        bytesSoFar += len;
        if(bytesSoFar > bytesLimit) {
            throw new LimitExceededException();
        }
    }

    public void write(int b) throws IOException {
        super.write(b);
        bytesSoFar += 1;
        if(bytesSoFar > bytesLimit) {
            throw new LimitExceededException();
        }
    }
}
