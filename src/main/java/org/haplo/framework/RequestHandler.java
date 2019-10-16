/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.framework;

import java.io.*;
import java.util.Formatter;
import java.util.Enumeration;
import java.util.List;

import javax.net.ssl.SSLSession;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.ServletInputStream;

import org.eclipse.jetty.server.Handler;
import org.eclipse.jetty.server.HttpConnection;
import org.eclipse.jetty.server.Request;
import org.eclipse.jetty.server.Handler;
import org.eclipse.jetty.server.handler.AbstractHandler;
import org.eclipse.jetty.server.InclusiveByteRange;

import org.apache.log4j.Logger;

import org.haplo.appserver.*;
import org.haplo.utils.LimitedFilterOutputStream;

/**
 * Request handler for the HTTP server.
 */
public class RequestHandler extends AbstractHandler {
    public static final int MAX_IN_MEMORY_BODY_SIZE = 1024 * 1024; // request handlers need to opt in to large request bodies

    private static final String HEALTH_URL = "/-health/"+System.getProperty("org.haplo.healthurl");

    private Framework framework;
    private boolean inDevelopmentMode;
    private long lastReloadCheck;
    private Logger logger;

    /**
     * Constructor
     *
     * @param runtime Ruby runtime started and initialised by the Boot process
     * @param framework The Ruby framework object used to handle requests
     * @param inDevelopmentMode Whether or not the app server is running in
     * development mode; reloads code, serves static files differently, etc
     */
    public RequestHandler(Framework framework, boolean inDevelopmentMode) {
        this.framework = framework;
        this.inDevelopmentMode = inDevelopmentMode;
        this.logger = Logger.getLogger("org.haplo.http");
    }

    /**
     * As interface
     */
    public void handle(String target, Request baseRequest, HttpServletRequest request, HttpServletResponse servletResponse) throws IOException, ServletException {
        baseRequest.setHandled(true);

        try {
            handle2(target, baseRequest, request, servletResponse);
        } catch(Exception e) {
            // Return some sort of response, ignoring errors
            try {
                String response = "<html><body><h1>Internal server error</h1></body></html>";
                if(e instanceof LimitedFilterOutputStream.LimitExceededException) {
                    response = "<html><body><h1>Request size limit exceeded</h1></body></html>";
                }
                servletResponse.setContentType("text/html; charset=utf-8");
                servletResponse.setStatus(500);
                OutputStream os = servletResponse.getOutputStream();
                os.write(response.getBytes("UTF-8"));
            } catch(Exception x1) {
                // Ignore
            }

            // Log the request, minimum information
            String requestLogLine = "?";
            try {
                requestLogLine = logRequest(baseRequest, request, servletResponse, 500, null, 0, 0, false, -1, -1);
            } catch(Exception x) {
                requestLogLine = "(exception occurred when logging request)";
            }

            // Create a string containing an error message and the backtrace
            String logMessage = "EXCEPTION " + e.toString() + "\n  while handling request: " + requestLogLine + "\n";
            StackTraceElement[] trace = e.getStackTrace();
            for(StackTraceElement b : trace) {
                logMessage += "  at ";
                logMessage += b.toString();
                logMessage += "\n";
            }

            Logger.getLogger("org.haplo.app").error(logMessage);
        }
    }

    /**
     * Handle for request
     */
    private void handle2(String target, Request baseRequest, HttpServletRequest request, HttpServletResponse servletResponse) throws IOException, ServletException {
        // Performance timer
        long startTime = System.currentTimeMillis();
        long frameworkHandleTime = 0;

        if(inDevelopmentMode) {
            developmentModeReloadCheck();
        }

        Response response = null;

        String hostname = request.getHeader("Host");
        if(hostname == null) {
            hostname = "--NO-HOSTNAME-IN-REQUEST"; // an invalid hostname!
        }
        // Strip any port number
        int portSeparator = hostname.lastIndexOf(':');
        if(portSeparator != -1) {
            hostname = hostname.substring(0, portSeparator);
        }

        Application app = Application.fromHostname(hostname);

        boolean isStaticResponse = false;
        if(response == null) {
            response = handleSpecial(baseRequest, request, app);
            if(response != null) {
                isStaticResponse = response.getBehavesAsStaticFile();
            }
        }

        // If the app isn't known, send an appropraite response.
        if(response == null && app == null) {
            response = GlobalStaticFiles.findStaticFile("404app.html");
            if(response == null) {
                throw new RuntimeException("couldn't find 404app.html static file");
            }
        }

        // Stop OPTIONS now
        if(response == null && request.getMethod().equals("OPTIONS")) {
            response = GlobalStaticFiles.findStaticFile("OPTIONS.html");
            if(response == null) {
                throw new RuntimeException("couldn't find OPTIONS.html static file");
            }
        }

        // Special handling for file uploads - ask the framework what to do with it, then decode the files as they're streamed in
        FileUploads fileUploads = null;
        if(response == null && request.getMethod().equals("POST")) {
            fileUploads = FileUploads.createIfUploads(request);
            if(fileUploads != null) {
                // Get details of what to do with the file uploads from the framework
                long frameworkStartTime = System.currentTimeMillis();
                Response r = readRequestBodyAndreadRequestBodyAndHandleWithFramework(baseRequest, request, app, fileUploads);
                frameworkHandleTime += System.currentTimeMillis() - frameworkStartTime;

                // Check the handler didn't return any content
                if(r.getContentLength() != 0) {
                    // Is this a reportable error that should be let through? (for JavaScript dev mode and file upload handlers)
                    String header = r.getFirstHeader("X-Haplo-Reportable-Error");
                    if(header != null && header.equals("yes")) {
                        // If it is, use the response to inform the developer.
                        response = r;
                    } else {
                        throw new RuntimeException("Framework handler returned content when asked for file upload instructions");
                    }
                } else {
                    // Do the hard work in uploading, decoding and processing the files
                    try {
                        fileUploads.performUploads(request);
                    } catch(FileUploads.UserReportableFileUploadException e) {
                        // This error can be reported to the user (for debugging applications)
                        // Create a very simple response with the text of the exception.
                        // Be paranoid and remove any angle brackets, even though the mime type is text.
                        response = new DataResponse(e.getMessage().replace("<", "&lt;").replace(">", "&gt;").getBytes("UTF-8"), 400 /* Bad Request */);
                        response.addHeader("Content-Type", "text/plain");
                        Logger.getLogger("org.haplo.app").error("While handling " + target + ", got UserReportableFileUploadException: " + e.getMessage());
                    }
                }
            }
        }

        // SAML2 integration needs special handling
        if(response == null && target.startsWith("/do/saml2-sp/")) {
            final String hostname2 = hostname; // needs to be final for lambda expression
            withPerApplicationRequestThrottle(app, () -> {
                framework.handleSaml2IntegrationFromJava(target, request, servletResponse, app);
                long handleTime = System.currentTimeMillis() - startTime;
                logRequest(baseRequest, request, servletResponse, 0, hostname2, 0, 0, false, handleTime, handleTime);
                return null;
            });
            return;
        }

        // Get the Ruby framework to handle the request if nothing else handled it
        if(response == null) {
            long frameworkStartTime = System.currentTimeMillis();
            response = readRequestBodyAndreadRequestBodyAndHandleWithFramework(baseRequest, request, app, fileUploads);
            frameworkHandleTime += System.currentTimeMillis() - frameworkStartTime;
        }

        // Continuation support
        if(response != null && response.isSuspended()) {
            // The request handling has been suspended using a Jetty continuation.
            // Log the progress made so far, and return without writing anything to the response.
            logRequest(baseRequest, request, servletResponse, 0, hostname, 0, 0, false, System.currentTimeMillis() - startTime, frameworkHandleTime);
            return;
        }

        if(fileUploads != null) {
            fileUploads.cleanUp();
        }

        response.applyHeadersTo(servletResponse);

        Enumeration<String> reqRanges = request.getHeaders("Range");
        if(reqRanges == null || !(reqRanges.hasMoreElements())) {
            reqRanges = null;
        }

        // TODO: Don't gzip responses if the content-type is an image (?)
        // gzip encoding handling
        long responseContentLength = response.getContentLength();
        long uncompressedContentLength = responseContentLength;
        boolean willGzip = false;
        // Headers allow gzipping?
        String acceptEncoding = request.getHeader("Accept-Encoding");
        if(reqRanges == null && // Response won't gzip if a range is requested
                acceptEncoding != null && acceptEncoding.indexOf("gzip") != -1) // not quite the best way of doing it, but sufficient for these purposes
        {
            // Can the response do gzipping?
            long gzipContentLength = response.getContentLengthGzipped();
            if(gzipContentLength != Response.NOT_GZIPABLE) {
                // Client can do gzipping, and so can the response. Set everything accordingly,
                // but only if it's acceptable to compress this response.
                if(isAcceptableToGzipResponse(response)) {
                    responseContentLength = gzipContentLength;
                    willGzip = true;
                    servletResponse.setHeader("Content-Encoding", "gzip");
                }
            }
        }

        // Safari likes to have Date headers
        String userAgent = request.getHeader("User-Agent");
        if(userAgent != null && userAgent.indexOf("Safari") != -1) {
            servletResponse.setDateHeader("Date", startTime);
        }

        // IE needs extra headers to prevent it ignoring the MIME types - works with IE8 upwards
        // and to stop the IE "compatibility view" option from potentially messing things up.
        if(userAgent != null && userAgent.indexOf("MSIE") != -1 && response.getResponseCode() == 200) {
            servletResponse.setHeader("X-Content-Type-Options", "nosniff");
            servletResponse.setHeader("X-UA-Compatible", "IE=Edge");
        }

        // Send response
        int responseCode = response.getResponseCode();
        if(request.getMethod().equals("HEAD")) {
            // HEAD request; no content
            servletResponse.setStatus(responseCode);
            responseContentLength = 0;
            uncompressedContentLength = 0;
        } else if(isStaticResponse && ((request.getHeader("If-None-Match") != null) || (request.getHeader("If-Modified-Since") != null))) {
            // Static responses never change, so any request from a client which includes these headers is for an unmodified resource.
            responseCode = 304;
            servletResponse.setStatus(responseCode);
            responseContentLength = 0;
            uncompressedContentLength = 0;
        } else {
            // ETag for static files?
            if(isStaticResponse) {
                // Use the pathname as a basis for the etag.
                servletResponse.setHeader("ETag", Integer.toHexString(target.hashCode() & 0xfffff));
            }

            // Going to send ranges?
            List<InclusiveByteRange> ranges = null;
            if(reqRanges != null && response.supportsRanges()) {
                // Decode ranges
                ranges = InclusiveByteRange.satisfiableRanges(reqRanges, responseContentLength);

                // If there are no satisfiable ranges (or more than one range), send 416 response
                // TODO: Implement multiple ranges support, see Jetty's DefaultServlet.
                if(ranges == null || ranges.size() != 1) {
                    responseCode = 416;
                    servletResponse.setHeader("Content-Range", InclusiveByteRange.to416HeaderRangeString(responseContentLength));
                    ranges = null;  // unset so entire response is written
                } else {
                    responseCode = 206; // partial content
                    InclusiveByteRange singleSatisfiableRange = ranges.get(0);
                    servletResponse.setHeader("Content-Range", singleSatisfiableRange.toHeaderRangeString(responseContentLength));
                    responseContentLength = singleSatisfiableRange.getSize();
                }
            }

            // Set the response and content-length
            servletResponse.setStatus(responseCode);
            if(responseContentLength != Response.CONTENT_LENGTH_UNCERTAIN
                    && responseContentLength != 0
                    && responseContentLength < (Integer.MAX_VALUE - 1)) {
                servletResponse.setContentLength((int)responseContentLength);
            }

            // Write body
            response.writeToServletResponse(servletResponse, willGzip, ranges);
        }

        long timeTakenForRequest = System.currentTimeMillis() - startTime;

        logRequest(baseRequest, request, servletResponse, responseCode, hostname, responseContentLength, uncompressedContentLength, willGzip, timeTakenForRequest, frameworkHandleTime);
    }

    /**
     * Check to see if it's OK to gzip a response.
     */
    private boolean isAcceptableToGzipResponse(Response response) {
        // MIME type?
        String mimeType = response.getFirstHeader("Content-Type");
        if(mimeType != null) {
            String m = mimeType.toLowerCase();
            if(m.startsWith("audio/") || m.startsWith("video/")) {
                // FireFox breaks with gzipped MP3 files. There's probably not much point in gzipping very compressed
                // files anyway, so don't bother if it's an audio or video file.
                return false;
            }
        }
        return true;
    }

    /**
     * Logs info about an http request.
     *
     * @return Log message string
     */
    private String logRequest(Request baseRequest, HttpServletRequest request, HttpServletResponse servletResponse, int responseCode, String hostname, long sentContentLength, long uncompressedContentLength, boolean gzip, long timeTakenForRequest, long frameworkHandleTime) {
        // Get info from request headers
        String referer = request.getHeader("Referer");
        if(referer == null) {
            referer = "-";
        }
        String userAgent = request.getHeader("User-Agent");
        if(userAgent == null) {
            userAgent = "-";
        }
        if(hostname == null) {
            hostname = request.getHeader("Host");
            if(hostname == null) {
                hostname = "-";
            }
        }

        // SSL?
        String cipher = "-";
        if(isRequestSSL(baseRequest)) {
            SSLSession sslSession = (SSLSession)request.getAttribute("org.eclipse.jetty.servlet.request.ssl_session");
            String tlsversion = "";
            if(sslSession != null) {
                tlsversion =sslSession.getProtocol();
            }
            String ncipher = (String)baseRequest.getAttributes().getAttribute("javax.servlet.request.cipher_suite");
            if(ncipher == null) {
                ncipher = "unknown";
            }
            cipher = tlsversion + ":" + ncipher;
        }

        // Reconstruct the URI
        String queryString = request.getQueryString();
        String requestURI = (queryString == null) ? request.getRequestURI() : String.format("%s?%s", request.getRequestURI(), queryString);

        String logMessage = String.format("%s %s %s %s %d %d %d %s %d %d %s \"%s\" \"%s\"",
                baseRequest.getHttpChannel().getRemoteAddress().getAddress().getHostAddress(), // Remote address (convoluted to avoid reverse DNS lookup)
                hostname, // Hostname
                request.getMethod(), // Method
                requestURI, // Request path + GET query
                responseCode, // Response code
                sentContentLength, // Content-Length sent
                uncompressedContentLength, // Compressed content-length
                gzip ? "gz" : "i", // encoding
                timeTakenForRequest, // Time in milliseconds (includes network transfer etc)
                frameworkHandleTime, // Time in milliseconds (may be 0 if framework not used)
                cipher, // Which SSL cipher suite?
                referer.replace("\"", "\\\""), // Referer URL
                userAgent.replace("\"", "\\\"") // User agent
        );
        logger.info(logMessage);
        return logMessage;
    }

    /**
     * Special request handling for static files and health URL handling
     */
    private Response handleSpecial(Request baseRequest, HttpServletRequest request, Application app) {
        Response response = null;

        String requestPath = request.getRequestURI();
        if(requestPath.length() > 1) {
            char f = requestPath.charAt(1);

            // Special handling for favicon.ico
            if(f == 'f' && requestPath.equals("/favicon.ico")) {
                response = GlobalStaticFiles.findStaticFile("favicon.ico");
            } else {
                // Is there a second slash in the request path, in which case the file might be a static file?
                int secondSlash = requestPath.indexOf('/', 1);
                if(secondSlash != -1) {
                    // Rest of path
                    String filePath = requestPath.substring(secondSlash + 1);

                    // Global static files / health URL
                    if(f == '-') {
                        response = GlobalStaticFiles.findStaticFile(filePath);

                        // Wasn't a known static file, see if it's a valid request for the health URL
                        if(response == null && requestPath.equals(HEALTH_URL)) {
                            response = handleHealthRequest(baseRequest, request);
                        }
                    }

                    // Development mode serves static files from other places too
                    if(inDevelopmentMode) {
                        String firstElement = requestPath.substring(1, secondSlash);
                        if(firstElement.equals("images") || firstElement.equals("stylesheets") || firstElement.equals("javascripts")) {
                            response = GlobalStaticFiles.findStaticFile(filePath);
                        }
                    }

                    // Application static files?
                    if(f == '~' && app != null) {
                        // Get the response, creating it if this is the first time it's been requested.
                        response = app.getDynamicFile(filePath);
                    }
                }
            }
        }

        return response;
    }

    /**
     * Checks the health of the application, and generates a response for the
     * monitoring system.
     */
    private Response handleHealthRequest(Request baseRequest, HttpServletRequest request) {
        String errors = null;

        // Call into Ruby framework to check everything is OK, but only if this is an https request
        if(isRequestSSL(baseRequest)) {
            try {
                errors = framework.checkHealth();
            } catch(Exception e) {
                // An exception was thrown from the Ruby code, so it's obviously not happy.
                errors = "ERROR (exception)";
            }
        }

        // If the concurrency semaphores don't have any permits left, the app will freeze. A semaphore running out is a bad sign.
        String javaErrors = null;
        if(ConcurrencyLimits.rubyRuntime.availablePermits() <= 0) {
            javaErrors = "CONCURRENCY_RUNTIME";
        } else {
            javaErrors = Application.checkAllApplicationConcurrencyLimits();
        }

        if(javaErrors != null) {
            if(errors == null) {
                errors = javaErrors;
            } else {
                errors = errors + ',' + javaErrors;
            }
        }

        if(errors != null) {
            Logger.getLogger("org.haplo.app").error("HEALTH CHECK FAILED: " + errors);
        }

        DataResponse response = new DataResponse(((errors == null) ? "OK" : errors).getBytes());
        response.addHeader("Cache-Control", "private, no-cache");
        return response;
    }

    /**
     * Implement the request throttle
     */
    private Response withPerApplicationRequestThrottle(Application app, ThrottledHandlingAction action) {
        // Don't allow too many concurrent requests on a single application
        // Get the app sempahore first, so lots of requests for an app don't use up the global ruby runtime permits
        app.getRequestConcurrencySempahore().acquireUninterruptibly();
        try {
            // The application caches data which is expensive to recreate, for example, user data and JavaScript runtimes.
            // If requests are made in parallel, multiple "caches" are created so that the caches and runtimes don't have
            // to support concurrency and make it a lot easier to write and reason about the code.
            // To avoid creating unnecessary copies of cached data, delay requests when other requests are being processed,
            // which, if the requests are processed fast enough, limits unnecessary concurrency.
            // The loop increases the chances of a successfully avoiding currency.
            for(int i = ConcurrencyLimits.APPLICATION_CONCURRENT_REQUESTS_MAX_SPINS; i > 0; --i) {
                if(!app.isAnotherRequestBeingProcessed()) {
                    break;
                }
                // Try waiting for a request to finish
                app.waitForARequestToFinish(ConcurrencyLimits.APPLICATION_CONCURRENT_REQUESTS_MAX_WAIT_TIME);
                // TODO: Monitor how many/much requests are getting delayed by request concurrency reduction code.
            }

            // Don't allow too many threads to go use the Ruby runtime at any one time
            ConcurrencyLimits.rubyRuntime.acquireUninterruptibly();
            try {
                return action.respond();
            } finally {
                // Always release the semaphore permit
                ConcurrencyLimits.rubyRuntime.release();
            }
        } finally {
            // Release app permit
            app.getRequestConcurrencySempahore().release();
            // Notify other threads waiting to avoid concurrent requests 
            app.requestFinished();
        }
    }

    private interface ThrottledHandlingAction {
        public Response respond();
    }

    /**
     * Use the Ruby framework to handle the request
     */
    private Response readRequestBodyAndreadRequestBodyAndHandleWithFramework(Request baseRequest, HttpServletRequest request, Application app, FileUploads fileUploads) throws IOException {
        byte[] body = null;
        String bodySpillPathname = null;

        try {
            // Read the body if it's a POST request and FileUploads haven't been triggered
            if(fileUploads == null) {
                // Only read the body if we expect it
                String method = request.getMethod();
                if("POST".equals(method) || "PUT".equals(method)) {
                    // See if there's a request body - but have a maximum amount of data to read
                    int contentLength = -1;
                    String contentLengthAsString = request.getHeader("Content-Length");
                    if(contentLengthAsString != null) {
                        contentLength = Integer.parseInt(contentLengthAsString);
                    }
                    if(contentLength != 0) {
                        // Read the data into a byte array, spilling into a file if it gets too long
                        InputStream bin = request.getInputStream();
                        OutputStream out = null;
                        ByteArrayOutputStream memoryOut = null;
                        boolean shouldSpill = false;
                        if(contentLength == -1) {
                            out = memoryOut = new ByteArrayOutputStream(1024); // unknown input size
                        } else if(contentLength < MAX_IN_MEMORY_BODY_SIZE) {
                            out = memoryOut = new ByteArrayOutputStream(contentLength); // known input size
                        } else {
                            shouldSpill = true; // it's going to be too big for memory, so spill immediately
                            if(!framework.request_large_body_spill_allowed(app.getApplicationID(), method, request.getRequestURI())) {
                                this.logger.error("Throwing exception to prevent reading long body because Content-Length is too long and plugins don't opt-in to large bodies.");
                                throw new RuntimeException("POST/PUT Advertised Content-Length of body is too long.");
                            }
                        }
                        try {
                            byte[] buffer = new byte[4096];
                            int count = 0;
                            int n = 0;
                            while(-1 != (n = bin.read(buffer))) {
                                if(shouldSpill) {
                                    if(!framework.request_large_body_spill_allowed(app.getApplicationID(), method, request.getRequestURI())) {
                                        this.logger.error("Throwing exception to prevent reading long body because too many bytes received and plugins don't opt-in to large bodies.");
                                        throw new RuntimeException("POST/PUT too many bytes read from body.");
                                    }
                                    // Find unused spill filename
                                    String dir = framework.get_directory_for_request_spill_file();
                                    int fileId = 0;
                                    do {
                                        bodySpillPathname = String.format("%1$s/rbs%2$d.%3$d", dir, Thread.currentThread().getId(), fileId++);
                                    } while(!(new File(bodySpillPathname)).createNewFile());
                                    // Replace output stream
                                    out = new FileOutputStream(bodySpillPathname);
                                    // Flush in memory stream to file
                                    if(memoryOut != null) {
                                        out.write(memoryOut.toByteArray());
                                        memoryOut.close();
                                        memoryOut = null;
                                    }
                                    shouldSpill = false;
                                }
                                out.write(buffer, 0, n);
                                count += n;
                                if((memoryOut != null) && (count > MAX_IN_MEMORY_BODY_SIZE)) {
                                    shouldSpill = true;
                                }
                            }

                            // Only pass the in memory byte array to the request handle if it didn't spill
                            if(memoryOut != null) {
                                body = memoryOut.toByteArray();
                            }
                        } finally {
                            out.close();
                        }
                    }
                }
            }

            // Invoke a method on the framework to handle the request
            final byte[] bodyBytes = body;
            final String bodySpillPathname2 = bodySpillPathname;
            return withPerApplicationRequestThrottle(app, () -> {
                // Call into Ruby interpreter
                Response response = framework.handle_from_java(request, app, bodyBytes, bodySpillPathname2, isRequestSSL(baseRequest), fileUploads);
                if(response == null) {
                    throw new RuntimeException("No response from Ruby interpreter");
                }
                return response;
            });

        } finally {
            if(bodySpillPathname != null) {
                File file = new File(bodySpillPathname);
                if(file.exists()) { file.delete(); }
            }
        }
    }

    /**
     * Utility method to find out if the request uses SSL
     */
    private boolean isRequestSSL(Request baseRequest) {
        return (null != baseRequest.getAttributes().getAttribute("javax.servlet.request.ssl_session_id"));
    }

    /**
     * Reloads the Ruby application source code if it's changed.
     *
     * Called in development mode only.
     */
    private void developmentModeReloadCheck() {
        long timeNow = (new java.util.Date()).getTime();
        if(timeNow > (lastReloadCheck + 3000)) {
            lastReloadCheck = timeNow;

            // Call the Ruby framework to see if a reload is necessary
            boolean r = framework.devmodeCheckReload();
            if(r == true) {
                // A reload is required, get the locks and do it!
                try {
                    // Get all the permits from the concurrency lock, so reloads don't happen during requests
                    ConcurrencyLimits.rubyRuntime.acquireUninterruptibly(ConcurrencyLimits.RUBY_RUNTIME_PERMITS);

                    // Call the reload method with the object returned before
                    framework.devmodeDoReload();
                } finally {
                    ConcurrencyLimits.rubyRuntime.release(ConcurrencyLimits.RUBY_RUNTIME_PERMITS);
                }
            }
        }
    }
}
