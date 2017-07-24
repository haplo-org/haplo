/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.httpclient;
import java.util.Map;
import java.util.HashMap;

public class HTTPClient {

    // Interface from Ruby via KHTTPClientJob in httpclient.rb:
    public static Map attemptHTTP(Map<String,String> requestSettings,
                                  Map<String,String> keychainData,
                                  String blacklist) throws Exception {
        HTTPOperation op = new HTTPOperation(requestSettings, keychainData, blacklist);
        try {
            op.perform();
            return op.result;
        } catch (Throwable e) {
            Map<String,Object> result = op.result;
            result.put("type","FAIL");
            result.put("exceptionType",e.getClass().getName());
            if (e.getMessage() != null) {
                result.put("errorMessage",e.getMessage());
            } else {
                result.put("errorMessage",e.toString());
            }
            return result;
        }
    }

    // Interface from JavaScript via KHost:

    public static void queueHttpClientRequest(String callbackName,
                                              String callbackDataJSON,
                                              Map requestSettings) {
        // Make it happen, job queue!
        rubyInterface.scheduleHttpClientJob(callbackName,
                                            callbackDataJSON,
                                            requestSettings);
    }

    // Interface to Ruby in js_httpclient_support.rb
    public interface Ruby {
        public void scheduleHttpClientJob(String callbackName,
                                          String callbackDataJSON,
                                          Map requestSettings);
    }

    private static Ruby rubyInterface;
    public static void setRubyInterface(Ruby ri) {
      rubyInterface = ri;
    }
}
