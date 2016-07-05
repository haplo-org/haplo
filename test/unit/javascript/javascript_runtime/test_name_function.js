/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {
    var registerService = O.$private.$registerService;

    // Main NAME() function

    // Without something being looked up
    TEST.assert_equal("not translated", NAME("not translated"));

    // Register a translator service
    registerService("std:NAME", function(name) {
        if(-1 !== name.indexOf('trans')) {
            return name+" X";
        }
    });

    // Was cached so doesn't change
    TEST.assert_equal("not translated", NAME("not translated"));

    TEST.assert_equal("translated X", NAME("translated"));
    TEST.assert_equal("abc", NAME("abc"));  // not matched by translator service

    registerService("std:NAME", function(name) {
        if(name === "ping") { return "pong"; }
    });

    TEST.assert_equal("pong", NAME("ping"));

    TEST.assert_equal("trans 2 X", NAME("trans 2"));

    // Template NAME() function
    var template = new $HaploTemplate('<div> NAME("ping") </div>');
    TEST.assert_equal("<div>pong</div>", template.render());

    // Bad templates
    TEST.assert_exceptions(function() {
        new $HaploTemplate('<div> NAME() </div>', 'test').render();
    }, "When rendering template 'test': Argument 1 expected for NAME()");
    TEST.assert_exceptions(function() {
        new $HaploTemplate('<div> NAME(something) </div>', 'test').render();
    }, "When rendering template 'test': Literal string argument expected for NAME()");

    // Simulate calling NAME() during plugin load
    $registry.services = {};
    TEST.assert_equal("trans during load X", NAME("trans during load"));
    TEST.assert_equal("during load", NAME("during load"));

});
