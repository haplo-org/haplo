/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var t = (function(root) {

    var lastRequestParameters, lastRequestOptions, pendingLast;

    var t = {

        // ----------------------------------------------------------------------------------------------
        //   API for built-in minimal testing framework and testing plugin functions

        test: function(test) {
            t.$startTest();
            try {
                test();
            } finally {
                t.$finishTest();
            }
        },

        assert: function(state, message) {
            $TEST.incAssertCount();
            if(!state) {
                $TEST.assertFailed(message || ""); // Throws exception
            }
        },

        login: function(user) {
            $host._test_resetForNewLogin();
            if(user !== 'ANONYMOUS') {
                user = O.user(user);
            }
            $TEST.login(user);
        },

        loginAnonymous: function() {
            t.login("ANONYMOUS");
        },

        logout: function() {
            $TEST.logout();
        },

        request: function(method, path, parameters, options) {
            var last = {};
            // Enable the hooks while the request is being processed
            $registry.$testingRequestHook = testingRequestHook;
            $registry.$testingRenderHook  = testingRenderHook;
            try {
                // Because parameters etc are picked up on demand from the underlying Ruby controller,
                // they need to be stashed for the testingRequestHook to pick up.
                lastRequestParameters = parameters || {};
                lastRequestOptions = options || {};
                // Store the pending 't.last' value so it can be filled in by the hooks
                pendingLast = last;
                // Find plugin and call handler
                var plugin = root[$TEST.pluginNameUnderTest];
                if(!plugin) {
                    throw new Error("Can't find plugin: "+$TEST.pluginNameUnderTest);
                }
                var response = plugin.handleRequest(method, path);
                // Fill in t.last and store
                if(response) {
                    last.body = response.body;
                } else {
                    // Implicit assert failure
                    t.assert(false, "Plugin didn't respond to request for "+method+" "+path+" (no handler or validation failure)");
                }
                t.last = last;
            } finally {
                delete $registry.$testingRequestHook;
                delete $registry.$testingRenderHook;
                pendingLast = undefined;
            }
            return last;
        },

        get: function(path, parameters, options) {
            return t.request("GET", path, parameters, options);
        },

        post: function(path, parameters, options) {
            return t.request("POST", path, parameters, options);
        },

        // ----------------------------------------------------------------------------------------------
        //   API for test framework integration

        $startTest: function() {
            lastRequestParameters = undefined;
            lastRequestOptions = undefined;
            pendingLast = undefined;
            t.last = {view:{}};
            $TEST.startTest();
        },

        $finishTest: function() {
            $TEST.finishTest();
        }
    };

    // ----------------------------------------------------------------------------------------------
    //   Request cycle hooks

    var testingRequestHook = function(handlerName, method, path, extraPathElements, E) {
        // Store information
        pendingLast.method = method;
        pendingLast.path = path;
        pendingLast.extraPathElements = extraPathElements;
        // Fake the Request object
        E.request = {
            method: method,
            path: path,
            extraPathElements: extraPathElements,
            parameters: lastRequestParameters,
            headers: lastRequestOptions.headers || {},  // use headers from the options if they're given
            remote: {protocol: "IPv4", address:"10.1.2.3"}
        };
    };

    var testingRenderHook = function(view, templateName, templateOptions) {
        pendingLast.view = view;
        pendingLast.templateName = templateName;
        pendingLast.templateOptions = templateOptions;
    };

    // ----------------------------------------------------------------------------------------------

    return t;

})(this);
