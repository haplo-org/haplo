/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // Platform default
    TEST.assert_equal("en", $i18n_defaults.locale_id); // std_i18n_locales uses this

    // Default locale
    TEST.assert_equal("en", test_i18n_text1.defaultLocaleId);
    var locale1 = test_i18n_text1.locale();
    TEST.assert_equal("English", locale1.name);
    TEST.assert_equal("English", locale1.nameInLanguage);
    TEST.assert_equal(true, locale1.defaultForPlugin);
    var text_one_en1 = locale1.text("category-one");

    TEST.assert_equal("en", locale1.id);
    TEST.assert_equal("en", test_i18n_text1.locale("en").id);
    TEST.assert_equal("cat 1, text 1, local", text_one_en1['string-1']);

    // Platform's current localeId
    TEST.assert_equal("en", O.currentLocaleId);

    // Undefined text is returned as is
    TEST.assert_equal("not translated", text_one_en1['not translated']);

    // Get non-default locale
    var locale2 = test_i18n_text2.locale("es");
    TEST.assert_equal("es", locale2.id);
    TEST.assert_equal("Spanish", locale2.name);
    TEST.assert_equal("Español", locale2.nameInLanguage);
    TEST.assert_equal(false, locale2.defaultForPlugin);
    var text_one_es2 = locale2.text("category-one");
    TEST.assert_equal("cat 1, text 2, local, ES", text_one_es2['string-1']);

    // Non-default falls back to en
    TEST.assert_equal("cat 1, text 2, global", text_one_es2['string-2']);

    // Bad locales throw exceptions
    TEST.assert_exceptions(function() {
        test_i18n_text1.locale("pants").text("category-one");
    }, "Unknown locale: pants");
    TEST.assert_exceptions(function() {
        test_i18n_text1.locale("../js").text("category-one");
    }, "Unknown locale: ../js");

    // Locales know about their plugin
    TEST.assert(locale1.plugin instanceof $Plugin);
    TEST.assert_equal("test_i18n_text1", locale1.plugin.pluginName);

    // Locale objects are cached
    TEST.assert(locale1 === test_i18n_text1.locale());

    // Text objects are cached
    TEST.assert(text_one_en1 === locale1.text("category-one"));

    // Multiple categories and they're independent
    TEST.assert(text_one_en1 !== locale1.text("category-two"));
    var text_two_en1 = locale1.text("category-two");
    TEST.assert_equal("cat 2, text 1, global", text_two_en1["string-1"]);

    // Text is subject to NAME() interpolation
    // Text which isn't in the strings files
    TEST.assert_equal("Hello name-one there is something else (not in strings file)", text_one_en1["Hello NAME(name-one) there is NAME(something else) (not in strings file)"]);
    // Test which is in the strings files
    TEST.assert_equal("Looked up: name-one but not xyz", text_one_en1["string-with-name"]);

});
