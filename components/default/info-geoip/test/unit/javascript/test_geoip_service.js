/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var result = O.service("haplo:info:geoip:lookup", "IPv4", "128.101.101.101");
    TEST.assert_equal("NA", result.continent);
    TEST.assert_equal("US", result.country);

    var bbc = O.service("haplo:info:geoip:lookup", "IPv4", "212.58.244.1");
    TEST.assert_equal("EU", bbc.continent);
    TEST.assert_equal("GB", bbc.country);

    TEST.assert_exceptions(function() {
        O.service("haplo:info:geoip:lookup", "xyz", "128.101.101.101");
    }, "Unsupported protocol: xyz");

    var notfound = O.service("haplo:info:geoip:lookup", "IPv4", "0.0.0.0");
    TEST.assert_equal("failed", notfound.error);

    TEST.assert_exceptions(function() {
        O.service("haplo:info:geoip:lookup", "IPv4", "invalid");
    }, "Bad address: invalid");

});
