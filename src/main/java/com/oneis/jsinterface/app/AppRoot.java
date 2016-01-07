/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface.app;

import com.oneis.appserver.FileUploads;
import java.sql.Connection;

public interface AppRoot {
    // Application information
    public int currentApplicationId();

    public String getApplicationInformation(String item);

    public String getApplicationConfigurationDataJSON();

    // Runtime properties
    public boolean javascriptWarningsAreErrors();

    public String getCurrentlyExecutingPluginName();

    // JavaScript plugin privileges
    public boolean currentlyExecutingPluginHasPrivilege(String privilegeName);

    // Database access
    public String getPostgresSchemaName();

    public Connection getJdbcConnection();

    public String getSchemaInfo(int type, int objId);

    // Permissions & request handling context
    public boolean isHandlingRequest();

    public void impersonating(AppUser user, Runnable runnable);

    public void withoutPermissionEnforcement(Runnable runnable);

    public String fetchRequestInformation(String infoName);

    public FileUploads fetchRequestUploads();

    public String getSessionJSON();

    public void setSessionJSON(String json);

    public String[] getSessionTray();

    // Rendering and templating
    public String renderObject(AppObject object, String style);

    String[] loadTemplateForPlugin(String pluginName, String templateName);

    String renderRubyTemplate(String templateName, Object[] args);

    void addRightContent(String html);

    // Plugin functions
    String pluginStaticDirectoryUrl(String pluginName);

    String pluginRewriteCSS(String pluginName, String css);

    // App globals
    public String readPluginAppGlobal(String pluginName);

    public void savePluginAppGlobal(String pluginName, String global);

    // Application support
    public void writeLog(String level, String text);

    // Event reporting
    public void reportHealthEvent(String eventTitle, String eventText);

    // Cache invalidation
    public void reloadUserPermissions();

    public void reloadNavigation();

    public void reloadJavaScriptRuntimes();
}
