/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


t.test(function() {

    // Check that the locals are defined when the tests run
    t.assertEqual(Special, 444);

    // Test exception thrown as expected
    t.assertThrows(P.willThrowException);
    t.assertThrows(P.willThrowException, "Error message");
    t.assertThrows(function() { P.willThrowException("New message"); }, "New message");


    // Check the schema is available
    t.assert(T.TestingPerson == O.ref('20x0'));
    t.assertEqual(Group.GroupOne, 21);

    t.assert(!O.isHandlingRequest);

    t.login("ANONYMOUS");
    t.assertEqual(O.currentUser.id, 2);
    O.session["tested_plugin:ping"] = 3;
    t.assert(O.isHandlingRequest);
    t.assertEqual(O.session["tested_plugin:ping"], 3);

    t.login("user1@example.com");
    t.assertEqual(O.currentUser.id, O.user("user1@example.com").id);
    t.assertEqual(O.session["tested_plugin:ping"], undefined);
    t.assert(O.isHandlingRequest);
    t.assertEqual(O.tray.length, 0);

    // Check that logged in user is restored after changes in AuthContext
    O.impersonating(O.SYSTEM, function() {
        t.assertEqual(O.currentUser.id, 0);
    });
    t.assertEqual(O.currentUser.id, 41);
    O.impersonating(O.user(42), function() {
        t.assertEqual(O.currentUser.id, 42);
    });
    t.assertEqual(O.currentUser.id, 41);
    O.withoutPermissionEnforcement(function() {
        t.assertEqual(O.currentUser.id, 41);  // user doesn't change
    });
    t.assertEqual(O.currentUser.id, 41);

    // Test login works with user object
    t.login(O.user(43));
    t.assertEqual(O.currentUser.id, 43);

    t.loginAnonymous();
    t.assertEqual(O.currentUser.id, 2);

    t.logout();
    t.assert(!O.isHandlingRequest);

    // LAST THING!
    // Leave logged in, so next test can check it isn't still logged in
    t.login("user1@example.com");
});
