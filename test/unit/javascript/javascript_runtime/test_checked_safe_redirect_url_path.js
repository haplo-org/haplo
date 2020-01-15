/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    TEST.assert_equal("/do/path", O.checkedSafeRedirectURLPath("/do/path"));
    TEST.assert_equal("/do/path?a=b&c=d&x=%20hello", O.checkedSafeRedirectURLPath("/do/path?a=b&c=d&x=%20hello"));
    TEST.assert_equal(null, O.checkedSafeRedirectURLPath("do/path"));
    TEST.assert_equal(null, O.checkedSafeRedirectURLPath("//example.org/do/path"));
    TEST.assert_equal(null, O.checkedSafeRedirectURLPath("/\\example.org/do/path")); // exploit browser flexibility
    TEST.assert_equal(null, O.checkedSafeRedirectURLPath("\\\\example.org/do/path"));

});
