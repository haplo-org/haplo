/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var ref1 = O.ref(OBJECT1);
    var ref2 = O.ref(OBJECT2);

    var USER1_ID = 41;
    var USER2_ID = 42;
    var USER3_ID = 43;

    var unit1 = O.work.create({
        workType:"test:pants",
        createdBy:USER3_ID,
        actionableBy:USER3_ID,
        ref: ref1
    });
    unit1.save();
    var unit2 = O.work.create({
        workType:"test:pants",
        createdBy:USER1_ID,
        actionableBy:USER1_ID,
        ref: ref2
    });
    unit2.save();

    var sortedIdsStr = function(q) { return _.map(q, function(wu) { return wu.id; }).sort().toString(); };

    TEST.assert_equal([unit1.id, unit2.id].toString(), sortedIdsStr(O.work.query("test:pants")));
    TEST.assert_equal([          unit2.id].toString(), sortedIdsStr(O.work.query("test:pants")._temp_refPermitsReadByUser(O.user(USER1_ID))));
    TEST.assert_equal([unit1.id, unit2.id].toString(), sortedIdsStr(O.work.query("test:pants")._temp_refPermitsReadByUser(O.user(USER3_ID))));

    TEST.assert_exceptions(function() { O.work.query("test:pants")._temp_refPermitsReadByUser(); }, "User object expected");
    TEST.assert_exceptions(function() { O.work.query("test:pants")._temp_refPermitsReadByUser(34); }, "User object expected");
    TEST.assert_exceptions(function() { O.work.query("test:pants")._temp_refPermitsReadByUser("32"); }, "User object expected");

});
