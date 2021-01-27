/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2021            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // TimeZone is a thin wrapper over the Java TimeZone object

    var utc = O.timeZone("UTC");
    TEST.assert_equal("UTC", utc.id);
    TEST.assert_equal("Coordinated Universal Time", utc.displayName);
    TEST.assert_equal(0, utc.getOffset());

    var utc4 = O.timeZone("Etc/GMT+4");
    TEST.assert_equal("Etc/GMT+4", utc4.id);
    TEST.assert_equal(-14400000, utc4.getOffset());
    TEST.assert_equal(-14400000, utc4.getOffset(null));
    TEST.assert_equal(-14400000, utc4.getOffset(undefined));

    var london = O.timeZone("Europe/London");
    TEST.assert_equal(0, london.getOffset(new Date(2020,02,01)));       // winter
    TEST.assert_equal(3600000, london.getOffset(new Date(2020,06,01))); // summer

    TEST.assert_exceptions(function() { london.getOffset("something"); }, "getOffset() requires an Date object, or no arguments to specify current time");

});
