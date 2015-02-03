/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.common.io;

import java.nio.ByteBuffer;
import java.io.InputStream;
import java.io.IOException;

public class ByteBufferInputStream extends InputStream {
    private ByteBuffer buffer;

    public ByteBufferInputStream(ByteBuffer buffer) {
        this.buffer = buffer;
    }

    public synchronized int read() throws IOException {
        if(!this.buffer.hasRemaining()) {
            return -1;
        }
        return this.buffer.get() & 0xFF;
    }

    public synchronized int read(byte[] bytes, int off, int len) throws IOException {
        if(!this.buffer.hasRemaining()) {
            return -1;
        }
        len = Math.min(len, this.buffer.remaining());
        this.buffer.get(bytes, off, len);
        return len;
    }
}
