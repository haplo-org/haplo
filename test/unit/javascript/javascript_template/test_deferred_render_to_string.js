/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var handlebarsDeferred = O.$createPluginTemplate({}, "test", "<div>XYZ</div>", "html").deferredRender({});
    var hsvtDeferred = new $HaploTemplate('<div> "PQY" </div>').deferredRender({});
    var genericDeferred = new $GenericDeferredRender(function() { return '<div>ABC</div>'; });

    TEST.assert_equal('<div>XYZ</div>', handlebarsDeferred.toString());
    TEST.assert_equal('<div>PQY</div>', hsvtDeferred.toString());
    TEST.assert_equal('<div>ABC</div>', genericDeferred.toString());

});
