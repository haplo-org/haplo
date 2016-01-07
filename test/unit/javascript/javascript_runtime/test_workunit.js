/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // javascript_controller_test checks that work units are created with the current user as a default in the context of a request

    // These IDs come from the fixture
    var USER1_ID = 41;
    var USER2_ID = 42;
    var USER3_ID = 43;
    var GROUP1_ID = 21;
    var GROUP2_ID = 22;
    var GROUP3_ID = 23;

    TEST.assert_exceptions(function() { O.work.create("ping"); });  // no plugin name prefix
    TEST.assert_exceptions(function() { O.work.create({workType:"ping"}); });  // no plugin name prefix
    var unit0 = O.work.create("plugin:something"); // valid name, defaults for everything
    TEST.assert_equal("plugin:something", unit0.workType);
    TEST.assert_equal(null, unit0.createdAt);   // not set yet
    TEST.assert_exceptions(function() { unit0.createdAt = new Date(); }); // not allowed
    TEST.assert_equal(0, unit0.createdBy.id);
    TEST.assert_equal(null, unit0.actionableBy);
    TEST.assert_equal(null, unit0.ref);
    unit0.ref = O.ref(2);
    TEST.assert(O.ref(2) == unit0.ref);
    TEST.assert(typeof(unit0.data) == 'object');
    TEST.assert_equal(true, unit0.visible);
    TEST.assert_equal(true, unit0.autoVisible);

    // Without all the bits filled in, saving a work unit will fail
    TEST.assert_exceptions(function() { O.work.create("ptest:pfdjn").save(); });

    // Date formatting helper function
    var dateStr = function(date) {
        return (new XDate(date)).toString('yyyy-MM-dd');
    };

    // Get user
    var user2 = O.user(USER2_ID);

    var unit1 = O.work.create({
        workType:"test:pants",
        createdBy:USER3_ID,   // as numeric ID
        actionableBy:user2 // as user object
    });
    TEST.assert_equal(false, unit1.isSaved);
    TEST.assert_equal("test:pants", unit1.workType);
    TEST.assert_exceptions(function() {
        var x = unit1.id;
    }, "WorkUnit has not been saved yet.");
    unit1.save();
    TEST.assert_equal(true, unit1.isSaved);
    TEST.assert_equal(dateStr(new Date()), dateStr(unit1.createdAt));   // check it was created today
    TEST.assert_equal(USER3_ID, unit1.createdBy.id);
    TEST.assert_equal(USER2_ID, unit1.actionableBy.id);
    TEST.assert(unit1.id > 0);
    unit1.ref = O.ref(70);
    unit1.deadline = new Date(2015, 5 - 1, 23);
    unit1.openedAt = new Date(2020, 11 - 1, 12);
    unit1.data["ping"] = [23,5,6];
    unit1.data["poing"] = "hello!";
    unit1.tags["tag1"] = "value1";
    unit1.tags["tag2"] = O.ref('8800z');
    unit1.save();

    // Load the object back
    var unit1b = O.work.load(unit1.id);
    TEST.assert_equal(dateStr(new Date()), dateStr(unit1b.createdAt));   // check it was created today
    TEST.assert_equal(USER3_ID, unit1b.createdBy.id);
    TEST.assert_equal(USER2_ID, unit1b.actionableBy.id);
    TEST.assert_equal(unit1.id, unit1b.id);
    TEST.assert(O.ref(70) == unit1b.ref);
    TEST.assert_equal('2015-05-23', dateStr(unit1b.deadline));
    TEST.assert_equal('2020-11-12', dateStr(unit1b.openedAt));
    TEST.assert_equal(false, unit1b.closed);
    TEST.assert(typeof(unit1b.data) == 'object');
    TEST.assert_equal("hello!", unit1b.data["poing"]);
    TEST.assert(_.isEqual([23,5,6], unit1b.data["ping"]));
    TEST.assert_equal("value1", unit1b.tags.tag1);
    TEST.assert_equal("8800z", unit1b.tags.tag2);   // ref got converted to String

    // Try closing it
    TEST.assert_equal(false, unit1.closed);
    unit1.close(user2);
    TEST.assert_equal(true, unit1.closed);
    unit1.save();
    var unit1c = O.work.load(unit1.id);
    TEST.assert_equal(true, unit1c.closed);
    TEST.assert_equal(dateStr(new Date()), dateStr(unit1c.closedAt));   // check it was closed today
    TEST.assert_equal(USER2_ID, unit1c.closedBy.id);
    TEST.assert_exceptions(function() { unit1c.closedAt = new Date(); });

    // Try reopening it
    unit1.reopen().save();
    TEST.assert_equal(false, unit1.closed);
    var unit1d = O.work.load(unit1.id);
    TEST.assert_equal(false, unit1d.closed);
    TEST.assert_equal(null, unit1d.closedAt);
    TEST.assert_equal(null, unit1d.closedBy);

    // Bad loads exception
    TEST.assert_exceptions(function() { O.work.load(unit1.id + 10020); });

    // Test loading open work units of a particular type
    // By default, query() loads all OPEN work units of the given type
    TEST.assert_equal(0, O.work.query("plugin:loading").length);
    var sourceunits = {};
    _.each(['a','p','q','z'], function(name) {
        var u = O.work.create({workType:"plugin:loading", createdBy:41, actionableBy:USER2_ID, data:{name:name}}).save();
        sourceunits[name] = u;
    });
    var checkLoad = function(expected, status) {
        var all = O.work.query("plugin:loading");
        if(status == "closed") { all.isClosed(); }
        if(status == "either") { all.isEitherOpenOrClosed(); }
        TEST.assert_equal(expected.length, all.length);
        var x = {};
        _.each(all, function(y) {x[y.data.name] = y;});
        _.each(expected, function(e) {
            TEST.assert(x[e] instanceof $WorkUnit);
        });
        // Check the has() function in the Java KWorkUnitQuery
        TEST.assert_equal(false, -1 in all);
        for(var i = 0; i < all.length; ++i) {
            TEST.assert_equal(true, i in all);
        }
        TEST.assert_equal(false, (all.length) in all);
        TEST.assert_equal(expected.length, all.count());
    };
    TEST.assert_equal('z', O.work.query("plugin:loading").first().data.name);
    TEST.assert_equal(null, O.work.query("plugin:loading").isClosed().latest());
    TEST.assert_equal(null, O.work.query("plugin:loading").isClosed().first()); // alias of latest
    TEST.assert_equal(0, O.work.query("plugin:loading").createdBy(USER2_ID).length);
    TEST.assert_equal(4, O.work.query("plugin:loading").createdBy(41).length);
    TEST.assert_equal(4, O.work.query("plugin:loading").actionableBy(USER2_ID).length);
    TEST.assert_equal(0, O.work.query("plugin:loading").actionableBy(41).length);
    checkLoad(['a','p','q','z']);
    checkLoad([], "closed");
    checkLoad(['a','p','q','z'], "either");
    sourceunits.a.close(O.user(USER2_ID)).save();
    checkLoad(['p','q','z']);
    checkLoad(['a'], "closed");
    O.work.create({workType:"plugin:NOT-loading", createdBy:41, actionableBy:USER2_ID, data:{name:"X"}}).save();
    checkLoad(['p','q','z']);
    checkLoad(['a'], "closed");
    checkLoad(['a','p','q','z'], "either");
    sourceunits.q.close(O.user(USER2_ID)).save();
    checkLoad(['p','z']);
    checkLoad(['a','q'], "closed");
    checkLoad(['a','p','q','z'], "either");
    TEST.assert_equal('q', O.work.query("plugin:loading").isClosed().latest().data.name);
    TEST.assert_equal('z', O.work.query("plugin:loading").latest().data.name);
    TEST.assert_equal('q', O.work.query("plugin:loading").isClosed().first().data.name); // alias of latest
    TEST.assert_equal('z', O.work.query("plugin:loading").first().data.name); // alias of latest
    TEST.assert_equal(4, O.work.query("plugin:loading").isEitherOpenOrClosed().actionableBy(USER2_ID).length);

    // can construct without work type
    O.work.query();
    O.work.query(null);
    O.work.query(undefined);
    // But if not, then must be valid
    TEST.assert_exceptions(function() { O.work.query(5); }, "Must pass work type as a string to O.work.query()");
    TEST.assert_exceptions(function() { O.work.query("ping"); }, "Work unit work type names must start with the plugin name followed by a : to avoid collisions.");
    TEST.assert_exceptions(function() { O.work.query(":ping"); }, "Work unit work type names must start with the plugin name followed by a : to avoid collisions.");
    // Queries without minimum WHERE clause requirements will exception when executed
    TEST.assert_exceptions(function() { var x = O.work.query().length; }, "Work unit queries must specify at least a work type, a ref, or a tag");
    TEST.assert_exceptions(function() { var x = O.work.query(null).length; }, "Work unit queries must specify at least a work type, a ref, or a tag");

    // Query on ref only
    var refQuery = O.work.query().ref(O.ref(70));
    TEST.assert_equal(1, refQuery.length);
    TEST.assert_equal(unit1.id, refQuery[0].id);
    // Query on tag only
    var tagQuery = O.work.query().tag("tag1", "value1");
    TEST.assert_equal(1, tagQuery.length);
    TEST.assert_equal(unit1.id, tagQuery[0].id);
    // And check work type too
    TEST.assert_equal(0, O.work.query("x:y").ref(O.ref(70)).length);

    // Create a work unit, then delete it
    var dt1 = O.work.create({workType:"plugin:deltest", createdBy: USER2_ID, actionableBy: USER2_ID});
    dt1.save();
    TEST.assert_equal(1, O.work.query("plugin:deltest").length);
    dt1.deleteObject();
    TEST.assert_equal(0, O.work.query("plugin:deltest").length);

    // Test library date conversion
    var testingDate = new Date();
    var workdates = O.work.create({
        workType: "plugin:datecheck",
        createdBy: USER2_ID,
        actionableBy: 23,
        openedAt: new XDate(testingDate),
        deadline: moment(testingDate),
    });
    workdates.save();
    var workdates2 = O.work.load(workdates.id);
    TEST.assert_equal(testingDate.toUTCString(), workdates2.openedAt.toUTCString());
    TEST.assert_equal(testingDate.toUTCString(), workdates2.deadline.toUTCString());

    //Test isActionableBy method
    unit1 = O.work.create({
        workType: "test:pants",
        createdBy: USER3_ID,   // as numeric ID
        actionableBy: user2 // as user object
    });
    unit1.save();
    TEST.assert(unit1.isActionableBy(user2));
    TEST.assert(unit1.isActionableBy(USER2_ID));
    TEST.assert(unit1.isActionableBy(USER3_ID) == false);
    TEST.assert_exceptions(function() { unit1.isActionableBy(GROUP1_ID); }, "isActionableBy must be passed a User, not a Group");

    var groupUnit1 = O.work.create({
        workType: "test:pants",
        createdBy: USER3_ID,
        actionableBy: GROUP2_ID
    });

    // Group 2 just has user 2 in it, and indirectly user 3
    TEST.assert(groupUnit1.isActionableBy(user2));
    TEST.assert(groupUnit1.isActionableBy(USER1_ID) == false);
    TEST.assert(groupUnit1.isActionableBy(USER3_ID));

    var groupUnit2 = O.work.create({
        workType: "test:pants",
        createdBy: USER3_ID,
        actionableBy: GROUP3_ID
    });

    // Group 3 just has user 3 in
    TEST.assert(groupUnit2.isActionableBy(user2) == false);
    TEST.assert(groupUnit2.isActionableBy(USER1_ID) == false);
    TEST.assert(groupUnit2.isActionableBy(USER3_ID));

    // Check date conversions and nulls
    var datesUnit = O.work.create({
        workType: "test:pants",
        createdBy: USER3_ID,
        actionableBy: GROUP2_ID
    });
    // Deadline (can be null)
    datesUnit.deadline = null;
    TEST.assert_equal(null, datesUnit.deadline);
    datesUnit.deadline = new XDate("2013-01-04");
    TEST.assert_equal("2013-01-04", dateStr(datesUnit.deadline));
    TEST.assert_exceptions(function() { datesUnit.openedAt = null; }, "openedAt must be set to a Date");

    // Visibility properties
    var visunit = O.work.create({workType:"test:pants", createdBy:USER3_ID, actionableBy:user2});
    TEST.assert_equal(true, visunit.visible);
    TEST.assert_equal(true, visunit.autoVisible);
    visunit.save();
    visunit.visible = false;      TEST.assert_equal(false, visunit.visible);
    visunit.save();
    var visunitb = O.work.load(visunit.id);
    TEST.assert_equal(false, visunitb.visible);
    TEST.assert_equal(true, visunitb.autoVisible);
    visunitb.visible = true;      TEST.assert_equal(true, visunitb.visible);
    visunitb.autoVisible = false; TEST.assert_equal(false, visunitb.autoVisible);
    visunitb.save();
    var visunitc = O.work.load(visunit.id);
    TEST.assert_equal(true, visunitc.visible);
    TEST.assert_equal(false, visunitc.autoVisible);
    // Test visibility properties in the constructor
    var visunit2 = O.work.create({workType:"test:abc", visible:false, autoVisible:false});
    TEST.assert_equal(false, visunit2.visible);
    TEST.assert_equal(false, visunit2.autoVisible);

    // Visibility queries
    O.work.create({workType:"test:visquery", createdBy:USER3_ID, actionableBy:user2, visible:true}).save();
    O.work.create({workType:"test:visquery", createdBy:USER3_ID, actionableBy:user2, visible:true}).save();
    O.work.create({workType:"test:visquery", createdBy:USER3_ID, actionableBy:user2, visible:false}).save();
    TEST.assert_equal(2, O.work.query("test:visquery").length); // default is only to return visible work units
    TEST.assert_equal(2, O.work.query("test:visquery").isVisible().length);
    TEST.assert_equal(1, O.work.query("test:visquery").isNotVisible().length);
    TEST.assert_equal(3, O.work.query("test:visquery").anyVisibility().length);

});
