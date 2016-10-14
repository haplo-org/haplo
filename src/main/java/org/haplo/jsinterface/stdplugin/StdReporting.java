/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.stdplugin;

import org.haplo.common.utils.WaitingFlag;

import org.mozilla.javascript.ScriptableObject;

import java.util.HashSet;


public class StdReporting extends ScriptableObject {
    private static boolean shouldStopUpdating = false;
    private static Object applicationsWithUpdatesLock = new Object();
    private static HashSet<Integer> applicationsWithUpdates = new HashSet<Integer>(16);
    private static WaitingFlag waitForUpdatesFlag = new WaitingFlag();

    public StdReporting() {
    }

    public String getClassName() {
        return "$StdReporting";
    }

    public static void jsStaticFunction_signalUpdatesRequired() {
        Integer appId = rubyInterface.getCurrentApplicationId();
        synchronized(applicationsWithUpdatesLock) {
            applicationsWithUpdates.add(appId);
        }
        waitForUpdatesFlag.setFlag();
    }

    public static boolean jsStaticFunction_shouldStopUpdating() {
        return shouldStopUpdating;
    }

    // ----------------------------------------------------------------------

    // Returns the set of applications needing updates, and resets the list atomically
    public static HashSet<Integer> getApplicationsWithUpdatesAndReset() {
        synchronized(applicationsWithUpdatesLock) {
            HashSet<Integer> r = applicationsWithUpdates;
            applicationsWithUpdates = new HashSet<Integer>(16);
            return r;
        }
    }

    // Stop the JS thread updating when the server is shutting down
    public static void setShouldStopUpdating() {
        shouldStopUpdating = true;
        waitForUpdatesFlag.setFlag();   // wake up background thread
    }

    public static boolean shouldRunUpdates() {
        return !shouldStopUpdating;
    }

    public static void waitForUpdates(int timeoutInSeconds) {
        waitForUpdatesFlag.waitForFlag(timeoutInSeconds * 1000);
    }

    // ----------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        Integer getCurrentApplicationId();
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }
}
