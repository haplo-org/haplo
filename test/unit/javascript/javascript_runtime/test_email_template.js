/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    $host.setLastUsedPluginName("");

    // Load the generic template
    var genericTemplate = O.email.template();
    TEST.assert(genericTemplate !== null && genericTemplate !== undefined);
    TEST.assert_equal(1, genericTemplate.id);
    TEST.assert_equal("Generic", genericTemplate.name);

    // Load it by name
    var genericTemplate2 = O.email.template("Generic");
    TEST.assert(genericTemplate2 !== null && genericTemplate2 !== undefined);
    TEST.assert_equal(1, genericTemplate2.id);
    TEST.assert_equal("Generic", genericTemplate2.name);

    // Check bad template request
    var noSuchTemplate = O.email.template("No such template");
    TEST.assert(undefined === noSuchTemplate);

    // Fetch another template
    var passwordRecoveryTemplate = O.email.template("Password recovery");
    TEST.assert_equal(2, passwordRecoveryTemplate.id);
    TEST.assert_equal("Password recovery", passwordRecoveryTemplate.name);

    // Make sure it's case sensitive
    TEST.assert(undefined === O.email.template("password recovery"));

    // Call deliver, watch it fail
    TEST.assert_exceptions(function() {
        genericTemplate.deliver("test@example.com", "Test Person", "Random Subject", "<p>XXX-MESSAGE-FROM-JAVASCRIPT-XXX</p>");
    });

    // Set the permissions_plugin as the last used plugin to enable the privilege
    $host.setLastUsedPluginName("grant_privileges_plugin");

    // Deliver a message, the result of which is tested in the ruby test
    genericTemplate.deliver("test@example.com", "Test Person", "Random Subject", "<p>XXX-MESSAGE-FROM-JAVASCRIPT-XXX</p>");

});
