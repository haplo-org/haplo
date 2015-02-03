/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.op;

import java.io.Serializable;
import java.lang.reflect.Field;
import java.lang.reflect.Modifier;

import org.apache.log4j.Logger;

/**
 * Implements the concept of an operation to perform something, probably with
 * data from external sources. Interface is intended to make it easy to run it
 * in a separate process which has no access to data, and to kill the process if
 * a operation takes too long.
 */
public class Operation implements Serializable {
    private static OpQueuer defaultQueuer;
    private static ThreadLocal<Object> inWorkerThread = new ThreadLocal<Object>();

    public Operation() {
    }

    public static void markThreadAsWorker() {
        Operation.inWorkerThread.set(new Object());
    }

    public static void unmarkThreadAsWorker() {
        Operation.inWorkerThread.set(null);
    }    // for tests

    public static boolean isThreadMarkedAsWorker() {
        return Operation.inWorkerThread.get() != null;
    }

    public static void setDefaultQueuer(OpQueuer queuer) {
        Operation.defaultQueuer = queuer;
    }

    /**
     * Call to run the operation.
     */
    public void perform(OpQueuer queuer) throws Exception {
        if(queuer == null) {
            throw new RuntimeException("No queuer given");
        }

        WaitingNotifyTarget target = new WaitingNotifyTarget();
        synchronized(target) {
            // TODO: Timeouts for performing operations
            try {
                // Queue the operation inside the synchronized block so there's no chance of the
                // operation completing before the wait begins and the wait() never returning.
                queuer.queueOperation(this, target);
                target.wait();
            } catch(InterruptedException e) {
                // TODO: Strategy for interruptions
            }
        }
        if(target.exception != null) {
            throw target.exception;
        }
    }

    public void perform() throws Exception {
        if(Operation.defaultQueuer == null) {
            throw new RuntimeException("No default queuer set for operations");
        }
        perform(Operation.defaultQueuer);
    }

    public void performInBackground(OpQueuer queuer, OpNotifyTarget target) throws Exception {
        if(queuer == null) {
            throw new RuntimeException("No queuer given");
        }
        queuer.queueOperation(this, target);
    }

    public void performInBackground(OpNotifyTarget target) throws Exception {
        if(Operation.defaultQueuer == null) {
            throw new RuntimeException("No default queuer set for operations");
        }
        performInBackground(Operation.defaultQueuer, target);
    }

    /**
     * Allow an Operation to use another operation as a sub-operation,
     * performing it in the same process.
     */
    public void performOperationLocally() throws Exception {
        if(!Operation.isThreadMarkedAsWorker()) {
            throw new RuntimeException("Cannot performOperationLocally() outside a worker process");
        }
        performOperation();
    }

    /**
     * Operations implement this to do their work.
     */
    protected void performOperation() throws Exception {
    }

    /**
     * Operations implement this to do work in the main application process
     * before dispatch. May be called multiple times if the operation has to be
     * retried.
     */
    protected void beforeRemoteExecution() {
    }

    /**
     * If an exception is ignored by an operation, for example, a file format
     * conversion failed, then call this function to log it consistently.
     */
    protected void logIgnoredException(String reason, Exception e) {
        Logger logger = Logger.getLogger("com.oneis.op.ignored");
        logger.info("Ignored exception: " + reason, e);
    }

    /**
     * Override this for more efficient result copying from the Operation
     * returned from the worker process.
     *
     * Overriding required if the base class has fields which need copying over
     * -- only copies fields declared in the exact class.
     */
    protected void copyResultsFromReturnedOperation(Operation resultOperation) {
        Class resultClass = resultOperation.getClass();
        if(this.getClass() != resultClass) {
            throw new RuntimeException("Result operation is not of same type as the original operation");
        }
        try {
            Field[] fields = resultClass.getDeclaredFields();
            for(Field field : fields) {
                if((field.getModifiers() & (Modifier.STATIC | Modifier.FINAL)) == 0) {
                    field.setAccessible(true);
                    field.set(this, field.get(resultOperation));
                }
            }
        } catch(java.lang.IllegalAccessException e) {
            // Should never happen as classes are checked above
            throw new RuntimeException("Logic error: Unexpected IllegalAccessException thrown", e);
        }
    }

    // -------------------------------------------------------------------------------------------------------
    private static class WaitingNotifyTarget implements OpNotifyTarget {
        public Exception exception;

        public void notifyOperationComplete(Operation operation) {
            synchronized(this) {
                notify();
            }
        }

        public void notifyOperationException(Operation operation, Exception exception) {
            this.exception = exception;
            synchronized(this) {
                notify();
            }
        }
    }
}
