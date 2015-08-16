/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.app;

import org.eclipse.jetty.continuation.Continuation;

// Java code called by the Ruby GeneratedFileController
public class GeneratedFileController {

    public static void safelyResumeContinuation(Continuation continuation) {
        synchronized(continuation) {
            if(continuation.isSuspended()) {
                continuation.resume();
            }
        }
    }

}
