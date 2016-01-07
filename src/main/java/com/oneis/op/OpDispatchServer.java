/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.op;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.UnknownHostException;
import java.nio.channels.Selector;
import java.nio.channels.ServerSocketChannel;
import java.nio.channels.SocketChannel;
import java.nio.channels.SelectionKey;
import java.io.IOException;

import org.apache.log4j.Logger;

public class OpDispatchServer extends Thread {
    static final public int DEFAULT_PORT = 1888;

    // How long to give a worker process to respond to a message -- as it's on the local machine it should be
    // able to respond very quickly if it's healthy.
    static final public int MAX_TIME_TO_ACKNOWLEDGE_OPERATION = 500;

    // How long to wait for an operation to execute on the remote worker process.
    static final public int MAX_TIME_TO_WAIT_FOR_OPERATION = 60 * 1000;

    private int port;
    private OpDispatcher dispatcher;
    private Logger logger;

    public OpDispatchServer(OpDispatcher dispatcher, int port) {
        this.dispatcher = dispatcher;
        this.port = port;
        this.logger = Logger.getLogger("com.oneis.op.server");
    }

    public OpDispatchServer(OpDispatcher dispatcher) {
        this(dispatcher, DEFAULT_PORT);
    }

    static public InetAddress getListeningAddress() {
        try {
            return InetAddress.getByName("127.0.0.1");
        } catch(UnknownHostException hostException) {
            throw new RuntimeException("Couldn't look up localhost", hostException);
        }
    }

    // --------------------------------------------------------------------------------
    public void run() {
        this.setName("OpDispatchServer");

        try {
            Selector selector = Selector.open();
            ServerSocketChannel server = ServerSocketChannel.open();
            server.socket().bind(new InetSocketAddress(getListeningAddress(), this.port), 16);
            server.configureBlocking(false);
            server.register(selector, SelectionKey.OP_ACCEPT);

            this.logger.info("OpDispatchServer: listening for incoming connections.");

            // TODO: Nice shutdown code for OpDispatchServer, and handling exceptions and timeouts nicely
            while(true) {
                selector.select();
                selector.selectedKeys().clear();
                SocketChannel incomingConnection = server.accept();
                if(incomingConnection != null) {
                    this.logger.info("Accepted incoming connection.");
                    Connection thread = new Connection(incomingConnection, this.dispatcher);
                    thread.start();
                }
            }
        } catch(IOException e) {
            // TODO: Handle IOException in main server loop
        }
    }

    // --------------------------------------------------------------------------------
    static private class Connection extends Thread {
        private OpDispatcher dispatcher;
        private OpDispatcher.Worker worker;
        private ObjectPipe pipe;
        private Logger logger;

        public Connection(SocketChannel socketChannel, OpDispatcher dispatcher) throws IOException {
            this.pipe = new ObjectPipe(socketChannel);
            this.dispatcher = dispatcher;
            this.logger = Logger.getLogger("com.oneis.op.server");
        }

        public void run() {
            try {
                run2();
            } catch(Exception e) {
                // TODO: What to do about general exceptions in OpDispatchServer threads?
                this.logger.error("Exception in OpDispatchServer worker thread", e);
            }

            try {
                if(!this.pipe.isClosed()) {
                    this.pipe.close();
                }
            } catch(Exception e) {
                this.logger.error("Exception closing pipe after OpDispatchServer worker thread", e);
            }

            if(this.worker != null) {
                this.dispatcher.workerCleanupConnection(this.worker);
            }
        }

        private void run2() throws IOException, ClassNotFoundException {
            this.setName("OpDispatchServer.Connection-waiting");
            this.logger.info("Waiting for authentication on thread " + getId());

            // Get the info object (exceptions if wrong thing recieved)
            OpServerMessage.Authenticate auth = (OpServerMessage.Authenticate)pipe.receiveObject(2000); // two seconds to authenticate
            if(auth == null) {
                throw new RuntimeException("Worker process didn't send authentication message in time.");
            }
            // TODO: Check authenticateToken
            this.setName("OpDispatchServer.Connection-" + auth.workerNumber);
            this.logger = Logger.getLogger("com.oneis.op.server.c" + auth.workerNumber);
            this.logger.info("Connection on thread " + getId() + " authenticated as " + auth.workerNumber);
            this.worker = this.dispatcher.workerConnected(auth.workerNumber);

            // Use the ObjectPipe as the waker for this worker, so we can use the ObjectPipe for waiting
            // so socket disconnects are noticed.
            this.worker.setWaker(this.pipe);

            // Notify the worker that authentication was accepted
            OpServerMessage.AuthenticateAccepted authAccepted = new OpServerMessage.AuthenticateAccepted();
            authAccepted.accepted = true;
            this.pipe.sendObject(authAccepted);

            while(true) {
                Operation operation = this.worker.getNextWork();

                if(operation == null) {
                    // Wait at least 20 seconds for work. Use the worker number to stagger the checks a little.
                    // Use the ObjectPipe for waking so that disconnections will wake up the process and throw an exception.
                    Object nothing = this.pipe.receiveObject((10 + auth.workerNumber) * 2000);
                    if(nothing != null) {
                        this.logger.error("Worker process didn't follow protocol -- unexpected object when waiting");
                        throw new RuntimeException("Worker process didn't follow protocol");
                    }
                } else {
                    this.logger.info("Dispatch op: " + operation);

                    boolean operationSentOk = false;
                    try {
                        OpServerMessage.DoOperation doOperation = new OpServerMessage.DoOperation();
                        doOperation.operation = operation;
                        this.pipe.sendObject(doOperation);

                        // Worker process must respond reasonably quickly to say it's got the operation and intends
                        // to start processing it.
                        OpServerMessage.AcknowledgeOperation acknowledgeOperation
                                = (OpServerMessage.AcknowledgeOperation)this.pipe.receiveObject(MAX_TIME_TO_ACKNOWLEDGE_OPERATION);
                        if(acknowledgeOperation != null) {
                            operationSentOk = acknowledgeOperation.ok;
                        } else {
                            this.logger.error("Didn't receive ack message from worker process within limit of " + MAX_TIME_TO_ACKNOWLEDGE_OPERATION + "ms");
                            // Don't throw or return: cleanup happens next
                        }
                    } catch(Exception e) {
                        this.logger.error("Exception when sending message to worker process", e);
                        // Don't throw or return: cleanup happens next
                    }

                    // If it can't be verified that the worker process got the operation, give up on the worker
                    // and requeue the operation.
                    if(!operationSentOk) {
                        this.worker.returnWork(operation, OpDispatcher.WorkerState.FAILED);
                        return;
                    }

                    // Wait for the operation to complete, sending a timeout exception & marking the worker as failed
                    // if it takes too long or the worker disconnects.
                    OpServerMessage.DoneOperation doneOperation = null;
                    Exception operationException = null;
                    try {
                        doneOperation = (OpServerMessage.DoneOperation)this.pipe.receiveObject(MAX_TIME_TO_WAIT_FOR_OPERATION);
                    } catch(Exception e) {
                        this.logger.error("Exception when waiting for operation reply", e);
                        operationException = e;
                    }

                    if(doneOperation == null) {
                        this.logger.error("Timed out waiting for the operation done response from worker");
                        operationException = new OperationTimeoutException(operation, "Operation timed out");
                    }
                    if(operationException != null) {
                        this.worker.finishedWork(operation, null, operationException, OpDispatcher.WorkerState.FAILED);
                        return;
                    }

                    this.logger.info("Got reply for: " + operation);
                    this.worker.finishedWork(operation, doneOperation.resultOperation, doneOperation.resultException,
                            doneOperation.willExit ? OpDispatcher.WorkerState.DISCONNECTING : OpDispatcher.WorkerState.OK);

                    // If the worker has signalled its intent to exit, exit now.
                    if(doneOperation.willExit) {
                        this.logger.info("Worker process intends to exit now, finishing.");
                        return;
                    }
                }
            }
        }
    }
}
