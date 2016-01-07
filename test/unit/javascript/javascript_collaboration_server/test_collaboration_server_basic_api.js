/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    TEST.assert_exceptions(function() {
        O.remote.collaboration.connect();
    }, "Callback function not passed to connect().");

    TEST.assert_exceptions(function() {
        O.remote.collaboration.connect("hello");
    }, "Callback function not passed to connect().");

    TEST.assert_exceptions(function() {
        O.remote.collaboration.connect("a", "b");
    }, "Callback function not passed to connect().");

    TEST.assert_exceptions(function() {
        O.remote.collaboration.connect(function() {});
    }, "Could not find credentials for collaboration service in application keychain.");

    TEST.assert_exceptions(function() {
        O.remote.collaboration.connect("hello", function() {});
    }, "Could not find credentials for collaboration service in application keychain.");

});

