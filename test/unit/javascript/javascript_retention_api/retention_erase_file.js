/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2021            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // Superuser required
    O.impersonating(O.user(41), function() {
        TEST.assert_exceptions(function() {
            O.retention.erase(O.file(DIGEST));
        }, "Can only erase files when super-user permissions are in force");
    });

    O.retention.erase(O.file(DIGEST));

    TEST.assert_exceptions(function() {
        O.file(DIGEST);
    }, "Cannot find or create a file from the value passed to O.file()");

});

