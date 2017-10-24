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

    // Two argument version
    TEST.assert_equal("ping", NAME("test:pong", "ping"));
    TEST.assert_equal("ping", NAME("test:pong", "ping")); // repeat
    TEST.assert_equal("ping2", NAME("test:pong", "ping2")); // different default
    TEST.assert_equal("ping", NAME("test:pong", "ping")); // original
    TEST.assert_equal("ping2", NAME("test:pong", "ping2")); // repeat different default

    TEST.assert_equal("test:pong", NAME("test:pong"));  // normal rules if one arg supplied
    TEST.assert_equal("ping", NAME("test:pong", "ping"));
    TEST.assert_equal("test:pong", NAME("test:pong"));
    TEST.assert_equal("test:translated x X", NAME("test:translated x", "hello"));
    TEST.assert_equal("test:translated x X", NAME("test:translated x"));
    TEST.assert_equal("test:translated x X", NAME("test:translated x", "hello"));
    TEST.assert_equal("test:translated x X", NAME("test:translated x", "hello"));
    TEST.assert_equal("test:translated x X", NAME("test:translated x", "hello"));

    registerService("std:NAME", function(name) {
        if(name === "ping") { return "pong"; }
    });

    TEST.assert_equal("pong", NAME("ping"));

    TEST.assert_equal("trans 2 X", NAME("trans 2"));

    // Template NAME() function
    var template = new $HaploTemplate('<div> NAME("ping") </div>');
    TEST.assert_equal("<div>pong</div>", template.render());

    // Template NAME() function with two arguments
    var templateD = new $HaploTemplate('<div> NAME("ping:x" "default1") </div>');
    TEST.assert_equal("<div>default1</div>", templateD.render());
    TEST.assert_equal("<div>default1</div>", templateD.render());
    template = new $HaploTemplate('<div> NAME("ping:x") </div>');   // one arg version with same name
    TEST.assert_equal("<div>ping:x</div>", template.render());
    TEST.assert_equal("<div>default1</div>", templateD.render());   // template with default

    template = new $HaploTemplate('<div> NAME("ping:translated y" "default2") </div>');
    TEST.assert_equal("<div>ping:translated y X</div>", template.render());
    TEST.assert_equal("<div>ping:translated y X</div>", template.render());

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

    // Test string interpolation function used by forms & workflow
    var transFn = O.$private.$interpolateNAMEinString;
    // one argument
    TEST.assert_equal("ABC pong", transFn("ABC NAME(ping)"))
    TEST.assert_equal("ABCNAME(ping)", transFn("ABCNAME(ping)")) // no word break before
    TEST.assert_equal("ABC hello translated XSOMETHING", transFn("ABC NAME(hello translated)SOMETHING"))
    // two arguments
    TEST.assert_equal("ABC ping XYZ", transFn("ABC NAME(test:pong|ping) XYZ"))
    TEST.assert_equal("ABC test:translated x X XYZ", transFn("ABC NAME(test:translated x|hello) XYZ"))

    // Public API
    TEST.assert_equal(O.interpolateNAMEinString, transFn); // is same implementation
    // one argument
    TEST.assert_equal("ABC pong", O.interpolateNAMEinString("ABC NAME(ping)"))
    TEST.assert_equal("ABCNAME(ping)", O.interpolateNAMEinString("ABCNAME(ping)")) // no word break before
    TEST.assert_equal("ABC hello translated XSOMETHING", O.interpolateNAMEinString("ABC NAME(hello translated)SOMETHING"))
    // two arguments
    TEST.assert_equal("ABC ping XYZ", O.interpolateNAMEinString("ABC NAME(test:pong|ping) XYZ"))
    TEST.assert_equal("ABC test:translated x X XYZ", O.interpolateNAMEinString("ABC NAME(test:translated x|hello) XYZ"))

});
