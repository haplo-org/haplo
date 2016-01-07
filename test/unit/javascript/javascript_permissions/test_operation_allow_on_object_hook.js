/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var readObj = O.ref(READ_OBJID).load();
    var updateObj = O.ref(UPDATE_OBJID).load();

    // User 41 is denied everything on COMMON, but the plugin will allow operations
    // User 42 is denied everything on COMMON
    // User 43 has no rules applied

    var user41 = O.user(41), user42 = O.user(42), user43 = O.user(43);

    // Special cases implemented by plugin
    TEST.assert_equal(true, user41.canRead(readObj));
    TEST.assert_equal(false, user41.canRead(updateObj));
    TEST.assert_equal(false, user41.canUpdate(readObj));
    TEST.assert_equal(true, user41.canUpdate(updateObj));

    // Denied by permission system
    TEST.assert_equal(false, user42.canRead(readObj));
    TEST.assert_equal(false, user42.canRead(updateObj));
    TEST.assert_equal(false, user42.canUpdate(readObj));
    TEST.assert_equal(false, user42.canUpdate(updateObj));

    // Allowed by permission system
    TEST.assert_equal(true, user43.canRead(readObj));
    TEST.assert_equal(true, user43.canRead(updateObj));
    TEST.assert_equal(true, user43.canUpdate(readObj));
    TEST.assert_equal(true, user43.canUpdate(updateObj));

    // Try loading objects
    $host._testCallback("41");
    readObj.ref.load(); // allowed by plugin

    $host._testCallback("42");
    TEST.assert_exceptions(function() {
        readObj.ref.load(); // denied by permissions system
    });

    $host._testCallback("43");
    readObj.ref.load(); // allowed by permissions system

});
