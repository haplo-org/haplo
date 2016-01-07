/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var genericTemplate = O.email.template();
    TEST.assert_exceptions(function() {
        genericTemplate.deliver("test@example.com", "Test Person", "Random Subject", "<p>XXX-MESSAGE-FROM-JAVASCRIPT-XXX</p>");
    });

});
