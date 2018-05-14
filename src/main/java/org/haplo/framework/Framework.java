/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.framework;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.haplo.appserver.Response;
import org.haplo.appserver.FileUploads;

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

    void handleSaml2IntegrationFromJava(String path, HttpServletRequest request, HttpServletResponse response, Application app);

    String checkHealth() throws Exception;

    // Application info
    long getCurrentApplicationId();

    // Installation properties
    String getInstallProperty(String name, String defaultValue);
    boolean pluginDebuggingEnabled();

    // Development mode support
    boolean devmodeCheckReload();

    void devmodeDoReload();
}
