/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var locale2 = test_i18n_text2.locale();
    var text_one_es2 = locale2.text("category-one");

    TEST.assert_equal("es", locale2.id);
    TEST.assert_equal(false, locale2.defaultForPlugin);
    TEST.assert_equal("cat 1, text 2, local, ES", text_one_es2['string-1']);

    // Platform's current localeId
    TEST.assert_equal("es", O.currentLocaleId);

});
