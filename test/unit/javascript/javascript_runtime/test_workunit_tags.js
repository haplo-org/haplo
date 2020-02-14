/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // Basic tests
    var unit1 = O.work.create({
        workType: "test:simple_tags",
        createdBy: 21,
        actionableBy: 21
    });
    TEST.assert(unit1.tags instanceof $HstoreBackedTags);
    unit1.tags["tag1"] = "value1";
    TEST.assert_equal("value1", unit1.tags["tag1"]);
    unit1.tags["tag2"] = O.ref('8800z');
    unit1.tags["x"] = "y";
    TEST.assert_equal("y", unit1.tags["x"]);
    unit1.tags["x"] = "";
    TEST.assert_equal("", unit1.tags["x"]);
    unit1.tags["x"] = null;
    TEST.assert_equal(undefined, unit1.tags["x"]);
    unit1.tags["x"] = "y";
    TEST.assert_equal("y", unit1.tags["x"]);
    unit1.tags["x"] = 42;
    TEST.assert_equal("42", unit1.tags["x"]);
    unit1.tags["x"] = undefined;
    TEST.assert_equal(undefined, unit1.tags["x"]);
    unit1.save();

    _.each([{value:"value1",count:1}, {value:"nothing",count:0}], function(p) {
        var q = O.work.query("test:simple_tags").tag("tag1", p.value);
        TEST.assert_equal(p.count, q.count());
        TEST.assert_equal(p.count, q.length);
        if(p.count) { TEST.assert_equal(unit1.id, q[0].id); }
    });

    var unit1b = O.work.load(unit1.id);
    TEST.assert_equal(undefined, unit1.tags[42]);   // can retrieve integer keys and get undefined
    TEST.assert_equal(undefined, unit1.tags["x"]);  // deleted key
    TEST.assert_equal("value1", unit1b.tags.tag1);
    TEST.assert_equal("8800z", unit1b.tags.tag2);   // ref got converted to String

    // --------------------------------------------------------------------------------------------

    // SQL injection shouldn't work
    var INJECT_STRING1 = "'); DROP TABLE work_units; --";
    var INJECT_STRING2 = "' = '')); DROP TABLE work_units; --";
    _.each([
        {key:INJECT_STRING1, value:"a"},
        {key:"b", value:INJECT_STRING1},
        {key:INJECT_STRING2, value:"a"},
        {key:"b", value:INJECT_STRING2}
    ], function(p) {
        var wu = O.work.create({
            workType: "test:inject",
            createdBy: 21,
            actionableBy: 22
        });
        wu.tags[p.key] = p.value;
        wu.save();
        TEST.assert_equal(1, O.work.query("test:inject").tag(p.key,p.value).count());
    });

    // --------------------------------------------------------------------------------------------

    var TEST_REF = O.ref(1623434);

    _.each([
        [0, "a", "b", null],
        [1, "a", "e", null],
        [2, "a", "e", ""], // "a","e" so it matches the line above, and gets summed together
        [3, "b", "d", "x"],
        [4, "a", "e", "x"],
        [5, "a", "b", "y"],
        [6, "a", "b", "x"],
        [7, TEST_REF, "X", "Y"],
        [8, 123, 456, "Y"]
    ], function(x) {
        var wu = O.work.create({
            workType: "test:tags",
            createdBy: 21,
            actionableBy: 22,
            data: {n:x[0]},
            tags: {"t0":x[1], "t1":x[2]}
        });
        TEST.assert(wu.tags instanceof $HstoreBackedTags);
        if(x[3]) {
            wu.tags.t2 = x[3];
        }
        wu.save();
    });

    // --------------------------------------------------------------------------------------------

    // Query by tags
    var test_tag_query = function(q, a) {
        var cc = _.map(q, function(wu) { return wu.data.n; });
        TEST.assert(_.isEqual(cc.sort(), a));
    };

    test_tag_query(O.work.query("test:tags").tag("t2","x"), [3,4,6]);
    test_tag_query(O.work.query("test:tags").tag("t2",null), [0,1,2]);  // null or ''
    test_tag_query(O.work.query("test:tags").tag("t2",""), [0,1,2]);    // also null or ''
    test_tag_query(O.work.query("test:tags").tag("t2",null).tag("t1","e"), [1,2]);
    test_tag_query(O.work.query("test:tags").tag("t0","a").tag("t1","e"), [1,2,4]);
    test_tag_query(O.work.query("test:tags").tag("t0",TEST_REF), [7]);
    test_tag_query(O.work.query("test:tags").tag("t1",456), [8]);

    TEST.assert_exceptions(function() {
        O.work.query("test:tags").tag("t1",{});
    }, "Invalid type of object for conversion to string.");
    TEST.assert_exceptions(function() {
        O.work.query("test:tags").tag("t1",[]);
    }, "Invalid type of object for conversion to string.");
    TEST.assert_exceptions(function() {
        O.work.query("test:tags").tag("t1",undefined);
    }, "undefined cannot be used with WorkUnitQuery tag()");
    TEST.assert_exceptions(function() {
        O.work.query("test:tags").tag("t1");
    }, "undefined cannot be used with WorkUnitQuery tag()");

    // Tidy up extra work units
    O.work.query("test:tags").tag("t0",TEST_REF)[0].deleteObject();
    O.work.query("test:tags").tag("t1",456)[0].deleteObject();

    // --------------------------------------------------------------------------------------------

    // Count by tags
    TEST.assert_exceptions(function() {
        O.work.query("test:tags").countByTags();
    }, "countByTags() requires at least one tag.");

    var test_tag_counts = function(tags, expected, extra) {
        var query = O.work.query("test:tags");
        if(extra) { extra(query); }
        // console.log("result", query.countByTags.apply(query, tags));
        TEST.assert(_.isEqual(expected, query.countByTags.apply(query, tags)));
    };

    // Basic one level counts
    test_tag_counts(['t0'], {a:6,b:1});

    // Query criteria is respected
    test_tag_counts(['t0'], {a:3}, function(query) { query.tag('t1','b'); });

    // Work units with no value for a tag are counted as the empty string
    test_tag_counts(['t2'], {x:3,y:1,"":3});

    // Nested queries
    test_tag_counts(['t0','t1'], {
        a:{b:3,e:3},
        b:{d:1}
    });
    test_tag_counts(['t1','t0'], {
        b:{a:3},
        e:{a:3},
        d:{b:1}
    });
    test_tag_counts(['t0','t1','t2'], {
        a:{
            b:{"":1,x:1,y:1},
            e:{"":2,x:1}
        },
        b:{d:{x:1}}
    });

    // Quoting
    test_tag_counts([INJECT_STRING1], {"":7});
    test_tag_counts([INJECT_STRING2], {"":7});

    // --------------------------------------------------------------------------------------------

    // Tags without any key/values work
    var unitNoTags = O.work.create({
        workType: "test:simple_tags",
        createdBy: 21,
        actionableBy: 21
    });
    unitNoTags.save();
    unitNoTags.tags['t0'] = '1';
    unitNoTags.save();
    TEST.assert_equal('[Tags {"t0":"1"}]', $KScriptable.forConsole(unitNoTags.tags));
    delete unitNoTags.tags['t0'];
    unitNoTags.save();
    var unitNoTagsReload = O.work.load(unitNoTags.id);
    TEST.assert_equal('[Tags {}]', $KScriptable.forConsole(unitNoTagsReload.tags));
    TEST.assert_equal(undefined, unitNoTagsReload.tags['t0']);

});
