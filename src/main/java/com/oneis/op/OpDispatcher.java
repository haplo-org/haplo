/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.op;

import java.util.ArrayList;
import java.lang.Class;

import org.apache.log4j.Logger;

public class OpDispatcher {
    private Policy policy;
    private OpWorkerSupervisor workerSupervisor;
    private Worker[] workers;
    private ArrayList<QueueEntry> queue;
    private Logger logger;

    public OpDispatcher(Policy policy) {
        this.policy = policy;
        this.workerSupervisor = null;
        this.workers = new Worker[this.policy.numberOfWorkers];
        for(int l = 0; l < this.workers.length; ++l) {
            this.workers[l] = new Worker(this, l);
        }
        this.queue = new ArrayList<QueueEntry>(16 /* initial array size */);
        this.logger = Logger.getLogger("com.oneis.op.dispatcher");
    }

    public Policy getPolicy() {
        return this.policy;
    }

    public void useSupervisor(OpWorkerSupervisor workerSupervisor) {
        this.workerSupervisor = workerSupervisor;
        this.workerSupervisor.startSupervision(this.policy);
    }

    // -----------------------------------------------------------------------------------------
    public void queueOperation(Operation operation, long applicationId, OpNotifyTarget notifyTarget) {
        QueueEntry entry = new QueueEntry();
        entry.operation = operation;
        entry.applicationId = applicationId;
        entry.notifyTarget = notifyTarget;

        synchronized(this) {
            if(queue.size() >= this.policy.maxQueueLength) {
                this.logger.error("OpDispatcher queue length exceeded");
                throw new RuntimeException("Queue length exceeded");
            }

            addQueueEntryWithoutSynchronization(entry, QueueAdditionAction.QUEUE_NORMAL);
        }

        this.logger.info("Queued for app " + applicationId + ": " + operation);
    }

    // -----------------------------------------------------------------------------------------
    public Worker workerConnected(int workerNumber) {
        Worker worker = null;
        synchronized(this) {
            if(workerNumber < 0 || workerNumber > this.workers.length || this.workers[workerNumber].connected) {
                throw new RuntimeException("Bad worker number or already connected on worker connection.");
            }
            worker = this.workers[workerNumber];
            worker.connected = true;
        }
        this.logger.info("Worker connected: " + workerNumber);
        return worker;
    }

    public void workerDisconnected(Worker worker) {
        synchronized(this) {
            checkWorkerWithoutSynchronization(worker, null);
            disconnectWorkerWithoutSynchronization(worker);
        }
        this.logger.info("Worker disconnected: " + worker.workerNumber);
    }

    // Clean up after a worker terminates a connection, by error or otherwise
    public void workerCleanupConnection(Worker worker) {
        boolean found = false;
        synchronized(this) {
            for(int l = 0; l < this.workers.length; ++l) {
                if(worker == this.workers[l]) {
                    found = true;
                    break;
                }
            }
            if(found) {
                disconnectWorkerWithoutSynchronization(worker);
            }
        }
        if(found) {
            this.logger.info("Cleaned up worker connection: " + worker.workerNumber);
        } else {
            this.logger.info("No cleanup needed for given worker connection: " + worker.workerNumber);
        }
    }

    protected Operation getNextWorkForWorker(Worker worker) {
        Operation nextWork = null;

        synchronized(this) {
            checkWorkerWithoutSynchronization(worker, null);
            if(worker.currentWork != null) {
                throw new RuntimeException("Logic error: Already working");
            }

            for(int i = 0; i < this.queue.size(); ++i) {
                QueueEntry possible = this.queue.get(i);

                int countForApp = 0;
                for(int w = 0; w < this.workers.length; ++w) {
                    Worker ww = this.workers[w];
                    if(ww.currentWork != null && ww.currentWork.applicationId == possible.applicationId) {
                        countForApp++;
                    }
                }

                // Choose this operation if the max ops per application policy wouldn't be exceeded
                if(countForApp < this.policy.maxOpsPerApplication) {
                    this.queue.remove(i);
                    worker.currentWork = possible;
                    nextWork = possible.operation;
                    possible.startTime = System.currentTimeMillis();

                    // Make sure the wake flag isn't set for this worker *in the synchronized block*,
                    // otherwise if the worker doesn't have to wait, the wait flag will be set when
                    // waiting for the ack from the worker. This would cause it to be timed out and
                    // the worker failed.
                    worker.unsetWakeFlag();

                    break;
                }
            }
        }

        if(nextWork != null) {
            try {
                nextWork.beforeRemoteExecution();
            } catch(Exception exception) {
                this.logger.error("Exception when performing beforeRemoteExecution() for op " + nextWork, exception);
                // Route the exception through the normal process
                workerFinishedWork(worker, nextWork, null, exception, WorkerState.OK /* don't fail worker, it was never called */);
                // Get the next operation instead, as the failed operation can't be returned
                // Just returning null might mean an unnecessary wait for work.
                nextWork = getNextWorkForWorker(worker);
            }
        }

        if(nextWork != null) {
            this.logger.info("Next operation for worker " + worker.workerNumber + " is " + nextWork);
        }

        return nextWork;
    }

    protected void workerReturnWork(Worker worker, Operation operation, WorkerState workerState) {
        synchronized(this) {
            checkWorkerWithoutSynchronization(worker, operation);

            QueueEntry returned = worker.currentWork;
            worker.currentWork = null;

            workerState.handleStateWithoutSynchronization(this, worker);

            addQueueEntryWithoutSynchronization(returned, QueueAdditionAction.QUEUE_RETURNED);
        }
        this.logger.info("Worker " + worker.workerNumber + " failed, and returned op " + operation);
    }

    // Call with either a result or an exception, but not both.
    protected void workerFinishedWork(Worker worker, Operation operation, Operation result, Exception exception, WorkerState workerState) {
        QueueEntry performed;

        if(result != null && exception != null) {
            throw new RuntimeException("Logic error: No result and no exception");
        }
        if(result == null && exception == null) {
            throw new RuntimeException("Logic error: Result and an exception at the same time");
        }

        synchronized(this) {
            checkWorkerWithoutSynchronization(worker, operation);
            if(worker.currentWork == null || worker.currentWork.operation != operation) {
                throw new RuntimeException("Logic error: Wrong operation returned");
            }

            if(result != null) {
                try {
                    worker.currentWork.operation.copyResultsFromReturnedOperation(result);
                } catch(Exception e) {
                    // Report this exception instead
                    result = null;
                    exception = e;
                }
            }

            performed = worker.currentWork;
            worker.currentWork = null;

            workerState.handleStateWithoutSynchronization(this, worker);
        }

        long timeTaken = System.currentTimeMillis() - performed.startTime;
        if(exception != null) {
            this.logger.info("Operation on worker " + worker.workerNumber + " took " + timeTaken + "ms and threw exception, op: " + operation);
        } else {
            this.logger.info("Operation finished on worker " + worker.workerNumber + ", took " + timeTaken + "ms for op: " + operation);
        }

        // Notify outside of the lock to avoid deadlocks
        if(result != null) {
            performed.notifyTarget.notifyOperationComplete(performed.operation);
        } else {
            performed.notifyTarget.notifyOperationException(performed.operation, exception);
        }
    }

    // -----------------------------------------------------------------------------------------
    public static class Policy {
        final static public int DEFAULT_WORKERS = 4;
        final static public int DEFAULT_MAX_OPS_PER_APP = 2;
        final static public int DEFAULT_MAX_QUEUE_LENGTH = 512;

        public int numberOfWorkers;
        public int maxOpsPerApplication;
        public int maxQueueLength;

        public Policy() {
            this.numberOfWorkers = DEFAULT_WORKERS;
            this.maxOpsPerApplication = DEFAULT_MAX_OPS_PER_APP;
            this.maxQueueLength = DEFAULT_MAX_QUEUE_LENGTH;
        }
    }

    // -----------------------------------------------------------------------------------------
    private static class QueueEntry {
        public Operation operation;
        public long applicationId;
        public OpNotifyTarget notifyTarget;
        public long startTime;
    }

    // -----------------------------------------------------------------------------------------
    public enum WorkerState {
        OK() {
                    public void handleStateWithoutSynchronization(OpDispatcher dispatcher, Worker worker) {
                    }
                },
        FAILED() {
                    public void handleStateWithoutSynchronization(OpDispatcher dispatcher, Worker worker) {
                        dispatcher.disconnectAndMarkWorkerFailedWithoutSynchronization(worker);
                    }
                },
        DISCONNECTING() {
                    public void handleStateWithoutSynchronization(OpDispatcher dispatcher, Worker worker) {
                        dispatcher.disconnectWorkerWithoutSynchronization(worker);
                    }
                };

        // Enum values know how to handle themselves
        public abstract void handleStateWithoutSynchronization(OpDispatcher dispatcher, Worker worker);
    }

    // -----------------------------------------------------------------------------------------
    public static class Worker {
        private OpDispatcher dispatcher;
        private int workerNumber;
        private boolean connected;
        private boolean failed;
        private QueueEntry currentWork;
        private Waker waker;

        protected Worker(OpDispatcher dispatcher, int workerNumber) {
            this.dispatcher = dispatcher;
            this.workerNumber = workerNumber;
            this.connected = false;
            this.failed = false;
        }

        protected void wake() {
            if(this.waker != null) {
                this.waker.wakeup();
            }
        }

        protected void unsetWakeFlag() {
            if(this.waker != null) {
                this.waker.unsetWakeFlag();
            }
        }

        // -----------------------------------------------------------------------------------------
        public void setWaker(Waker waker) {
            this.waker = waker;
        }

        public Operation getNextWork() {
            return this.dispatcher.getNextWorkForWorker(this);
        }

        public boolean isConnected() {
            return this.connected;
        }

        public boolean isFailed() {
            return this.failed;
        }

        // Called if the worker process doesn't acknowledge recipet of the operation
        public void returnWork(Operation operation, WorkerState workerState) {
            this.dispatcher.workerReturnWork(this, operation, workerState);
        }

        public void finishedWork(Operation operation, Operation result, Exception exception, WorkerState workerState) {
            this.dispatcher.workerFinishedWork(this, operation, result, exception, workerState);
        }
    }

    // -----------------------------------------------------------------------------------------
    private enum QueueAdditionAction {
        QUEUE_NORMAL, QUEUE_RETURNED
    }

    // Must be called in a synchronized(this) block.
    private void addQueueEntryWithoutSynchronization(QueueEntry entry, QueueAdditionAction action) {
        if(action == QueueAdditionAction.QUEUE_NORMAL) {
            // TODO: Priority ordering of operations based on predicted speed of running
            this.queue.add(entry);
        } else {
            this.queue.add(0, entry);
        }

        // This op may not be runnable yet because of the limit on number of ops per application outstanding,
        // but just wake the lowest numbered connected worker which isn't doing anything.
        for(int l = 0; l < this.workers.length; ++l) {
            Worker worker = this.workers[l];
            if(worker.connected && worker.currentWork == null) {
                worker.wake();
                break;
            }
        }
    }

    private void disconnectWorkerWithoutSynchronization(Worker worker) {
        if(!worker.connected) {
            throw new RuntimeException("Worker isn't connected.");
        }
        if(worker.currentWork != null) {
            throw new RuntimeException("Worker has outstanding work when disconnecting.");
        }
        // Instead of just doing worker.connected = false, replace the Worker object in the list
        // to invalidate the current Worker object completely.
        worker.connected = false;
        this.workers[worker.workerNumber] = new Worker(this, worker.workerNumber);
    }

    private void disconnectAndMarkWorkerFailedWithoutSynchronization(Worker worker) {
        disconnectWorkerWithoutSynchronization(worker);

        worker.failed = true;

        // Tell the supervisor that the process failed to get it restarted.
        if(this.workerSupervisor != null) {
            this.workerSupervisor.workerFailed(worker.workerNumber);
        }
    }

    private void checkWorkerWithoutSynchronization(Worker worker, Operation operation) {
        boolean found = false;
        for(int l = 0; l < this.workers.length; ++l) {
            if(worker == this.workers[l]) {
                found = true;
                break;
            }
        }
        if(!found) {
            throw new RuntimeException("Logic error: Worker isn't part of this dispatcher");
        }
        if(operation != null) {
            if(worker.currentWork == null || worker.currentWork.operation != operation) {
                throw new RuntimeException("Logic error: Worker isn't running the expected operation");
            }
        }
    }
}
