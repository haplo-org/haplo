/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

(function() {
    // HTTP Response
    var HTTPResponse = O.$private.$HTTPResponse = function() { };
    HTTPResponse.prototype.singleValueHeader = function(n,d) {
        var key = 'header:' + n.toLowerCase();
        if(key in this) {
            return this[key];
        } else {
            return d;
        }
    };
    HTTPResponse.prototype.bodyAsString = function() {
        return this.body.readAsString(this.charset);
    };
    var makeHTTPResponse = function(data, body) {
        var r = _.extend(new HTTPResponse(), data);
        r.successful = (r.type === "SUCCEEDED");

        if(body) {
            r.body = body;
        }

        return r;
    };
    var toStringOrEmptyString = function(v) {
        return (v === null || v === undefined) ? '' : v.toString();
    };

    // HTTP Client
    var HTTPClient = O.$private.$HTTPClient = function(requestSettings, sealed) {
        this.$requestSettings = requestSettings;
        this.$sealed = sealed; // Object.seal() won't help us here
    };
    HTTPClient.prototype.$ensureMutable = function() {
        if(this.$sealed) {
            throw new Error("Cannot modify a started HTTP request");
        }
    };
    HTTPClient.prototype.url = function(v) {
        this.$ensureMutable();
        this.$requestSettings.url = v.toString();
        return this;
    };
    HTTPClient.prototype.method = function(v) {
        this.$ensureMutable();
        this.$requestSettings.method = v.toString();
        return this;
    };
    HTTPClient.prototype.agent = function(v) {
        this.$ensureMutable();
        this.$requestSettings.agent = v.toString();
        return this;
    };
    HTTPClient.prototype.bodyParameter = function(k,v) {
        this.$ensureMutable();
        this.$requestSettings["bodyParam:"+(Object.keys(this.$requestSettings).length)+":"+k.toString()] = toStringOrEmptyString(v);
        return this;
    };
    HTTPClient.prototype.body = function(type,value) {
        this.$ensureMutable();
        this.$requestSettings["bodyType"] = type;
        this.$requestSettings["bodyString"] = value;
        return this;
    };
    HTTPClient.prototype.queryParameter = function(k,v) {
        this.$ensureMutable();
        this.$requestSettings["queryParam:"+(Object.keys(this.$requestSettings).length)+":"+k.toString()] = toStringOrEmptyString(v);
        return this;
    };
    HTTPClient.prototype.header = function(k,v) {
        this.$ensureMutable();
        this.$requestSettings["header:"+k.toString()] = v.toString();
        return this;
    };
    HTTPClient.prototype.retryDelay = function(v) {
        this.$ensureMutable();
        this.$requestSettings.retryDelay = v;
        return this;
    };
    HTTPClient.prototype.redirectLimit = function(v) {
        this.$ensureMutable();
        this.$requestSettings.redirectLimit = v;
        return this;
    };
    HTTPClient.prototype.useCredentialsFromKeychain = function(v) {
        this.$ensureMutable();
        this.$requestSettings.auth = v;
        return this;
    };
    HTTPClient.prototype.useClientCertificateFromKeychain = function(v) {
        this.$ensureMutable();
        this.$requestSettings.clientCertificate = v;
        return this;
    };
    HTTPClient.prototype.mutableCopy = function() {
        return new HTTPClient(this.$requestSettings, false);
    };
    HTTPClient.prototype.request = function(callback, callbackData) {
        if(this.$sealed) {
            throw new Error("Cannot resubmit a started HTTP request");
        }
        if(!(callback instanceof $Plugin.$Callback)) {
            throw new Error("request() must be called with a callback object obtained from P.callback()");
        }
        this.$sealed = true;
        $host.httpClientRequest(callback.$name,
                                (typeof callbackData === 'object') ? JSON.stringify(callbackData) : '{}',
                                this.$requestSettings);
        return;
    };

    O.httpClient = function(url) {
        var requestSettings = {};
        requestSettings.url = url;
        requestSettings.method = "GET";
        requestSettings.agent = "Haplo Platform";
        requestSettings.redirectLimit = "10";
        requestSettings.retryDelay = "60";
        return new HTTPClient(requestSettings, false);
    };

    O.$private.$callbackConstructors.makeHTTPResponse = function(nextArg) {
        var responseData = JSON.parse(nextArg());
        var body = nextArg();
        return makeHTTPResponse(responseData, body);
    };
    O.$private.$callbackConstructors.makeHTTPClient = function(nextArg) {
        return new HTTPClient(JSON.parse(nextArg()), true);
    };


})();
