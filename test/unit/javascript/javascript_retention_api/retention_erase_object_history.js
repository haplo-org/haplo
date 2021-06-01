/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2021            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // Superuser required
    O.impersonating(O.user(41), function() {
        TEST.assert_exceptions(function() {
            O.retention.eraseHistory(O.ref(OBJID));
        }, "Can only erase objects when super-user permissions are in force");
    });

    TEST.assert_exceptions(function() {
        O.retention.eraseHistory(null);
    }, "Must pass a StoreObject or Ref to O.retention.eraseHistory()");

    TEST.assert_exceptions(function() {
        O.retention.eraseHistory("object");
    }, "Must pass a StoreObject or Ref to O.retention.eraseHistory()");

    TEST.assert_equal(1, O.ref(OBJID).load().history.length);

    // StoreObject
    O.retention.eraseHistory(O.ref(OBJID).load());

    TEST.assert_equal(0, O.ref(OBJID).load().history.length);

    // Ref for same object doesn't throw an error, as it still exists
    O.retention.eraseHistory(O.ref(OBJID));

    TEST.assert_equal(0, O.ref(OBJID).load().history.length);

});

