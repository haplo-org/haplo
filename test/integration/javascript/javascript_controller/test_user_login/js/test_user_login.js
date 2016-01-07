/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.respond("GET", "/do/test-user-login/user", [
], function(E) {
    E.response.body = O.currentUser.name;
    E.response.kind = "text";
});

P.respond("GET", "/do/test-user-login/set-user", [
    {pathElement:0, as:"int"}
], function(E, uid) {
    O.user(uid).setAsLoggedInUser("USER AUDIT INFO");
    E.response.body = ""+uid;
    E.response.kind = "text";
});
