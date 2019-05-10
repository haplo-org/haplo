/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var parser0 = O.dateParser("yyyy-MM-dd");
    TEST.assert_equal("function", typeof(parser0));
    TEST.assert(parser0("2000-09-28") instanceof Date);
    TEST.assert_equal("Mon Mar 19 2001 00:00:00 GMT-0000 (UTC)", parser0("2001-03-19").toString());
    TEST.assert_equal("Fri Dec 17 1976 00:00:00 GMT-0000 (UTC)", parser0("1976-12-17").toString());
    TEST.assert_equal(null, parser0("gardens"));

    var parser1 = O.dateParser("yyyy.MM.dd G 'at' HH:mm:ss z");
    TEST.assert_equal("Wed Jul 04 2001 19:08:56 GMT-0000 (UTC)", parser1('2001.07.04 AD at 12:08:56 PDT').toString());

    TEST.assert_exceptions(function() {
        O.dateParser();
    }, "Bad format argument to O.dateParser()");
    TEST.assert_exceptions(function() {
        O.dateParser(234);
    }, "Bad format argument to O.dateParser()");

});
