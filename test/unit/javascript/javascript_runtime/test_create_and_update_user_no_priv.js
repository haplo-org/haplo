/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    TEST.assert_exceptions(function() {
        O.setup.createUser({nameFirst:"x", nameLast:"y", email:"x@example.com"});
    }, "Cannot call O.setup.createUser() without the pCreateUser privilege. Add it to privilegesRequired in plugin.json");

    // And set ref on existing user
    TEST.assert_exceptions(function() {
       O.user(41).ref = O.ref(1244);
    }, "Cannot set ref property without the pUserSetRef privilege. Add it to privilegesRequired in plugin.json");

    // Test activation of user require privilege
    TEST.assert_exceptions(function() {
       O.user(41).setIsActive(false);
    }, "Cannot call setIsActive() without the pUserActivation privilege. Add it to privilegesRequired in plugin.json");

    // Password recovery URLs
    TEST.assert_exceptions(function() {
       O.user(41).generatePasswordRecoveryURL();
    }, "Cannot call generatePasswordRecoveryURL() without the pUserPasswordRecovery privilege. Add it to privilegesRequired in plugin.json");
    TEST.assert_exceptions(function() {
       O.user(41).generateWelcomeURL();
    }, "Cannot call generateWelcomeURL() without the pUserPasswordRecovery privilege. Add it to privilegesRequired in plugin.json");

});
