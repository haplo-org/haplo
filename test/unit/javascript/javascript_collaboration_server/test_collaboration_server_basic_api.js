/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    TEST.assert_exceptions(function() {
        O.remote.collaboration.connect(function() {});
    }, "Cannot use a collaboration service without the pRemoteCollaborationService privilege. Add it to privilegesRequired in plugin.json");

    $host.setLastUsedPluginName("grant_privileges_plugin");

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

