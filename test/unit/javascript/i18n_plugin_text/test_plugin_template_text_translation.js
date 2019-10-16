/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var template = test_i18n_text1.template("translated");

    var view = {value:23};
    TEST.assert_equal("<div>String in the template</div><p>cat 1, text 1, local</p><p>Interpolated 23 things</p><p>name-one, something else</p>", template.render(view));
    TEST.assert_equal("This is a page title", view.pageTitle);
    TEST.assert_equal("Back!", view.backLinkText);

    // Plurals work
    var pluralsTemplate = test_i18n_text1.template("plurals");
    TEST.assert_equal("<p>There are 23 items</p>", pluralsTemplate.render({count:23}));
    TEST.assert_equal("<p>There is 1 item</p>", pluralsTemplate.render({count:1}));
    TEST.assert_equal("<p>There are 0 items</p>", pluralsTemplate.render({count:0}));

});
