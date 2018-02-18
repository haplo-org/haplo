/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.framework;

import java.io.*;

import java.util.ArrayList;
import java.util.regex.Pattern;

import javax.net.ssl.*;

import org.jruby.Ruby;
import org.jruby.RubyRuntimeAdapter;
import org.jruby.RubyInstanceConfig;
import org.jruby.javasupport.JavaEmbedUtils;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.RubyNil;

import org.eclipse.jetty.server.Connector;
import org.eclipse.jetty.server.HttpConfiguration;
import org.eclipse.jetty.server.HttpConnectionFactory;
import org.eclipse.jetty.server.SecureRequestCustomizer;
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.server.ServerConnector;
import org.eclipse.jetty.server.SslConnectionFactory;
import org.eclipse.jetty.util.ssl.SslContextFactory;
import org.eclipse.jetty.util.thread.QueuedThreadPool;

import org.apache.log4j.Logger;
import org.apache.log4j.Appender;
import org.apache.log4j.Level;
import org.apache.log4j.PropertyConfigurator;
import org.apache.log4j.varia.LevelRangeFilter;

import org.haplo.common.utils.SSLCertificates;
import org.haplo.common.utils.SSLCipherSuites;

import org.haplo.utils.ProcessStartupFlag;

import org.haplo.appserver.Scheduler;

/**
 * Boot contains the main() function for the framework.
 *
 * Command line arguments: <framework root dir> <environment>
 *
 */
public class Boot {
    /**
     * Starts the application.
     *
     * @param args Command line arguments
     */
    public static void main(String[] args) throws Exception {
        (new Boot()).boot(args);
    }

    // State for the running application server
    private Ruby runtime;
    private RubyRuntimeAdapter rubyEvaluater;
    private Framework framework;
    private Server httpSrv;

    // Port positions in the org.haplo.listen property
    public static final int PORT_INTERNAL_CLEAR = 0;
    public static final int PORT_INTERNAL_ENCRYPTED = 2;

    /**
     * Runs the boot process.
     */
    private void boot(String[] args) throws Exception {
        long bootTime = System.currentTimeMillis();

        if(args.length < 2) {
            System.out.println("Bad arguments");
            return;
        }

        String rootDir = args[0];
        if(rootDir.length() < 2 || rootDir.charAt(0) != '/') {
            System.out.println("Bad root directory");
            return;
        }

        String envName = args[1];
        String envFilename = rootDir + "/config/environments/" + envName + ".rb";
        if(!(new File(envFilename)).exists()) {
            System.out.println("Bad environment name");
            return;
        }

        if(!java.awt.GraphicsEnvironment.isHeadless()) {
            System.err.println("Must run in headless mode, add -Djava.awt.headless=true to the command line");
            return;
        }

        System.out.println("===============================================================================");
        System.out.println("               Haplo Platform (c) Haplo Services Ltd 2006 - 2018");
        System.out.println("             Licensed under the Mozilla Public License Version 2.0");
        System.out.println("===============================================================================");
        System.out.println("Starting framework in " + rootDir + " with environment " + envName);

        // Get a ruby runtime
        RubyInstanceConfig rubyConfig = new RubyInstanceConfig();
        rubyConfig.setExternalEncoding("UTF-8");
        rubyConfig.setInternalEncoding("UTF-8");
        runtime = JavaEmbedUtils.initialize(new ArrayList<String>(), rubyConfig);
        rubyEvaluater = JavaEmbedUtils.newRuntimeAdapter();

        // Set constants in the runtime, then run the boot.rb script
        IRubyObject iro = rubyEvaluater.eval(runtime,
                "KFRAMEWORK_ROOT = '" + rootDir + "'\n"
                + "KFRAMEWORK_ENV = '" + envName + "'\n"
                + "require '" + rootDir + "/framework/boot'\n"
                + "KFRAMEWORK__BOOT_OBJECT");

        // Check the result of the boot evaluation is the expected framework object
        if(iro == null || iro instanceof RubyNil) {
            System.out.println("Failed to obtain Ruby KFramework object when booting");
            return;
        }
        framework = (Framework)iro;

        // Initialise the shared JavaScript environment
        org.haplo.javascript.Runtime.initializeSharedEnvironment(rootDir, framework.pluginDebuggingEnabled());

        // TODO: Pause unless the parent runner asks to start the servers
        // All looks good, continue...
        // Configure logging for the java side
        // This is delayed until the Ruby code has properly started, so that when fast-restart is implemented,
        // the Java logs will be closed by the old process before being opened by the new process.
        PropertyConfigurator.configure(rootDir + "/config/log4j/" + envName + ".properties");
        if(envName.equals("production")) {
            // Add a filter to the ERRORS appender so that it only includes WARN or above
            Appender appender = Logger.getLogger("org.haplo").getAppender("ERRORS");
            if(appender != null) {
                LevelRangeFilter filter = new LevelRangeFilter();
                filter.setLevelMin(Level.WARN);
                appender.addFilter(filter);
            }
        }

        Logger logger = Logger.getLogger("org.haplo.app");
        logger.info("Application loaded (took " + (System.currentTimeMillis() - bootTime) + "ms), logging started.");
        logger.info("JavaScript initialisation took " + org.haplo.javascript.Runtime.initializeSharedEnvironmentTimeTaken + "ms");

        Application.setDynamicFileFactory(framework.getDynamicFileFactory());

        Scheduler.start(framework);

        OperationRunner.start(framework, envName.equals("production"));

        framework.startApplication();

        boolean inDevelopmentMode = (envName.equals("development"));

        // SSL certificates
        SSLContext publicSSLContext = loadSSLCerticates(envName, "server", null);
        if(publicSSLContext == null) {
            System.out.println("Failed to load public SSL certificates");
            return;
        }

        // Thread pool for Jetty
        QueuedThreadPool jettyThreadPool = new QueuedThreadPool(128 /* maximum number of threads */);
        jettyThreadPool.setMinThreads(16);
        jettyThreadPool.setMaxThreads(128);

        // Create the public facing HTTP server
        httpSrv = new Server(jettyThreadPool);

        // Server ports
        int[] ports = getConfiguredListeningPorts(envName);

        // Set up HTTP
        HttpConfiguration httpConfig = new HttpConfiguration();
        httpConfig.setSecurePort(ports[PORT_INTERNAL_ENCRYPTED]); // not what it's using now, for redirects
        httpConfig.setSendServerVersion(false);     // don't waste bytes on the server header
        httpConfig.setSendDateHeader(false);
        ServerConnector http = new ServerConnector(httpSrv, new HttpConnectionFactory(httpConfig));
        http.setPort(ports[PORT_INTERNAL_CLEAR]);

        // Set up HTTPS
        SslContextFactory publicSSLContextFactory = new SslContextFactory();
        SSLCipherSuites.configureCipherSuites(publicSSLContextFactory);
        publicSSLContextFactory.setSslContext(publicSSLContext);
        HttpConfiguration httpsConfig = new HttpConfiguration(httpConfig);
        httpsConfig.addCustomizer(new SecureRequestCustomizer());
        // HTTPS connector
        ServerConnector https = new ServerConnector(
                httpSrv,
                new SslConnectionFactory(publicSSLContextFactory, "HTTP/1.1"),
                new HttpConnectionFactory(httpsConfig)
        );
        https.setPort(ports[PORT_INTERNAL_ENCRYPTED]);

        // Set the connectors, request handler, and start the server
        httpSrv.setConnectors(new Connector[]{http, https});
        httpSrv.setHandler(new RequestHandler(framework, inDevelopmentMode));
        httpSrv.start();

        // Test mode?
        if(envName.equals("test")) {
            String testArgs[] = new String[args.length - 2];
            System.arraycopy(args, 2, testArgs, 0, testArgs.length);
            runTests(runtime, testArgs);
            unboot();
            // Terminate the runtime - calls shutdown hooks to terminate everything nicely
            java.lang.Runtime.getRuntime().exit(0);
            // TODO: indicate test pass or not with java process exit code
            return;
        }

        Runtime.getRuntime().addShutdownHook(new ShutdownHook(this));

        logger.info("Ready to handle requests. Boot took " + (System.currentTimeMillis() - bootTime) + "ms");

        ProcessStartupFlag.processIsReady();

        try {
            framework.startBackgroundTasks();
            logger.info("Background tasks started.");
        } catch(Exception e) {
            logger.error("Failed to start background tasks (exception thrown into Java boot).");
        }
    }

    // -------------------------------------------------------------------------------------------------------------------------
    /**
     * Cleanly shuts down the running application server.
     */
    public void unboot() {
        // Log shutdown
        Logger logger = Logger.getLogger("org.haplo.app");
        logger.info("Shutting down application server...");

        // Stop scheduler
        Scheduler.stop();

        // Stop the server components
        try {
            if(httpSrv != null) {
                httpSrv.stop();
            }
        } catch(Exception e) {
            logger.error("Exception while stopping server components: " + e.toString());
        }

        // Ask the framework to stop and save state
        if(framework != null) {
            try {
                framework.stopApplication();
            } catch(Exception e) {
                logger.error("Exception thrown when asking Ruby framework to stop: " + e.toString());
            }
        }

        // Log that everything is complete
        logger.info("Shutdown complete.");
    }

    // -------------------------------------------------------------------------------------------------------------------------
    static class ShutdownHook extends Thread {
        private Boot boot;

        public ShutdownHook(Boot boot) {
            this.boot = boot;
        }

        public void run() {
            try {
                boot.unboot();
            } catch(Exception e) {
                Logger.getLogger("org.haplo.app").error("Caught exception while shutting down " + e.toString());
            }
        }
    }

    // -------------------------------------------------------------------------------------------------------------------------

    public static int[] getConfiguredListeningPorts(String envName) {
        String configuredPortsProperty = System.getProperty("org.haplo.listen."+envName, System.getProperty("org.haplo.listen"));
        if(configuredPortsProperty == null || !(Pattern.matches("\\A\\d+,\\d+,\\d+,\\d+\\z", configuredPortsProperty))) {
            throw new RuntimeException("No org.haplo.listen property defined or invalid string specified");
        }
        String configuredPorts[] = configuredPortsProperty.split(",");
        int ports[] = new int[4];
        for(int l = 0; l < 4; ++l) {
            ports[l] = Integer.valueOf(configuredPorts[l]);
        }
        return ports;
    }

    // -------------------------------------------------------------------------------------------------------------------------
    // Load the certifcates
    public static SSLContext loadSSLCerticates(String envName, String certsName, String clientCAName) {
        try {
            // Which directory should it be stored in?
            String keysDirectory = (envName.equals("production")
                    ? "/haplo/sslcerts" // main certs for everything else
                    : java.lang.System.getProperty("user.home") + "/haplo-dev-support/certificates"); // private certs for everything else mode
            return SSLCertificates.load(keysDirectory, certsName, clientCAName);
        } catch(Exception e) {
            throw new RuntimeException("Failed to load certificates for " + certsName, e);
        }
    }

    // -------------------------------------------------------------------------------------------------------------------------
    private static void runTests(Ruby runtime, String args[]) {
        Logger logger = Logger.getLogger("org.haplo.app");
        logger.info("Ready to start tests.");

        // Run Ruby tests
        try {
            RubyRuntimeAdapter rubyEvaluater = JavaEmbedUtils.newRuntimeAdapter();
            String testCode = "KTEST_ARGS = [";
            for(int i = 0; i < args.length; ++i) {
                if(i != 0) {
                    testCode += ",";
                }
                testCode += "'";
                testCode += args[i].replace("'", "\\'");
                testCode += "'";
            }
            testCode += "]\nrequire 'test/test'";
            rubyEvaluater.eval(runtime, testCode);
        } catch(Exception e) {
            logger.error("Uncaught exception within tests: " + e.toString());
            e.printStackTrace();
        }

        logger.info("Finished tests.");
    }
}
