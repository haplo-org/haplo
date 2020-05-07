/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var db = this.__test_database_db;

TEST(function() {

    // =====================================================================================
    // JSON data type
    db.json1.create({number:4}).save();
    db.json1.create({number:8,data:{a:1,b:2}}).save();
    var jr1 = db.json1.select().where("number","=",4)[0];
    TEST.assert_equal(null, jr1.data);
    var jr2 = db.json1.select().where("number","=",8)[0];
    TEST.assert_equal(2, jr2.data.b);
    TEST.assert(_.isEqual({b:2,a:1}, jr2.data));
    // Test that modifications to the deserialised object persist (ie cache is working, but not saved)
    jr2.data.b = 3;
    jr2.number = 9;
    TEST.assert_equal(3, jr2.data.b);   // modifies cached value
    jr2.save();
    jr2 = db.json1.load(jr2.id);
    TEST.assert_equal(2, jr2.data.b);   // NOT modified by save because data property was not assigned explicitly
    TEST.assert_equal(9, jr2.number);
    // Assign to property to actually change it
    jr2.data = {b:4,c:8};
    TEST.assert_equal(4, jr2.data.b);   // invalidated cache
    jr2.save();
    jr2 = db.json1.load(jr2.id);
    TEST.assert_equal(4, jr2.data.b);
    TEST.assert(_.isEqual({c:8,b:4}, jr2.data));
    // Can't use them in where clauses...
    TEST.assert_exceptions(function() {
        db.json1.select().where("data","=",{a:2});
    }, "json columns cannot be used in where clauses, except as a comparison to null.");
    TEST.assert_exceptions(function() {
        db.json1.select().where("data","=",'{"a":2}');  // even as JSON encoded text
    }, "json columns cannot be used in where clauses, except as a comparison to null.");
    // ... except when comparing to null.
    var jqn1 = db.json1.select().where("data","=",null);
    TEST.assert_equal(1, jqn1.length);
    TEST.assert_equal(4, jqn1[0].number);
    var jqn2 = db.json1.select().where("data","!=",null);
    TEST.assert_equal(1, jqn2.length);
    TEST.assert_equal(9, jqn2[0].number);
    // Query on JSON
    db.json1.create({number:18,data:{a:17,b:"24"},text:JSON.stringify({"foo":"bar"})}).save();
    db.json1.create({number:19,data:{a:12,b:"1"},text:JSON.stringify({"foo":"baz","FOO":"ping"})}).save();
    var jqn3 = db.json1.select().whereJSONProperty("data", "b", "=", "4");
    TEST.assert_equal(1, jqn3.length);
    TEST.assert_equal(9, jqn3[0].number);
    var jqn4 = db.json1.select().whereJSONProperty("data", "b", "!=", "2");
    TEST.assert_equal(3, jqn4.length);
    // Can also use text fields as JSON
    var jqn5 = db.json1.select().whereJSONProperty("text", "foo", "=", "bar");
    TEST.assert_equal(1, jqn5.length);
    TEST.assert_equal(18, jqn5[0].number);
    // And values can be compared to null
    var jqn6 = db.json1.select().whereJSONProperty("text", "FOO", "=", null);
    TEST.assert_equal(3, jqn6.length);
    // Only text and json types allowed
    TEST.assert_exceptions(function() {
        db.json1.select().whereJSONProperty("number","x","=",{a:2});
    }, "Cannot extract JSON property from 'number' for table 'json1'");

    // =====================================================================================
    // Numeric data type
    db.numerics.create({
        n0: O.bigDecimal(10.00999999977648258209228515625),
        n1: O.bigDecimal(198.56),
        n2: O.bigDecimal(9274.123)
    }).save();
    var nq = db.numerics.select();
    TEST.assert_equal(1, nq.length);
    var nrow = nq[0];
    TEST.assert(nrow.n0 instanceof $BigDecimal);
    TEST.assert_equal("10.00999999977648258209228515625", nrow.n0.toString()); // exact representation
    TEST.assert(nrow.n1 instanceof $BigDecimal);
    TEST.assert_equal("199", nrow.n1.toString());       // gets rounded to int because scale 0
    TEST.assert(nrow.n2 instanceof $BigDecimal);
    TEST.assert_equal("9274.1230", nrow.n2.toString()); // has scale 4

    db.numerics.create({
        n0: O.bigDecimal(1)
    }).save();
    var numericSum = db.numerics.select().aggregate("SUM", "n0");
    TEST.assert(numericSum instanceof $BigDecimal);
    TEST.assert_equal("11.00999999977648258209228515625", numericSum.toString());

    var numericCount = db.numerics.select().count();
    TEST.assert_equal("number", typeof(numericCount));
    TEST.assert_equal(2, numericCount);

    var numericSumNull = db.numerics.select().where("n2","=",O.bigDecimal(0)).aggregate("SUM", "n0");
    TEST.assert_equal(null, numericSumNull);

    db.numerics.create({n0:O.bigDecimal(1),n1:O.bigDecimal(2)}).save();
    var nq2 = db.numerics.select().where("n2","=",O.bigDecimal(9274.123).setScaleWithRounding(4));  // scale to match numeric column
    TEST.assert_equal(1, nq2.length);

    // =====================================================================================
    // Update
    db.numbers.select().deleteAll();
    var requiredState = {};
    _.each([
        {name:"a1", medium:348, small:32, bools:false },
        {name:"a2", medium:2, small:32, bools:true },
        {name:"a3", medium:9888, small:37, pingTime:new DBTime(12,45), bools:true },
        {name:"a4", medium:10, small:12 },
        {name:"a5", medium:349, small:100, big:239349, pingTime:new DBTime(12,45,56) },
        {name:"a6", medium:2837, small:23, big:3498, pingTime:new DBTime(8,3), bools:true },
    ], function(o) {
        let row = db.numbers.create(o).save();
        o.id = row.id;
        requiredState[row.id] = o;
    });

    var updateRequiredState = function(rows, fn) {
        _.each(requiredState, function(rs) {
            if(-1 !== rows.indexOf(rs.name)) { fn(rs); }
        });
    };

    var testRequiredStateAgainstDB = function() {
        let allRows = db.numbers.select();
        TEST.assert_equal(_.keys(requiredState).length, allRows.length);
        allRows.each((row) => {
            var required = requiredState[row.id];
            _.each(["id", "big", "small", "medium", "bools"], function(column) {
                let testValue = required[column];
                if(testValue === undefined) {
                    testValue = null;
                };
                TEST.assert_equal(testValue, row[column]);
            });
            _.each(["pingTime", "pingDate"], function(col) {
                if(required[col]) {
                    TEST.assert_equal(required[col].toString(), row[col].toString());
                } else {
                    TEST.assert(!row[col]);
                }
            });
        });
    };

    TEST.assert_equal(2, db.numbers.select().where("small","=",32).update({small:33,big:null}));
    updateRequiredState(["a1", "a2"], function(rs) {
        rs.small = 33;
    });
    testRequiredStateAgainstDB();

    TEST.assert_equal(4, db.numbers.select().where("small",">",1).or(function(sq) {
        sq.where("bools", "=", true).where("pingTime","<", new DBTime(13,45));
    }).update({big:5}));
    updateRequiredState(["a2", "a3", "a5", "a6"], function(rs) {
        rs.big = 5;
    });
    testRequiredStateAgainstDB();

    TEST.assert_equal(2, db.numbers.select().where("small","=",33).update({pingTime:new DBTime(13,10)}));
    updateRequiredState(["a1", "a2"], function(rs) {
        rs.pingTime = new DBTime(13,10);
    });
    testRequiredStateAgainstDB();

    TEST.assert_equal(2, db.numbers.select().where("small","=",33).update({pingDate:new XDate(2013,10,10)}));
    updateRequiredState(["a1", "a2"], function(rs) {
        rs.pingDate = new XDate(2013,10,10);
    });
    testRequiredStateAgainstDB();

    TEST.assert_equal(0, db.numbers.select().where("bools", "=", false).where("small",">",1000).update({small:1001}));
    testRequiredStateAgainstDB();

    TEST.assert_exceptions(function() {
        db.numbers.select().update({id:1});
    }, "Bad field 'id' for table 'numbers'");
    testRequiredStateAgainstDB();

    TEST.assert_exceptions(function() {
        db.numbers.select().update({notARealColumn:1});
    }, "Bad field 'notARealColumn' for table 'numbers'");
    testRequiredStateAgainstDB();

    TEST.assert_exceptions(function() {
        db.numbers.select().update({small:2, notARealColumn:1});
    }, "Bad field 'notARealColumn' for table 'numbers'");
    testRequiredStateAgainstDB();

    TEST.assert_equal(0, db.numbers.select().update({3:1001}));
    testRequiredStateAgainstDB();

    TEST.assert_equal(0, db.numbers.select().update({}));
    testRequiredStateAgainstDB();

    TEST.assert_equal(3, db.numbers.select().where("small",">",1).where("bools", "=", true).update({big:150, small: 25}));
    updateRequiredState(["a2", "a3", "a6"], function(rs) {
        rs.big = 150;
        rs.small = 25;
    });
    testRequiredStateAgainstDB();

    TEST.assert_equal(3, db.numbers.select().where("small",">",1).where("bools", "=", true).update({big:150, small: 25}));
    testRequiredStateAgainstDB();

    TEST.assert_equal(6, db.numbers.select().update({bools:true}));
    updateRequiredState(["a1", "a2", "a3", "a4", "a5", "a6"], function(rs) {
        rs.bools = true;
    });
    testRequiredStateAgainstDB();


    // =====================================================================================
    // Very simple migration test
    db.forMigration.create({number1:2}).save();
    db.forMigration.create({number1:4}).save();
    var migrated_select0 = db.forMigration.select().where("number1","=",4);
    TEST.assert_equal(1, migrated_select0.length);
    TEST.assert_equal(undefined, migrated_select0[0].text1);
    // Do actual migration
    delete db.forMigration;   // to avoid redeclaration warning
    db.table("forMigration", {
        number1: { type:"int" },
        text1: { type:"text", nullable:true }
    });
    $host._testCallback("");
    // Check existing data is still there, and new field works
    var migrated_select1 = db.forMigration.select().where("number1","=",4);
    TEST.assert_equal(1, migrated_select1.length);
    TEST.assert_equal(null, migrated_select1[0].text1);
    migrated_select1[0].text1 = "Hello";
    migrated_select1[0].save();
    var migrated_select2 = db.forMigration.select().where("number1","=",4);
    TEST.assert_equal(1, migrated_select2.length);
    TEST.assert_equal("Hello", migrated_select2[0].text1);

    // =====================================================================================
    // Dynamic tables
    var dyn1 = db._dynamicTable("dyn1", {
        name: {type:"text", indexed:true},
        number: {type:"int"}
    });
    TEST.assert_equal(true, dyn1.wasCreated);
    TEST.assert_equal(true, dyn1.databaseSchemaChanged);
    // can be used immediately without setting up storage
    dyn1.create({name:"Ping", number:76}).save();
    dyn1.create({name:"Pong", number:87}).save();
    var dyn1_select1 = dyn1.select().where("name","=","Ping");
    TEST.assert_equal(1, dyn1_select1.length);
    TEST.assert_equal(76, dyn1_select1[0].number);
    // Redefined with automigrate of new nullable columns
    dyn1 = db._dynamicTable("dyn1", {
        name: {type:"text"},
        number: {type:"int"},
        add1: {type:"text", nullable:true, indexed:true},   // and indicies work
        add2: {type:"smallint", nullable:true}
    });
    TEST.assert_equal(false, dyn1.wasCreated);
    TEST.assert_equal(true, dyn1.databaseSchemaChanged);
    var dyn1_select2 = dyn1.select().where("name","=","Pong");
    TEST.assert_equal(1, dyn1_select2.length);
    TEST.assert_equal(87, dyn1_select2[0].number);
    // Can use the additional fields
    var dyn1row = dyn1_select2[0];
    dyn1row.add1 = "additional one";
    dyn1row.add2 = 48;
    dyn1row.save();
    var dyn1row_reload = dyn1.select().where("name","=","Pong")[0];
    TEST.assert_equal(87, dyn1row_reload.number);
    TEST.assert_equal("additional one", dyn1row_reload.add1);
    TEST.assert_equal(48, dyn1row_reload.add2);
    // Can redefine, losing one of the additional fields
    dyn1 = db._dynamicTable("dyn1", {
        name: {type:"text", indexed:true},
        number: {type:"int"},
        add2: {type:"smallint", nullable:true}
    });
    TEST.assert_equal(false, dyn1.wasCreated);
    TEST.assert_equal(false, dyn1.databaseSchemaChanged);
    var dyn1row_lost1 = dyn1.select().where("name","=","Pong")[0];
    TEST.assert_equal(87, dyn1row_lost1.number);
    TEST.assert_equal(undefined, dyn1row_lost1.add1);
    TEST.assert_equal(48, dyn1row_lost1.add2);
    // But it'll appear again if it appears in a new redefinition
    dyn1 = db._dynamicTable("dyn1", {
        name: {type:"text", indexed:true},
        number: {type:"int"},
        add1: {type:"text", nullable:true},
        add2: {type:"smallint", nullable:true}
    });
    TEST.assert_equal(false, dyn1.wasCreated);
    TEST.assert_equal(false, dyn1.databaseSchemaChanged);
    var dyn1row_reappear1 = dyn1.select().where("name","=","Pong")[0];
    TEST.assert_equal(87, dyn1row_reappear1.number);
    TEST.assert_equal("additional one", dyn1row_reappear1.add1);
    TEST.assert_equal(48, dyn1row_reappear1.add2);
    // Can't redefine with non-nullable columns
    TEST.assert_exceptions(function() {
        var dyn1 = db._dynamicTable("dyn1", {
            name: {type:"text"},
            number: {type:"int"},
            nonnullable: {type:"text"}
        });
    }, "Cannot automatically migrate table definition: in plugin dummy_plugin_name!, table dyn1, column nonnullable is not nullable");
    // Redefine back to the basics, the Ruby test checks that all the expected fields are there.
    dyn1 = db._dynamicTable("dyn1", {
        name: {type:"text"},
        number: {type:"int"}
    });
    TEST.assert_equal(false, dyn1.wasCreated);
    TEST.assert_equal(false, dyn1.databaseSchemaChanged);

});
