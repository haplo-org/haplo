/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2021            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    TEST.assert_exceptions(function() {
        O.retention.erase();
    }, "Must pass something to O.retention.erase()");

    TEST.assert_exceptions(function() {
        O.retention.erase(23);
    }, "O.retention.erase() cannot erase something of this type");

    TEST.assert_exceptions(function() {
        O.retention.erase("something");
    }, "O.retention.erase() cannot erase something of this type");

});

