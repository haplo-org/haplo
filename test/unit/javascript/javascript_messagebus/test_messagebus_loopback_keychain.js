/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // Unknown keychain entry returns a fake loopback bus
    var FakeBus = O.messageBus.remote("Unknown Bus");
    TEST.assert_equal(FakeBus._loopbackName, "$fallbackNotInKeychain:Unknown Bus")

    // Loopback from keychain
    var Bus = O.messageBus.remote("Test Message Bus");
    TEST.assert_equal(Bus._loopbackName, "test:loopback:from_keychain")

    // Same as one created through loopback()
    TEST.assert(Bus === O.messageBus.loopback("test:loopback:from_keychain"));

    // Quick check the loopback bus works
    var X = '';
    Bus.receive(function(msg) { X+=msg.parsedBody().x; });
    Bus.message().body({x:"sent"}).send();
    TEST.assert_equal(X, "sent");

});
