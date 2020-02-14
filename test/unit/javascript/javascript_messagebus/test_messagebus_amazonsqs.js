/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var Bus = O.messageBus.remote("test-sqs");
    TEST.assert(Bus === O.messageBus.remote("test-sqs")); // get the same bus twice

    messagebus_test_sqs.db.info.select().deleteAll();

    var testValue = Date.now() % 10000000;
    var testMsg = Bus.message().body({value:testValue});
    testMsg.send();

    TEST.assert_equal(0, messagebus_test_sqs.db.info.select().count());

    // Use callback to trigger delivery
    $host._testCallback("deliverAmazonSQSMessages");

    TEST.assert_equal(1, messagebus_test_sqs.db.info.select().count());

    // TODO: test delivery

});
