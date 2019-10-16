/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var template = test_i18n_text1.template("translated");

    var view = {value:24};
    TEST.assert_equal("<div>String in the template</div><p>cat 1, text 1, local</p><p>Cosas 24 interpoladas</p><p>name-one, something else</p>", template.render(view));
    TEST.assert_equal("Este es un título de página", view.pageTitle);
    TEST.assert_equal("Back!", view.backLinkText); // not translated, but looked up

});
