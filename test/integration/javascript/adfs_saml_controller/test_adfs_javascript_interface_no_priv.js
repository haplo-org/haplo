/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    TEST.assert_exceptions(function() {
        var u = O.remote.authentication.urlToStartOAuth("data", "js-idp.example.org");
    }, "Cannot start OAuth without the pStartOAuth privilege. Add it to privilegesRequired in plugin.json");

});
