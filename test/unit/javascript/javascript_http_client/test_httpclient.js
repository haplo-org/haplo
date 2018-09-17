/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {
    // Values passed from the callback back to the Ruby test wrapper
    // in http_client_test.rb, to see if everything went according to
    // plan.
    FAILED = "No";
    REQUESTS_REPLIED = 0;
    REQUESTS_TRIED = 0;

    var callback = new $Plugin.$Callback({$pluginName:"testHTTP"}, "wibble",
         function(data, client, result) {
             var failures = 0;
             for(key in data) {
                 var rd = undefined;
                 if(key === '$contentType') {
                     rd = result.body.mimeType;
                 } else if(key === '$contentCharset') {
                     rd = result.charset;
                 } else if(key === '$body') {
                     rd = result.bodyAsString();
                 } else if(key === '$succeeded') {
                     rd = result.successful.toString();
                 } else if(key === '$filename') {
                     rd = result.body.filename;
                 } else if(key === '$errorMessageWithoutIPs') {
                     rd = result.errorMessage.replace(/\[[0-9.]+\]/g,"[WHATEVER]");
                 } else if(key === '$isSpilledFile') {
                     rd = (result.body instanceof $BinaryDataTempFile);
                 } else if(key === '$digest') {
                     rd = result.body.digest;
                 } else if(key === '$filename') {
                     rd = result.body.filename;
                 } else if(key.startsWith('$do')) {
                     rd = true;
                 } else {
                     rd = result[key];
                 }
                 if(data[key] !== rd) {
                     console.log("HTTP client result mismatch: response[" + key + "] = '" + rd + "', expected '" + data[key] + "'");
                     console.log(rd);
                     console.log(data[key]);
                     FAILED = "FAILED - check logs for test failure";
                     failures = failures + 1;
                 }
             }
             if(failures > 0) {
                 for(key in result) {
                     console.log("HTTP result: response[" + key + "]", result[key] );
                 }
             }
             if(data.$doAddResponseToFileStore) {
                 O.file(result.body);
             }
             REQUESTS_REPLIED++;
         }
    );
    $registry.callbacks["testHTTP:wibble"] = callback;

    var hostname = 'localhost:'+TEST_SERVER_PORT;
    var illegalHostname = 'haplo.org';

    // Must use a callback object
    client = O.httpClient("http://" + hostname + "/wontrequest");
    TEST.assert_exceptions(function() {
        client.request("testHTTP:wibble", {});
    }, "request() must be called with a callback object obtained from P.callback()");

    // Normal request
    client = O.httpClient("http://" + hostname + "/success").method("GET");
    TEST.assert_equal("http://" + hostname + "/success",client.$requestSettings.url);
    TEST.assert_equal("GET",client.$requestSettings.method);
    client.request(callback,
                   {type: "SUCCEEDED",
                    status: "200",
                    '$succeeded': 'true',
                    '$contentType': 'text/plain',
                    '$contentCharset': 'ISO-8859-1',
                    '$filename': 'File "name".ext',
                    '$body': "It worked!"});
    REQUESTS_TRIED++;

    // 404
    client = O.httpClient("http://" + hostname + "/nonexistant");
    client.request(callback, {type:"FAIL", status:"404"});
    REQUESTS_TRIED++;

    // 404 again, with a cloned client
    client = client.mutableCopy();
    client.request(callback, {type:"FAIL", status:"404"});
    REQUESTS_TRIED++;

    // Redirect to 404
    client = O.httpClient("http://" + hostname + "/redirect?status=307&target=http://" + hostname + "/nonexistant");
    client.request(callback,
                   {type: "FAIL",
                    status: "404",
                    url: "http://" + hostname + "/nonexistant"});
    REQUESTS_TRIED++;

    // Redirect to success
    client = O.httpClient("http://" + hostname + "/redirect?status=307&target=http://" + hostname + "/success");
    client.request(callback,
                   {type: "SUCCEEDED",
                    status: "200",
                    '$body': "It worked!",
                    url: "http://" + hostname + "/success"});
    REQUESTS_TRIED++;

    // Redirect loop
    client = O.httpClient("http://" + hostname + "/redirect?status=307&target=loop");
    client.retryDelay(1)
    client.request(callback,
                   {type: "TEMP_FAIL",
                    status: "307"});
    REQUESTS_TRIED++;

    // Invalid IP
    client = O.httpClient("http://" + illegalHostname + "/");
    client.request(callback, {type:"FAIL", "$errorMessageWithoutIPs":"Illegal URL [http://haplo.org/], IP [WHATEVER] is blacklisted."});
    REQUESTS_TRIED++;

    // Redirect to invalid IP
    client = O.httpClient("http://" + hostname + "/redirect?status=307&target=http://" + illegalHostname + "/");
    client.request(callback,
                   {type: "FAIL",
                    "$errorMessageWithoutIPs": "Illegal URL [http://haplo.org/], IP [WHATEVER] is blacklisted."});
    REQUESTS_TRIED++;

    // Illegal headers
    client = O.httpClient("http://" + hostname + "/success");
    client.header("HOST", "www.example.com");
    client.request(callback, {type:"FAIL", errorMessage:"Overriding the Host: header is forbidden."});
    REQUESTS_TRIED++;

    client = O.httpClient("http://" + hostname + "/success");
    client.header("content-length", "0");
    client.request(callback, {type:"FAIL", errorMessage:"Overriding the Content-Length: header is forbidden."});
    REQUESTS_TRIED++;

    // Params - this test may be a bit fragile, as the order of the
    // body/query strings returned depends on how Java decides to iterate
    // through the contents of a Map, whic is undefined.
    client = O.httpClient("http://" + hostname + "/dump?x=0").method("POST");
    client.queryParameter("a","1");
    client.queryParameter("a","2");
    client.queryParameter("a1","3");
    client.bodyParameter("b","4");
    client.bodyParameter("b","5");
    client.bodyParameter("b1=","?6");
    client.request(callback, {type: "SUCCEEDED",
                                       status: "200",
                                       "$isSpilledFile": false,
                                       '$body': "POST BODY: 'b=5&b=4&b1%3D=%3F6' QUERY: 'x=0&a1=3&a=2&a=1'"});
    REQUESTS_TRIED++;

    client = O.httpClient("http://" + hostname + "/dump").method("GET");
    client.queryParameter("a","1");
    client.queryParameter("a","2");
    client.queryParameter("a1","3");
    client.queryParameter("a-_.~4=","=&x~._-");   // check that argument URL encoding escapes, but doesn't "overescape"
    client.bodyParameter("b","4");
    client.bodyParameter("b","5");
    client.bodyParameter("b1","6");
    client.request(callback, {type: "SUCCEEDED",
                                       status: "200",
                                       '$body': "GET BODY: 'b=4&b=5&b1=6' QUERY: 'a1=3&a=2&a=1&a-_.~4%3D=%3D%26x~._-'"});
    REQUESTS_TRIED++;

    // null and undefined in parameters are treated as the empty string
    client = O.httpClient("http://" + hostname + "/dump").method("GET");
    client.queryParameter("qn",null);
    client.queryParameter("qu",undefined);
    client.queryParameter("qs","");
    client.bodyParameter("bn",null);
    client.bodyParameter("bu",undefined);
    client.bodyParameter("bs","");
    client.request(callback, {type: "SUCCEEDED",
                                       status: "200",
                                       '$body': "GET BODY: 'bs=&bu=&bn=' QUERY: 'qs=&qu=&qn='"});
    REQUESTS_TRIED++;

    // Raw body
    client = O.httpClient("http://" + hostname + "/dump").method("PUT");
    client.body("text/plain", "This is a test");
    client.request(callback, {type: "SUCCEEDED",
                                       status: "200",
                                       '$body': "PUT BODY: 'This is a test' QUERY: ''"});
    REQUESTS_TRIED++;

    // Authentication
    client = O.httpClient("http://" + hostname + "/auth-basic");
    client.useCredentialsFromKeychain("test-basic-http-auth");
    client.request(callback, {type: "SUCCEEDED",
                                       status: "200",
                                       '$body': "Basic Auth succeeded!"});
    REQUESTS_TRIED++;

    client = O.httpClient("http://" + hostname + "/auth-basic");
    client.useCredentialsFromKeychain("test-basic-http-auth-bad");
    client.request(callback, {type: "FAIL",
                                       status: "401"});
    REQUESTS_TRIED++;

    // Large request which will spill to a file
    client = O.httpClient("http://" + hostname + "/large");
    client.request(callback, {type: "SUCCEEDED",
                                       status: "200",
                                       "$contentType": "text/plain",
                                       "$isSpilledFile": true,
                                       "$digest": 'd8b2af1c85cdb4588e978aed5875e12cbfd20f68009823cf914b40cf41d8e4ce',
                                       "$filename": 'sixty-four-k.txt',
                                       "$doAddResponseToFileStore": true,
                                       "$body": "0123456789abcdef".repeat(4096)});
    REQUESTS_TRIED++;

/*
    These tests are disabled, as we don't have an SSL site available
    on localhost yet. Ideally, we'll access it as localhost (matching the cert)
    and as 127.0.0.1 (not matching the cert) to see success/failure cases.

    We can't use these tests as-is, because they use external IPs,
    which we can't easily poke holes in the environments/test.rb blacklist for,
    as we'd have to hardcode the IPs.

    // An SSL site
    client = O.httpClient("https://www.google.com/");
    client.retryDelay(1);
    client.request(callback, {type: "SUCCEEDED",
                                       status: "200"});
    REQUESTS_TRIED++;

    // An invalid cert, it's www.kitten-technologies.co.uk
    client = O.httpClient("https://www.snell-pym.org.uk/");
    client.retryDelay(1);
    client.request(callback, {type: "TEMP_FAIL"});
    REQUESTS_TRIED++;
*/
});
