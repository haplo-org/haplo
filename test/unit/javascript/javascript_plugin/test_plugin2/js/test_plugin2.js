/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.hook('hTestNullOperation2', function(response) {
    $host._testCallback("hTestNullOperation2");
});

P.hook('hChainTest1', function(response) {
    $host._debug_string = "1 - test_plugin2";
});

P.hook('hChainTest2', function(response) {
    $host._debug_string = "2 - test_plugin2";
});

P.hook('hTestDatabase', function(response) {
    var d1 = this.db.department.create({name:"Test dept"});
    d1.save();
    var d2 = this.db.department.create({name:"Other dept", roomNumber:45});
    d2.save();
    var e1 = this.db.employee.create({name:"Joe Bloggs", department:d1});
    e1.save();
    var eq = this.db.employee.select();
    var dq = this.db.department.select();
    response.string = ""+eq.length+" "+dq.length;
});

// Simple database definition
P.db.table("department", {
    name: { type:"text" },
    roomNumber: { type:"int", nullable:true }
});
P.db.table("employee", {
    name: { type:"text" },
    department: { type:"link", nullable:true},
});

// Simple service for calling from the other plugin
P.implementService("test_service", function(arg1) {
    return "service "+$host.getCurrentlyExecutingPluginName()+" "+arg1;
});
