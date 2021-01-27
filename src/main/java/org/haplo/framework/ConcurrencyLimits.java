/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.framework;

import java.util.concurrent.Semaphore;

/**
 * Container for semaphores to restrict concurrency of various operations.
 *
 */
public class ConcurrencyLimits {
    // How many requests can an application have in-flight at once?
    public static final int APPLICATION_CONCURRENT_REQUESTS_PERMITS = 8;

    // When another request is in progress, how many times should the handler wait to see if it can be the only request processed at once?
    public static final int APPLICATION_CONCURRENT_REQUESTS_MAX_SPINS = 4;
    // And how long should it wait?
    public static final int APPLICATION_CONCURRENT_REQUESTS_MAX_WAIT_TIME = 5;  /* ms */
}
