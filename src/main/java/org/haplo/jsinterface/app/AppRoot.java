/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.app;

import org.haplo.appserver.FileUploads;
import org.haplo.jsinterface.template.TemplatePlatformFunctions;
import org.haplo.jsinterface.KBinaryDataStaticFile;
import org.haplo.i18n.RuntimeStrings;
import java.sql.Connection;
import org.eclipse.jetty.continuation.Continuation;

public interface AppRoot {
    // Application information
    public int currentApplicationId();

    public String getApplicationInformation(String item);

    public String getApplicationConfigurationDataJSON();

    // Runtime properties
    public String getCurrentlyExecutingPluginName();

    // JavaScript plugin privileges
    public boolean currentlyExecutingPluginHasPrivilege(String privilegeName);
    public boolean pluginHasPrivilege(String pluginName, String privilegeName);

    // Database access
    public String getPostgresSchemaName();

    public Connection getJdbcConnection();

    public String getSchemaInfo(int type, int objId);

    public String getSchemaInfoTypesWithAnnotation(String annotation);

    // Permissions & request handling context
    public boolean isHandlingRequest();

    public void impersonating(AppUser user, Runnable runnable);

    public void withoutPermissionEnforcement(Runnable runnable);

    public String fetchRequestInformation(String infoName);

    public FileUploads fetchRequestUploads();

    public Continuation fetchRequestContinuation();

    public static class RequestBodyBinaryDataInfo {
        public byte[] bytes;
        public String spillFilePathname;
        public String mimeType;
        public String filename;
    }
    public void fetchRequestBodyBinaryData(RequestBodyBinaryDataInfo info);

    public String getSessionJSON();

    public void setSessionJSON(String json);

    public String[] getSessionTray();

    // Rendering and templating
    TemplatePlatformFunctions createTemplatePlatformFunctionsProxy();

    public String renderObject(AppObject object, String style);

    String[] loadTemplateForPlugin(String pluginName, String templateName);

    String renderRubyTemplate(String templateName, Object[] args);

    void addRightContent(String html);
    String getRightColumnHTML();

    String userTimeZone();

    // Files
    boolean hasFileForPlugin(String pluginName, String pathname);
    boolean loadFileForPlugin(String pluginName, String pathname, KBinaryDataStaticFile data);

    // Plugin functions
    String pluginStaticDirectoryUrl(String pluginName);

    String pluginRewriteCSS(String pluginName, String css);

    // App globals
    public String readPluginAppGlobal(String pluginName);

    public void savePluginAppGlobal(String pluginName, String global);

    // Application support
    public void writeLog(String level, String text);

    // Event reporting
    public void reportHealthEvent(String eventTitle, String eventText, Object exception, String exceptionText);

    // Cache invalidation
    public void reloadUserPermissions();

    public void reloadNavigation();

    public void reloadJavaScriptRuntimes();

    public void reloadUserSchema();

    public void reloadPlatformDynamicFiles();

    // i18n
    public String i18n_getCurrentLocaleId();
    public String i18n_setSessionLocaleId(String localeId);

    public RuntimeStrings i18n_getRuntimeStringsForLocale(String localeId);
}
