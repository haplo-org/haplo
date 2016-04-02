/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    $registry.pluginLoadFinished = false;

    // Create a test kind
    var tester = {};
    O.$private.$registerService("std:action:check:tester", function(user, thing) {
        return tester[thing+user.id];;
    });

    // Define some actions
    var ActionOne = O.action("test:one").
        title("Test action one").
        allow("group", 21). // set with IDs, not symbolic names
        deny("group", 22);

    var ActionTwo = O.action("test:two").
        title("Action TWO").
        allow("group", 22);
    // Can add rules to an existing action
    O.action("test:two").
        allow("tester", "a").
        deny("tester", "d");

    var ActionNull = O.action("test:null");
    var ActionAllowAll = O.action("test:allowall").allow("all");
    var ActionDenyAll = O.action("test:denyall").allow("group",22).deny("all");

    TEST.assert_exceptions(function() { ActionTwo.allow("pants", "Pants"); }, "Unimplemented kind for allow() or deny(), service std:action:check:pants must be implemented.");

    TEST.assert_equal("test:one", ActionOne.code);
    TEST.assert_equal("Test action one", ActionOne.$title);

    // Pretend plugins are loaded...
    $Plugin.$callOnLoad();
    // ... then check actions can't be created or modified afterwards.
    TEST.assert_exceptions(function() { O.action("test:three"); }, "Cannot create or configure Actions after plugins have been loaded.");
    TEST.assert_exceptions(function() { ActionOne.title("hello"); }, "Cannot create or configure Actions after plugins have been loaded.");
    TEST.assert_exceptions(function() { ActionOne.allow("group", 2); }, "Cannot create or configure Actions after plugins have been loaded.");
    TEST.assert_exceptions(function() { ActionOne.deny("group", 2); }, "Cannot create or configure Actions after plugins have been loaded.");

    // Using O.action() again for actions which have already been defined returns the identical object
    TEST.assert(O.action("test:one") === ActionOne);
    TEST.assert(O.action("test:two") === ActionTwo);

    // Admin memberships
    TEST.assert_equal(true,  O.user(41).isMemberOf(SCHEMA.GROUP["std:group:administrators"]));
    TEST.assert_equal(false, O.user(42).isMemberOf(SCHEMA.GROUP["std:group:administrators"]));

    // Check actions
    TEST.assert_equal(true,  O.user(41).allowed(ActionOne));
    TEST.assert_equal(false, O.user(42).allowed(ActionOne));

    // Use ActionTwo to test plugin defined kinds
    TEST.assert_equal(false, O.user(41).allowed(ActionTwo)); // not allowed or denies
    tester.a41 = true;
    TEST.assert_equal(true, O.user(41).allowed(ActionTwo)); // allowed
    tester.d41 = true;
    TEST.assert_equal(false, O.user(41).allowed(ActionTwo)); // allowed and denied, so denies

    // Another user with an allow group
    TEST.assert_equal(true, O.user(42).allowed(ActionTwo)); // has group
    tester.a42 = true;
    TEST.assert_equal(true, O.user(42).allowed(ActionTwo)); // has group & a test allow, still allowed
    tester.d42 = true;
    TEST.assert_equal(false, O.user(42).allowed(ActionTwo)); // now has a deny

    // 'all' kind
    TEST.assert_equal(false, O.user(42).allowed(ActionNull));
    TEST.assert_equal(true, O.user(42).allowed(ActionAllowAll));
    TEST.assert_equal(true, O.user(42).isMemberOf(22)); // in ActionDenyAll
    TEST.assert_equal(false, O.user(42).allowed(ActionDenyAll));

    // enforce() utility function
    ActionAllowAll.enforce();
    O.impersonating(O.user(42), function() {
        ActionAllowAll.enforce();   // doesn't exception
        TEST.assert_exceptions(function() {
            ActionOne.enforce();
        }, "O.stop() called - You are not permitted to perform this action.");
        TEST.assert_exceptions(function() {
            ActionOne.enforce("Specified message");
        }, "O.stop() called - Specified message");
    });

    // Administrator override
    TEST.assert_equal(true, O.user(43).isMemberOf(21)); // allow group
    TEST.assert_equal(true, O.user(43).isMemberOf(22)); // deny group
    TEST.assert_equal(true, O.user(43).isMemberOf(SCHEMA.GROUP["std:group:administrators"]));
    TEST.assert_equal(false, O.user(43).allowed(ActionOne)); // has a deny group

    // Add administrators to magic action, then check the admin group is allowed
    $registry.pluginLoadFinished = false;
    O.action("std:action:administrator_override").allow("group", SCHEMA.GROUP["std:group:administrators"]);
    $Plugin.$callOnLoad();

    // Now 43 can do this action
    TEST.assert_equal(true, O.user(43).allowed(ActionOne)); // may have a deny group, but it's a member of administrators so gets it anyway
    // 42 is still not allowed
    TEST.assert_equal(false, O.user(42).allowed(ActionOne));

    // Try deny as well
    $registry.pluginLoadFinished = false;
    O.action("std:action:administrator_override").deny("group", SCHEMA.GROUP["std:group:administrators"]);
    $Plugin.$callOnLoad();

    TEST.assert_equal(false, O.user(43).allowed(ActionOne)); // may have a deny group, but it's a member of administrators so gets it anyway

});
