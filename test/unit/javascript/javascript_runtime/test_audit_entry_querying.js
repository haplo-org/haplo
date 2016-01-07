/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    $host._testCallback("resetAudit");
    // -------------------------------------------------------------------------
    // Write a simple entry
    var data = {"a": "b", "d": 458745};
    var entry0 = O.audit.write({
        auditEntryType: "test:kind0",
        displayable: true,
        data: data
    });

    var query = O.audit.query();
    TEST.assert_equal(query.length, 1);
    var entry = query[0];
    TEST.assert_equal(query[0].auditEntryType, "test:kind0");
    TEST.assert_equal(_.isEqual(query[0].data, data), true);

    // -------------------------------------------------------------------------
    $host._testCallback("resetAudit");

    O.audit.write({
        auditEntryType: "test:kind0",
        displayable: true,
    });
    O.audit.write({
        auditEntryType: "test:kind1",
        displayable: false,
    });

    function countByType(expected) {
        var types = _.toArray(arguments).slice(1);
        var query = O.audit.query().displayable(null);
        query.auditEntryType.apply(query, types);
        if(query.length !== expected) {
            console.log("Got " + query.length + " audit entries, expected " + expected + ". types: " + types);
            _.each(query, function(entry) {
                console.log(entry.auditEntryType);
            });
        }
        TEST.assert_equal(query.length, expected);
        return query;
    }

    countByType(1, "test:kind0");
    countByType(0, "test:kind2");
    countByType(2, "test:kind0", "test:kind1");
    countByType(1, "test:kind0", "test:kind2");

    // -------------------------------------------------------------------------
    $host._testCallback("loadFixture");

    var after = new Date();

    function getTypes(query) {
        return _.map(_.toArray(query), function(entry) {
            return entry.data.XX;
        }).join('');
    }
    function queryAll() {
        return O.audit.query().displayable(null);
    }
    // Look in fixtures/audit_entry.csv to understand these:
    // Note, displayable=true only by default..
    TEST.assert_equal(getTypes(O.audit.query()), "98642");
    TEST.assert_equal(getTypes(queryAll()), "987654321");
    TEST.assert_equal(getTypes(queryAll().sortBy("auditEntryType")), "543198762");
    // This next one isn't the exact reverse, because implicit created_at DESC sorting
    // still applies, so the kind sorting is reversed, but not the date..
    TEST.assert_equal(getTypes(queryAll().sortBy("auditEntryType_asc")), "627895431");
    TEST.assert_equal(getTypes(queryAll().sortBy("displayable")), "986427531");

    // Displayable
    TEST.assert_equal(getTypes(O.audit.query()), "98642");
    TEST.assert_equal(getTypes(O.audit.query().displayable(true)), "98642");
    TEST.assert_equal(getTypes(O.audit.query().displayable(false)), "7531");
    TEST.assert_equal(getTypes(O.audit.query().displayable(null)), "987654321");

    O.impersonating(O.SYSTEM, function() {
        TEST.assert_equal(getTypes(O.audit.query().displayable(null)), "987654321");
    });

    // Time based queries
    var may = new Date("May 1, 2013 11:00:00");
    var tenOClock = new Date("June 6, 2013 10:00:00");  // entry 1
    var elevenOClock = new Date("June 6, 2013 11:00:00"); // entry 2
    var oneOClock = new Date("June 6, 2013 13:00:00"); // after entry 3
    var july = new Date("July 1, 2013 00:00:00"); // After all
    TEST.assert_equal(getTypes(queryAll().dateRange(may, july)), "987654321");
    TEST.assert_equal(getTypes(queryAll().dateRange(oneOClock, july)), "987654");
    TEST.assert_equal(getTypes(queryAll().dateRange(may, elevenOClock)), "21");
    TEST.assert_equal(getTypes(queryAll().dateRange(elevenOClock, oneOClock)), "32");

    // Based on Object
    TEST.assert_equal(getTypes(queryAll().ref(O.ref(75))), "64");
    TEST.assert_equal(getTypes(queryAll().ref(76)), "7");

    // Based on editing a user
    TEST.assert_equal(getTypes(queryAll().entityId(129)), "41");
    TEST.assert_equal(getTypes(queryAll().entityId(130)), "");

    // Edited by a user
    TEST.assert_equal(getTypes(queryAll().userId(129)), "741");
    TEST.assert_equal(getTypes(queryAll().userId(120)), "986532");

    // Edited by a user with impersonation
    TEST.assert_equal(getTypes(queryAll().authenticatedUserId(121)), "98765");
    TEST.assert_equal(getTypes(queryAll().authenticatedUserId(129)), "4321");

    // Test chaining.  USER-LOGIN: 1, 3, 4, 5.  Ref(75): 4, 6 so expect only 4
    TEST.assert_equal(getTypes(queryAll().auditEntryType("USER-LOGIN").ref(O.ref(75))), "4");
    // {987654} & {986532} => {9865}
    TEST.assert_equal(getTypes(queryAll().dateRange(oneOClock, july).userId(120)), "9865");

    // First method
    TEST.assert_equal(queryAll().displayable(true).first().data.XX, 9);

    var sortedQuery = queryAll().sortBy("auditEntryType_asc"); //62785431
    TEST.assert_equal(sortedQuery.first().data.XX, 6);
    TEST.assert_equal(sortedQuery.length, 9);

    TEST.assert_equal(queryAll().limit(2).length, 2);
    TEST.assert_equal(queryAll().limit(1000).length, 9);

    for(var i=0; i < 1010; ++i) {
        O.audit.write({
            auditEntryType: "test:kindx",
            displayable: true,
        });
    }

    TEST.assert_equal(queryAll().auditEntryType("test:kindx").length, 1000);
    TEST.assert_equal(queryAll().auditEntryType("test:kindx").limit(500).length, 500);
    TEST.assert_equal(queryAll().auditEntryType("test:kindx").limit(2000).length, 1010);

});