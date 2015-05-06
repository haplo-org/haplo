/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.javascript;

import java.io.LineNumberReader;
import java.io.FileReader;
import java.util.HashSet;

import org.mozilla.javascript.*;
import org.mozilla.javascript.json.JsonParser;

import org.apache.commons.io.IOUtils;

import com.oneis.jsinterface.*;
import com.oneis.jsinterface.app.*;
import com.oneis.jsinterface.db.*;
import com.oneis.jsinterface.generate.*;
import com.oneis.jsinterface.remote.*;
import com.oneis.jsinterface.util.*;

/**
 * Sandboxed Javascript runtime for ONEIS
 */
public class Runtime {
    // The shared global objects which are used for every runtime
    static private ScriptableObject sharedScope;

    // How to find the current Runtime
    static private ThreadLocal<Runtime> threadRuntime = new ThreadLocal<Runtime>();

    // Information for the current runtime
    private Context currentContext;
    private Scriptable runtimeScope;
    private KONEISHost host;
    private boolean haveInitialisedSchema;
    private PluginTestingSupport testingSupport;

    // Interface to load standard templates
    public interface StandardTemplateLoader {
        public String standardTemplateJSON();
    }
    private static StandardTemplateLoader standardTemplateLoader;

    public static void setStandardTemplateLoader(StandardTemplateLoader loader) {
        standardTemplateLoader = loader;
    }

    /**
     * Construct a new runtime, backed by the shared scope
     */
    public Runtime() {
        if(sharedScope == null) {
            throw new RuntimeException("Runtime.initializeSharedEnvironment() not called yet");
        }

        // Flag for schema initialisation
        this.haveInitialisedSchema = false;

        Context cx = Runtime.enterContext();
        try {
            // Generate a new scope for the runtime, which borrows the objects in the main shared scope
            ScriptableObject scope = (ScriptableObject)cx.newObject(sharedScope);
            scope.setPrototype(sharedScope);
            scope.setParentScope(null);

            // Initialise the scope and set the $host object
            Object initialiser = sharedScope.get("$oneis_framework_initialiser", scope); // ConsString is checked
            if(initialiser == null || initialiser == Scriptable.NOT_FOUND || !(initialiser instanceof Function)) {
                throw new RuntimeException("JavaScript Runtime can't find the initialiser function");
            } else {
                Function f = (Function)initialiser;
                Object result = f.call(cx, scope, scope, null); // ConsString is checked
                if(!(result instanceof KONEISHost)) {
                    throw new RuntimeException("JavaScript Runtime initialiser returned something unexpected");
                }
                host = (KONEISHost)result;
            }

            runtimeScope = scope;
        } finally {
            cx.exit();
        }
    }

    /**
     * Set this Runtime for use on this Thread
     */
    public void useOnThisThread(AppRoot supportRoot) {
        if(currentContext != null || Context.getCurrentContext() != null || threadRuntime.get() != null) {
            throw new RuntimeException("JavaScript Runtime is not in the right state for useOnThisThread()");
        }
        currentContext = Runtime.enterContext();
        threadRuntime.set(this);
        host.setSupportRoot(supportRoot);
        // Check it's using one of our ErrorReporter
        ErrorReporter reporter = currentContext.getErrorReporter();
        if(!(reporter instanceof OErrorReporter)) {
            currentContext.setErrorReporter(new OErrorReporter(reporter, supportRoot.javascriptWarningsAreErrors()));
        }
    }

    /**
     * Stop using this runtime on this Thread
     */
    public void stopUsingOnThisThread() {
        if(currentContext == null || currentContext != Context.getCurrentContext() || threadRuntime.get() != this) {
            throw new RuntimeException("JavaScript Runtime is not in the right state for stopUsingOnThisThread()");
        }
        currentContext.exit();
        currentContext = null;
        host.clearSupportRoot();
        threadRuntime.remove();
    }

    /**
     * Get the current Runtime object for this thread
     */
    public static Runtime getCurrentRuntime() {
        Runtime runtime = threadRuntime.get();
        if(runtime == null) {
            throw new RuntimeException("No JavaScript runtime in use on this thread");
        }
        return runtime;
    }

    /**
     * Get the Javascript context
     */
    public Context getContext() {
        return currentContext;
    }

    /**
     * Load a script into the runtime
     */
    public void loadScript(String scriptPathname, String givenFilename, String prefix, String suffix) throws java.io.IOException {
        checkContext();
        FileReader script = new FileReader(scriptPathname);
        try {
            if(prefix != null || suffix != null) {
                // TODO: Is it worth loading JS files with prefix+suffix using a fancy Reader which concatenates other readers?
                StringBuilder builder = new StringBuilder();
                if(prefix != null) {
                    builder.append(prefix);
                }
                builder.append(IOUtils.toString(script));
                if(suffix != null) {
                    builder.append(suffix);
                }
                currentContext.evaluateString(runtimeScope, builder.toString(), givenFilename, 1, null /* no security domain */);
            } else {
                currentContext.evaluateReader(runtimeScope, script, givenFilename, 1, null /* no security domain */);
            }
        } finally {
            script.close();
        }
    }

    /**
     * Evaluate a string in the runtime
     */
    public void evaluateString(String string, String sourceName) throws java.io.IOException {
        checkContext();
        if(sourceName == null) {
            sourceName = "<eval>";
        }
        currentContext.evaluateString(runtimeScope, string, sourceName, 1, null /* no security domain */);
    }

    /**
     * Get the main host object
     */
    public KONEISHost getHost() {
        return host;
    }

    /**
     * Get the main host object for the Runtime in use on the current thread.
     */
    static public KONEISHost currentRuntimeHost() {
        Runtime runtime = threadRuntime.get();
        if(runtime == null) {
            throw new RuntimeException("No JavaScript runtime in use on this thread");
        }
        return runtime.getHost();
    }

    /**
     * Get the scope for executing JavaScript
     */
    public Scriptable getJavaScriptScope() {
        return runtimeScope;
    }

    /**
     * Get the shared scope
     */
    public Scriptable getSharedJavaScriptScope() {
        return sharedScope;
    }

    /**
     * Check that a plugin with a given privilege is active, throwing a reportable exception otherwise
     */
    public static void privilegeRequired(String privilege, String attemptedAction) {
        if(!(Runtime.currentRuntimeHost().getSupportRoot().currentlyExecutingPluginHasPrivilege(privilege))) {
            throw new OAPIException("Cannot "+attemptedAction+" without the "+privilege+" privilege. Add it to privilegesRequired in plugin.json");
        }
    }

    /**
     * Create a new host object in the Runtime in use on the current thread,
     * finding the correct scope to create the object in. (Avoids the sealed
     * shared scope, which is the only easy one to find with the the Rhino API.)
     */
    static public Scriptable createHostObjectInCurrentRuntime(String constructorName, Object... constructorArguments) {
        Runtime runtime = threadRuntime.get();
        if(runtime == null) {
            throw new RuntimeException("No JavaScript runtime in use on this thread");
        }
        return runtime.createHostObject(constructorName, constructorArguments);
    }

    /**
     * Create a new host object in this Runtime.
     */
    public Scriptable createHostObject(String constructorName, Object... constructorArguments) {
        checkContext();
        return currentContext.newObject(runtimeScope, constructorName, constructorArguments);
    }

    /**
     * Get a JSON parser which creates objects in the correct scope.
     */
    public JsonParser makeJsonParser() {
        checkContext();
        return new JsonParser(this.currentContext, this.runtimeScope);
    }

    /**
     * Stringify a JavaScript object in the current scope
     */
    public String jsonStringify(Object object) {
        checkContext();
        ScriptableObject json = (ScriptableObject)sharedScope.get("JSON", this.runtimeScope); // ConsString is checked
        Function stringify = (Function)json.get("stringify"); // ConsString is checked
        Object result = stringify.call(this.currentContext, this.runtimeScope, this.runtimeScope, new Object[]{object}); // ConsString is checked
        if(result == null || !(result instanceof CharSequence)) {
            throw new RuntimeException("Couldn't JSON stringify JavaScript object");
        }
        return ((CharSequence)result).toString();
    }

    /**
     * A subsitute for the Rhino Context.enter() which sets up options for the
     * context.
     */
    private static Context enterContext() {
        Context cx = Context.enter();
        return cx;
    }

    /**
     * Check that the Runtime is set up correctly for the current thread
     */
    private void checkContext() {
        if(currentContext == null) {
            throw new RuntimeException("JavaScript Runtime must call useOnThisThread() before being used.");
        }
        if(currentContext != Context.getCurrentContext()) {
            throw new RuntimeException("JavaScript Runtime is being used on the wrong thread.");
        }
    }

    // Don't use the default ContextFactory
    static {
        ContextFactory.initGlobal(new OContextFactory());
    }

    /**
     * Initialize the shared JavaScript environment. Loads libraries and removes
     * methods of escaping the sandbox.
     */
    public static void initializeSharedEnvironment(String frameworkRoot) throws java.io.IOException {
        // Don't allow this to be called twice
        if(sharedScope != null) {
            return;
        }

        long startTime = System.currentTimeMillis();

        final Context cx = Runtime.enterContext();
        try {
            final ScriptableObject scope = cx.initStandardObjects(null, false /* don't seal the standard objects yet */);

            if(!scope.has("JSON", scope)) {
                throw new RuntimeException("Expecting built-in JSON support in Rhino, check version is at least 1.7R3");
            }

            if(standardTemplateLoader == null) {
                throw new RuntimeException("StandardTemplateLoader for Runtime hasn't been set.");
            }
            String standardTemplateJSON = standardTemplateLoader.standardTemplateJSON();
            scope.put("$STANDARDTEMPLATES", scope, standardTemplateJSON);

            // Load the library code
            FileReader bootScriptsFile = new FileReader(frameworkRoot + "/lib/javascript/bootscripts.txt");
            LineNumberReader bootScripts = new LineNumberReader(bootScriptsFile);
            String scriptFilename = null;
            while((scriptFilename = bootScripts.readLine()) != null) {
                FileReader script = new FileReader(frameworkRoot + "/" + scriptFilename);
                cx.evaluateReader(scope, script, scriptFilename, 1, null /* no security domain */);
                script.close();
            }
            bootScriptsFile.close();

            // Load the list of allowed globals
            FileReader globalsWhitelistFile = new FileReader(frameworkRoot + "/lib/javascript/globalswhitelist.txt");
            HashSet<String> globalsWhitelist = new HashSet<String>();
            LineNumberReader whitelist = new LineNumberReader(globalsWhitelistFile);
            String globalName = null;
            while((globalName = whitelist.readLine()) != null) {
                String g = globalName.trim();
                if(g.length() > 0) {
                    globalsWhitelist.add(g);
                }
            }
            globalsWhitelistFile.close();

            // Remove all the globals which aren't allowed, using a whitelist            
            for(Object propertyName : scope.getAllIds()) // the form which includes the DONTENUM hidden properties
            {
                if(propertyName instanceof String) // ConsString is checked
                {
                    // Delete any property which isn't in the whitelist
                    if(!(globalsWhitelist.contains(propertyName))) {
                        scope.delete((String)propertyName); // ConsString is checked
                    }
                } else {
                    // Not expecting any other type of property name in the global namespace
                    throw new RuntimeException("Not expecting global JavaScript scope to contain a property which isn't a String");
                }
            }

            // Run through the globals again, just to check nothing escaped
            for(Object propertyName : scope.getAllIds()) {
                if(!(globalsWhitelist.contains(propertyName))) {
                    throw new RuntimeException("JavaScript global was not destroyed: " + propertyName.toString());
                }
            }
            // Run through the whilelist, and make sure that everything in it exists
            for(String propertyName : globalsWhitelist) {
                if(!scope.has(propertyName, scope)) {
                    // The whitelist should only contain non-host objects created by the JavaScript source files.
                    throw new RuntimeException("JavaScript global specified in whitelist does not exist: " + propertyName);
                }
            }
            // And make sure java has gone, to check yet again that everything expected has been removed
            if(scope.get("java", scope) != Scriptable.NOT_FOUND) {
                throw new RuntimeException("JavaScript global 'java' escaped destruction");
            }

            // Seal the scope and everything within in, so nothing else can be added and nothing can be changed
            // Asking initStandardObjects() to seal the standard library doesn't actually work, as it will leave some bits
            // unsealed so that decodeURI.prototype.pants = 43; works, and can pass information between runtimes.
            // This recursive object sealer does actually work. It can't seal the main host object class, so that's
            // added to the scope next, with the (working) seal option set to true.
            HashSet<Object> sealedObjects = new HashSet<Object>();
            recursiveSealObjects(scope, scope, sealedObjects, false /* don't seal the root object yet */);
            if(sealedObjects.size() == 0) {
                throw new RuntimeException("Didn't seal any JavaScript globals");
            }

            // Add the host object classes. The sealed option works perfectly, so no need to use a special seal function.
            defineSealedHostClass(scope, KONEISHost.class);
            defineSealedHostClass(scope, KObjRef.class);
            defineSealedHostClass(scope, KScriptable.class);
            defineSealedHostClass(scope, KLabelList.class);
            defineSealedHostClass(scope, KLabelChanges.class);
            defineSealedHostClass(scope, KLabelStatements.class);
            defineSealedHostClass(scope, KDateTime.class);
            defineSealedHostClass(scope, KObject.class);
            defineSealedHostClass(scope, KText.class);
            defineSealedHostClass(scope, KQueryClause.class);
            defineSealedHostClass(scope, KQueryResults.class);
            defineSealedHostClass(scope, KPluginAppGlobalStore.class);
            defineSealedHostClass(scope, KPluginResponse.class);
            defineSealedHostClass(scope, KTemplatePartialAutoLoader.class);
            defineSealedHostClass(scope, KAuditEntry.class);
            defineSealedHostClass(scope, KAuditEntryQuery.class);
            defineSealedHostClass(scope, KUser.class);
            defineSealedHostClass(scope, KUserData.class);
            defineSealedHostClass(scope, KWorkUnit.class);
            defineSealedHostClass(scope, KWorkUnitQuery.class);
            defineSealedHostClass(scope, KEmailTemplate.class);
            defineSealedHostClass(scope, KBinaryData.class);
            defineSealedHostClass(scope, KUploadedFile.class);
            defineSealedHostClass(scope, KStoredFile.class);
            defineSealedHostClass(scope, KJob.class);
            defineSealedHostClass(scope, KSessionStore.class);

            defineSealedHostClass(scope, KSecurityRandom.class);
            defineSealedHostClass(scope, KSecurityBCrypt.class);
            defineSealedHostClass(scope, KSecurityDigest.class);
            defineSealedHostClass(scope, KSecurityHMAC.class);

            defineSealedHostClass(scope, JdNamespace.class);
            defineSealedHostClass(scope, JdTable.class);
            defineSealedHostClass(scope, JdSelectClause.class);
            defineSealedHostClass(scope, JdSelect.class, true /* map inheritance */);

            defineSealedHostClass(scope, KGenerateTable.class);
            defineSealedHostClass(scope, KGenerateXLS.class, true /* map inheritance */);

            defineSealedHostClass(scope, KRefKeyDictionary.class);
            defineSealedHostClass(scope, KRefKeyDictionaryHierarchical.class, true /* map inheritance */);
            defineSealedHostClass(scope, KCheckingLookupObject.class);

            defineSealedHostClass(scope, KCollaborationService.class);
            defineSealedHostClass(scope, KCollaborationFolder.class);
            defineSealedHostClass(scope, KCollaborationItemList.class);
            defineSealedHostClass(scope, KCollaborationItem.class);

            defineSealedHostClass(scope, KAuthenticationService.class);

            // Seal the root now everything has been added
            scope.sealObject();

            // Check JavaScript TimeZone
            checkJavaScriptTimeZoneIsGMT();

            sharedScope = scope;
        } finally {
            cx.exit();
        }

        initializeSharedEnvironmentTimeTaken = System.currentTimeMillis() - startTime;
    }

    // For logging
    static public long initializeSharedEnvironmentTimeTaken = 0;

    private static void recursiveSealObjects(ScriptableObject object, ScriptableObject scope, HashSet<Object> seen, boolean sealThisObject) {
        // Avoid infinite recursion
        if(seen.contains(object)) {
            return;
        }
        seen.add(object);

        for(Object propertyName : object.getAllIds()) {
            // Seal any getter or setters
            boolean foundGetter = false;
            if(propertyName instanceof String) // ConsString is checked -- property names are always proper Strings
            {
                for(int s = 0; s <= 1; s++) {
                    boolean setter = (s == 0);
                    Object gs = object.getGetterOrSetter((String)propertyName, 0, setter); // ConsString is checked
                    if(gs != null && gs instanceof ScriptableObject) {
                        if(!setter) {
                            foundGetter = true;
                        }
                        recursiveSealObjects((ScriptableObject)gs, scope, seen, true);
                    }
                }
            }
            // If there wasn't a getter, seal the property
            if(!foundGetter) {
                Object property = null;
                if(propertyName instanceof String) // ConsString is checked
                {
                    property = object.get((String)propertyName, scope); // ConsString is checked
                } else if(propertyName instanceof Integer) {
                    property = object.get(((Integer)propertyName).intValue(), scope);
                }
                if(property != null && property instanceof ScriptableObject) {
                    recursiveSealObjects((ScriptableObject)property, scope, seen, true);
                }
            }
        }
        // Seal the prototype too?
        Scriptable prototype = object.getPrototype();
        if(prototype != null && prototype instanceof ScriptableObject) {
            recursiveSealObjects((ScriptableObject)prototype, scope, seen, true);
        }
        // Seal the parent scope?
        Scriptable parentScope = object.getParentScope();
        if(parentScope != null && parentScope instanceof ScriptableObject) {
            recursiveSealObjects((ScriptableObject)parentScope, scope, seen, true);
        }

        // Seal this object
        if(sealThisObject) {
            object.sealObject();
        }
    }

    // Define a sealed class for a given host object class
    private static <T extends Scriptable> void defineSealedHostClass(ScriptableObject scope, Class<T> klass) {
        defineSealedHostClass(scope, klass, false);
    }

    private static <T extends Scriptable> void defineSealedHostClass(ScriptableObject scope, Class<T> klass, boolean mapInheritance) {
        try {
            scope.defineClass(scope, klass, true, mapInheritance);
        } catch(Exception e) {
            throw new RuntimeException("Can't define JavaScript host class for " + klass.getName(), e);
        }
    }

    public Object callSharedScopeJSClassFunction(String jsClassName, String jsFunctionName, Object[] args) {
        Scriptable jsPluginClass = JsGet.scriptable(jsClassName, this.sharedScope);
        if(jsPluginClass == null) {
            throw new OAPIException("Unexpected modification of JavaScript runtime");
        }
        Function fn = (Function)JsGet.objectOfClass(jsFunctionName, jsPluginClass, Function.class);
        if(fn == null) {
            throw new OAPIException("Unexpected modification of JavaScript runtime");
        }
        Object r = null;
        try {
            r = fn.call(this.currentContext, this.runtimeScope, fn, args);
        } catch(StackOverflowError e) {
            // JRuby 1.7.19 doesn't cartch StackOverflowError exceptions any more, so wrap it into a JS Exception
            throw new org.mozilla.javascript.WrappedException(e);
        }
        return r;
    }

    public PluginTestingSupport getTestingSupport() throws java.io.IOException {
        if(testingSupport == null) {
            // Make a testing object accessible by defining it as a sealed class
            defineSealedHostClass((ScriptableObject)runtimeScope, PluginTestingSupport.class);
            PluginTestingSupport obj = (PluginTestingSupport)currentContext.newObject(runtimeScope, "$TESTSUPPORT");
            runtimeScope.put("$TEST", runtimeScope, obj);
            // TODO: Load plugin testing support more elegantly in JavaScript runtimes
            this.loadScript("lib/javascript/lib/testing/testing_support.js", "testing/testing_support.js", null, null);
            testingSupport = obj;
        }
        return testingSupport;
    }

    private static void checkJavaScriptTimeZoneIsGMT() {
        // Check that the timezone is GMT - datetime.js has created a Date object to run static initializers.
        // This is specific to the exact version of the Rhino implementation, but should fail gracefully if it's changed.
        boolean nativeDateTimeZoneOK = false;
        try {
            java.lang.Class nativeDate = java.lang.Class.forName("org.mozilla.javascript.NativeDate");
            java.lang.reflect.Field nativeDateTimeZoneField = nativeDate.getDeclaredField("thisTimeZone");
            nativeDateTimeZoneField.setAccessible(true);
            java.util.TimeZone tz = (java.util.TimeZone)nativeDateTimeZoneField.get(null);
            java.lang.reflect.Field nativeDateLocalTZAField = nativeDate.getDeclaredField("LocalTZA");
            nativeDateLocalTZAField.setAccessible(true);
            if(tz != null && (tz.getID().equals("GMT0") || tz.getID().equals("GMT") || tz.getID().equals("UTC")) && nativeDateLocalTZAField.getDouble(null) == 0.0) {
                nativeDateTimeZoneOK = true;
            }
        } catch(Exception e) {
            // Ignore, nativeDateTimeZoneOK won't be set to true.
        }
        if(!nativeDateTimeZoneOK) {
            System.out.println("\n\nThe operating system's time zone must be set to GMT (GMT0 Java TimeZone).\n");
            throw new RuntimeException("JavaScript interpreter's local time zone is not GMT (GMT0 Java TimeZone).");
        }
    }

    // Date library support
    public boolean isAcceptedJavaScriptDateObject(Object value) {
        if(value == null) {
            return false;
        }
        ScriptableObject o = (ScriptableObject)sharedScope.get("O", sharedScope); // ConsString is checked
        Function checker = (Function)o.get("$isAcceptedDate", o);
        Object result = checker.call(this.currentContext, o, o, new Object[]{value}); // ConsString is checked
        return (result instanceof Boolean) && ((Boolean)result).booleanValue();
    }

    public Object convertIfJavaScriptLibraryDate(Object value) {
        if(value == null) {
            return null;
        }
        ScriptableObject o = (ScriptableObject)sharedScope.get("O", sharedScope); // ConsString is checked
        Function converter = (Function)o.get("$convertIfLibraryDate", o);
        return converter.call(this.currentContext, o, o, new Object[]{value});
    }

    // Find plugin on stack
    public static String findCurrentlyExecutingPluginFromStack() {
        ScriptStackElement[] stack = (new JavaScriptException("a","b",-1)).getScriptStack();
        for(ScriptStackElement e : stack) {
            // Does the filename exist and start with p/ ?
            String f = e.fileName;
            if((f != null) && (f.length() > 3) && (f.charAt(0) == 'p') && (f.charAt(1) == '/')) {
                // Find the plugin name from the pathname
                int nextSlashIndex = f.indexOf('/', 2);
                if(nextSlashIndex > 4) {
                    return f.substring(2, nextSlashIndex);
                }
            }
        }
        return null;
    }
}
