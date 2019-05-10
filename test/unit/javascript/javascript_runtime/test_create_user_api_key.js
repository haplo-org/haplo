/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    TEST.assert_exceptions(function() {
        O.group(21).createAPIKey("test1", "/api/path");
    }, "Cannot create API keys for groups");

    var apiKey = O.user(41).createAPIKey("Test Key", "/api/path/2");
    TEST.assert_equal("string", typeof(apiKey));
    TEST.assert_equal(44, apiKey.length);

});
