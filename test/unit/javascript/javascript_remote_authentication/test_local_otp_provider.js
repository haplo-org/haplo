/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    O.remote.authentication.connect('ONE-TIME-PASSWORD', function(service) {

        TEST.assert_equal("ONE-TIME-PASSWORD", service.name);

        var i0 = service.authenticate("test-1-time", '');
        TEST.assert_equal("failure", i0.result);

        var i1 = service.authenticate("test-1-time", '000000');
        TEST.assert_equal("failure", i1.result);

        var i2 = service.authenticate("test-1-time", NEXT_OTP);
        TEST.assert_equal("success", i2.result);

    });

});
