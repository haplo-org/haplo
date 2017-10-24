/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var d0 = O.bigDecimal(123498271);
    TEST.assert(d0 instanceof $BigDecimal);
    TEST.assert_equal("123498271", d0.toString());
    TEST.assert_equal(123498271, d0.toDouble());

    var d1 = O.bigDecimal(1625211);
    TEST.assert_equal(1625211, d1.toDouble());

    var d2 = d0.multiply(d1);
    TEST.assert_equal("200710748510181", d2.toString());
    TEST.assert_equal("[BigDecimal 200710748510181]", $KScriptable.forConsole(d2));

    TEST.assert_equal("2477241303320889914445", d0.multiply(d1).multiply(O.bigDecimal(12342345)).toString());

    // Equality
    TEST.assert_equal(false, d0.equals(d1));
    TEST.assert_equal(true, d0.equals(d0));
    TEST.assert_equal(true, d0.equals(O.bigDecimal(123498271)));
    TEST.assert_equal(0, d0.compareTo(O.bigDecimal(123498271)));
    TEST.assert_equal(1, d0.compareTo(d1));

    // Operations (script generated from Java interface)
    TEST.assert_equal("1234", O.bigDecimal(-1234).abs().toString());
    TEST.assert_equal("1001", O.bigDecimal(1000).add(O.bigDecimal(1)).toString());
    TEST.assert_equal(4, O.bigDecimal(1000).precision());
    TEST.assert_equal("8000", O.bigDecimal(20).pow(3).toString())

    // Setting scale
    var rounded = O.bigDecimal(19.229435).setScaleWithRounding(2);
    TEST.assert_equal("19.23", rounded.toString());

    // Formatting
    TEST.assert_equal("123,456,789.90", O.bigDecimal(123456789.897).format("#,###.00"));
    var formatter = O.numberFormatter("#,##.000");
    TEST.assert(typeof(formatter) === "function");
    TEST.assert_equal("9,87,65,43.827", formatter(O.bigDecimal(9876543.8273)));

    // Formatting also works with JS numbers
    TEST.assert_equal("12,34,56.123", formatter(123456.123455));

    // Check formatter API
    var specialFormatter = function() { return "special"; };
    TEST.assert_equal(specialFormatter, O.numberFormatter(specialFormatter));
    TEST.assert_equal("special", O.numberFormatter(specialFormatter)(1234));

    // Construct from String
    d10 = O.bigDecimal("1.2348726e12");
    TEST.assert_equal("1234872600000", d10.toString());
    d11 = O.bigDecimal("102389372310.3487236217361782846251");
    TEST.assert_equal("102389372310.3487236217361782846251", d11.toString());

    // Bad use of interface
    TEST.assert_exceptions(function() {
        O.bigDecimal([]);
    }, "BigDecimals must be constructed with a number or a string representation of a BigDecimal");
    TEST.assert_exceptions(function() {
        d0.divide("x");
    }, "argument must be a BigDecimal");
    TEST.assert_exceptions(function() {
        d0.scaleByPowerOfTen("x");
    }, "argument must be a number");

});
