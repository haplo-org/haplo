/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    TEST.assert_exceptions(function() {
       O.user(41).createAPIKey("test1", "/api/path");
    }, "Cannot call createAPIKey() without the pUserCreateAPIKey privilege. Add it to privilegesRequired in plugin.json");

});
