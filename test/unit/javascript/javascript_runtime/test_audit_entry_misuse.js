/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    $host._testCallback("loadFixture");

    TEST.assert_exceptions(function() {
        O.audit.query().table("foo");
    }, "Audit entries have no field named 'foo'.");

    TEST.assert_exceptions(function() {
        O.audit.query().table("'; drop");
    }, "Audit entries have no field named ''; drop'.");

    TEST.assert_exceptions(function() {
        O.audit.query().sortBy("foo");
    }, "Audit entries have no field named 'foo'.");

});