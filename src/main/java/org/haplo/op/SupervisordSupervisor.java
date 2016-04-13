/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

/*
 * This is a worker supervisor, using supervisord
 */

package org.haplo.op;

import java.io.IOException;
import org.apache.log4j.Logger;

public class SupervisordSupervisor implements OpWorkerSupervisor {

    private static final String SUPERVISORD = "/usr/bin/supervisord";
    private static final String SUPERVISORCTL = "/usr/bin/supervisorctl";
    private static final String SUPERVISORD_CONF="/opt/haplo/config/haplo-supervisord.conf";
    private static boolean supervising = false;

    private Logger logger;

    public SupervisordSupervisor() {
        this.logger = Logger.getLogger("org.haplo.op.supervisor");
    }

    public void startSupervision(OpDispatcher.Policy policy) {
        this.logger.info("Starting supervisord supervision of " + policy.numberOfWorkers + " workers.");
	startWorkers();
    }

    public void workerFailed(int workerNumber) {
        this.logger.info("Worker instance " + workerNumber + " failed, initiating restart.");
	restartWorker(workerNumber);
    }

    private void startWorkers() {
	if (!supervising) {
	    try {
		Process p = Runtime.getRuntime().exec(SUPERVISORD + " -c " + SUPERVISORD_CONF);
	    } catch (IOException ioe) {}
	    supervising = true;
	    Runtime.getRuntime().addShutdownHook(new ShutdownHook(this));
	}
    }

    public void stopWorkers() {
	try {
	    Process p = Runtime.getRuntime().exec(SUPERVISORCTL + " -c " + SUPERVISORD_CONF + " shutdown");
	} catch (IOException ioe) {}
	supervising = false;
    }

    private void restartWorker(int workerNumber) {
	try {
	    Process p = Runtime.getRuntime().exec(SUPERVISORCTL + " -c " + SUPERVISORD_CONF + " restart w" + workerNumber);
	} catch (IOException ioe) {}
    }

    static class ShutdownHook extends Thread {
        private SupervisordSupervisor ssupervisor;

        public ShutdownHook(SupervisordSupervisor ssupervisor) {
            this.ssupervisor = ssupervisor;
        }

        public void run() {
            try {
                ssupervisor.stopWorkers();
            } catch(Exception e) {
                Logger.getLogger("org.haplo.app").error("Caught exception while shutting down " + e.toString());
            }
        }
    }
}
