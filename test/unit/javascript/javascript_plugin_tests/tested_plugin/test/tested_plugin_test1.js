/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


T.test(function() {

    T.assert(!O.isHandlingRequest);

    T.login("ANONYMOUS");
    T.assert(O.currentUser.id === 2);
    O.session["tested_plugin:ping"] = 3;
    T.assert(O.isHandlingRequest);
    T.assert(O.session["tested_plugin:ping"] === 3);

    T.login("user1@example.com");
    T.assert(O.currentUser.id === O.user("user1@example.com").id);
    T.assert(O.session["tested_plugin:ping"] === undefined);
    T.assert(O.isHandlingRequest);
    T.assert(O.tray.length === 0);

    T.loginAnonymous();
    T.assert(O.currentUser.id === 2);

    T.logout();
    T.assert(!O.isHandlingRequest);

    // LAST THING!
    // Leave logged in, so next test can check it isn't still logged in
    T.login("user1@example.com");
});
