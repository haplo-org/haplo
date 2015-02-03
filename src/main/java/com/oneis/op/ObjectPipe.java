/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.op;

import java.io.IOException;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;

import java.nio.ByteBuffer;
import java.nio.channels.Selector;
import java.nio.channels.SocketChannel;
import java.nio.channels.SelectionKey;
import java.nio.BufferOverflowException;

import com.oneis.common.io.ByteBufferInputStream;
import com.oneis.common.io.ByteBufferOutputStream;

public class ObjectPipe implements Waker {
    public static final int BUFFER_SIZE = (4 * 1024 * 1024);    // max size of serialised objects
    public static int EXTRA_TIME_ALOWED_WHEN_RECEIVING = 1000;  // extra second when data has started to be received

    private SocketChannel channel;
    private Selector selector;
    private SelectionKey selectionKey;
    private ByteBuffer buffer;
    private int nextObjectPosition;
    private boolean wakeupFlag;

    public ObjectPipe(SocketChannel channel) throws IOException {
        this.buffer = ByteBuffer.allocate(BUFFER_SIZE); // has a backing array
        this.buffer.position(0).limit(0);
        this.channel = channel;
        this.selector = Selector.open();
        channel.configureBlocking(false);
        channel.socket().setTcpNoDelay(true);
        this.selectionKey = channel.register(this.selector, SelectionKey.OP_READ);
        this.nextObjectPosition = 0;
        this.wakeupFlag = false;
    }

    public void wakeup() {
        this.wakeupFlag = true;
        this.selector.wakeup();
    }

    public void unsetWakeFlag() {
        this.wakeupFlag = false;
    }

    public void close() throws IOException {
        this.channel.socket().close();
    }

    public boolean isClosed() {
        return this.channel.socket().isClosed();
    }

    public void sendObject(Object object) throws IOException {
        if(this.buffer.hasRemaining() && this.buffer.position() != 0) {
            throw new RuntimeException("Buffer has data remaining from read operation - call receiveObject() first");
        }

        this.selectionKey.interestOps(SelectionKey.OP_WRITE);

        this.buffer.clear();
        this.buffer.putInt(0);
        int posBefore = this.buffer.position();
        try {
            ObjectOutputStream out = new ObjectOutputStream(new ByteBufferOutputStream(this.buffer));
            out.writeObject(object);
            out.close();
        } catch(BufferOverflowException e) {
            throw new RuntimeException("Serialised object too big to fit over ObjectPipe");
        }
        this.buffer.putInt(0, this.buffer.position());
        this.buffer.limit(this.buffer.position());
        this.buffer.position(0);
        while(this.buffer.hasRemaining()) {
            this.selector.select(4096);
            this.selector.selectedKeys().clear();
            this.channel.write(this.buffer);
        }
        this.buffer.position(0).limit(0);
    }

    public Object receiveObject(long timeout) throws IOException, ClassNotFoundException {
        long timeNow = System.currentTimeMillis();
        long requiredBy = timeNow + timeout;
        boolean allowedExtraTime = false;

        this.selectionKey.interestOps(SelectionKey.OP_READ);

        if(nextObjectPosition == 0) {
            // If there's nothing waiting in the buffer to be read (which could be the first bit of the next object
            // left over from a previous call) then clear it, so there's room to read data.
            // If nextObjectPosition == 0 then there can't be anything in the buffer because otherwise a timeout
            // would have been thrown on the previous call.
            this.buffer.clear();
        }

        while(true) {
            // See if there's anything ready to return -- before the select() in case we have the
            // entire next object in the buffer.
            if(this.buffer.position() >= (nextObjectPosition + 4)) {
                int currentFrameLength = this.buffer.getInt(nextObjectPosition);
                int currentReceivePosition = this.buffer.position();
                if((nextObjectPosition + currentFrameLength) <= currentReceivePosition) {
                    // Deserialise
                    this.buffer.position(nextObjectPosition);
                    this.buffer.getInt();
                    ObjectInputStream in = new ObjectInputStream(new ByteBufferInputStream(this.buffer));
                    Object r = in.readObject();
                    if(currentReceivePosition == (nextObjectPosition + currentFrameLength)) {
                        // Nothing left - so reset for possible write operation
                        nextObjectPosition = 0;
                        this.buffer.position(0).limit(0);
                    } else {
                        // Setup for next read
                        nextObjectPosition = currentFrameLength;
                        this.buffer.position(currentReceivePosition);
                    }
                    return r;
                }
            }

            int bytesRead = this.channel.read(this.buffer);
            if(bytesRead == -1) {
                throw new IOException("ObjectPipe closed");
            } else if(bytesRead == 0) {
                // If wakeup requested, return immediately
                if(this.wakeupFlag) {
                    this.wakeupFlag = false;
                    return null;
                }

                // If no bytes were read, check to see if the read has timed out
                if((bytesRead == 0) && (timeNow > requiredBy)) {
                    if(this.buffer.position() != 0) {
                        if(allowedExtraTime) {
                            throw new IOException("Timed out read operation in middle of receiving data.");
                        } else {
                            // If data has just started arriving at the very end of a timeout, allow a
                            // little more time for it to complete. But only once.
                            requiredBy += EXTRA_TIME_ALOWED_WHEN_RECEIVING;
                            allowedExtraTime = true;
                        }
                    } else {
                        return null;
                    }
                }
                // Wait for more data
                long selectTimeout = requiredBy - timeNow;
                if(selectTimeout < 1) {
                    selectTimeout = 1;
                }
                this.selector.select(selectTimeout);
                this.selector.selectedKeys().clear();
            }

            timeNow = System.currentTimeMillis();
        }
    }
}
