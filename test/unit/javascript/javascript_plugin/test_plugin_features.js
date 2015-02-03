/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    TEST.assert_equal(true, O.featureImplemented("test:feature"));
    TEST.assert_equal(false, O.featureImplemented("test:notimpl"));

    // Check the function got injected by the providing plugin
    // TODO: More tests for plugin features, especially around error checking and edge cases

    // Plugin using use() function
    TEST.assert_equal("function", typeof(test_use_feature.timesTwo));
    TEST.assert_equal(42, test_use_feature.timesTwo(21));

    // Plugin using use:[] in plugin.json
    TEST.assert_equal("function", typeof(test_use_feature2.timesTwo));
    TEST.assert_equal(64, test_use_feature2.timesTwo(32));

});
