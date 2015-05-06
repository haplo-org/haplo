/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // Load the generic template
    var genericTemplate = O.email.template();
    TEST.assert(genericTemplate !== null && genericTemplate !== undefined);
    TEST.assert_equal(1, genericTemplate.id);
    TEST.assert_equal("Generic", genericTemplate.name);
    TEST.assert_equal("std:email-template:generic", genericTemplate.code);

    // Load it by name
    var genericTemplate2 = O.email.template("std:email-template:generic");
    TEST.assert(genericTemplate2 !== null && genericTemplate2 !== undefined);
    TEST.assert_equal(1, genericTemplate2.id);
    TEST.assert_equal("Generic", genericTemplate2.name);

    // Check fallback of loading via name
    var genericTemplate3 = O.email.template("Password recovery");
    TEST.assert_equal("std:email-template:password-recovery", genericTemplate3.code);

    // Check bad template request
    var noSuchTemplate = O.email.template("test:email-template:no-such-template");
    TEST.assert(undefined === noSuchTemplate);

    // Fetch another template
    var passwordRecoveryTemplate = O.email.template("std:email-template:password-recovery");
    TEST.assert_equal(2, passwordRecoveryTemplate.id);
    TEST.assert_equal("Password recovery", passwordRecoveryTemplate.name);

    // Make sure it's case sensitive
    TEST.assert(undefined === O.email.template("std:email-template:Password-Recovery"));

    // Deliver a message, the result of which is tested in the ruby test
    genericTemplate.deliver("test@example.com", "Test Person", "Random Subject", "<p>XXX-MESSAGE-FROM-JAVASCRIPT-XXX</p>");

});
