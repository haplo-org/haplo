/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    var t1 = new DBTime(12,54,23);
    TEST.assert_equal("12:54:23", t1.toString());
    TEST.assert_equal(12, t1.getHours());
    TEST.assert_equal(54, t1.getMinutes());
    TEST.assert_equal(23, t1.getSeconds());
    TEST.assert_equal(46463000, t1.getTime());  // check conversion to milliseconds
    var t2 = new DBTime(1,2,3);
    TEST.assert_equal("01:02:03", t2.toString());
    TEST.assert_equal(1, t2.getHours());
    TEST.assert_equal(2, t2.getMinutes());
    TEST.assert_equal(3, t2.getSeconds());
    var t3 = new DBTime(1,20);
    TEST.assert_equal("01:20", t3.toString());
    TEST.assert_equal(1, t3.getHours());
    TEST.assert_equal(20, t3.getMinutes());
    TEST.assert_equal(0, t3.getSeconds());
    var t7 = new DBTime(23);
    TEST.assert_equal("23:00", t7.toString());
    TEST.assert_equal(23, t7.getHours());
    TEST.assert_equal(0, t7.getMinutes());
    TEST.assert_equal(0, t7.getSeconds());

    TEST.assert_exceptions(function() { new DBTime(-1, 3, 3); });
    TEST.assert_exceptions(function() { new DBTime(3, -1, 3); });
    TEST.assert_exceptions(function() { new DBTime(3, 3, -1); });
    TEST.assert_exceptions(function() { new DBTime(24, 3, 3); });
    TEST.assert_exceptions(function() { new DBTime(3, 60, 3); });
    TEST.assert_exceptions(function() { new DBTime(3, 3, 60); });
    TEST.assert_exceptions(function() { new DBTime("A", 3); });
    TEST.assert_exceptions(function() { new DBTime(4, "b"); });
    TEST.assert_exceptions(function() { new DBTime(); });

    var t4 = DBTime.parse("01:34");
    TEST.assert_equal(1, t4.getHours());
    TEST.assert_equal(34, t4.getMinutes());
    TEST.assert_equal(0, t4.getSeconds());
    var t5 = DBTime.parse("15:59:03");
    TEST.assert_equal(15, t5.getHours());
    TEST.assert_equal(59, t5.getMinutes());
    TEST.assert_equal(3, t5.getSeconds());

    TEST.assert_equal(null, DBTime.parse("0:12:02"));
    TEST.assert_equal(null, DBTime.parse("12:2:01"));
    TEST.assert_equal(null, DBTime.parse("12:12:3"));
    TEST.assert_equal(null, DBTime.parse("12:12:3"));
    TEST.assert_equal(null, DBTime.parse("12"));
    TEST.assert_equal(null, DBTime.parse("ping"));
    TEST.assert_equal(null, DBTime.parse("pi:ng:00"));
    TEST.assert_equal(null, DBTime.parse("12:00:00:23"));

});

