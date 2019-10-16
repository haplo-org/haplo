/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var user41 = O.user(41),
        user42 = O.user(42);

    TEST.assert_equal('en', user41.localeId);
    TEST.assert_equal('es', user42.localeId);

    TEST.assert_exceptions(function() {
        user41.setLocaleId("xyz");
    }, "Unknown locale: xyz");

    user41.setLocaleId('cy');

});
