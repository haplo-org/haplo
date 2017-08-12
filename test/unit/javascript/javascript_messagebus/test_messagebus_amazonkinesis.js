/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var Bus = O.messageBus.remote("test-kinesis");
    TEST.assert(Bus === O.messageBus.remote("test-kinesis")); // get the same bus twice

    messagebus_test2.db.info.select().deleteAll();

    var testValue = Date.now() % 10000000;
    var testMsg = Bus.message().body({value:testValue});
    testMsg.send();

    TEST.assert_equal(0, messagebus_test2.db.info.select().count());

    // Use callback to trigger delivery
    $host._testCallback("deliverAmazonKinesisMessages");

    TEST.assert_equal(1, messagebus_test2.db.info.select().count());

    // Check delivery report now it's been sent to Kinesis
    var report = JSON.parse(messagebus_test2.db.info.select()[0].info);
    TEST.assert_equal("success", report.status);
    TEST.assert(typeof(report.information.result) === "string");
    console.log("Kinesis delivery:", report.information.result);
    TEST.assert_equal(testValue, report.messageBody.value);

    // TODO: test delivery

});
