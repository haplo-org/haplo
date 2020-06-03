/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.framework;

import java.util.Map;
import java.util.HashMap;
import java.util.concurrent.Semaphore;
import java.util.Collection;
import java.util.ArrayList;
import java.util.Set;
import java.util.TreeSet;
import java.util.regex.Pattern;
import java.util.regex.Matcher;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.TimeUnit;

import org.haplo.appserver.Response;

// TODO: For app deletion, make sure the deletion utility calls something to remove the old Application object.
/**
 * Underlying support for multi-tenancy to run multiple "applications" for
 * multiple customers within a single app server.
 *
 * Manages the mapping of hostname to application ID, and maintains cached
 * state.
 */
public class Application {
    // Tracking Application objects globaly
    private static Map<String, Long> hostnameMapping = new AppMap();
    private static volatile HashMap<Long, Application> applications = new HashMap<Long, Application>();
    private static Object applicationsCreateLock = new Object();

    // Application data
    private long applicationID;
    private Object rubyObject;
    private Semaphore requestConcurrencySempahore;
    private Lock requestFinishedLock;
    private Condition requestFinishedCondition;
    private volatile HashMap<String, Response> dynamicFiles; // could probably get away with not being volatile
    private int numAppSpecificStaticFiles;   // the files uploaded by the user for use in styling. -1 means "not set"
    private Set<String> allowedPluginFilePaths;

    /**
     * Get the Application object given a hostname. Creates a new object if
     * required.
     */
    public static Application fromHostname(String hostname) {
        if(hostnameMapping == null) {
            throw new RuntimeException("Hostname mapping not loaded; loadHostnameMapping() needs to be called first.");
        }

        Long applicationID = hostnameMapping.get(hostname.toLowerCase());

        // Look it up (if applicationID == null, it'll return null)
        return fromApplicationID(applicationID);
    }

    /**
     * Given an application ID, return an Application object, creating one
     * (thread safe) if it doesn't exist.
     */
    public static Application fromApplicationID(Long applicationID) {
        if(applicationID == null) {
            return null;
        }

        Application app = applications.get(applicationID);

        if(app == null) {
            // Create a new one; but app creations are syncronised
            synchronized(applicationsCreateLock) {
                // Try to get the value again, in case some other thread added it
                app = applications.get(applicationID);
                if(app == null) {
                    // Still not there, make a new one and store it for later
                    HashMap<Long, Application> newApplications = new HashMap<Long, Application>(applications);
                    app = new Application(applicationID);
                    newApplications.put(applicationID, app);
                    applications = newApplications;
                }
            }
        }

        return app;
    }

    /**
     * Check applications for exceeded concurrency limits
     */
    public static String checkAllApplicationConcurrencyLimits() {
        for(Application app : applications.values()) {
            if(app.getRequestConcurrencySempahore().availablePermits() <= 0) {
                // Too much concurrency - all permits used
                return String.format("CONCURRENCY_APP %d", app.getApplicationID());
            }
        }

        return null;
    }

    /**
     * Forgets about an application, used for app deletion
     */
    public static void forgetApplication(Long applicationID) {
        applications.remove(applicationID.longValue());
    }

    /**
     * For development mode use only, not very efficient
     */
    public static Collection<Application> allLoadedApplicationObjects() {
        return applications.values();
    }

    // ===============================================================================================================================
    // Implementation of Application objects
    /**
     * Constructor, given an application ID.
     */
    private Application(long applicationID) {
        this.applicationID = applicationID;
        this.requestConcurrencySempahore = new Semaphore(ConcurrencyLimits.APPLICATION_CONCURRENT_REQUESTS_PERMITS, true /* sempahore is fair */);
        this.requestFinishedLock = new ReentrantLock(true);
        this.requestFinishedCondition = requestFinishedLock.newCondition();
        this.numAppSpecificStaticFiles = -1;
    }

    /**
     * Returns the application ID.
     */
    public long getApplicationID() {
        return applicationID;
    }

    /**
     * If a ruby object is not set, set the object from the argument. If it is
     * already set, ignore and return the old one. Caller should be careful of
     * thread safety.
     */
    public Object setRubyObject(Object robj) {
        if(rubyObject == null) {
            rubyObject = robj;
        }
        return rubyObject;
    }

    /**
     * Returns the Ruby object. Used by the Ruby side of the framework.
     */
    public Object getRubyObject() {
        return rubyObject;
    }

    /**
     * Returns the semaphore to stop too many concurrent requests for this
     * application.
     */
    public Semaphore getRequestConcurrencySempahore() {
        return requestConcurrencySempahore;
    }

    /**
     * Invalidates all cached app specific dynamic files
     */
    public void invalidateAllDynamicFiles() {
        this.dynamicFiles = null;
    }

    /**
     * Reset the number of app static files, so it's recached next time.
     */
    public void resetNumAppSpecificStaticFiles() {
        this.numAppSpecificStaticFiles = -1;
    }

    /**
     * Reset plugin paths, for when plugins added/removed.
     */
    public void resetAllowedPluginFilePaths() {
        this.allowedPluginFilePaths = null;
    }

    // ===============================================================================================================================
    // Dynamic files
    public interface DynamicFileFactory {
        int numberOfAppStaticFilesFor(long applicationID);

        Set<String> getPluginPathnames(long applicationID);

        Response generate(long applicationID, String filename);
    }

    private static DynamicFileFactory dynamicFileFactory;

    public static void setDynamicFileFactory(DynamicFileFactory factory) {
        dynamicFileFactory = factory;
    }

    private static Set<String> allowedFilenames = new TreeSet<String>();
    private static Pattern appUploadedFilenameTest = Pattern.compile("\\A(\\d+)\\.\\w+\\z");

    /**
     * Set allowed filenames on global startup. Must not be called after app
     * startup as the list is not locked.
     */
    public static void addAllowedFilename(String filename) {
        allowedFilenames.add(filename);
    }

    /**
     * Get a response to a request for an application dynamic file, generating
     * the file if necessary.
     */
    @SuppressWarnings("unchecked")  // Use of Set / Set<String> in JRuby interface
    public Response getDynamicFile(String filename) {
        // Is it an allowed filename? This check avoids giving users the ability to make lots of
        // calls into the Ruby runtime.
        if(!allowedFilenames.contains(filename)) {
            // Not in the main allowed filenames, perhaps it's a file uploaded by the user?
            Matcher matcher = appUploadedFilenameTest.matcher(filename);
            if(matcher.matches()) {
                // Could be a valid app specific file. What's the ID?
                String appFileID = matcher.group(1);

                if(this.numAppSpecificStaticFiles == -1) {
                    // Need to ask the app for this value
                    this.numAppSpecificStaticFiles = dynamicFileFactory.numberOfAppStaticFilesFor(this.applicationID);
                }
                if(Integer.parseInt(appFileID) >= this.numAppSpecificStaticFiles) {
                    // Can't be a valid file, the ID is too high
                    return null;
                }

                // It's a valid app specific file. Use the ID part of the filename *ONLY* so that it's not possible
                // to request lots and lots of files with different extensions to fill up the cache.
                filename = appFileID;
            } else {
                // Perhaps it's a file generated by a plugin?
                if(this.allowedPluginFilePaths == null) {
                    // Ask the Ruby code to generate it, and cache
                    this.allowedPluginFilePaths = dynamicFileFactory.getPluginPathnames(this.applicationID);
                }

                if(!this.allowedPluginFilePaths.contains(filename)) {
                    // Not a plugin file either, stop now without talking to the Ruby code.
                    return null;
                }
            }
        }

        Response response;
        if(this.dynamicFiles != null && (response = dynamicFiles.get(filename)) != null) {
            return response;
        }

        response = dynamicFileFactory.generate(this.applicationID, filename);

        // Store the response, creating a copy to avoid concurrent access. A risk that the same file
        // will be generated lots of times under load, but should settle down.
        HashMap<String, Response> newDynamicFiles = (this.dynamicFiles == null) ? new HashMap<String, Response>() : new HashMap<String, Response>(this.dynamicFiles);
        newDynamicFiles.put(filename, response);
        this.dynamicFiles = newDynamicFiles;

        return response;
    }

    // ===============================================================================================================================
    // Request ending notification and waiting
    /**
     * Is there another request in progress?
     */
    public boolean isAnotherRequestBeingProcessed() {
        // This is called by RequestHandler after it gains a semaphore, so if the count is more than total - 1, something else is working too.
        return requestConcurrencySempahore.availablePermits() < (ConcurrencyLimits.APPLICATION_CONCURRENT_REQUESTS_PERMITS - 1);
    }

    /**
     * Call when a request has finished.
     */
    public void requestFinished() {
        requestFinishedLock.lock();
        try {
            requestFinishedCondition.signal();
        } finally {
            requestFinishedLock.unlock();
        }
    }

    /**
     * Wait for a request to finish
     * returns true if the wait finished early because a request finished
     */
    public boolean waitForARequestToFinish(long timeout) {
        requestFinishedLock.lock();
        try {
            return requestFinishedCondition.await(timeout, TimeUnit.MILLISECONDS);
        } catch(InterruptedException e) {
            return false; // request didn't finish
        } finally {
            requestFinishedLock.unlock();
        }
    }

    // ===============================================================================================================================
    // For Ruby code to set mappings
    // It's necessary to create a subclass so that there's a method with the exact type signature we need to use.
    // Otherwise JRuby will generate objects with the wrong type, as the types on the generics aren't visible to JRuby.
    public static class AppMap extends HashMap<String, Long> {
        public void setMapping(String hostname, Long applicationID) {
            this.put(hostname, applicationID);
        }
    }

    /**
     * Create an empty hostname map. Used by the Ruby code to create the right
     * class of map.
     */
    public static Map<String, Long> createEmptyHostnameMapping() {
        return new AppMap();
    }

    /**
     * Set the new hostname mapping. Called by the Ruby code.
     */
    public static void setHostnameMapping(Map<String, Long> mapping) {
        // Set the new mapping for future calls
        hostnameMapping = mapping;
    }

    // ===============================================================================================================================
    // A similar helper class for the Ruby code to return plugin pathnames
    public static class PluginFilePathnames extends TreeSet<String> {
        public void addAllowedPathname(String path) {
            this.add(path);
        }
    }
}
