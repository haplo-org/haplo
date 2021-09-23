/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2021            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.javascript.debugger;

import java.util.HashMap;

import org.mozilla.javascript.debug.Debugger;


public class Debug {
    private static boolean debuggingEnabled = false;
    private static HashMap<Long, Factory> debuggerFactories = new HashMap<Long, Factory>();

    public static void enable() {
        debuggingEnabled = true;
    }

    public static void setFactoryForApplication(long applicationId, Factory factory) {
        if(debuggingEnabled == false) {
            throw new RuntimeException("Debugging not enabled");
        }
        synchronized(debuggerFactories) {
            Factory oldFactory = debuggerFactories.put(applicationId, factory);
            if(null != oldFactory) {
                oldFactory.onDetach();
            }
        }
    }

    public static Factory getFactoryForApplication(long applicationId) {
        if(debuggingEnabled == false) {
            return null;
        }
        synchronized(debuggerFactories) {
            return debuggerFactories.get(applicationId);
        }
    }

    // ----------------------------------------------------------------------

    public interface Factory {
        public Implementation makeImplementation();
        default public void onDetach() {};
    }

    // ----------------------------------------------------------------------

    public abstract static class Implementation implements Debugger {
        public abstract void useOnThisThread();
        public abstract void stopUsingOnThisThread();
    }

}

