/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // JavaScript native types
    TEST.assert_equal(O.T_INTEGER, O.typecode(23));
    TEST.assert_equal(O.T_NUMBER, O.typecode(23.5));    // not ideal really, but there you go
    TEST.assert_equal(O.T_TEXT, O.typecode("hello"));   // because it'll be autoconverted
    TEST.assert_equal(O.T_DATETIME, O.typecode(new Date()));
    TEST.assert_equal(O.T_DATETIME, O.typecode(O.datetime(new Date())));
    TEST.assert_equal(O.T_BOOLEAN, O.typecode(true));
    TEST.assert_equal(O.T_BOOLEAN, O.typecode(false));

    // Things which can't be used as values in an object
    TEST.assert_equal(null, O.typecode({}));
    TEST.assert_equal(null, O.typecode([]));
    TEST.assert_equal(null, O.typecode(null));
    TEST.assert_equal(null, O.typecode(undefined));

    // Ref
    TEST.assert_equal(O.T_REF, O.T_OBJREF); // check alias
    var ref = O.ref(24);
    TEST.assert_equal(O.T_REF, O.typecode(ref));
    TEST.assert_equal(true, O.isRef(ref));
    TEST.assert_equal(false, O.isRef("hello"));

    // Text
    var t1 = O.text(O.T_TEXT_PARAGRAPH, "Ping");
    TEST.assert_equal(O.T_TEXT_PARAGRAPH, O.typecode(t1));
    TEST.assert_equal(true, O.isText(t1));
    var t2 = O.text(O.T_TEXT_PERSON_NAME, {first:"Hello", last:"World"});
    TEST.assert_equal(O.T_TEXT_PERSON_NAME, O.typecode(t2));
    TEST.assert_equal(true, O.isText(t2));
    var t3 = O.text(O.T_IDENTIFIER_POSTAL_ADDRESS, {street1:"Ping", city:"Somewhere", country:"GB"});
    TEST.assert_equal(O.T_IDENTIFIER_POSTAL_ADDRESS, O.typecode(t3));
    TEST.assert_equal(true, O.isText(t3));
    var t4 = O.text(O.T_IDENTIFIER_TELEPHONE_NUMBER, {guess_number:"+4470471111", guess_country:"GB"});
    TEST.assert_equal(O.T_IDENTIFIER_TELEPHONE_NUMBER, O.typecode(t4));
    TEST.assert_equal(true, O.isText(t4));
    TEST.assert_equal(false, O.isText(ref));

});
