/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    var checkRefArray = function(expected, given) {
        TEST.assert_equal(expected.length, given.length);
        for(var i = 0; i < expected.length; ++i) {
            TEST.assert(given[i] instanceof $Ref);
            TEST.assert_equal(given[i].objId, expected[i]);
        }
    };

    checkRefArray([2], [O.ref(2)]);

    // Get the test object
    TEST.assert(TEST_OBJ_ID > 1024);
    var testObject = O.ref(TEST_OBJ_ID).load();
    TEST.assert(testObject instanceof $StoreObject);
    TEST.assert_equal(TEST_OBJ_ID, testObject.ref.objId);

    // Emptiness
    checkRefArray([], O.deduplicateArrayOfRefs(undefined));
    checkRefArray([], O.deduplicateArrayOfRefs(null));
    checkRefArray([], O.deduplicateArrayOfRefs([]));
    checkRefArray([], O.deduplicateArrayOfRefs([null]));
    checkRefArray([], O.deduplicateArrayOfRefs([undefined]));
    checkRefArray([], O.deduplicateArrayOfRefs([undefined,null]));

    // Entries with wrong type
    var BAD_TYPE_MSG = "Array for Ref deduplication may only contain Ref objects, StoreObject objects, undefined and null";
    TEST.assert_exceptions(function() { O.deduplicateArrayOfRefs(["hello"]); }, BAD_TYPE_MSG);
    TEST.assert_exceptions(function() { O.deduplicateArrayOfRefs([1]); }, BAD_TYPE_MSG);
    TEST.assert_exceptions(function() { O.deduplicateArrayOfRefs([false]); }, BAD_TYPE_MSG);
    TEST.assert_exceptions(function() { O.deduplicateArrayOfRefs(["ping", O.ref(12)]); }, BAD_TYPE_MSG);

    // Allowed types work
    checkRefArray([10],          O.deduplicateArrayOfRefs([O.ref(10)]));
    checkRefArray([TEST_OBJ_ID], O.deduplicateArrayOfRefs([testObject]));

    // Multiple entries with null/undefined
    checkRefArray([10, 12], O.deduplicateArrayOfRefs([O.ref(10), O.ref(12)]));
    checkRefArray([10, 12], O.deduplicateArrayOfRefs([O.ref(10), O.ref(12), null]));
    checkRefArray([TEST_OBJ_ID, TEST_OBJ_ID+1], O.deduplicateArrayOfRefs([testObject, undefined, O.ref(TEST_OBJ_ID+1)]));

    // Deduplication
    checkRefArray([10],          O.deduplicateArrayOfRefs([O.ref(10), O.ref(10), null]));
    checkRefArray([TEST_OBJ_ID], O.deduplicateArrayOfRefs([O.ref(TEST_OBJ_ID), testObject]));
    checkRefArray([10, 12],      O.deduplicateArrayOfRefs([O.ref(10), O.ref(12), O.ref(10), null]));
    checkRefArray([10, 12],      O.deduplicateArrayOfRefs([O.ref(10), O.ref(10), O.ref(12)]));
    checkRefArray([10, 12, 100], O.deduplicateArrayOfRefs([O.ref(10), O.ref(10), O.ref(12), O.ref(10), O.ref(100)]));

});
