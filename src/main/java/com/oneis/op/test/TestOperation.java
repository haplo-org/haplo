/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.op.test;

import com.oneis.op.Operation;

// A very simple operation used for testing
public class TestOperation extends Operation {
    public String string;
    public int useMemory;   // in Kbytes
    public int sleepSeconds;
    public boolean throwException;
    public boolean callExit;
    public boolean infiniteLoop;

    public TestOperation(String string) {
        this.string = string;
        this.useMemory = 0;
        this.sleepSeconds = 0;
        this.throwException = false;
        this.callExit = false;
        this.infiniteLoop = false;
    }

    protected void performOperation() throws Exception {
        if(this.useMemory > 0) {
            // Allocate and use a load of memory, but in small chunks on the heap, and make
            // sure they're not garbage collected by making sure there's always a reference
            // either in a static var or in another leak object.
            for(int b = 0; b < this.useMemory; ++b) {
                leakRoot = new MemoryLeak(leakRoot);
            }
        }
        if(this.sleepSeconds > 0) {
            try {
                Thread.sleep(this.sleepSeconds * 1000);
            } catch(InterruptedException e) {
            }
        }
        if(this.throwException) {
            throw new TestOpException("Test exception from " + this.string);
        }
        if(this.callExit) {
            System.exit(0);
        }
        if(this.infiniteLoop) {
            byte[] bytes = new byte[16 * 1024];
            while(true) {
                for(int l = 0; l < bytes.length; ++l) {
                    bytes[l] = (byte)(((bytes[(l + 1) % 256] * 2) + 1) % 256);
                }
            }
        }
        this.string = "COMPLETE: " + this.string;
    }

    public String toString() {
        return "TestOperation@" + Integer.toHexString(hashCode()) + " string=" + string;
    }

    static private MemoryLeak leakRoot;

    static private class MemoryLeak {
        private MemoryLeak next;
        private byte[] memory;

        public MemoryLeak(MemoryLeak next) {
            this.next = next;
            this.memory = new byte[1024];
            for(int i = 0; i < 1024; ++i) {
                this.memory[i] = 1;   // write to make sure it's allocated
            }
        }
    }

    static public class TestOpException extends Exception {
        public TestOpException(String message) {
            super(message);
        }
    }
}
