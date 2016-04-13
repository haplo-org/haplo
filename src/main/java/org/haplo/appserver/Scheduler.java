/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.appserver;

import java.util.Timer;
import java.util.TimerTask;
import java.util.Calendar;
import java.util.GregorianCalendar;
import java.util.TimeZone;

import org.apache.log4j.Logger;

import org.haplo.framework.Framework;

/**
 * A handy interface to java.util.Timer for the Ruby scheduled tasks.
 */
public class Scheduler {
    static private Timer timer;
    static private Framework framework;
    static private Logger logger;

    /**
     * Called by the Boot class to start the scheduler
     */
    static public void start(Framework framework) {
        Scheduler.timer = new Timer("org.haplo.appserver.scheduler");
        Scheduler.framework = framework;
        Scheduler.logger = Logger.getLogger("org.haplo.app.scheduler");
    }

    /**
     * Stops the scheduler
     */
    static public void stop() {
        if(timer != null) {
            timer.cancel();
        }
    }

    /**
     * Add a named task. The time of day is given as a reference point.
     *
     * @param Hour Hour of day
     * @param Minute Minute of hour which this task should first run
     * @param Period Period between invokations
     * @param TaskName Name of task, to be passed to framework
     */
    static public void add(int Hour, int Minute, int Period, String TaskName) {
        // Get the time now, in the GMT timezone
        TimeZone gmt = TimeZone.getTimeZone("GMT");
        GregorianCalendar now = new GregorianCalendar(gmt);

        // Make a new date with the time set to the given time, today.
        GregorianCalendar startDate = new GregorianCalendar(
                now.get(Calendar.YEAR), now.get(Calendar.MONTH), now.get(Calendar.DAY_OF_MONTH),
                Hour, Minute);
        startDate.setTimeZone(gmt);

        // Now move this date forward, until it's after now
        while(startDate.compareTo(now) < 0) {
            startDate.add(Calendar.SECOND, Period);
        }

        logger.info(String.format("Scheduler: Task %s is scheduled for first run at %tF %tT", TaskName, startDate, startDate));

        timer.scheduleAtFixedRate(
                new Task(TaskName),
                startDate.getTime(),
                Period * 1000 // seconds to ms
        );
    }

    static private class Task extends java.util.TimerTask {
        private String name;

        public Task(String name) {
            this.name = name;
        }

        public void run() {
            Scheduler.doTask(name);
        }
    }

    static public void doTask(String name) {
        logger.info("Running scheduled task: " + name);

        framework.scheduledTaskPerform(name);
    }
}
