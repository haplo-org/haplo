/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.framework;

import javax.servlet.http.HttpServletRequest;

import com.oneis.appserver.Response;
import com.oneis.appserver.FileUploads;

public interface Framework {
    // Application control
    void startApplication() throws Exception;

    void startBackgroundTasks() throws Exception;

    void stopApplication() throws Exception;

    void scheduledTaskPerform(String name);

    // Other objects
    Application.DynamicFileFactory getDynamicFileFactory();

    // Request handling
    Response handleFromJava(HttpServletRequest request, Application app, byte[] body, boolean isRequestSSL, FileUploads fileUploads);

    String checkHealth() throws Exception;

    // Application info
    long getCurrentApplicationId();

    // Development mode support
    boolean devmodeCheckReload();

    void devmodeDoReload();
}
