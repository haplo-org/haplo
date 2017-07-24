/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var srv0 = O.serviceUser("test:service-user:test");
    TEST.assert_equal(true, srv0.isServiceUser);
    TEST.assert(srv0 instanceof $User);
    TEST.assert_equal("Service user 0", srv0.name);
    TEST.assert_equal(SVR0_USER_ID, srv0.id);

    TEST.assert_exceptions(function() { O.serviceUser(); }, "Must pass API code as string to O.serviceUser()");
    TEST.assert_exceptions(function() { O.serviceUser(23); }, "Must pass API code as string to O.serviceUser()");
    TEST.assert_exceptions(function() { O.serviceUser("test:service-user:does-not-exist"); }, "Service user test:service-user:does-not-exist not does not exist, define in plugin requirements.schema");

    O.impersonating(srv0, function() {
        TEST.assert_equal(SVR0_USER_ID, O.currentUser.id);
        TEST.assert_equal(true, O.currentUser.isServiceUser);
    });
    
});
