/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.common.server;

import org.apache.log4j.Logger;

public class JettyLog4j implements org.eclipse.jetty.util.log.Logger {
    private String name;
    private Logger logger;

    public JettyLog4j(String name) {
        this.name = name;
        this.logger = Logger.getLogger(name);
    }

    public String getName() {
        return this.name;
    }

    public void warn(String msg, Object... args) {
        this.logger.warn(format(msg, args));
    }

    public void warn(Throwable thrown) {
        this.logger.warn(thrown);
    }

    public void warn(String msg, Throwable thrown) {
        this.logger.warn(msg, thrown);
    }

    public void info(String msg, Object... args) {
        this.logger.info(format(msg, args));
    }

    public void info(Throwable thrown) {
        this.logger.info(thrown);
    }

    public void info(String msg, Throwable thrown) {
        this.logger.info(msg, thrown);
    }

    public boolean isDebugEnabled() {
        return false;
    }

    public void setDebugEnabled(boolean enabled) {
    }

    public void debug(String msg, Object... args) {
        this.logger.debug(format(msg, args));
    }

    public void debug(String msg, long value) {
        this.logger.debug(format(msg, value));
    }

    public void debug(Throwable thrown) {
        this.logger.debug(thrown);
    }

    public void debug(String msg, Throwable thrown) {
        this.logger.warn(msg, thrown);
    }

    public org.eclipse.jetty.util.log.Logger getLogger(String name) {
        return this;
    }

    public void ignore(Throwable ignored) {
    }

    private String format(String msg, Object... args) {
        msg = String.valueOf(msg); // Avoids NPE
        String braces = "{}";
        StringBuilder builder = new StringBuilder();
        int start = 0;
        for(Object arg : args) {
            int bracesIndex = msg.indexOf(braces, start);
            if(bracesIndex < 0) {
                builder.append(msg.substring(start));
                builder.append(" ");
                builder.append(arg);
                start = msg.length();
            } else {
                builder.append(msg.substring(start, bracesIndex));
                builder.append(String.valueOf(arg));
                start = bracesIndex + braces.length();
            }
        }
        builder.append(msg.substring(start));
        return builder.toString();
    }
}
