/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    TEST.assert_equal("test_provide_feature,no_privileges_plugin,test_plugin", O.application.plugins.join(',')); // so when it fails, the error is clear
    TEST.assert(_.isEqual(["test_provide_feature","no_privileges_plugin","test_plugin"], O.application.plugins)); // proper typed test
    // NOTE: Ruby plugins are not included

    var tpf = O.getPluginInstance("test_provide_feature");
    TEST.assert(tpf instanceof $Plugin);
    TEST.assert_equal("test_provide_feature", tpf.pluginName);
    TEST.assert_exceptions(function() {
        O.getPluginInstance("std_document_store");
    }, "Unknown plugin: std_document_store");

});
