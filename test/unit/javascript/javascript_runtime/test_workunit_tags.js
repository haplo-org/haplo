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
    TEST.assert(unit1.tags instanceof $WorkUnitTags);
    unit1.tags["tag1"] = "value1";
    TEST.assert_equal("value1", unit1.tags["tag1"]);
    unit1.tags["tag2"] = O.ref('8800z');
    unit1.tags["x"] = "y";
    TEST.assert_equal("y", unit1.tags["x"]);
    unit1.tags["x"] = null;
    TEST.assert_equal(undefined, unit1.tags["x"]);
    unit1.tags["x"] = "y";
    TEST.assert_equal("y", unit1.tags["x"]);
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

    _.each([
        ["a", "b", null],
        ["a", "e", null],
        ["a", "e", ""], // "a","e" so it matches the line above, and gets summed together
        ["b", "d", "x"],
        ["a", "e", "x"],
        ["a", "b", "y"],
        ["a", "b", "x"]
    ], function(x) {
        var wu = O.work.create({
            workType: "test:tags",
            createdBy: 21,
            actionableBy: 22,
            tags: {"t0":x[0], "t1":x[1]}
        });
        TEST.assert(wu.tags instanceof $WorkUnitTags);
        if(x[2]) {
            wu.tags.t2 = x[2];
        }
        wu.save();
    });

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

});
