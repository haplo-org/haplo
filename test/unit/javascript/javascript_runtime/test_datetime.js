/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // Belts and braces check to make sure the JavaScript runtime is in GMT.
    TEST.assert_equal(0, (new Date()).getTimezoneOffset());

    var dt1 = O.datetime(new Date(2011, 4 - 1, 12, 19, 14));
    TEST.assert_equal(O.T_DATETIME, O.typecode(dt1));
    TEST.assert_equal(O.PRECISION_DAY, dt1.precision);
    TEST.assert_equal(null, dt1.timezone);
    TEST.assert_equal("12 Apr 2011", dt1.toString());
    TEST.assert_equal("12 Apr 2011", dt1.toHTML());
    TEST.assert_equal("Tue, 12 Apr 2011 00:00:00 GMT", dt1.start.toUTCString());
    TEST.assert_equal("Wed, 13 Apr 2011 00:00:00 GMT", dt1.end.toUTCString());

    var dt2 = O.datetime(new Date(2010, 12 - 1, 2, 9, 4), null, O.PRECISION_MINUTE, 'Europe/London');
    TEST.assert_equal(O.PRECISION_MINUTE, dt2.precision);
    TEST.assert_equal('Europe/London', dt2.timezone);
    TEST.assert_equal("02 Dec 2010, 09:04 (Europe/London)", dt2.toString());
    TEST.assert_equal("02 Dec 2010, 09:04 (Europe/London)", dt2.toHTML());
    TEST.assert_equal("Thu, 02 Dec 2010 09:04:00 GMT", dt2.start.toUTCString());
    TEST.assert_equal("Thu, 02 Dec 2010 09:05:00 GMT", dt2.end.toUTCString());

    var dt3 = O.datetime(new Date(2010, 7 - 1, 15, 18, 56), new Date(2010, 7 - 1, 21, 12, 23), O.PRECISION_MINUTE, 'Europe/London');
    TEST.assert_equal(O.PRECISION_MINUTE, dt3.precision);
    TEST.assert_equal('Europe/London', dt3.timezone);
    TEST.assert_equal("15 Jul 2010, 18:56 to 21 Jul 2010, 12:23 (Europe/London)", dt3.toString());
    TEST.assert_equal("15 Jul 2010, 18:56 <i>to</i><br>21 Jul 2010, 12:23 (Europe/London)", dt3.toHTML());
    // Note that the *times* below are different due to conversion to GMT
    TEST.assert_equal("Thu, 15 Jul 2010 17:56:00 GMT", dt3.start.toUTCString());
    TEST.assert_equal("Wed, 21 Jul 2010 11:23:00 GMT", dt3.end.toUTCString()); // not extended by precision time unit

    // Construction with library dates
    var cdt10 = O.datetime(new XDate(2020, 12 - 1, 2, 9, 4), null, O.PRECISION_MINUTE);
    TEST.assert_equal("Wed, 02 Dec 2020 09:04:00 GMT", cdt10.start.toUTCString());
    var cdt11 = O.datetime(moment(new Date(2021, 12 - 1, 2, 9, 4)), null, O.PRECISION_MINUTE);
    TEST.assert_equal("Thu, 02 Dec 2021 09:04:00 GMT", cdt11.start.toUTCString());

    // TODO: Check bad construction of datetimes, eg wrong precision, bad timezone, etc

    // Check framework library integration
    // 1) Testing acceptable dates
    TEST.assert_equal(false, O.$isAcceptedDate(false));
    TEST.assert_equal(false, O.$isAcceptedDate(true));
    TEST.assert_equal(false, O.$isAcceptedDate(undefined));
    TEST.assert_equal(false, O.$isAcceptedDate(null));
    TEST.assert_equal(false, O.$isAcceptedDate("Wed, 21 Jul 2010 11:23:00 GMT"));
    TEST.assert_equal(true, O.$isAcceptedDate(new Date())); // Native
    TEST.assert_equal(true, O.$isAcceptedDate(new XDate())); // XDate
    TEST.assert_equal(true, O.$isAcceptedDate(moment(new Date()))); // moment.js
    // 2) Conversion from library date
    TEST.assert_equal(false, O.$convertIfLibraryDate(false));
    TEST.assert_equal(true, O.$convertIfLibraryDate(true));
    TEST.assert_equal(undefined, O.$convertIfLibraryDate(undefined));
    TEST.assert_equal(null, O.$convertIfLibraryDate(null));
    TEST.assert_equal("Hello", O.$convertIfLibraryDate("Hello"));
    TEST.assert_equal("", O.$convertIfLibraryDate(""));
    var d1 = new Date(2012, 10, 9, 2, 50);
    TEST.assert_equal(d1, O.$convertIfLibraryDate(d1));
    TEST.assert(O.$convertIfLibraryDate(new XDate(d1)) instanceof Date);
    TEST.assert(d1.toUTCString() == O.$convertIfLibraryDate(new XDate(d1)).toUTCString());
    TEST.assert(O.$convertIfLibraryDate(moment(d1)) instanceof Date);
    TEST.assert(d1.toUTCString() == O.$convertIfLibraryDate(moment(d1)).toUTCString());

    // Test moment.js parsing and formatting (library requires modification for sealed environment)
    TEST.assert_equal('April 5th 2011', moment("20110405","YYYYMMDD").format('MMMM Do YYYY'));
});
