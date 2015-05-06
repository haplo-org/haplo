/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


t.test(function() {

    // Check that the locals are defined when the tests run
    t.assert(Special === 444);

    // Check the schema is available
    t.assert(T.TestingPerson == O.ref('20x0'));
    t.assert(Group.GroupOne === 21);

    t.assert(!O.isHandlingRequest);

    t.login("ANONYMOUS");
    t.assert(O.currentUser.id === 2);
    O.session["tested_plugin:ping"] = 3;
    t.assert(O.isHandlingRequest);
    t.assert(O.session["tested_plugin:ping"] === 3);

    t.login("user1@example.com");
    t.assert(O.currentUser.id === O.user("user1@example.com").id);
    t.assert(O.session["tested_plugin:ping"] === undefined);
    t.assert(O.isHandlingRequest);
    t.assert(O.tray.length === 0);

    t.loginAnonymous();
    t.assert(O.currentUser.id === 2);

    t.logout();
    t.assert(!O.isHandlingRequest);

    // LAST THING!
    // Leave logged in, so next test can check it isn't still logged in
    t.login("user1@example.com");
});
