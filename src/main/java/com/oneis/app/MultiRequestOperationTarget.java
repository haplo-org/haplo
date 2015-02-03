/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.app;

import java.util.ArrayList;

import org.eclipse.jetty.continuation.Continuation;

import com.oneis.op.Operation;
import com.oneis.op.OpNotifyTarget;

public class MultiRequestOperationTarget implements OpNotifyTarget {
    private boolean complete;
    private Exception exception;
    private ArrayList<Continuation> continuations;

    public MultiRequestOperationTarget() {
        this.complete = false;
        this.continuations = new ArrayList<Continuation>(4);
    }

    public boolean addContinuation(Continuation continuation) {
        synchronized(this) {
            if(this.complete) {
                return false;   // not added, because the operation is complete
            } else {
                this.continuations.add(continuation);
                return true;
            }
        }
    }

    public int numberOfContinuations() {
        synchronized(this) {
            return this.continuations.size();
        }
    }

    public synchronized boolean isComplete() {
        return this.complete;
    }

    public synchronized boolean wasSuccessful() {
        return (null == this.exception);
    }

    public synchronized Exception getException() {
        return this.exception;
    }

    public void notifyOperationComplete(Operation operation) {
        synchronized(this) {
            doCompletion();
        }
    }

    public void notifyOperationException(Operation operation, Exception exception) {
        synchronized(this) {
            this.exception = exception;
            doCompletion();
        }
    }

    private void doCompletion() {
        this.complete = true;
        int numContinuations = this.continuations.size();
        for(int i = 0; i < numContinuations; ++i) {
            Continuation continuation = this.continuations.get(i);
            if(continuation.isSuspended()) {
                continuation.resume();
            }
            // If this isn't the last continuation, sleep a tiny amount to stagger the requests resuming
            if(i < (numContinuations - 1)) {
                try {
                    Thread.sleep(1);
                } catch(InterruptedException interrupted) {
                }
            }
        }
    }
}
