/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    TEST.assert_equal(_TEST_APP_ID, O.application.id);
    TEST.assert_equal("ONEIS Test System "+_TEST_APP_ID, O.application.name);
    TEST.assert_equal("www"+_TEST_APP_ID+".example.com", O.application.hostname);
    TEST.assert_equal("http://www"+_TEST_APP_ID+".example.com"+SERVER_PORT_EXTERNAL_CLEAR_IN_URL, O.application.url);

    // Not set yet
    TEST.assert_equal(undefined, O.application.config["TEST_VALUE"]);

});
