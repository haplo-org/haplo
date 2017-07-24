/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // Inter-app from keychain
    var Bus = O.messageBus.remote("Test Inter App Bus");
    TEST.assert_equal(Bus._interappName, "https://example.org/name/"+O.application.id);
    TEST.assert_equal(Bus._interappSecret, "secret1234");

    // Get the same one back if requested twice
    TEST.assert(Bus === O.messageBus.remote("Test Inter App Bus"));

    // Use a database to get info between runtimes
    messagebus_test1.db.values.select().deleteAll();
    var getValueFromDatabase = function() {
        var q = messagebus_test1.db.values.select();
        TEST.assert(q.length < 2);    // delivery only once
        return q.length ? q[0].value : undefined;
    };

    // Send a message, check it isn't delivered yet
    TEST.assert_equal(undefined, getValueFromDatabase());
    messagebus_test1.data.lastMsgValue = '';
    var testValue = Date.now() % 10000000;
    Bus.message().body({value:testValue}).send();
    TEST.assert_equal(undefined, getValueFromDatabase());

    // Use callback to trigger delivery
    $host._testCallback("deliverInterAppMessages");

    // It's delivered now
    TEST.assert_equal(testValue, getValueFromDatabase());

});
