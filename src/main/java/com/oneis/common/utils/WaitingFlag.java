/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.common.utils;

/**
 * Underlying implementation for signalling worker threads.
 */
public class WaitingFlag {
    private boolean flagged;

    /**
     * Constructor
     */
    public WaitingFlag() {
        flagged = false;
    }

    /**
     * Is the flag currently flagged?
     */
    public synchronized boolean isFlagged() {
        return flagged;
    }

    /**
     * Set the flag, potentially releasing worker threads.
     */
    public synchronized void setFlag() {
        flagged = true;
        notify();
    }

    /**
     * Clear the flag. Will have no immediate effect on anything waiting on this
     * flag.
     */
    public synchronized void clearFlag() {
        flagged = false;
    }

    /**
     * Wait for the flag to be set. If the flag status is critical, the return
     * value should be checked.
     *
     * @param timeout Maximum amount of time to wait, in ms
     *
     * @return Flag status (false if not flagged)
     */
    public synchronized boolean waitForFlag(long timeout) {
        if(flagged) {
            flagged = false;
            return true;
        }

        try {
            wait(timeout);
        } catch(java.lang.InterruptedException e) {
            // Ignore
        }

        boolean wasFlagged = flagged;
        flagged = false;
        return wasFlagged;
    }

    /**
     * Wake all the waiting threads.
     */
    public synchronized void wakeAllWaiting() {
        notifyAll();
    }
}
