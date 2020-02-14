/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// For storing values received in messages for checking in test
P.db.table("info", {"info":{type:"text"}});

var Bus = O.messageBus.remote("test-kinesis");

Bus.deliveryReport(function(status, information, message) {
    console.log("Kinesis delivery report:", status, information.result);
    var info = {
        status: status,
        information: information,
        messageBody: message.parsedBody()
    };
    P.db.info.create({info:JSON.stringify(info)}).save();
});
