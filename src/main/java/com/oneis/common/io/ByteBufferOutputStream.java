/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.common.io;

import java.nio.ByteBuffer;
import java.io.OutputStream;
import java.io.IOException;

public class ByteBufferOutputStream extends OutputStream {
    private ByteBuffer buffer;

    public ByteBufferOutputStream(ByteBuffer buffer) {
        this.buffer = buffer;
    }

    public synchronized void write(int b) throws IOException {
        this.buffer.put((byte)b);
    }

    public synchronized void write(byte[] bytes, int off, int len) throws IOException {
        this.buffer.put(bytes, off, len);
    }

}
