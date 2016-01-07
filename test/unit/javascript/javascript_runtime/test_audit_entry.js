/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    // 1) Test all the errors when writing an audit entry

    // Check bad data types
    _.each(["Hello", null, undefined, [1,2,4], 17, function() {}], function(bad) {
        TEST.assert_exceptions(function() {
            O.audit.write(bad);
        }, "Must pass an object to O.audit.write()");
    });

    // Check ref & secId (handled in JS)
    TEST.assert_exceptions(function() {
        O.audit.write({secId:90});
    }, "Use of secId is no longer valid.");
    TEST.assert_exceptions(function() {
        O.audit.write({ref:O.ref(2), objId:90});
    }, "Can't pass objId property to O.audit.write()");
    TEST.assert_exceptions(function() {
        O.audit.write({ref:"hello"});
    }, "The ref property for O.audit.write() must be a Ref");

    // Check data (done in JS)
    TEST.assert_exceptions(function() {
        O.audit.write({data:"123"});
    }, "The data property must be an Object for O.audit.write()");
    TEST.assert_exceptions(function() {
        O.audit.write({data:["123",4]});
    }, "The data property must be an Object for O.audit.write()");

    // Check checks on properties
    TEST.assert_exceptions(function() {
        O.audit.write({hello:true});
    }, "Property auditEntryType is required for O.audit.write()");
    TEST.assert_exceptions(function() {
        O.audit.write({auditEntryType:true});
    }, "Property auditEntryType must be a string");
    TEST.assert_exceptions(function() {
        O.audit.write({auditEntryType:"ping"});
    }, "Property auditEntryType must match /^[a-z0-9_]+:[a-z0-9_]+$/");
    TEST.assert_exceptions(function() {
        O.audit.write({auditEntryType:"ABC:DEF09"});
    }, "Property auditEntryType must match /^[a-z0-9_]+:[a-z0-9_]+$/");
    TEST.assert_exceptions(function() {
        O.audit.write({auditEntryType:"a:x", entityId:"hello"});
    }, "Property entityId must be a integer");
    TEST.assert_exceptions(function() {
        O.audit.write({auditEntryType:"a:x", displayable:"carrots"});
    }, "Property displayable must be true or false");

    // ----------------------------------------------------------------------------------------

    // 2) Check actual writing of entries

    // Write a simple entry
    var entry0 = O.audit.write({
        auditEntryType: "test:kind0",
        displayable: true,
        data: {"a": "b", "d": 458745}
    });

    // Check what was returned
    TEST.assert_equal("test:kind0", entry0.auditEntryType);
    TEST.assert_equal(true, entry0.displayable);
    var UNLABELLED = 100;
    TEST.assert(O.ref(UNLABELLED), entry0.labels[0]);
    TEST.assert_equal(1, entry0.labels.length);
    TEST.assert_equal(null, entry0.remoteAddress);
    TEST.assert_equal(0, entry0.userId);
    TEST.assert_equal(0, entry0.authenticatedUserId);
    TEST.assert_equal(null, entry0.entityId);
    TEST.assert_equal("b", entry0.data["a"]);
    TEST.assert_equal(458745, entry0.data["d"]);

    // Check the ruby side was happy
    $host._testCallback("ONE");

    // Another using a ref
    var entry1 = O.audit.write({
        auditEntryType: "test:ping4",
        displayable: false,
        ref: O.ref(89),
        entityId: 997
    });

    TEST.assert_equal("test:ping4", entry1.auditEntryType);
    TEST.assert_equal(false, entry1.displayable);
    TEST.assert(O.ref(89) == entry1.ref);
    TEST.assert_equal(undefined, entry1.objId); // doesn't have matching objId
    TEST.assert_equal(997, entry1.entityId);

    $host._testCallback("TWO");

    // Check displayable defaults to false, and all you need is a kind
    var entry2 = O.audit.write({auditEntryType: "test:kind2"});
    TEST.assert_equal(false, entry2.displayable);

});
