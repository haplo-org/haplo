/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.utils;

import java.io.File;

import org.apache.log4j.Logger;

public class ProcessStartupFlag {
    public static void processIsReady() {
        Logger logger = Logger.getLogger("com.oneis.app");

        String startupFlagFilename = System.getProperty("com.oneis.startupflag", "");
        if(startupFlagFilename.length() == 0) {
            logger.info("No startup flag file specified, won't do anything.");
        } else {
            logger.info("Startup flag file: " + startupFlagFilename);
            File file = new File(startupFlagFilename);
            if(file.exists()) {
                file.delete();
                logger.info("Deleted startup flag file.");
            } else {
                logger.info("Startup flag file doesn't exist, won't do anything.");
            }
        }
    }
}
