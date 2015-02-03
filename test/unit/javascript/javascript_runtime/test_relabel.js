/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    function assert_labels(obj, labels) {
        var reloaded = O.ref(obj.ref).load();
        var expected = _.map(labels, function(label) {
            return (label instanceof $Ref) ? label : O.ref(label);
        }).sort();
        TEST.assert_equal(expected.toString(), _.toArray(reloaded.labels).toString());
    }

    var myLabel = O.ref(9999);

    var obj = O.object();
    obj.append(TYPE["std:type:book"], ATTR.Type);
    TEST.assert_exceptions(function() {
        // relabel before save..
        obj.relabel(O.labelChanges([myLabel], []));
    }, "Cannot call relabel on a storeObject before it has been saved");
    obj.save();

    TEST.assert_exceptions(function() {
        obj.relabel(O.labelChanges([myLabel], []));
    }, "relabel() can only be used on immutable objects");

    obj = obj.ref.load();

    TEST.assert(!obj.isMutable());
    obj.relabel(O.labelChanges([myLabel], []));
    assert_labels(obj, [LABEL["std:label:common"], myLabel]);

    obj.relabel(O.labelChanges([], [myLabel]));
    assert_labels(obj, [LABEL["std:label:common"]]);

    TEST.assert_exceptions(function() {
        obj.relabel(O.labelChanges([8888], []));
    }, "Not permitted to relabel with proposed new labels for object " + obj.ref.toString());

    // Add 4444, but then check we can't relabel subsequently (deny :relabel 4444)..
    obj.relabel(O.labelChanges([4444], []));
    TEST.assert_exceptions(function() {
        obj.relabel(O.labelChanges([], [4444]));
    }, "Not permitted to relabel object " + obj.ref.toString());

    // Object is now locked for labelling, so create a new one
    obj = O.object();
    obj.append(TYPE["std:type:book"], ATTR.Type);
    obj.save();
    obj = obj.ref.load();

    // Can label an object such that it can't be subsequently read..
    obj.relabel(O.labelChanges([7777], []));
    TEST.assert_exceptions(function() {
        obj.ref.load();
    }, "Operation read not permitted for object " + obj.ref.toString() + " with labels [7551,7777]");

    obj.relabel(O.labelChanges([6666, 5555], [7777]));
    assert_labels(obj, [LABEL["std:label:common"], 5555, 6666]);

    // Label changes which don't actually change anything, don't actually change anything.
    obj.relabel(O.labelChanges([6666], [12121212]));
    assert_labels(obj, [LABEL["std:label:common"], 5555, 6666]);

    TEST.assert_exceptions(
        function() { obj.relabel(); },
        "relabel must be passed an O.labelChanges object");
    TEST.assert_exceptions(
        function() { obj.relabel(1); },
        "relabel must be passed an O.labelChanges object");
    TEST.assert_exceptions(
        function() { obj.relabel("a"); },
        "relabel must be passed an O.labelChanges object");

});
