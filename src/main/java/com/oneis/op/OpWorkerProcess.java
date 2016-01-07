/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.op;

import java.nio.channels.SocketChannel;
import java.net.ConnectException;
import java.net.InetSocketAddress;
import java.io.IOException;

import org.apache.log4j.Logger;

import com.oneis.utils.ProcessStartupFlag;

public class OpWorkerProcess extends Thread {
    static final private int CONNECTION_ATTEMPTS = 20;   // will retry this number of times with 1 second pauses between
    static final private int RESTART_IF_MEMORY_USAGE_INCREASES_BY = 32; // in percent
    // TODO: Reduce RESTART_IF_MEMORY_USAGE_OVER, and implement another limit that, if exceeded, the op worker restarts after 5 minutes of being idle.

    static public boolean restartOnHighMemoryUsage = true;

    private int workerNumber;
    private String authenticationToken;
    private Logger logger;

    public OpWorkerProcess(int workerNumber, String authenticationToken) {
        this.workerNumber = workerNumber;
        this.authenticationToken = authenticationToken;
        this.logger = Logger.getLogger("com.oneis.op.worker.w" + workerNumber);
    }

    // --------------------------------------------------------------------------------
    public static void main(String argv[]) {
        // TODO: Read worker number and authentication token from configuration file (avoids confidential info in ps listing)
        OpWorkerProcess process = new OpWorkerProcess(Integer.parseInt(argv[0]), "TODO-AUTH-TOKEN");
        process.start();

        // Let the startup utility know everything is running
        ProcessStartupFlag.processIsReady();

        try {
            process.join();
        } catch(InterruptedException e) {
            // Ignore
        }

        process.logger.info("Worker process exiting.");
    }

    // --------------------------------------------------------------------------------
    public void run() {
        this.logger.info("Starting...");
        Operation.markThreadAsWorker(); // so "performOperationLocally" sub-processes work
        try {
            run2();
        } catch(Exception e) {
            this.logger.error("Exception in worker thread", e);
        }
        // Just exit the process and let it be restarted by external supervisor
    }

    public void run2() throws IOException, ClassNotFoundException {
        SocketChannel socketChannel = null;
        int connectionAttempts = CONNECTION_ATTEMPTS;
        while(socketChannel == null) {
            try {
                socketChannel = SocketChannel.open(new InetSocketAddress(OpDispatchServer.getListeningAddress(), OpDispatchServer.DEFAULT_PORT));
            } catch(ConnectException e) {
                if((connectionAttempts--) > 0) {
                    // Pause before retry
                    this.logger.info("Failed connection attempt, " + connectionAttempts + " retries left.");
                    try {
                        Thread.sleep(1000);
                    } catch(InterruptedException interrupted) {
                    }
                } else {
                    throw e; // connection attempts exceeded
                }
            }
        }
        this.logger.info("Connected.");
        ObjectPipe pipe = new ObjectPipe(socketChannel);

        // Send auth info to server
        OpServerMessage.Authenticate auth = new OpServerMessage.Authenticate();
        auth.workerNumber = this.workerNumber;
        auth.authenticationToken = this.authenticationToken;
        pipe.sendObject(auth);

        // Only continue if the server liked the response
        OpServerMessage.AuthenticateAccepted authAccepted = (OpServerMessage.AuthenticateAccepted)pipe.receiveObject(1000);
        if(authAccepted == null || !authAccepted.accepted) {
            this.logger.error("Authentication wasn't accepted.");
            pipe.close();
            return;
        }
        this.logger.info("Authenticated with server, waiting for operations.");
        int initialMemoryUsage = approxMemoryUsagePercent();
        int restartWhenMemoryUsageOver = initialMemoryUsage + RESTART_IF_MEMORY_USAGE_INCREASES_BY;
        this.logger.info("Approx initial memory usage: " + initialMemoryUsage + "%, will restart when memory usage over " + restartWhenMemoryUsageOver + "%");

        while(true) {
            OpServerMessage.DoOperation doOperation = (OpServerMessage.DoOperation)pipe.receiveObject(1000 * 60 * 5);
            if(doOperation != null) {
                // Immediately send an "ack" message back to the server so it knows the operation has been recieved,
                // processing is started, and doesn't need to return it to the queue.
                OpServerMessage.AcknowledgeOperation acknowledgeOperation = new OpServerMessage.AcknowledgeOperation();
                acknowledgeOperation.ok = true;
                pipe.sendObject(acknowledgeOperation);

                OpServerMessage.DoneOperation doneOperation = new OpServerMessage.DoneOperation();
                doneOperation.willExit = false;
                try {
                    this.logger.info("Start operation: " + doOperation.operation);

                    doOperation.operation.performOperation();
                    doneOperation.resultOperation = doOperation.operation;
                } catch(Exception e) {
                    this.logger.error("Exception performing operation: " + doOperation.operation, e);
                    doneOperation.resultException = e;
                }

                // Check memory usage
                int memoryPercent = approxMemoryUsagePercent();
                this.logger.info("Approx memory usage after operation: " + memoryPercent + "%");
                if((memoryPercent > restartWhenMemoryUsageOver) && restartOnHighMemoryUsage) {
                    this.logger.info("Will exit after sending reply.");
                    doneOperation.willExit = true;
                }

                this.logger.info("Sending reply.");
                pipe.sendObject(doneOperation);

                if(doneOperation.willExit) {
                    // Wait a small amount of time then exit
                    try {
                        Thread.sleep(250);
                    } catch(InterruptedException interrupted) {
                    }
                    return;
                }
            }
        }
    }

    protected int approxMemoryUsagePercent() {
        Runtime runtime = Runtime.getRuntime();
        return (int)((runtime.totalMemory() * 100) / runtime.maxMemory());
    }
}
