/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Create database namespace outside function so it can be picked up by the test callback
var db = new $DbNamespace();

TEST(function() {

    // Check that field names can't be duplicated, differing in case only
    TEST.assert_exceptions(function() {
        db.table("duplicatedfield", {
            startDate: { type:"date", nullable:true },
            startdate: { type:"text" }
        });
    }, "Field name duplicatedfield.startdate differs from another field name by case only.");

    // Test id isn't allowed as a field name
    TEST.assert_exceptions(function() {
        db.table("duplicatedfield", {
            id: { type:"text" },
            startDate: { type:"date", nullable:true }
        });
    }, "'id' is not allowed as field name.");
    // Test indexedWith specifiers can only contain strings
    TEST.assert_exceptions(function() {
        db.table("badindexedwith", {
            t1: { type:"text" },
            t2: { type:"text", indexedWith:["t1",5] }
        });
    }, "Field t2 has bad field name in indexedWith array");

    TEST.assert_exceptions(function() {
        db.table("bad_table_name", { abc: { type:"text" } });
    }, "Database table or column name 'bad_table_name' is not allowed. Names must begin with a-z and be composed of a-zA-Z0-9 only.");
    TEST.assert_exceptions(function() {
        db.table("lovelyTable", { _abc: { type:"text" } });
    }, "Database table or column name '_abc' is not allowed. Names must begin with a-z and be composed of a-zA-Z0-9 only.");

    db.table("department", {
        name: { type:"text" },
        randomDateTime: {type:"datetime", nullable:true },
        roomNumber: { type:"int", nullable:true }
    }, {
        // Define a method on the row objects
        fancyStuff: function(ping) { return ping + " pong"; }
    });

    db.table("employee", {
        name: { type:"text" },
        user: { type:"user", nullable:true },
        startDate: { type:"date", nullable:true },
        salary: { type:"int", nullable:true, indexed:true },
        ref: { type:"ref", nullable:true, indexed:true, uniqueIndex:true },
        department: { type:"link", nullable:true, indexedWith:["lastDepartment","salary"] },
        lastDepartment: { type:"link", nullable:true, linkedTable:"department" }, // table name doesn't match the field name
        caseInsensitiveValue: { type:"text", nullable:true, caseInsensitive:true, indexed:true }
    }, function(rowPrototype) {
        rowPrototype.__defineGetter__("testGetter", function() {
            return "ID:"+this.id;
        });
    });

    db.table("numbers", {
        name: { type:"text" },
        pingTime: { type:"time", nullable:true },
        bools: { type:"boolean", nullable:true },
        small: { type:"smallint", indexed:true },
        medium: { type:"int" },
        big: { type:"bigint", nullable:true },
        floaty: { type:"float", nullable:true }
    });

    db.table("times", {
        entry: {type:"int"},
        lovelyTime: {type:"datetime"}
    });

    db.table("x1", {
        number: { type:"int" }
    });
    db.table("x2", {
        number: { type:"int" },
        xlink: { type:"link", linkedTable:"x1" }
    });

    db.table("files1", {
        description: { type:"text" },
        attachedFile: { type:"file", indexed:true }
    });
    db.table("files2", {
        description2: { type:"text" },
        attachedFile2: { type:"file", nullable:true }
    });

    // Set up the storage
    $host._testCallback("");

    // Create an object
    var engineering = db.department.create({name:"Engineering'"});  // add ' to make sure SQL is escaped
    engineering.roomNumber = 42;
    TEST.assert_equal("Engineering'", engineering.name);
    var engineeringsaveresult = engineering.save();
    TEST.assert(engineering.id > 0);
    TEST.assert(engineeringsaveresult === engineering);    // check save() returns itself

    // Test the method is applied to the object
    TEST.assert_equal("ping pong", engineering.fancyStuff("ping"));

    // Trying to retrieve rows which don't exist just returns null
    TEST.assert_equal(null, db.department.load(engineering.id + 100));

    // Load it back
    var engineering2 = db.department.load(engineering.id);
    TEST.assert_equal(engineering.id, engineering2.id);
    TEST.assert_equal("Engineering'", engineering2.name);

    // Another department
    var hr = db.department.create();
    hr.name = "Human resources";
    var hrRandomDateTime = new Date(2012, 12, 15, 12, 52);
    hr.randomDateTime = hrRandomDateTime;
    hr.roomNumber = 101;
    hr.save();
    TEST.assert(hr.id != engineering.id);

    // Check the datatime is retrieved OK
    var hrForDateTime = db.department.load(hr.id);
    TEST.assert_equal(hrRandomDateTime.toUTCString(), hrForDateTime.randomDateTime.toUTCString());

    // Select all the objects
    var alldepartments = db.department.select().stableOrder();
    TEST.assert_equal(2, alldepartments.count());   // count() before select
    TEST.assert_equal(2, alldepartments.length);
    TEST.assert_equal(2, alldepartments.count());   // count() after select
    TEST.assert_equal(undefined, alldepartments[-1]);
    TEST.assert_equal("Engineering'", alldepartments[0].name);
    TEST.assert_equal("Human resources", alldepartments[1].name);
    TEST.assert_equal(undefined, alldepartments[2]);
    TEST.assert_exceptions(function() {
        // Check that the query can't be modified after it's been run
        alldepartments.where("name","=",'Human resources');
    }, "Query has been executed, and cannot be modified.");
    _.each(["order","stableOrder","limit","offset","include","whereMemberOfGroup","and","or"], function(fn) {
        TEST.assert_exceptions(function() {
            alldepartments[fn].call(alldepartments);
        }, "Query has been executed, and cannot be modified.");
    });

    // Check has() function in Java JdSelect objects
    TEST.assert_equal(false, -1 in alldepartments);
    TEST.assert_equal(true, 0 in alldepartments);
    TEST.assert_equal(true, 1 in alldepartments);
    TEST.assert_equal(false, 2 in alldepartments);

    // Select one object in two different ways
    var onedepartment = db.department.select().where("name", "=", "Human resources");
    TEST.assert_equal("Human resources", onedepartment[0].name);
    TEST.assert_equal(1, onedepartment.length);
    TEST.assert_equal(1, onedepartment.count());
    TEST.assert_equal(hr.id, onedepartment[0].id);
    var deptbynum = db.department.select().where("roomNumber", "<", 100);
    TEST.assert_equal("Engineering'", deptbynum[0].name);
    TEST.assert_equal(1, deptbynum.length);

    // Create an object in another table, referencing the first
    var fred = db.employee.create();
    fred.name = "Fred Bloggs";
    TEST.assert_equal("Fred Bloggs", fred.name);
    fred.salary = 90000;
    fred.ref = O.ref(1000);
    var fredStartDate = new Date(2010, 4, 23);
    fred.startDate = fredStartDate;
    TEST.assert_equal(fredStartDate.toUTCString(), fred.startDate.toUTCString());
    fred.department = engineering;
    fred.save();
    TEST.assert(fred.id > 0);
    TEST.assert(fred.department.id === engineering.id);

    // Was the getter implemented by the row prototype initialiser?
    TEST.assert_equal("ID:"+fred.id, fred.testGetter);
    TEST.assert_equal(undefined, fred.fancyStuff);  // function not available

    // Check nullable checks
    TEST.assert_exceptions(function() { db.x1.create().save(); }, "number cannot be null");
    TEST.assert_exceptions(function() {
        var x = db.x2.create({number:null});
        x.save();
    }, "number cannot be null");
    TEST.assert_exceptions(function() {
        var x = db.x2.create();
        x.number = null;
        x.save();
    }, "number cannot be null");

    // The method on the department table doesn't leak to the employee table
    if(undefined != fred.fancyStuff) { TEST.assert(false); }    // written this way to avoid triggering a warning

    // Select by a linked field
    _.each([engineering, engineering.id], function(linkto) {
        var s = db.employee.select().where("department", "=", linkto);
        TEST.assert_equal(1, s.length);
        TEST.assert_equal("Fred Bloggs", s[0].name);
    });

    // Select by a joined field
    var linkedFieldSelect = db.employee.select().where("department.roomNumber", "=", 42);
    TEST.assert_equal(1, linkedFieldSelect.length);
    TEST.assert_equal("Fred Bloggs", linkedFieldSelect[0].name);

    // Check you can't delete with that query
    TEST.assert_exceptions(function() { linkedFieldSelect.deleteAll(); }, "deleteAll() cannot use selects which include other tables, or where clauses which refer to a field in another table via a link field. Remove include() statements and check your where() clauses.");

    // Check the unique index on the ref field works
    TEST.assert_exceptions(function() {
        var ping = db.employee.create({name:"Ping",ref:O.ref(1000)}); // duplicates ref on fred
        ping.save();
    });
    var ping2 = db.employee.create({name:"Ping2",ref:O.ref(1001)});  // another ref, but different
    ping2.save();

    // Load it back
    var fred2 = db.employee.load(fred.id);
    TEST.assert_equal(fred.id, fred2.id);
    TEST.assert_equal("Fred Bloggs", fred2.name);
    TEST.assert(O.ref(1000) == fred2.ref);
    // Check that the same object is returned the second time a linked table is requested
    var fred2_department = fred2.department;
    TEST.assert(fred2_department !== null);
    TEST.assert(fred2_department === fred2.department);
    TEST.assert_equal("Engineering'", fred2.department.name);
    TEST.assert_equal(fredStartDate.toUTCString(), fred2.startDate.toUTCString());  // Dates don't really like being compared
    fred2.save();   // do a null save and check everything still works
    TEST.assert_equal(fred.id, fred2.id);
    TEST.assert_equal("Fred Bloggs", fred2.name);
    TEST.assert_equal(fredStartDate.toUTCString(), fred2.startDate.toUTCString());  // Dates don't really like being compared

    // Check null fields
    var john = db.employee.create({name:"John Doe",department:hr});
    john.save();
    TEST.assert(john.id > 0);
    TEST.assert(john.id != fred.id);
    var john2 = db.employee.load(john.id);
    TEST.assert_equal("John Doe", john2.name);
    TEST.assert_equal(null, john2.startDate);
    TEST.assert_equal("Human resources", john2.department.name);

    // Test selecting by an ref field
    var selectbyref = db.employee.select().where("ref", "=", O.ref(1000));
    TEST.assert_equal(1, selectbyref.length);
    TEST.assert_equal(fred.id, selectbyref[0].id);
    var selectbynoref = db.employee.select().where("ref", "=", null);
    TEST.assert_equal(1, selectbynoref.length);
    TEST.assert_equal(john.id, selectbynoref[0].id);
    var selectbynotnullref = db.employee.select().where("ref", "<>", null).stableOrder();
    TEST.assert_equal(2, selectbynotnullref.length);
    TEST.assert_equal(fred.id, selectbynotnullref[0].id);
    TEST.assert_equal(ping2.id, selectbynotnullref[1].id);

    // Run a query which includes the other tables, checking they behave as expected
    var field_not_null = function(o,field) { return o.$values[field] != null; };
    var not_loaded = function(o,field) { return !(o.$values[field+'_obj']); };
    var notincluding = db.employee.select();
    TEST.assert_equal(3, notincluding.count());
    TEST.assert_equal(3, notincluding.length);
    notincluding.each(function(o) {
        if(field_not_null(o,'department')) { TEST.assert(not_loaded(o,"department")); }
        if(field_not_null(o,'lastDepartment')) { TEST.assert(not_loaded(o,"lastDepartment")); }
    });
    var including1 = db.employee.select().include("department");
    TEST.assert_equal(3, including1.count());
    TEST.assert_equal(3, including1.length);
    including1.each(function(o) {
        if(field_not_null(o,'department')) { TEST.assert( ! not_loaded(o,"department")); }
        if(field_not_null(o,'lastDepartment')) { TEST.assert(not_loaded(o,"lastDepartment")); }
    });
    var including2 = db.employee.select().include("department").include("lastDepartment").order("name");
    TEST.assert_equal(3, including2.length);
    including2.each(function(o) {
        if(field_not_null(o,'department')) { TEST.assert( ! not_loaded(o,"department")); }
        if(field_not_null(o,'lastDepartment')) { TEST.assert( ! not_loaded(o,"lastDepartment")); }
    });
    var including3 = db.employee.select().include("department").include("lastDepartment").where("name", "=", "Fred Bloggs");
    TEST.assert_equal(1, including3.length);
    TEST.assert_equal("Fred Bloggs", including3[0].name);
    TEST.assert_equal(null, including3[0].lastDepartment);
    TEST.assert_equal("Engineering'", including3[0].department.name);

    // Update a field and check it worked
    john2.name = "John Doe-Modified";
    TEST.assert_equal("John Doe-Modified", john2.name);
    TEST.assert_equal(null, john2.ref);
    john2.save();
    var john3 = db.employee.load(john.id);
    TEST.assert_equal("John Doe-Modified", john3.name);
    TEST.assert_exceptions(function() {
        john3.name = null;
    });
    john3.startDate = new Date();
    TEST.assert_exceptions(function() {
        john3.lastDepartment = "Pants"; // wrong type of value
    });
    TEST.assert_exceptions(function() {
        john3.lastDepartment = fred2; // wrong table
    });
    john3.lastDepartment = engineering.id;  // do it by ID, not by object
    john3.save();
    var john4 = db.employee.load(john.id);
    TEST.assert_equal("John Doe-Modified", john4.name);
    TEST.assert_equal("Engineering'", john4.lastDepartment.name);
    TEST.assert(john4.startDate != null);
    // Update more than one at a time, include a NULL
    john4.name = "John Doe-Mod2";
    john4.startDate = null;
    john4.ref = O.ref(8);
    john4.save();
    var john5 = db.employee.load(john.id);
    TEST.assert_equal("John Doe-Mod2", john5.name);
    TEST.assert_equal(null, john5.startDate);
    TEST.assert(O.ref(8) == john5.ref);

    // Make sure the other employee wasn't changed
    var fred3 = db.employee.load(fred.id);
    TEST.assert_equal("Fred Bloggs", fred3.name);
    TEST.assert_equal(fredStartDate.toUTCString(), fred3.startDate.toUTCString());  // Dates don't really like being compared

    // Try deleting with two different row objects, then make sure it doesn't load
    TEST.assert_equal(true, john3.deleteObject());
    TEST.assert_equal(false, john3.deleteObject());
    TEST.assert_equal(false, john2.deleteObject()); // because it's already gone from the database
    TEST.assert_equal(null, db.employee.load(john.id));

    // Make
    var unsavedemployee = db.employee.create({name:"Hello"});
    TEST.assert_equal(false, unsavedemployee.deleteObject());

    // Make sure the other employee still exists!
    var fred4 = db.employee.load(fred.id);
    TEST.assert(null != fred4);
    TEST.assert_equal(90000, fred4.salary);

    // Can order by ref types
    db.employee.select().order("ref");

    // Try number types
    var numbers1 = db.numbers.create({name:"test1", medium:34344});
    TEST.assert_equal(null, numbers1.big);  // make sure new objects have null in the right place!
    TEST.assert_exceptions(function() {
        numbers1.save();
    });
    numbers1.small = 2;
    numbers1.save();
    var numbers1a = db.numbers.load(numbers1.id);
    TEST.assert_equal(2, numbers1a.small);
    TEST.assert_equal(null, numbers1a.floaty);
    TEST.assert_equal(null, numbers1a.big);
    numbers1.floaty = 1.235585;
    numbers1.big = 922337203685476000;
    numbers1.save();
    var numbers2 = db.numbers.load(numbers1.id);
    TEST.assert_equal(2, numbers2.small);
    TEST.assert_equal(34344, numbers2.medium);
    TEST.assert_equal(922337203685476000, numbers2.big);
    TEST.assert_equal(1.235585, numbers2.floaty);
    TEST.assert_equal(null, numbers2.pingTime);

    // Make sure the hidden 'nullableNulls' object doesn't get corrupted
    var nnn1 = db.numbers.create();
    nnn1.bools = true;
    var nnn2 = db.numbers.create();
    TEST.assert_equal(null, nnn2.bools);

    // Try time type
    numbers1.pingTime = new DBTime(12,23);
    numbers1.save();
    var numbers3 = db.numbers.load(numbers1.id);
    TEST.assert(numbers3.pingTime instanceof DBTime);
    TEST.assert_equal("12:23", numbers3.pingTime.toString());
    numbers1.pingTime = new DBTime(23,18,56);
    numbers1.save();
    var numbers4 = db.numbers.load(numbers1.id);
    TEST.assert(numbers4.pingTime instanceof DBTime);
    TEST.assert_equal("23:18:56", numbers4.pingTime.toString());

    // Try boolean type
    TEST.assert_equal(null, numbers1.bools);
    numbers1.bools = true;
    TEST.assert_equal(true, numbers1.bools);
    numbers1.save();
    var numbers5 = db.numbers.load(numbers1.id);
    TEST.assert_equal(true, numbers5.bools);
    numbers1.bools = false;
    numbers1.save();
    var numbers6 = db.numbers.load(numbers1.id);
    TEST.assert_equal(false, numbers6.bools);

    // Attempt to delete an object which is referenced from another table
    var terry = db.employee.create({name:"Terry Jones", department:hr, startDate:new Date(), salary:20});
    terry.save();
    TEST.assert(null != db.department.load(hr.id));
    TEST.assert_exceptions(function() {
        hr.deleteObject();
    });
    TEST.assert(null != db.department.load(hr.id));
    // Remove the reference to it and try again
    terry.department = null;
    terry.save();
    TEST.assert_equal(true, hr.deleteObject());
    TEST.assert_equal(null, db.department.load(hr.id));

    // Test user field type
    var gordon = db.employee.create({name:"Gordon", user:O.user(42), caseInsensitiveValue:"PiNg"});
    gordon.save();
    var gordon2 = db.employee.load(gordon.id);
    TEST.assert(null != gordon2);
    TEST.assert(gordon2.user != null);
    TEST.assert(gordon2.user instanceof $User);
    TEST.assert_equal(42, gordon2.user.id);
    var gordonQ = db.employee.select().where("user", "=", O.user(42));
    TEST.assert_equal(1, gordonQ.length);
    TEST.assert_equal(gordon.id, gordonQ[0].id);
    TEST.assert_equal("Gordon", gordonQ[0].name);
    // null in user columns
    var jane = db.employee.create({name:"Jane", caseInsensitiveValue:"x"});
    jane.save();
    TEST.assert(null === jane.user);
    var jane2 = db.employee.load(jane.id);
    TEST.assert(null === jane2.user);
    jane2.user = O.user(43);
    jane2.save();
    TEST.assert(db.employee.load(jane.id).user.id === 43);
    jane2.user = null;
    jane2.save();
    TEST.assert(db.employee.load(jane.id).user === null);

    // Check string query case sensitive options
    TEST.assert(db.employee.select().length > 1);    // must be more than one for this to be a proper test
    var caseSensitiveQuery1 = db.employee.select().where("name","=","gordon");
    TEST.assert_equal(0, caseSensitiveQuery1.length);
    var caseSensitiveQuery2 = db.employee.select().where("name","=","Gordon");
    TEST.assert_equal(1, caseSensitiveQuery2.length);
    TEST.assert_equal(gordon.id, caseSensitiveQuery2[0].id);
    var caseInsensitiveQuery1 = db.employee.select().where("caseInsensitiveValue","=","ping");
    TEST.assert_equal(1, caseInsensitiveQuery1.length);
    TEST.assert_equal(gordon.id, caseInsensitiveQuery1[0].id);
    var caseInsensitiveQuery2 = db.employee.select().where("caseInsensitiveValue","=","PING");
    TEST.assert_equal(1, caseInsensitiveQuery2.length);
    TEST.assert_equal(gordon.id, caseInsensitiveQuery2[0].id);

    // LIKE where clauses
    var likeQuery1 = db.employee.select().where("name", "LIKE", "Gor%");
    TEST.assert_equal(1, likeQuery1.length);
    TEST.assert_equal(gordon.id, likeQuery1[0].id);
    var likeQuery2 = db.employee.select().where("name", "LIKE", "gor%"); // case sensitive
    TEST.assert_equal(0, likeQuery2.length);
    var likeQuery3 = db.employee.select().where("caseInsensitiveValue", "LIKE", "pi__"); // case insensitive
    TEST.assert_equal(1, likeQuery3.length);
    TEST.assert_equal(gordon.id, likeQuery3[0].id);
    var likeQuery4 = db.employee.select().where("caseInsensitiveValue", "LIKE", "PI%"); // case insensitive
    TEST.assert_equal(1, likeQuery4.length);
    TEST.assert_equal(gordon.id, likeQuery4[0].id);
    // Check value sanity
    TEST.assert_exceptions(function() { db.employee.select().where("name", "LIKE", ""); }, "Value for a LIKE where clause must be at least one character long.");
    TEST.assert_exceptions(function() { db.employee.select().where("name", "LIKE", "_A"); }, "Value for a LIKE clause may not have a wildcard as the first character.");
    TEST.assert_exceptions(function() { db.employee.select().where("name", "LIKE", "%A"); }, "Value for a LIKE clause may not have a wildcard as the first character.");

    // Delete everything from the numbers table - inefficiently
    db.numbers.select().each(function(o) { o.deleteObject(); });

    // Try some selects
    _.each([
        {name:"a1", medium:348, small:32, bools:false },
        {name:"a2", medium:2, small:34, bools:true },
        {name:"a3", medium:9888, small:37, pingTime:new DBTime(12,45), bools:true },
        {name:"a4", medium:10, small:12 },
        {name:"a5", medium:349, small:100, big:239349, pingTime:new DBTime(12,45,56) },
        {name:"a6", medium:2837, small:23, big:3498, pingTime:new DBTime(8,3) },
    ], function(o) {
        db.numbers.create(o).save();
    });
    var t_res = function(q) {
        var expected_i = 0;
        var x = "";
        q.each(function(row, i) {
            TEST.assert_equal(expected_i++, i);
            x += row.name;
            x += ":";
        });
        return x;
    };
    TEST.assert_equal("a1:a4:a2:", t_res(db.numbers.select().where("medium", "<", 349).order("medium", true)));
    TEST.assert_equal("a1:a4:a2:", t_res(db.numbers.select().where("medium", "<", 349).order("medium", true).stableOrder()));
    TEST.assert_equal("a1:a4:a2:", t_res(db.numbers.select().where("medium", "<", 349).stableOrder().order("medium", true)));
    TEST.assert_equal("a5:", t_res(db.numbers.select().where("big", ">", 4000)));
    TEST.assert_equal("a4:a6:", t_res(db.numbers.select().where("small", "<=", 23).where("medium", ">", 2).order("small")));
    TEST.assert_equal("a3:a1:a4:", t_res(db.numbers.select().where("big", "=", null).where("medium", ">=", 10).order("medium", true)));
    TEST.assert_equal("a3:a1:a4:", t_res(db.numbers.select().where("big", "=", null).where("medium", ">=", 10).order("medium", true).stableOrder()));
    TEST.assert_equal("a5:", t_res(db.numbers.select().where("big", "<>", 3498).order("medium")));
    TEST.assert_equal("a5:a6:", t_res(db.numbers.select().where("big", "<>", null).order("medium")));
    TEST.assert_equal("a5:", t_res(db.numbers.select().where("big", "<>", null).where("medium", "<", 2000).order("medium")));
    TEST.assert_equal("a5:", t_res(db.numbers.select().where("pingTime", ">", new DBTime(12,45))));
    TEST.assert_equal("a3:", t_res(db.numbers.select().where("pingTime", "=", new DBTime(12,45))));
    TEST.assert_equal("a2:a4:a1:", t_res(db.numbers.select().where("pingTime", "=", null).order("medium")));
    TEST.assert_equal("a5:a6:a3:", t_res(db.numbers.select().where("pingTime", "<>", null).order("medium")));
    TEST.assert_equal("a2:a3:", t_res(db.numbers.select().where("bools", "=", true).order("medium")));

    // Limits and offsets
    TEST.assert_equal("a4:", t_res(db.numbers.select().where("pingTime", "=", null).offset(1).limit(1).order("medium")));
    TEST.assert_equal("a1:a4:a2:", t_res(db.numbers.select().where("medium", "<", 349).limit(100).order("medium", true)));
    TEST.assert_equal("", t_res(db.numbers.select().where("medium", "<", 349).offset(100).order("medium", true)));
    TEST.assert_equal("a3:a1:", t_res(db.numbers.select().where("big", "=", null).limit(2).where("medium", ">=", 10).order("medium", true)));
    TEST.assert_equal("a4:a2:", t_res(db.numbers.select().offset(1).where("medium", "<", 349).order("medium", true)));
    TEST.assert_exceptions(function() { db.numbers.select().limit(-1); }, "Limit cannot be negative");
    TEST.assert_exceptions(function() { db.numbers.select().offset(-1); }, "Offset cannot be negative");

    // Delete rows
    TEST.assert_equal("a3:a6:a5:a1:a4:a2:", t_res(db.numbers.select().order("medium", true)));
    TEST.assert_equal(1, db.numbers.select().where("medium", "=", 349).deleteAll());
    TEST.assert_equal("a3:a6:a1:a4:a2:", t_res(db.numbers.select().order("medium", true)));
    TEST.assert_equal(2, db.numbers.select().where("medium", ">", 2000).deleteAll());
    TEST.assert_equal("a1:a4:a2:", t_res(db.numbers.select().order("medium", true)));
    TEST.assert_equal(3, db.numbers.select().deleteAll());
    TEST.assert_equal("", t_res(db.numbers.select().order("medium", true)));
    TEST.assert_equal(0, db.numbers.select().deleteAll());

    // Test where clauses with selection with whereMemberOfGroup()
    db.employee.select().deleteAll();
    _.each([41,42,43,44], function(uid) {
        db.employee.create({name:"U"+uid, user:O.user(uid)}).save();
    });
    var u_res = function(q) {
        var x = "";
        q.each(function(row) {
            x += row.name;
            x += ":";
        });
        return x;
    };
    TEST.assert_equal("U41:", u_res(db.employee.select().whereMemberOfGroup("user", 21).order("user")));
    TEST.assert_equal("U42:", u_res(db.employee.select().whereMemberOfGroup("user", 22).order("user")));
    TEST.assert_equal("U41:U42:U43:", u_res(db.employee.select().whereMemberOfGroup("user", 23).order("user")));

    // =====================================================================================
    // Check linked fields
    var x1Records = _.map([3, 6, 87, 292, 4729], function(v) {
        var r = db.x1.create({number:v});
        r.save();
        return r;
    });
    _.each([[0,76], [0,287], [2,48], [4,12], [4,98]], function(x) {
        db.x2.create({xlink:x1Records[x[0]], number:x[1]}).save();
    });
    var testLinkedQueryResults = function(expected, query) {
        var actual = _.map(query.order("number"), function(n) { return n.number; });
        TEST.assert(_.isEqual(expected, actual));
    };
    testLinkedQueryResults([76,287], db.x2.select().where("xlink.number", "=", 3));
    TEST.assert_equal(2, db.x2.select().where("xlink.number", "=", 3).count());
    testLinkedQueryResults([12,48,98], db.x2.select().where("xlink.number", ">", 3));
    TEST.assert_equal(3, db.x2.select().where("xlink.number", ">", 3).count());
    testLinkedQueryResults([48,76,287], db.x2.select().where("xlink.number", "<", 1000));
    TEST.assert_equal(3, db.x2.select().where("xlink.number", "<", 1000).count());
    // Error messages are nice
    TEST.assert_exceptions(function() { db.x2.select().where("x1.number"); }, "No link field 'x1' in table 'x2' for where clause on x1.number");
    TEST.assert_exceptions(function() { db.x2.select().where("xlink.pants"); }, "Bad field 'pants' for table 'x1'");
    TEST.assert_exceptions(function() { db.x2.select().where("carrots"); }, "Bad field 'carrots' for table 'x2'");

    // =====================================================================================
    // Check sub-clauses and their interaction with linked fields
    testLinkedQueryResults([6,87], db.x1.select().or(function(s) { s.where("number","=",6).where("number","=",87); }));
    testLinkedQueryResults([76,98], db.x2.select().where("number",">",12).or(function(s) { s.where("xlink.number",">",292).where("number","=",76); }));
    TEST.assert_equal(2, db.x2.select().where("number",">",12).or(function(s) { s.where("xlink.number",">",292).where("number","=",76); }).count());
    // Test a sub-clause using a linked field, and building via a sub-clause being returned
    var lqscq1 = db.x2.select().where("number",">",15);
    var lqscq1_or = lqscq1.or();
    lqscq1_or.where("xlink.number",">",4000).where("xlink.number","<",80);
    TEST.assert_equal(3, lqscq1.count());
    testLinkedQueryResults([76,98,287], lqscq1);
    // Sub-clauses must have at least one where clause
    TEST.assert_exceptions(function() { var x = db.x2.select().where("number","=",1).or(function() {}).length; }, "Sub-clauses must have at least one where() clause.");

    // =====================================================================================
    //  Check automatic support of the included date time libraries
    var dateTimeLibraryNum = 4;
    _.each([

        function(d) { return d;},               // native dates
        moment,                                 // moment.js
        function(d) { return new XDate(d); }    // XDate

    ], function(dateObjFn) {
        var date = new Date(2010, 4, 5 + dateTimeLibraryNum, 6, 7);
        var libraryDate = dateObjFn(date);
        db.times.create({entry: dateTimeLibraryNum, lovelyTime: libraryDate}).save();
        var sel = db.times.select().where("entry", "=", dateTimeLibraryNum);
        TEST.assert_equal(1, sel.length);
        // Check it comes out as the right date
        TEST.assert(sel[0].lovelyTime.toUTCString() == date.toUTCString());
        // Check where clause accepts library dates
        var sel2 = db.times.select().where("lovelyTime", "=", libraryDate);
        TEST.assert_equal(1, sel2.length);
        TEST.assert_equal(dateTimeLibraryNum, sel2[0].entry);
        TEST.assert_equal(0, db.times.select().where("lovelyTime", "=", dateObjFn(new Date(2010, 4, 1, 6, 7))).length);
        // Use a different index for each library
        dateTimeLibraryNum++;
    });

    // =====================================================================================
    //  Check dodgy select creation
    var ss = db.employee.select();
    TEST.assert_exceptions(function() { ss.where("notAField", "=", "twelve"); });
    TEST.assert_exceptions(function() { ss.where("name", "not an op", "hello"); });
    TEST.assert_exceptions(function() { ss.where("name", "=", 4); });
    TEST.assert_exceptions(function() { ss.where("name", "<", null); });
    TEST.assert_exceptions(function() { ss.where("name", "=", null); });    // because it's not a nullable field
    ss.where("salary", "=", null);    // which will work
    TEST.assert_exceptions(function() { ss.where("department", "=", john); });
    TEST.assert_exceptions(function() { ss.where("department", "=", db.department.create({name:"hello"})); });
    TEST.assert_exceptions(function() { ss.where("ref", "=", "engineering"); });
    ss.stableOrder().order("name");   // allowed
    var ss2 = db.employee.select();
    ss2.order("name").stableOrder(); // also allowed
    var ss3 = db.employee.select();
    TEST.assert_exceptions(function() { ss3.order("notAField"); });
    TEST.assert_exceptions(function() { var l = db.employee.select().where("ref", "<", O.ref(1)).length; }); // requires execution to fail
    ss3.include("department").include("lastDepartment").include("department");
    TEST.assert_exceptions(function() { ss3.include("notAField"); });
    TEST.assert_exceptions(function() { ss3.include("salary"); });
    var ss4 = db.employee.select();
    TEST.assert_exceptions(function() { ss4.whereMemberOfGroup("notAField", 67); }, "Bad field 'notAField' for table 'employee'");
    TEST.assert_exceptions(function() { ss4.whereMemberOfGroup("department", 67); });

    // =====================================================================================
    //  Check validation of set values

    var ee1 = db.employee.create();

    // ref fields:
    // Validation error
    TEST.assert_exceptions(function() { ee1.ref = 1234; }, "ref must be a Ref or StoreObject");
    // Setting ref
    ee1.ref = O.ref(2);
    TEST.assert(ee1.ref == O.ref(2));
    // Setting with a store object
    var store1 = O.object();
    store1.appendType(TYPE["std:type:book"]);
    store1 = store1.append(12, "ABC");
    store1.save();
    ee1.ref = store1.ref;
    TEST.assert(ee1.ref == store1.ref);

    // TODO: Check all validation for setters on JS database objects

    // =====================================================================================
    //  Test file values
    var file1 = O.file("e199da10191404b79421199004f4f93787e367c3f44b635d86397ff8c782fba2");
    TEST.assert_equal("example10.tiff", file1.filename);
    var file2 = O.file("feed2644bd4834c2b7f9b3ed845f6f1ab4f4b7f3fc45ee3bbc55e71e2a507369");
    TEST.assert_equal("example7.html", file2.filename);

    var file_row1 = db.files1.create({
        description: "Example picture",
        attachedFile: file1
    });
    file_row1.save();
    var file_row2 = db.files1.create();
    file_row2.description = "Lovely HTML document";
    file_row2.attachedFile = file2;
    file_row2.save();

    // Check retrival
    var file_select1 = db.files1.select().where("attachedFile","=",file1);
    TEST.assert_equal(1, file_select1.length);
    TEST.assert(file_select1[0].attachedFile instanceof $StoredFile);
    TEST.assert_equal("e199da10191404b79421199004f4f93787e367c3f44b635d86397ff8c782fba2", file_select1[0].attachedFile.digest);

    // Check anything convertable to a StoredFile can be passed in as a file value
    _.each([
        "feed2644bd4834c2b7f9b3ed845f6f1ab4f4b7f3fc45ee3bbc55e71e2a507369",
        {digest:"feed2644bd4834c2b7f9b3ed845f6f1ab4f4b7f3fc45ee3bbc55e71e2a507369"},
        {digest:"feed2644bd4834c2b7f9b3ed845f6f1ab4f4b7f3fc45ee3bbc55e71e2a507369", fileSize:611}
    ], function(value) {
        var row = db.files1.create({
            description: "hellow",
            attachedFile: value
        }).save();
    });
    TEST.assert_equal(4, db.files1.select().where("attachedFile","=",file2).length);

    // Check updates
    TEST.assert_equal(1, db.files1.select().where("attachedFile","=",file1).length);
    var file_row1_l = db.files1.load(file_row1.id);
    file_row1_l.attachedFile = file2;
    file_row1_l.save();
    TEST.assert_equal(0, db.files1.select().where("attachedFile","=",file1).length);
    TEST.assert_equal(5, db.files1.select().where("attachedFile","=",file2).length);

    // Check null values
    db.files2.create({
        description2: "No file"
    }).save();
    db.files2.create({
        description2: "Hello!",
        attachedFile2: file1
    }).save();
    var filenullable_select1 = db.files2.select().where("attachedFile2","=",null);
    TEST.assert_equal(1, filenullable_select1.length);
    TEST.assert_equal(null, filenullable_select1[0].attachedFile2);
    var filenullable_select2 = db.files2.select().where("attachedFile2","=",file1);
    TEST.assert_equal(1, filenullable_select2.length);
    TEST.assert_equal("example10.tiff", filenullable_select2[0].attachedFile2.filename);
    var filenullable_select3 = db.files2.select().where("attachedFile2","<>",null);
    TEST.assert_equal(1, filenullable_select3.length);
    TEST.assert_equal("example10.tiff", filenullable_select3[0].attachedFile2.filename);
    filenullable_select3[0].attachedFile2 = null;
    filenullable_select3[0].save();
    TEST.assert_equal(0, db.files2.select().where("attachedFile2","<>",null).length);

});
