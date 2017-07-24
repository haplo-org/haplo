/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var Bus = O.messageBus.remote("test-kinesis");
    TEST.assert(Bus === O.messageBus.remote("test-kinesis")); // get the same bus twice

    var testValue = Date.now() % 10000000;
    Bus.message().body({value:testValue}).send();

    // Use callback to trigger delivery
    $host._testCallback("deliverAmazonKinesisMessages");

    // TODO: test delivery

});
