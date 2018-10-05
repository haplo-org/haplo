/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;
import org.mozilla.javascript.*;

import org.haplo.appserver.FileUploads;

import org.haplo.jsinterface.app.*;
import org.haplo.jsinterface.stdplugin.StdWebPublisher;
import org.haplo.jsinterface.db.JdNamespace;
import org.haplo.jsinterface.xml.XmlDocument;
import org.haplo.jsinterface.template.TemplateIncludedRenderer;
import org.haplo.jsinterface.template.TemplatePlatformFunctions;
import org.haplo.template.driver.rhinojs.HaploTemplate;
import org.haplo.httpclient.HTTPClient;

import java.util.Map;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.WeakHashMap;

/**
 * Main Javascript host object for Haplo
 */
public class KHost extends KScriptable {
    private AppRoot supportRoot;
    private TemplatePlatformFunctions templatePlatformFunctions;
    private String userTimeZone;
    private LinkedHashMap<String, Scriptable> plugins; // use LinkedHashMap so iterator is plugin load order
    private String nextPluginToBeRegistered;
    private boolean nextPluginToBeRegisteredUsesDatabase;
    private String nextPluginDatabaseNamespace;
    private TestCallback testCallback;
    private KSessionStore sessionStore;
    private Function renderSearchResultFunction;
    private HashMap<String, KObjRef> behaviourRefCache;
    private HashMap<Integer, String> refBehaviourCache;

    public KHost() {
        this.plugins = new LinkedHashMap<String, Scriptable>(8);
        this.sessionStore = null;
    }

    public void setSupportRoot(AppRoot supportRoot) {
        this.supportRoot = supportRoot;
        this.templatePlatformFunctions = null;
        this.userTimeZone = null;
        // Reset all the data read from app globals - this is a convenient time to do the reset.
        // TODO: For efficiency, only reset app data stores for JavaScript plugins when it's changed by the same plugin in another JavaScript runtime
        resetPluginAppDataStores();
        // Make sure there's no session store
        this.sessionStore = null;
    }

    public void clearSupportRoot() {
        this.supportRoot = null;
        this.templatePlatformFunctions = null;
        this.userTimeZone = null;
        // Throw away any session store
        this.sessionStore = null;
    }

    public AppRoot getSupportRoot() {
        return this.supportRoot;
    }

    public TemplatePlatformFunctions getTemplatePlatformFunctions() {
        if(this.templatePlatformFunctions == null) {
            this.templatePlatformFunctions = this.supportRoot.createTemplatePlatformFunctionsProxy();
        }
        return this.templatePlatformFunctions;
    }

    public String getUserTimeZone() {
        if(this.userTimeZone == null) { this.userTimeZone = this.supportRoot.userTimeZone(); }
        if(this.userTimeZone == null) { this.userTimeZone = "Etc/UTC"; }
        return this.userTimeZone;
    }

    public int getNumberOfPluginsRegistered() {
        return this.plugins.size();
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$Host";
    }

    // --------------------------------------------------------------------------------------------------------------
    public String jsFunction_getApplicationInformation(String item) {
        return this.supportRoot.getApplicationInformation(item);
    }

    public String jsFunction_getApplicationConfigurationDataJSON() {
        return this.supportRoot.getApplicationConfigurationDataJSON();
    }

    public String jsFunction_getApplicationInformationPlugins() {
        StringBuilder builder = new StringBuilder();
        for(String name : this.plugins.keySet()) {
            if(builder.length() != 0) { builder.append(','); }
            builder.append(name);
        }
        return builder.toString();
    }

    // --------------------------------------------------------------------------------------------------------------
    public void setNextPluginToBeRegistered(String pluginName, String databaseNamespace) {
        this.nextPluginToBeRegistered = pluginName;
        this.nextPluginToBeRegisteredUsesDatabase = (databaseNamespace != null);
        nextPluginDatabaseNamespace = databaseNamespace;
    }

    static public class DbNamespaceInformation {
        public String name;
        public String pluginName;
        public String postgresSchemaName;
    }

    public DbNamespaceInformation getNextDatabaseNamespace() { // for JdNamespace
        if(this.nextPluginDatabaseNamespace == null) { return null; }
        DbNamespaceInformation info = new DbNamespaceInformation();
        info.name = this.nextPluginDatabaseNamespace;
        info.pluginName = this.nextPluginToBeRegistered;
        info.postgresSchemaName = this.supportRoot.getPostgresSchemaName();
        return info;
    }

    public boolean pluginImplementsHook(String pluginName, String hookName) {
        Scriptable plugin = this.plugins.get(pluginName);
        if(plugin == null) {
            throw new OAPIException("Plugin " + pluginName + " is not registered.");
        }
        // Only check the actual plugin object, not its prototype chain. Hooks can only be defined on the
        // plugins, because allowing base class implementations would mean every plugin has to be called
        // for that hook. Which is inefficient.
        return plugin.has(hookName, plugin);
    }

    public void callAllPluginOnLoad() {
        Runtime.getCurrentRuntime().callSharedScopeJSClassFunction("$Plugin", "$callOnLoad", new Object[]{});
    }

    public void callAllPluginOnInstall() {
        Runtime.getCurrentRuntime().callSharedScopeJSClassFunction("$Plugin", "$callOnInstall", new Object[]{});
    }

    public void callHookInAllPlugins(Object[] args) {
        Runtime.getCurrentRuntime().callSharedScopeJSClassFunction("$Plugin", "$callAllHooks", args);
    }

    public void setupDatabaseStorage(String pluginName) {
        Scriptable plugin = this.plugins.get(pluginName);
        if(plugin == null) {
            throw new OAPIException("Plugin " + pluginName + " is not registered.");
        }
        Object database = plugin.get("db", plugin); // ConsString is checked
        if(database == null || !(database instanceof JdNamespace)) {
            throw new OAPIException("Plugin " + pluginName + " does not have database as expected.");
        }
        ((JdNamespace)database).setupStorage();
    }

    public String readPluginAppGlobal(String pluginName) {
        return this.supportRoot.readPluginAppGlobal(pluginName);
    }

    public void savePluginAppGlobal(String pluginName, String global) {
        // TODO: Give warning messages when too much is stored in plugin.store, but before it's too big to exception here
        if(global.length() > (16 * 1024)) {
            // Make sure the plugin doesn't save too much data.
            throw new OAPIException("Plugin store is too large");
        }
        this.supportRoot.savePluginAppGlobal(pluginName, global);
    }

    private void resetPluginAppDataStores() {
        for(Scriptable plugin : plugins.values()) {
            Object store = plugin.get("data", plugin); // ConsString is checked
            if(store != null && store instanceof KPluginAppGlobalStore) {
                ((KPluginAppGlobalStore)store).invalidateAllStoredData();
            }
        }
    }

    public boolean currentlyExecutingPluginHasPrivilege(String privilegeName) {
        return this.supportRoot.currentlyExecutingPluginHasPrivilege(privilegeName);
    }

    public boolean pluginHasPrivilege(String pluginName, String privilegeName) {
        return this.supportRoot.pluginHasPrivilege(pluginName, privilegeName);
    }

    // --------------------------------------------------------------------------------------------------------------
    public String jsFunction_getSchemaInfo(int type, int objId) {
        return this.supportRoot.getSchemaInfo(type, objId);
    }

    public String jsFunction_getSchemaInfoTypesWithAnnotation(String annotation) {
        return this.supportRoot.getSchemaInfoTypesWithAnnotation(annotation);
    }

    // --------------------------------------------------------------------------------------------------------------

    // The host object is a convenient place to keep the behaviour ref cache, as it needs to be per-Runtime
    // as Ref objects shouldn't be shared between runtimes.

    public HashMap<String, KObjRef> getBehaviourRefCache() {
        if(this.behaviourRefCache == null) {
            this.behaviourRefCache = new HashMap<String, KObjRef>();
        }
        return this.behaviourRefCache;
    }

    public HashMap<Integer, String> getRefBehaviourCache() {
        if(this.refBehaviourCache == null) {
            this.refBehaviourCache = new HashMap<Integer, String>();
        }
        return this.refBehaviourCache;
    }

    // --------------------------------------------------------------------------------------------------------------
    public Function findPluginFunction(Scriptable plugin, String pluginName, String name) {
        Object property = ScriptableObject.getProperty(plugin, name);
        if(!(property instanceof Function)) {
            throw new OAPIException("Can't find " + name + "() function for plugin " + pluginName);
        }
        return (Function)property;
    }

    // --------------------------------------------------------------------------------------------------------------
    public String getFileUploadInstructions(String pluginName, String path) {
        Scriptable plugin = this.plugins.get(pluginName);
        if(plugin == null) {
            throw new OAPIException("Tried to find file upload instructions for plugin " + pluginName + " but it's not registered.");
        }
        Runtime runtime = Runtime.getCurrentRuntime();
        Function getInstructions = findPluginFunction(plugin, pluginName, "getFileUploadInstructions"); // exceptions if it can't be found
        Object r = getInstructions.call(runtime.getContext(), runtime.getJavaScriptScope(), plugin, new Object[]{path}); // ConsString is checked
        return (r == null || !(r instanceof CharSequence)) ? null : ((CharSequence)r).toString();
    }

    // --------------------------------------------------------------------------------------------------------------
    // For invoking generic plugin callbacks
    public Object callCallback(Object[] arguments) {
        Runtime runtime = Runtime.getCurrentRuntime();
        Scriptable scope = runtime.getSharedJavaScriptScope();

        Scriptable o = (Scriptable)ScriptableObject.getProperty(scope, "O");
        Scriptable privateThings = (Scriptable)ScriptableObject.getProperty(o, "$private");
        Function invokeCallback = (Function)ScriptableObject.getProperty(privateThings, "invokeCallback");

        Object r = null;
        try {
            r = invokeCallback.call(runtime.getContext(),
                                    runtime.getJavaScriptScope(), runtime.getJavaScriptScope(),
                                    arguments);
        } catch(StackOverflowError e) {
            // JRuby 1.7.19 doesn't cartch StackOverflowError exceptions any more, so wrap it into a JS Exception
            throw new org.mozilla.javascript.WrappedException(e);
        }
        return r;
    }

    // --------------------------------------------------------------------------------------------------------------
    final static int RESPONSE_BODY_INDEX = 2;
    final static private Object[][] REQUEST_HANDLER_RESPONSE = new Object[][]{
        new Object[]{"statusCode", Integer.class},
        new Object[]{"$headersJSON", String.class},
        new Object[]{"body", String.class}, // at RESPONSE_BODY_INDEX
        new Object[]{"kind", String.class},
        new Object[]{"layout", String.class},
        new Object[]{"pageTitle", String.class},
        new Object[]{"$staticResources", String.class},
        new Object[]{"$backLink", String.class},
        new Object[]{"$backLinkText", String.class}
    };
    private static interface CallJSHandlerFn { Object call(Runtime r); }

    // Normal plugin HTTP request handling
    public Object[] callRequestHandler(String pluginName, String method, String path) {
        Scriptable plugin = this.plugins.get(pluginName);
        if(plugin == null) {
            throw new OAPIException("Tried to call request handler for plugin " + pluginName + " but it's not registered.");
        }
        Function handleRequest = findPluginFunction(plugin, pluginName, "handleRequest"); // exceptions if it can't be found
        return callJSFunctionAndDecodeResponseObject(
            (runtime) -> handleRequest.call(runtime.getContext(), runtime.getJavaScriptScope(), plugin, new Object[]{method, path}) // ConsString is checked
        );
    }

    // std_web_publisher special case HTTP request handling
    public Object[] callWebPublisherHandler(String host, String method, String path) {
        Scriptable plugin = this.plugins.get("std_web_publisher");
        Function handleRequest = findPluginFunction(plugin, "std_web_publisher", "$webPublisherHandle");
        return callJSFunctionAndDecodeResponseObject(
            (runtime) -> handleRequest.call(runtime.getContext(), runtime.getJavaScriptScope(), plugin, new Object[] {host, method, path})
        );
    }

    private Object[] callJSFunctionAndDecodeResponseObject(CallJSHandlerFn jsFn) {
        Runtime runtime = Runtime.getCurrentRuntime();
        Object r = null;
        try {
            r = jsFn.call(runtime);
        } catch(StackOverflowError e) {
            // JRuby 1.7.19 doesn't cartch StackOverflowError exceptions any more, so wrap it into a JS Exception
            throw new org.mozilla.javascript.WrappedException(e);
        }
        if(r == null) {
            return null;
        }
        if(!(r instanceof Scriptable)) {
            throw new OAPIException("JS request handler didn't return correct type");
        }
        Scriptable response = (Scriptable)r;
        // Call the $finaliseResponse method to build the final data structures
        Function finaliseResponse = (Function)response.getPrototype().get("$finaliseResponse", response.getPrototype());
        finaliseResponse.call(runtime.getContext(), runtime.getJavaScriptScope(), response, new Object[]{});
        // Pull out the information for the Ruby side
        Object[] info = new Object[REQUEST_HANDLER_RESPONSE.length];
        for(int i = 0; i < REQUEST_HANDLER_RESPONSE.length; ++i) {
            String propertyName = (String)REQUEST_HANDLER_RESPONSE[i][0]; // ConsString is checked
            Class propertyClass = (Class)REQUEST_HANDLER_RESPONSE[i][1];
            Object property = response.get(propertyName, response); // ConsString is checked
            if((property != null) && (property instanceof CharSequence)) {
                property = ((CharSequence)property).toString();
            }
            if(property != null && propertyClass.isInstance(property)) {
                info[i] = property;
            }
        }
        // body may need special handling
        if(info[RESPONSE_BODY_INDEX] == null) {
            // Perhaps it's a generated file?
            Object body = response.get("body", response); // ConsString is checked
            if((body != null) &&
                   ((body instanceof KBinaryData) || (body instanceof KStoredFile) || (body instanceof XmlDocument))) {
                // Send it to the Ruby side, which knows how to handle it
                info[RESPONSE_BODY_INDEX] = body;
            } else if(body != UniqueTag.NOT_FOUND) {
                throw new OAPIException("The response body (usually E.response.body)"
                        + " is not valid, must be a String, StoredFile, XML document, or a generator (O.generate) object. "
                        + "JSON responses should be encoded using JSON.stringify by the request handler.");
            }
        }
        return info;
    }

    // --------------------------------------------------------------------------------------------------------------
    public StdWebPublisher.WebPublisher getWebPublisher() {
        return getWebPublisherImpl(true);
    }

    public StdWebPublisher.WebPublisher getWebPublisherMaybe() {
        return getWebPublisherImpl(false);
    }

    private StdWebPublisher.WebPublisher getWebPublisherImpl(boolean required) {
        Scriptable plugin = this.plugins.get("std_web_publisher");
        if(plugin == null) {
            if(required) {
                throw new RuntimeException("std_web_publisher was expected to be installed, but wasn't.");
            }
            return null;
        }
        return new StdWebPublisher.WebPublisher(Runtime.getCurrentRuntime(), plugin);
    }

    // --------------------------------------------------------------------------------------------------------------
    public Object jsFunction_getCurrentlyExecutingPluginName() {
        // Return undefined if no plugin is currently in use
        String name = this.supportRoot.getCurrentlyExecutingPluginName();
        return (name == null) ? Context.getUndefinedValue() : name;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsFunction_registerPlugin(String pluginName, Scriptable plugin) {
        // Check plugin name is allowed, to stop random plugins being registered
        if(this.nextPluginToBeRegistered == null) {
            throw new OAPIException("Unexpected plugin registration.");
        } else if(!this.nextPluginToBeRegistered.equals(pluginName)) {
            throw new OAPIException("Unexpected plugin registration, '" + pluginName + "' given, '" + this.nextPluginToBeRegistered + "' expected.");
        }
        this.nextPluginToBeRegistered = null;
        // Check it hasn't already been registered
        if(this.plugins.containsKey(pluginName)) {
            throw new OAPIException("Plugin " + pluginName + " is already registered");
        }
        // Initialise the plugin app globals store
        KPluginAppGlobalStore store = (KPluginAppGlobalStore)Runtime.createHostObjectInCurrentRuntime("$PluginStore");
        store.setPluginNameAndHost(pluginName, this);
        plugin.put("data", plugin, store);

        this.plugins.put(pluginName, plugin);
    }

    public boolean jsFunction_nextPluginUsesDatabase() {
        return this.nextPluginToBeRegisteredUsesDatabase;
    }

    public void jsFunction_enforcePluginPrivilege(String pluginName, String privilege, String action) {
        Runtime.enforcePrivilegeRequired(pluginName, privilege, action);
    }

    // --------------------------------------------------------------------------------------------------------------
    public boolean jsFunction_isHandlingRequest() {
        return this.supportRoot.isHandlingRequest();
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class FunctionRunner implements Runnable {
        private Function action;
        public Object result;

        FunctionRunner(Function action) {
            this.action = action;
        }

        @Override
        public void run() {
            Runtime runtime = Runtime.getCurrentRuntime();
            this.result = action.call(runtime.getContext(), runtime.getJavaScriptScope(), action, EMPTY_ARGS);
        }
        private static final Object[] EMPTY_ARGS = new Object[] {};
    }

    public Object jsFunction_impersonating(KUser user, Function action) {
        FunctionRunner runner = new FunctionRunner(action);
        this.supportRoot.impersonating((user == null) ? null : user.toRubyObject(), runner);
        return runner.result;
    }

    public Object jsFunction_withoutPermissionEnforcement(Function action) {
        FunctionRunner runner = new FunctionRunner(action);
        this.supportRoot.withoutPermissionEnforcement(runner);
        return runner.result;
    }

    // --------------------------------------------------------------------------------------------------------------
    public String jsFunction_fetchRequestInformation(String infoName) {
        return this.supportRoot.fetchRequestInformation(infoName);
    }

    public KUploadedFile jsFunction_fetchRequestUploadedFile(String parameterName) {
        FileUploads uploads = this.supportRoot.fetchRequestUploads();
        if(uploads == null) {
            return null;
        }
        FileUploads.Upload upload = uploads.getFile(parameterName);
        if(upload == null) {
            return null;
        } // might not exist
        if(!upload.wasUploaded()) {
            return null;
        } // might not have been uploaded
        // Construct a JavaScript UploadedFile object
        KUploadedFile file = (KUploadedFile)Runtime.createHostObjectInCurrentRuntime("$UploadedFile");
        file.setUpload(upload);
        return file;
    }

    public KRequestContinuation jsFunction_fetchRequestContinuation() {
        KRequestContinuation c = (KRequestContinuation)Runtime.createHostObjectInCurrentRuntime("$RequestContinuation");
        c.setContinuation(this.supportRoot.fetchRequestContinuation());
        return c;
    };

    public KSessionStore jsFunction_getSessionStore() {
        if(sessionStore == null) {
            sessionStore = (KSessionStore)Runtime.createHostObjectInCurrentRuntime("$SessionStore");
            sessionStore.setIsRealSessionStore();
        }
        return sessionStore;
    }

    public Scriptable jsFunction_getSessionTray() {
        String[] t1 = this.supportRoot.getSessionTray();
        Object[] t2 = new Object[t1.length];
        for(int l = 0; l < t1.length; ++l) {
            t2[l] = KObjRef.fromString(t1[l]);
        }
        Runtime runtime = Runtime.getCurrentRuntime();
        return runtime.getContext().newArray(runtime.getJavaScriptScope(), t2);
    }

    // --------------------------------------------------------------------------------------------------------------
    // Rendering and views
    public String renderObject(AppObject object, String style) {
        return this.supportRoot.renderObject(object, style);
    }

    public Scriptable jsFunction_loadTemplateForPlugin(Scriptable plugin, String pluginName, String templateName) {
        String[] r = this.supportRoot.loadTemplateForPlugin(pluginName, templateName);
        if(r == null) {
            throw new OAPIException("Plugin " + pluginName + " doesn't have a template named " + templateName);
        }
        final Runtime runtime = Runtime.getCurrentRuntime();
        final Context cx = runtime.getContext();
        final Scriptable sharedScope = runtime.getSharedJavaScriptScope();
        final Scriptable scope = runtime.getJavaScriptScope();
        if("hsvt".equals(r[1])) {
            HaploTemplate template = (HaploTemplate)cx.newObject(scope, "$HaploTemplate", new Object[]{r[0], templateName});
            template.put("kind", template, "html");
            template.setOwner(plugin);
            return template;
        }
        final Scriptable o = (Scriptable)sharedScope.get("O", sharedScope);
        final Function createPluginTemplateFn = (Function)o.get("$createPluginTemplate", o);
        return (Scriptable)createPluginTemplateFn.call(cx, scope, o, new Object[]{plugin, templateName, r[0], r[1]});
    }

    public String jsFunction_renderRTemplate(String templateName, Object arg1, Object arg2, Object arg3, Object arg4, Object arg5, Object arg6) {
        Object[] args = new Object[]{arg1, arg2, arg3, arg4, arg5, arg6}; // Rhino doesn't support varargs
        for(int index = 0; index < args.length; index++) {
            Object arg = args[index];
            if(arg == org.mozilla.javascript.Context.getUndefinedValue()) {
                args[index] = null;
            } else if(arg instanceof CharSequence) {
                args[index] = ((CharSequence)arg).toString();
            }
        }
        return this.supportRoot.renderRubyTemplate(templateName, args);
    }

    public void jsFunction_addRightContent(String html) {
        this.supportRoot.addRightContent(html);
    }

    public String jsFunction_getRightColumnHTML() {
        return this.supportRoot.getRightColumnHTML();
    }

    public boolean jsFunction_hasFileForPlugin(String pluginName, String pathname) {
        return this.supportRoot.hasFileForPlugin(pluginName, pathname);
    }

    public Scriptable jsFunction_loadFileForPlugin(String pluginName, String pathname) {
        KBinaryDataStaticFile data = (KBinaryDataStaticFile)Runtime.createHostObjectInCurrentRuntime("$BinaryDataStaticFile");
        if(!this.supportRoot.loadFileForPlugin(pluginName, pathname, data)) {
            throw new OAPIException("Cannot load plugin data file "+pathname);
        }
        return data;
    }

    public boolean jsFunction_isDeferredRender(Object object) {
        return (object instanceof org.haplo.template.html.DeferredRender);
    }

    // Search result rendering is special
    public void jsFunction_setRenderSearchResult(Function fn) {
        this.renderSearchResultFunction = fn;
    }

    public boolean doesAnyPluginRenderSearchResults() {
        return this.renderSearchResultFunction != null;
    }

    public String callRenderSearchResult(AppObject appObject) {
        final Scriptable object = KObject.fromAppObject(appObject, false /* not mutable */);
        final Runtime runtime = Runtime.getCurrentRuntime();
        final Scriptable scope = runtime.getJavaScriptScope();
        final Object result = this.renderSearchResultFunction.call(runtime.getContext(), scope, scope, new Object[]{object}); // ConsString is checked
        return (result instanceof CharSequence) ? result.toString() : null;
    }

    // --------------------------------------------------------------------------------------------------------------
    public KObjRef jsFunction_objrefFromString(String string) {
        return KObjRef.fromString(string);
    }

    // --------------------------------------------------------------------------------------------------------------
    public String jsFunction_pluginStaticDirectoryUrl(String pluginName) {
        if(null == this.plugins.get(pluginName)) {
            throw new OAPIException("Plugin not registered");
        }
        return this.supportRoot.pluginStaticDirectoryUrl(pluginName);
    }

    public String jsFunction_pluginRewriteCSS(String pluginName, String css) {
        if(null == this.plugins.get(pluginName)) {
            throw new OAPIException("Plugin not registered");
        }
        return this.supportRoot.pluginRewriteCSS(pluginName, css);
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsFunction_writeLog(String level, String text) {
        this.supportRoot.writeLog(level, text);
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsFunction_reportHealthEvent(String eventTitle, String eventText, Object exception, String exceptionText) {
        Runtime.privilegeRequired("pReportHealthEvent", "report health events");
        this.supportRoot.reportHealthEvent(eventTitle, eventText, exception, exceptionText);
    }

    // --------------------------------------------------------------------------------------------------------------
    // Cache invalidation
    public void jsFunction_reloadUserPermissions() {
        this.supportRoot.reloadUserPermissions();
    }

    public void jsFunction_reloadNavigation() {
        this.supportRoot.reloadNavigation();
    }

    public void jsFunction_reloadJavaScriptRuntimes() {
        this.supportRoot.reloadJavaScriptRuntimes();
    }

    // --------------------------------------------------------------------------------------------------------------
    // HTTP Client
    public void jsFunction_httpClientRequest(String callbackName,
                                             String callbackData,
                                             Scriptable requestSettings) {
        Runtime.privilegeRequired("pHTTPClient", "perform HTTP requests");
        Map<String,Object> requestSettingsMap = new HashMap<String,Object>();
        for(Object id : requestSettings.getIds()) {
            requestSettingsMap.put(id.toString(),
                                   requestSettings.get(id.toString(),
                                                       requestSettings));
        }
        HTTPClient.queueHttpClientRequest(callbackName, callbackData, requestSettingsMap);
    }

    // --------------------------------------------------------------------------------------------------------------
    // Plugin test scripts support
    public void jsFunction__test_resetForNewLogin() {
        this.sessionStore = null;
    }

    // --------------------------------------------------------------------------------------------------------------
    // A private property for debugging and testing
    private String debugString;

    public void jsSet__debug_string(String string) {
        debugString = string;
    }

    public String jsGet__debug_string() {
        return debugString;
    }

    // Callback for testing
    public interface TestCallback {
        public String call(String string);
    }

    public String jsFunction__testCallback(String string) {
        if(this.testCallback == null) {
            throw new OAPIException("Can't call the test callback");
        }
        return this.testCallback.call(string);
    }

    public void setTestCallback(TestCallback callback) {
        this.testCallback = callback;
    }

    // Collect items for testing
    private java.util.ArrayList<Object> debugCollection;

    public void jsFunction__debugPushObject(Object object) {
        if(debugCollection == null) {
            debugCollection = new java.util.ArrayList<Object>();
        }
        debugCollection.add(object);
    }

    public java.util.ArrayList<Object> getDebugCollection() {
        java.util.ArrayList<Object> r = (debugCollection == null) ? new java.util.ArrayList<Object>() : debugCollection;
        debugCollection = null;
        return r;
    }
}
