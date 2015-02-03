/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    var object;

    TEST.assert_equal("[]", O.object().labels.toString());
    TEST.assert_equal("[1]", O.object(1).labels.toString());
    TEST.assert_equal("[1, 2]", O.object(1, 2).labels.toString());
    TEST.assert_equal("[" + LABEL["std:label:common"] + "]", O.object(LABEL["std:label:common"]).labels.toString());

    object = O.object();
    object.append(TYPE["std:type:person"], ATTR.Type);
    TEST.assert(object.labels instanceof $LabelList);
    TEST.assert("[]", object.labels);
    object.save();
    TEST.assert("[" + LABEL["std:label:common"] + "]", object.labels);
    TEST.assert_equal(O.labelList(LABEL["std:label:common"]).toString(), object.labels.toString());

    object = O.object();
    object.append(TYPE["std:type:book"], ATTR.Type);
    object.save();
    TEST.assert_equal(
        O.labelList(LABEL["std:label:common"], TYPE["std:type:book"]).toString(),
        object.labels.toString());


    object = O.object();
    object.append(TYPE["std:type:equipment:laptop"], ATTR.Type);
    object.save();

    TEST.assert_equal(
        O.labelList(LABEL["std:label:common"], LABEL["test:label:mine"], object.ref).toString(),
        object.labels.toString());

    // Save, but add Book type as label, and remove COMMON label..
    object.save(O.labelChanges([TYPE["std:type:book"]], [LABEL["std:label:common"]]));
    TEST.assert_equal(
        O.labelList(TYPE["std:type:book"], LABEL["test:label:mine"], object.ref).toString(),
        object.labels.toString());
    var before_list = object.labels;
    object.save();

    TEST.assert_equal(before_list.toString(), object.labels.toString());

    // Remove all labels
    object.save(O.labelChanges([], [TYPE["std:type:book"],
                                    LABEL["test:label:mine"],
                                    LABEL["std:label:common"],
                                    object.ref]));
    TEST.assert_equal("[" + LABEL["std:label:unlabelled"] + "]", object.labels.toString());

    // Remove unrelated labels
    object = O.object();
    object.append(TYPE["std:type:book"], ATTR.Type);

    object.save(O.labelChanges([], [LABEL["test:label:mine"]]));
    TEST.assert_equal(
        O.labelList(LABEL["std:label:common"], TYPE["std:type:book"]).toString(),
        object.labels.toString());

});