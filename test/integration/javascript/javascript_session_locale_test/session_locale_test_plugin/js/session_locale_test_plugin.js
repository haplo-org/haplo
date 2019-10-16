/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.respond("GET", "/do/session-local-test/session-locale", [
    {parameter:"set", as:"string", optional:true}
], function(E, newLocaleId) {
    if(newLocaleId) {
        O.setSessionLocaleId(newLocaleId);
    }
    E.response.kind = "text";
    E.response.body = "O.currentUser.id="+O.currentUser.id+
        " O.currentLocaleId="+O.currentLocaleId+
        " P.locale().id="+P.locale().id;
});
