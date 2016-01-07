/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {
    var e1 = O.ref(5);
    var e2 = O.ref(5);
    var e3 = O.ref(7);
    var e4 = O.ref(8);
    TEST.assert(e1 == e2);
    TEST.assert(e1 != e3);
    TEST.assert(e1 != e4);
    // TEST.assert(e1 === e2); // nice to make this work, but can't
    TEST.assert(e1 !== e2);  // Rhino doesn't allow overriding of ===
    TEST.assert(e1 !== e3);
    TEST.assert(e1 !== e4);
    TEST.assert_equal("5", e1.toString());
    TEST.assert_equal("8", e4.toString());
    TEST.assert_equal("12345", O.ref(0x12345).toString());
    TEST.assert_equal(null, O.ref("pants"));
    TEST.assert(null == O.ref("-1-1zq4"));
    TEST.assert(null == O.ref("1-1zq4-"));
    TEST.assert(null == O.ref("-1zq4"));
    TEST.assert(null == O.ref("1-"));
    TEST.assert(O.ref("qvwxyz") == O.ref(0xabcdef));

    // Passing a ref into O.ref() returns the same object
    var e1_refed = O.ref(e1);
    TEST.assert_equal("5", e1_refed.toString());
    TEST.assert_equal(e1, e1_refed);

    // Passing null or undefined into O.ref() returns null
    TEST.assert_equal(null, O.ref(null));
    TEST.assert_equal(null, O.ref(undefined));

    // Anything else throws an exception
    TEST.assert_exceptions(function() { O.ref([]); });

    TEST.assert_equal(null, O.ref("foobar"));

    TEST.assert_exceptions(function() {
        O.ref(1, 2);
    }, "Bad arguments to O.ref(). O.ref no longer takes a section.");

    var ref = O.ref(1);
    TEST.assert_equal(1, ref.objId);

    var ref2 = O.ref(O.ref(2));
    TEST.assert_equal(2, ref2.objId);

});