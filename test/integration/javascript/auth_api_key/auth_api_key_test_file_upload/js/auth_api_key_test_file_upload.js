/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.respond("POST", "/do/auth-api-key-test-file-upload/test", [
    {parameter:"file", as:"file"}
], function(E, file) {
    E.response.kind = "text";
    E.response.body = ""+O.currentUser.id+" "+file.fileSize;
});
