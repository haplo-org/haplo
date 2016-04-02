/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var handlebarsTemplate = O.$createPluginTemplate({}, "test", "<div><div>", "html");
    var hsvtTemplate = new $HaploTemplate("<div> </div>");

    TEST.assert_equal(false, O.isDeferredRender(1));
    TEST.assert_equal(false, O.isDeferredRender(null));
    TEST.assert_equal(false, O.isDeferredRender(undefined));
    TEST.assert_equal(false, O.isDeferredRender(handlebarsTemplate));
    TEST.assert_equal(false, O.isDeferredRender(hsvtTemplate));
    TEST.assert_equal(false, O.isDeferredRender(handlebarsTemplate.render()));
    TEST.assert_equal(false, O.isDeferredRender(hsvtTemplate.render()));

    TEST.assert_equal(true, O.isDeferredRender(handlebarsTemplate.deferredRender()));
    TEST.assert_equal(true, O.isDeferredRender(hsvtTemplate.deferredRender()));

    var genericDeferred = new $GenericDeferredRender(function() { return ''; });
    TEST.assert_equal(true, O.isDeferredRender(genericDeferred));

});
