/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // NOTE: Services only work after the plugin's onLoad function has been called. After then,
    // $registry.services is the same object as $registry.servicesReg, so new services are available
    // immediately they're registered. Therefore this test doesn't need to worry about making them available.

    // Fish out the registration function so the underlying service system can be tested without using plugins
    var registerService = O.$private.$registerService;

    // For checking plugin names
    var currentPluginName = function() { return $host.getLastUsedPluginName(); };

    // Register some services
    var callOrder = [];
    TEST.assert(!O.serviceImplemented("service1"));
    var count = registerService("service1", function(arg1) {
        TEST.assert_equal("this1", this.x);
        TEST.assert_equal("pluginName1", currentPluginName());
        callOrder.push("fn1", arg1);
        if(arg1 == 'do return') { return "stopped"; }
    }, {x:"this1"}, "pluginName1");
    TEST.assert_equal(1, count);
    TEST.assert(O.serviceImplemented("service1"));
    count = registerService("service1", function(arg1) { // service1 again
        TEST.assert_equal("this2", this.x);
        TEST.assert_equal("pluginName2", currentPluginName());
        callOrder.push("fn2", arg1);
    }, {x:"this2"}, "pluginName2");
    TEST.assert_equal(2, count);
    TEST.assert(O.serviceImplemented("service1"));
    TEST.assert(!O.serviceImplemented("service3"));
    count = registerService("service3", function(arg1) { // different service
        TEST.assert_equal("this3", this.x);
        TEST.assert_equal("pluginName3", currentPluginName());
        callOrder.push("fn3", arg1);
    }, {x:"this3"}, "pluginName3");
    TEST.assert_equal(1, count);
    TEST.assert(O.serviceImplemented("service3"));

    // And then call them
    TEST.assert(undefined === currentPluginName());
    var r = O.service("service1", "call1");
    TEST.assert(undefined === currentPluginName());
    TEST.assert(undefined === r);
    TEST.assert(_.isEqual(['fn1','call1','fn2','call1'], callOrder));
    callOrder = [];
    r = O.service("service3", "call2");
    TEST.assert(undefined === currentPluginName());
    $host.setLastUsedPluginName("pants");
    TEST.assert("pants" == currentPluginName());
    TEST.assert(undefined === r);
    TEST.assert(_.isEqual(['fn3','call2'], callOrder));
    TEST.assert("pants" == currentPluginName());

    // Test that returning a result from a service stops the chain and returns that result
    callOrder = [];
    r = O.service("service1", "do return");
    TEST.assert(_.isEqual(['fn1','do return'], callOrder));
    TEST.assert_equal("stopped", r);

    // Test unregistered service exceptions when a call is attempted
    TEST.assert_exceptions(function() { O.service("carrots"); }, "No provider registered for service 'carrots' (or attempt to use service during plugin loading)");

});
