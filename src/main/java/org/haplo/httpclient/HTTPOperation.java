/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.httpclient;

import org.haplo.op.Operation;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.UnknownHostException;
import java.net.URISyntaxException;
import java.net.URI;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.charset.Charset;
import java.nio.channels.FileChannel;
import java.nio.file.FileSystems;
import java.nio.file.StandardOpenOption;
import java.security.KeyStore;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Executor;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.CountDownLatch;
import java.util.Base64;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;

import javax.net.ssl.SSLHandshakeException;

import org.eclipse.jetty.client.HttpClient;
import org.eclipse.jetty.client.HttpClientTransport;
import org.eclipse.jetty.client.HttpDestination;
import org.eclipse.jetty.client.HttpContentResponse;
import org.eclipse.jetty.client.api.ContentResponse;
import org.eclipse.jetty.client.api.Request;
import org.eclipse.jetty.client.api.Response;
import org.eclipse.jetty.client.api.Result;
import org.eclipse.jetty.client.http.HttpClientTransportOverHTTP;
import org.eclipse.jetty.client.util.FormContentProvider;
import org.eclipse.jetty.client.util.StringContentProvider;
import org.eclipse.jetty.client.util.BufferingResponseListener;
import org.eclipse.jetty.http.HttpField;
import org.eclipse.jetty.util.Fields;
import org.eclipse.jetty.util.thread.QueuedThreadPool;
import org.eclipse.jetty.util.thread.ScheduledExecutorScheduler;
import org.eclipse.jetty.util.thread.Scheduler;
import org.eclipse.jetty.util.Promise;
import org.eclipse.jetty.util.Callback;
import org.eclipse.jetty.util.SocketAddressResolver;
import org.eclipse.jetty.util.ssl.SslContextFactory;

import org.haplo.template.html.Escape;
import org.haplo.template.html.Context;


public class HTTPOperation extends Operation {

    protected static final int MAX_IN_MEMORY_RESPONSE_SIZE = (32*1024); // relatively small
    protected static final int MAX_ON_DISK_RESPONSE_SIZE = 2147483647; // 2GB should be enough
    // NOTE: Increasing the MAX_ON_DISK_RESPONSE_SIZE limit will require re-implementing Jetty's BufferingResponseListener
    // rather from deriving from it, as it has an int max size, and the onHeader handler checks the content length.

    // Gadgets and gubbins
    QueuedThreadPool executor;
    ScheduledExecutorScheduler scheduler;

    // Inputs
    private String url;
    private String method;
    private String agent;
    private Map<String,List<String>> bodyParams;
    private String bodyType;
    private String bodyString;
    private String bodyPathname;    // file to spill to if response is long
    private Map<String,List<String>> queryParams;
    private Map<String,String> headers;
    private int redirectLimit;
    private List<Pattern> blacklist;

    private boolean httpAuthEnabled;
    private String httpAuthType;
    private String httpAuthUsername;
    private String httpAuthPassword;

    // Outputs
    // Result map is processed in httpclient.rb
    // See there for how to return errors/success, etc
    public Map<String,Object> result;

    public HTTPOperation(Map<String,String> details,
                         Map<String,String> keychain,
                         String bodyPathname,
                         String blacklistString) {
        // The contents of this map match where it's set up in
        // framework.js under O.httpClient
        url = (String)details.get("url");
        method = (String)details.get("method");
        agent = (String)details.get("agent");

        // Key format: [body|query]Param:<index>:<name>=<value>
        // ..the arbitrary index string is used to disambiguate multiple
        // values for the same name
        bodyParams = new HashMap<String,List<String>>();
        for(Map.Entry<String,String> entry : details.entrySet()) {
           if (entry.getKey().startsWith("bodyParam:")) {
               String[] parts = entry.getKey().split(":");
               String key = parts[2];
               if (!bodyParams.containsKey(key)) {
                   bodyParams.put(key, new LinkedList<String>());
               }
               bodyParams.get(key).add(entry.getValue());
           }
        }

        if (details.containsKey("bodyString")) {
            bodyString = details.get("bodyString");
            if (details.containsKey("bodyType")) bodyType = details.get("bodyType");
            else bodyType = "text/plain";
        }
        else {
            bodyString = null;
            bodyType = null;
        }

        queryParams = new HashMap<String,List<String>>();
        for(Map.Entry<String,String> entry : details.entrySet()) {
           if (entry.getKey().startsWith("queryParam:")) {
               String[] parts = entry.getKey().split(":");
               String key = parts[2];
               if (!queryParams.containsKey(key)) {
                   queryParams.put(key, new LinkedList<String>());
               }
               queryParams.get(key).add(entry.getValue());
           }
        }

        headers = new HashMap<String,String>();
        for(Map.Entry<String,String> entry : details.entrySet()) {
           if (entry.getKey().startsWith("header:")) {
               headers.put(entry.getKey().substring(7), entry.getValue());
           }
        }

        redirectLimit = Integer.parseInt((String)details.get("redirectLimit"));

        // TODO: Request body: literal string in request, or file upload.
        // TODO: Cookies, in the same format as cookies returned in responses use.
        // TODO: SSL client/server certs, server SSL requirements

        // Load keychain data
        if(keychain.containsKey("auth_type")) {
            httpAuthEnabled = true;
            httpAuthType = keychain.get("auth_type");
            httpAuthUsername = keychain.get("auth_username");
            httpAuthPassword = keychain.get("auth_password");
        } else {
            httpAuthEnabled = false;
        }

        // Parse blacklist
        blacklist = new LinkedList<Pattern>();
        String[] blacklistEntries = blacklistString.split(",");
        for(String ble : blacklistEntries) {
            blacklist.add(Pattern.compile(ble));
        }
        // Prepare result map
        result = new HashMap<String,Object>();

        this.bodyPathname = bodyPathname;

        executor = null;
        scheduler = null;
    }

    private void start() throws Exception {
        executor = new QueuedThreadPool();
        executor.start();

        scheduler = new ScheduledExecutorScheduler("resolver", false);
        scheduler.start();
    }

    private void stop() throws Exception {
        if(executor != null) {
            executor.stop();
            executor = null;
        }
        if(scheduler != null) {
            scheduler.stop();
            scheduler = null;
        }
    }

    protected void putResult(String key, Object value) {
       if (value != null) result.put(key, value);
    }

    protected void markRequestAsPermanentlyFailed(String reason) {
        putResult("type", "FAIL");
        putResult("errorMessage", reason);
    }

    protected void markRequestAsTemporarilyFailed(String reason) {
        putResult("type", "TEMP_FAIL");
        putResult("errorMessage", reason);
    }

    protected void markRequestAsPermanentlyFailed(Throwable reason) {
        StringBuffer sb = new StringBuffer();
        while(reason != null) {
           sb.append(reason.getMessage());
           if(reason.getCause() != null)
               sb.append(" / ");
           reason = reason.getCause();
        }
        markRequestAsPermanentlyFailed(sb.toString());
    }

    protected void markRequestAsTemporarilyFailed(Throwable reason) {
        StringBuffer sb = new StringBuffer();
        while(reason != null) {
           sb.append(reason.getMessage());
           if(reason.getCause() != null)
               sb.append(" / ");
           reason = reason.getCause();
        }
        markRequestAsTemporarilyFailed(sb.toString());
    }

    protected boolean isRedirect(int status) {
        switch(status) {
        case 301:
        case 302:
        case 303:
        case 307:
            return true;
        default:
            return false;
        }
    }

    protected class ValidatingSocketAddressResolver extends SocketAddressResolver.Async {
        public ValidatingSocketAddressResolver(Executor executor, Scheduler scheduler, long timeout) {
            super(executor, scheduler, timeout);
        }

        public void resolve(String host, int port, Promise<List<InetSocketAddress>> promise) {
            super.resolve(host, port, new Promise<List<InetSocketAddress>>() {
                @Override
                public void succeeded(List<InetSocketAddress> socketAddresses) {
                    for(InetSocketAddress sockaddr : socketAddresses) {
                        InetAddress ip = sockaddr.getAddress();
                        String stringFormOfIP = ip.getHostAddress();
                        for (Pattern p : blacklist) {
                            if(p.matcher(stringFormOfIP).matches()) {
                                promise.failed(new SecurityException("Illegal URL [" + url + "], IP [" + stringFormOfIP + "] is blacklisted."));
                                return;
                            }
                        }
                    }
                    
                    promise.succeeded(socketAddresses);
                }
                @Override
                public void failed(Throwable x) {
                    promise.failed(x);
                }
            });
        }
    }

    protected HttpClient setupHTTPClient() throws Exception {
        SslContextFactory sslContextFactory = new SslContextFactory();
        // TODO: Set up SSL options here from request params, see http://grepcode.com/file/repo1.maven.org/maven2/org.eclipse.jetty/jetty-util/9.2.1.v20140609/org/eclipse/jetty/util/ssl/SslContextFactory.java#SslContextFactory for available options to pick up from the settings.

        // Enable checking of the server's certificate
        sslContextFactory.setEndpointIdentificationAlgorithm("HTTPS");

        // Set up the transport
        HttpClient httpClient = new HttpClient(sslContextFactory);
        httpClient.setFollowRedirects(false);
        httpClient.setRemoveIdleDestinations(true);

        ValidatingSocketAddressResolver resolver = new ValidatingSocketAddressResolver(executor, scheduler, httpClient.getAddressResolutionTimeout());
        httpClient.setSocketAddressResolver(resolver);
        httpClient.start();

        return httpClient;
    }

    protected void insertQueryParamsIntoUrl() {
        // Take the URL supplied by the user, and apply any
        // parameters they have requested in the request settings
        if(queryParams.size() != 0) {
            StringBuilder u = new StringBuilder(url);
            char separator = (url.indexOf('?') != -1) ? '&' : '?';
            for(Map.Entry<String,List<String>> entry : queryParams.entrySet()) {
                for(String value : entry.getValue()) {
                    u.append(separator);
                    separator = '&';
                    Escape.escape(entry.getKey(), u, Context.URL);
                    u.append('=');
                    Escape.escape(value, u, Context.URL);
                }
            }
            url = u.toString();
        }
    }

    protected void initialiseRequestBody(Request request) {
        if(bodyParams.size() != 0) {
            // Construct a body from supplied parameters
            // Do not use request.param, it tries to be smart and
            // makes query or body parameters depending on method,
            // but doesn't set Content-Length for body parameters.
            Fields fields = new Fields();
            for(Map.Entry<String, List<String>> entry : bodyParams.entrySet()) {
                for(String value : entry.getValue()) {
                    fields.add(entry.getKey(), value);
                }
            }
            // TODO: Option to use MultiPartContentProvider instead.
            FormContentProvider fcp = new FormContentProvider(fields, Charset.forName("UTF-8"));
            request.content(fcp, "application/x-www-form-urlencoded");
        } else if(bodyString != null) {
            request.content(new StringContentProvider(bodyType,
                                                      bodyString,
                                                      Charset.forName("UTF-8")));
        }
    }

    protected void initialiseRequestHeaders(Request request) {
        for(Map.Entry<String, String> entry : headers.entrySet()) {
            if(entry.getKey().equalsIgnoreCase("Host"))
                throw new SecurityException("Overriding the Host: header is forbidden.");
            if(entry.getKey().equalsIgnoreCase("Content-Length"))
                throw new SecurityException("Overriding the Content-Length: header is forbidden.");
            request.header(entry.getKey(), entry.getValue());
        }
    }

    protected void initialiseRequestAuthentication(Request request) {
        if(httpAuthEnabled) {
            if(httpAuthType.equalsIgnoreCase("basic")) {
                String authToken = httpAuthUsername + ":" + httpAuthPassword;
                String encodedToken = Base64.getEncoder().encodeToString(authToken.getBytes(Charset.forName("UTF-8")));
                request.header("Authorization", "Basic " + encodedToken);
            } else {
                throw new IllegalArgumentException("Unknown HTTP authentication type: '" + httpAuthType + "', supported value is 'basic'");
            }
        }
    }

    protected void processResult(ResponseListener responseListener) {
        ContentResponse response = responseListener.response;
        // TODO: If the request specifies caching, cache the result, storing
        // validity data.
        int status = response.getStatus();
        putResult("url", url); // We may have been redirected, so this may differ from the original.
        putResult("mediaType", response.getMediaType());
        putResult("encoding", response.getEncoding());
        if(responseListener.spilledToFile()) {
            putResult("bodySpilledToFile", true);
        } else {
            putResult("body", response.getContent());
        }
        putResult("status", new Integer(status).toString());
        putResult("reason", response.getReason());
        for(HttpField field : response.getHeaders()) {
            // TODO: Handle multivalue headers
            putResult("header:" + field.getName().toLowerCase(), field.getValue());
        }

        if(status >= 400 && status <= 500) {
            // Request is bad, fail it
            markRequestAsPermanentlyFailed(status + " " + response.getReason());
        } else if(status >= 500 && status <= 600) {
            // Remote server is bad, retry it
            markRequestAsTemporarilyFailed(status + " " + response.getReason());
        } else if(isRedirect(status)) {
            // We fell out of a redirect loop, which is a server-side problem,
            // so let's retry it
            markRequestAsTemporarilyFailed("Redirection loop");
        } else {
            putResult("type", "SUCCEEDED");
        }
    }

    protected void performOperation() throws Exception {
        // We use the blocking Jetty HTTP client library, because we
        // are already decoupled from the app via the Operation
        // infrastructure; and we need to block this operation handler
        // thread until the HTTP request is done anyway.
        HttpClient httpClient = null;
        try {
            start();

            // TODO: Check if the response is marked as cacheable, and a cached copy
            // meeting the validity requirements in the request exists, which also
            // meets the validity requirements of the request *that cached it*!
            httpClient = setupHTTPClient();
            insertQueryParamsIntoUrl();

            boolean redirected;
            int redirectsLeft = redirectLimit;
            do { // Redirection loop
                redirected = false;
                Request request = null;
                request = httpClient.newRequest(url);
                request.method(method);
                request.agent(agent);

                initialiseRequestBody(request);
                initialiseRequestHeaders(request);
                initialiseRequestAuthentication(request);

                ResponseListener responseListener = new ResponseListener(request, this.bodyPathname);

                try {
                    //response = request.send();
                    request.send(responseListener);
                    responseListener.waitForResponse();
                } catch(ExecutionException e) {
                    // Unwrap execution exceptions
                    throw e.getCause();
                } finally {
                    responseListener.ensureSpillFileClosed();
                }

                int status = responseListener.response.getStatus();
                // Loop back if we hit a redirect. Set redirected = true and mutate url.
                if(isRedirect(status)) {
                // Redirection
                    String location = responseListener.response.getHeaders().get("Location");
                    if(location != null && redirectsLeft > 0) {
                        redirectsLeft--;
                        redirected = true;
                        url = location;

                        if(status != 307) { // All other redirects go to a GET
                            method = "GET";
                        }

                        continue; // Take another try around the redirect loop
                    }
                }

                processResult(responseListener);
            } while (redirected);

        } catch(InterruptedException e) {
            markRequestAsTemporarilyFailed(e);
        } catch(TimeoutException e) {
            markRequestAsTemporarilyFailed(e);
        } catch(SSLHandshakeException e) {
            // SSL problems may be fixed at the remote end
            markRequestAsTemporarilyFailed(e);
        } catch(SecurityException e) {
            // The hostname failed validation
            markRequestAsPermanentlyFailed(e);
        } catch(Throwable e) {
            markRequestAsPermanentlyFailed(e);
        } finally {
            if(httpClient != null) { httpClient.stop(); }
            stop();
        }
    }

    // ----------------------------------------------------------------------

    // A listener for the response which will spill long responses to a file
    private static class ResponseListener extends BufferingResponseListener {
        private final CountDownLatch latch = new CountDownLatch(1);
        private Request request;
        private String spillFilePathname;
        private FileChannel spillFile;
        private long preSpillLength = 0;
        private Throwable failure;

        // Fields used by main class
        public ContentResponse response;

        public ResponseListener(Request request, String spillFilePathname) {
            // Set max size to disk size, because BufferingResponseListener checks Content-Length header
            // before receiving the response body.
            super(HTTPOperation.MAX_ON_DISK_RESPONSE_SIZE);
            this.request = request;
            this.spillFilePathname = spillFilePathname;
        }

        @Override
        public void onContent(Response response, ByteBuffer content) {
            try {
                // Spill to file if the content size has exceeded the in memory buffer limit
                if((this.spillFile == null) && (this.preSpillLength + content.remaining()) > HTTPOperation.MAX_IN_MEMORY_RESPONSE_SIZE) {
                    this.spillFile = FileChannel.open(FileSystems.getDefault().getPath(this.spillFilePathname), StandardOpenOption.CREATE, StandardOpenOption.WRITE);
                    // Write content collected so far by the superclass BufferingResponseListener
                    ByteBuffer c = ByteBuffer.wrap(this.getContent());
                    while(c.hasRemaining()) {
                        this.spillFile.write(c);
                    }
                }
                if(this.spillFile != null) {
                    while(content.hasRemaining()) {
                        this.spillFile.write(content);
                    }
                } else {
                    this.preSpillLength += content.remaining();
                    super.onContent(response, content);
                }
            } catch(IOException e) {
                this.request.abort(e);
            }
        }

        @Override
        public void onComplete(Result result) {
            this.response = new HttpContentResponse(result.getResponse(), getContent(), getMediaType(), getEncoding());
            this.failure = result.getFailure();

            // Close spill file, if fails, set failure exception if it's not set by something else
            if(this.spillFile != null) {
                try {
                    this.spillFile.close();
                } catch(IOException e) {
                    if(this.failure == null) { this.failure = e; }
                }
            }

            this.latch.countDown();
        }

        public void waitForResponse() throws InterruptedException, ExecutionException, TimeoutException {
            // TODO: Does this need a timeout, or is letting Jetty handle this sufficient?
            this.latch.await();
            if(this.failure != null) { throw new ExecutionException(this.failure); }
        }

        public void ensureSpillFileClosed() throws IOException {
            // Make sure spill file is always closed
            if((this.spillFile != null) && this.spillFile.isOpen()) {
                this.spillFile.close();
            }
        }

        public boolean spilledToFile() {
            return this.spillFile != null;
        }
    }
}
