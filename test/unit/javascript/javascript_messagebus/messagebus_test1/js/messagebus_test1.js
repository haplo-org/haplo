/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// For storing values received in messages for checking in test
P.db.table("values", {"value":{type:"int"}});

var Bus = O.messageBus.remote("Test Inter App Bus");

Bus.receive(function(message) {
    P.db.values.create({
        value: message.parsedBody().value
    }).save();
});
