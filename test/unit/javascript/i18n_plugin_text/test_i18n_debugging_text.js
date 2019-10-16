/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // Templates
    var template = test_i18n_text1.template("translated");
    var view = {value:26};
    TEST.assert_equal("<div>•[String in the template]•</div><p>•[cat 1, text 1, local]•</p><p>•[Interpolated 26 things]•</p><p>•[name-one, something else]•</p>", template.render(view));
    TEST.assert_equal("•[This is a page title]•", view.pageTitle);
    TEST.assert_equal("•[Back!]•", view.backLinkText);

    // Plain text
    var locale1 = test_i18n_text1.locale();
    var text_one_en1 = locale1.text("category-one");
    TEST.assert_equal("•[cat 1, text 1, local]•", text_one_en1['string-1']);
    TEST.assert_equal("•[not translated]•", text_one_en1['not translated']);

});
