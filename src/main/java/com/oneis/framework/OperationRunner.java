/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.framework;

import org.apache.log4j.Logger;

import com.oneis.op.Operation;
import com.oneis.op.OpDispatcher;
import com.oneis.op.OpNotifyTarget;
import com.oneis.op.OpQueuer;
import com.oneis.op.OpDispatchServer;
import com.oneis.op.OpWorkerProcess;
import com.oneis.op.OpWorkerSupervisor;
import com.oneis.op.SupervisordSupervisor;

public class OperationRunner {
    private static OpDispatcher dispatcher;
    private static OpDispatchServer dispatchServer;
    private static Framework framework;

    static void start(Framework framework, boolean productionEnvironment) {
        // Framework object is needed to determine which app is active when queueing an Operation.
        OperationRunner.framework = framework;

        OpDispatcher.Policy defaultPolicy = new OpDispatcher.Policy();
        OperationRunner.dispatcher = new OpDispatcher(defaultPolicy);

        OperationRunner.dispatchServer = new OpDispatchServer(OperationRunner.dispatcher);
        OperationRunner.dispatchServer.start();

        Operation.setDefaultQueuer(new DefaultQueuer());

        // Use supervisord in production mode only
        if(productionEnvironment) {
	    OperationRunner.dispatcher.useSupervisor(new SupervisordSupervisor());
        }
    }

    static class DefaultQueuer implements OpQueuer {
        public void queueOperation(Operation operation, OpNotifyTarget notifyTarget) {
            dispatcher.queueOperation(operation, framework.getCurrentApplicationId(), notifyTarget);
        }
    }

    // -------------------------------------------------------------------------------------------------------
    // For test/development use only -- run workers in the same process for convenience
    static public void startTestInProcessWorkers() {
        String disableRunners = System.getenv("DISABLE_IN_PROCESS_WORKERS");
        if(disableRunners != null && disableRunners.equals("yes")) {
            Logger.getLogger("com.oneis.testing").info("Not running in-process operation workers because environment variable DISABLE_IN_PROCESS_WORKERS=yes");
            return;
        }
        OperationRunner.dispatcher.useSupervisor(new TestInProcessWorkerSupervisor());
        // Don't let operation runners restart on low memory usage, as that would break things.
        OpWorkerProcess.restartOnHighMemoryUsage = false;
    }

    static private class TestInProcessWorkerSupervisor implements OpWorkerSupervisor {
        private OpWorkerProcess processes[];
        private Logger logger;

        public TestInProcessWorkerSupervisor() {
            this.logger = Logger.getLogger("com.oneis.testopsupervisor");
        }

        public void startSupervision(OpDispatcher.Policy policy) {
            this.logger.info("Starting supervision of in process operation workers");
            this.processes = new OpWorkerProcess[policy.numberOfWorkers];
            for(int workerNumber = 0; workerNumber < this.processes.length; ++workerNumber) {
                this.processes[workerNumber] = new OpWorkerProcess(workerNumber, "TODO-AUTH-TOKEN");
                this.processes[workerNumber].start();
            }
        }

        public void workerFailed(int workerNumber) {
            this.logger.info("Failing in process worker " + workerNumber);
            // Interrupt old
            this.processes[workerNumber].interrupt();
            // Start new
            this.processes[workerNumber] = new OpWorkerProcess(workerNumber, "TODO-AUTH-TOKEN");
            this.processes[workerNumber].start();
        }
    }
}
