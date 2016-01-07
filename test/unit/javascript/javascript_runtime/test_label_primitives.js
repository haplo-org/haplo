/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    TEST.assert_exceptions(function() { O.labelList(-1); }, "Bad label value (<= 0)");
    TEST.assert_exceptions(function() { O.labelList("Ping"); }, "Bad label value");

    var labels0 = O.labelList(3, 1, 2, O.ref(238), [19, 388]);
    TEST.assert(labels0 instanceof $LabelList);
    TEST.assert_equal("[1, 2, 3, 13, yy, 184]", labels0.toString());
    TEST.assert_equal(6, labels0.length);
    TEST.assert(O.ref(238) == labels0[4]);

    TEST.assert_exceptions(function() { var x = labels0[-1]; }, "Index out of range for LabelList (requested index -1 for list of length 6)");
    TEST.assert_exceptions(function() { var x = labels0[6];  }, "Index out of range for LabelList (requested index 6 for list of length 6)");

    var labels1 = O.labelList([3, 4]);
    var labels2 = O.labelList(3, 4);
    var labels3 = O.labelList(2, 4);
    var labels4 = O.labelList();
    TEST.assert_equal(0, labels4.length);
    TEST.assert(labels1 == labels2);
    TEST.assert(labels2 != labels3);
    TEST.assert(labels4 != labels3);
    TEST.assert(labels4 != labels1);

    TEST.assert(labels1.includes(3));
    TEST.assert(! labels1.includes(23));
    TEST.assert(! labels3.includes(3));

    // ---------------------------------------------------------------------------------------------

    // Label list filtering
    var labelsX = O.labelList(TYPE["std:type:book"], LABEL["std:label:common"], LABEL["std:label:confidential"], 10999382);
    var filteredToProperLabels = labelsX.filterToLabelsOfType([TYPE["std:type:label"]]);
    TEST.assert(filteredToProperLabels == O.labelList(LABEL["std:label:common"], LABEL["std:label:confidential"]));
    TEST.assert_exceptions(function() { labelsX.filterToLabelsOfType(); }, "Must pass an array to filterToLabelsOfType()");
    TEST.assert_exceptions(function() { labelsX.filterToLabelsOfType("hello"); }, "Must pass an array to filterToLabelsOfType()");
    TEST.assert_exceptions(function() { labelsX.filterToLabelsOfType({}); }, "Must pass an array to filterToLabelsOfType()");
    TEST.assert_exceptions(function() { labelsX.filterToLabelsOfType([]); }, "Must pass at least one type to filterToLabelsOfType()");

    // And test we can use that to make a nice LabelChanges object which makes that change
    var filteringChanges = O.labelChanges();
    filteringChanges.remove(labelsX);
    filteringChanges.add(filteredToProperLabels);
    TEST.assert(filteringChanges.change(labelsX) == O.labelList(LABEL["std:label:common"], LABEL["std:label:confidential"]));

    // ---------------------------------------------------------------------------------------------

    var changes0 = O.labelChanges();
    TEST.assert(changes0 instanceof $LabelChanges);
    TEST.assert_equal("{+[] -[]}", changes0.toString());
    var changes1 = O.labelChanges(1, 2);
    TEST.assert_equal("{+[1] -[2]}", changes1.toString());
    var changes2 = O.labelChanges([1,2]);
    TEST.assert_equal("{+[1, 2] -[]}", changes2.toString());
    var changes3 = O.labelChanges(undefined, [1,2]);
    TEST.assert_equal("{+[] -[1, 2]}", changes3.toString());

    // Test add() and remove() with ints, objrefs, LabelLists and arrays
    var ch0 = O.labelChanges(1,2);
    ch0.add(4);
    ch0.add([5,7]);
    ch0.add(O.ref(9));
    TEST.assert_equal("{+[1, 4, 5, 7, 9] -[2]}", ch0.toString());
    ch0.remove(8);
    ch0.remove([29,92]);
    ch0.remove(O.ref(888));
    TEST.assert_equal("{+[1, 4, 5, 7, 9] -[2, 8, 1x, 5w, 378]}", ch0.toString());
    ch0.add(O.labelList(876, 776));
    TEST.assert_equal("{+[1, 4, 5, 7, 9, 308, 36w] -[2, 8, 1x, 5w, 378]}", ch0.toString());
    ch0.remove(O.labelList(876, 776)); // note same labels
    TEST.assert_equal("{+[1, 4, 5, 7, 9] -[2, 8, 1x, 5w, 308, 36w, 378]}", ch0.toString());

    // And bad things on add()/remove()
    TEST.assert_exceptions(function() { ch0.add(null); }, "Bad label value");
    TEST.assert_exceptions(function() { ch0.add(undefined); }, "Bad label value");
    TEST.assert_exceptions(function() { ch0.add("Hello"); }, "Bad label value");
    TEST.assert_exceptions(function() { ch0.remove("Hello"); }, "Bad label value");

    // Test making changes to a label list
    var ch1 = O.labelChanges(1, 4);
    TEST.assert_exceptions(function() { ch1.change("Hello"); }, "Must pass a LabelList to change()");
    TEST.assert_equal("[1, 5, 7]", ch1.change(O.labelList(4, 5, 7)).toString());

    // Add and remove do chaining
    var ch2 = O.labelChanges();
    TEST.assert(ch2 === ch2.add(1));
    TEST.assert(ch2 === ch2.remove(2));

    // Check add() and remove() remove labels from the other list
    var ch3 = O.labelChanges();
    ch3.add([1,2]);
    ch3.remove([2,3]);
    TEST.assert_equal("{+[1] -[2, 3]}", ch3.toString());
    ch3.remove([4,5,6,7]);
    TEST.assert_equal("{+[1] -[2, 3, 4, 5, 6, 7]}", ch3.toString());
    ch3.add(3);
    TEST.assert_equal("{+[1, 3] -[2, 4, 5, 6, 7]}", ch3.toString());
    ch3.add(O.labelList([4,5,6]));
    TEST.assert_equal("{+[1, 3, 4, 5, 6] -[2, 7]}", ch3.toString());
    ch3.remove(5);
    TEST.assert_equal("{+[1, 3, 4, 6] -[2, 5, 7]}", ch3.toString());

    // ---------------------------------------------------------------------------------------------

    // Label changes with parents
    var ch4 = O.labelChanges();
    ch4.add(TYPE["std:type:person:staff"]);
    ch4.remove(TYPE["std:type:organisation:supplier"]);
    TEST.assert_equal("{+[20x1] -[206y]}", ch4.toString());
    var ch5 = O.labelChanges();
    ch5.add(TYPE["std:type:person:staff"], "with-parents");
    ch5.remove(TYPE["std:type:organisation:supplier"], "with-parents");
    TEST.assert_equal("{+[20x0, 20x1] -[206w, 206y]}", ch5.toString());

    // ---------------------------------------------------------------------------------------------

    // LabelStatementsBuilder + LabelStatements (hUserPermissionRules, statements creation)
    var builder1 = O.labelStatementsBuilder();
    TEST.assert(builder1 instanceof $LabelStatementsBuilder);
    TEST.assert(builder1.rule === builder1.add);  // check alias
    builder1.rule(1, O.STATEMENT_ALLOW, O.PERM_READ);
    builder1.add(O.ref(1234567), O.STATEMENT_ALLOW, O.PERM_READ);
    TEST.assert_exceptions(function() {
        builder1.rule(undefined, O.STATEMENT_ALLOW, O.PERM_READ);
    }, "Bad label value");
    TEST.assert_exceptions(function() {
        builder1.rule(0, O.STATEMENT_ALLOW, O.PERM_READ);
    }, "Bad label value");
    TEST.assert_exceptions(function() {
        builder1.rule(-123, O.STATEMENT_ALLOW, O.PERM_READ);
    }, "Bad label value");
    var statements1 = builder1.toLabelStatements();
    TEST.assert(statements1 instanceof $LabelStatements);
    TEST.assert_equal(true, statements1.allow("read", O.labelList(1)));
    TEST.assert_equal(false, statements1.allow("read", O.labelList(2)));

    var builder2 = O.labelStatementsBuilder();
    builder2.rule(4, O.STATEMENT_ALLOW, O.PERM_READ);
    builder2.rule(40, O.STATEMENT_DENY, O.PERM_READ);
    var statements2 = builder2.toLabelStatements();

    var combined_or = statements1.or(statements2);
    TEST.assert(combined_or instanceof $LabelStatements);
    TEST.assert_equal(true, combined_or.allow("read", O.labelList(1)));    // statements1
    TEST.assert_equal(true, combined_or.allow("read", O.labelList(4)));    // statements2

    var combined_and = statements1.and(statements2);
    TEST.assert_equal(true, statements1.allow("read", O.labelList(1,40)));    // statements1 allows this 'cos 40 not mentioned
    TEST.assert_equal(false, combined_and.allow("read", O.labelList(1,40)));    // by statements2 in combined denies 40

});
