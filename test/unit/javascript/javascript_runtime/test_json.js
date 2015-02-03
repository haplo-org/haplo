/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    // Simple hash with varying contents
    var t1 = {pant:2, arr:[1,4, 6], str:"Ping"};
    // Array with nulls
    // Sparse arrays generated with var t2 = [132,652,10884]; t2[12] = 34;
    // don't have the same keys, so don't pass underscore's strict tests
    var t2 = [132,652,10884,null,null,null,null,null,null,null,null,null,34];

    var t1_json = JSON.stringify(t1);
    TEST.assert_equal('{"pant":2,"arr":[1,4,6],"str":"Ping"}', t1_json);
    TEST.assert(_.isEqual(t1, JSON.parse(t1_json)));

    var t2_json = JSON.stringify(t2);
    TEST.assert_equal('[132,652,10884,null,null,null,null,null,null,null,null,null,34]', t2_json);
    TEST.assert(_.isEqual(t2, JSON.parse(t2_json)));

});
