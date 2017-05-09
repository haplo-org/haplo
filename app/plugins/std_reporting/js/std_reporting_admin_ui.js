/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var CanAdminReporting = O.action("std:reporting:admin:can-administrate-reporting").
    title("Reporting: Use administrative interface for collections").
    allow("group", Group.Administrators);

var validCollectionName = function(name) {
    P.ensureCollectionsDiscovered();
    return !!(P._collections[name]);
};

// --------------------------------------------------------------------------

P.hook('hGetReportsList', function(response) {
    if(O.currentUser.allowed(CanAdminReporting)) {
        response.reports.push(["/do/reporting/admin", "Reporting administration"]);
    }
});

P.respond("GET", "/do/reporting/admin", [
], function(E) {
    CanAdminReporting.enforce();
    P.ensureCollectionsDiscovered();
    var collections = [];
    _.each(P._collections, function(collection, name) {
        collections.push({
            collection: collection
        });
    });
    E.render({
        collections: collections
    }, "admin/collections-admin-ui");
});

// --------------------------------------------------------------------------

P.respond("POST", "/do/reporting/admin/rebuild-collection", [
    {parameter:"collection", as:"string", validate:validCollectionName}
], function(E, name) {
    CanAdminReporting.enforce();
    var collection = P.getCollection(name);
    collection.collectAllFactsInBackground();
    E.response.redirect("/do/reporting/admin");
});

// --------------------------------------------------------------------------

P.respond("GET", "/do/reporting/admin/collection-facts", [
    {pathElement:0, as:"string", validate:validCollectionName}
], function(E, name) {
    CanAdminReporting.enforce();
    var collection = P.getCollection(name);
    var facts = [];
    _.each(collection.$factDescription, function(description, name) {
        facts.push({
            name: name,
            type: collection.$factType[name],
            description: description
        });
    });
    E.render({
        collection: collection,
        facts: facts
    }, "admin/collection-facts");
});

// --------------------------------------------------------------------------

P.respond("GET", "/do/reporting/admin/collection-fact-lookup", [
    {pathElement:0, as:"string", validate:validCollectionName},
    {parameter:"ref", as:"string"}
], function(E, name, refStr) {
    CanAdminReporting.enforce();
    var collection = P.getCollection(name);
    var object, ref = O.ref(refStr);
    if(!ref || !(object = ref.load())) {
        return E.response.redirect("/do/reporting/admin/collection-facts/"+collection.name);
    }
    var factsAtTimes = [];
    var factNamesSorted = _.keys(collection.$factDescription).sort();
    var factDefns = collection.$factFieldDefinition;
    _.each(collection.$table.select().where("ref","=",ref).order("xImplValidFrom",true),
        function(row, index, facts) {
        var factDisplay = [];
        _.each(factNamesSorted, function(name) {
            var e = {name:name};
            var value = row[name];
            if(index < facts.length-1) {
                var prevValue = facts[index+1][name];
                if(factDefns[name].type === "date" || factDefns[name].type === "datetime") {
                    if(value && !prevValue) { e.updated = true; }
                    else if(!value && prevValue) { e.updated = true; }
                    else if(value && prevValue && value.getTime() != prevValue.getTime()) { 
                        e.updated = true;
                    }
                } else {
                    if(prevValue != value) {
                        e.updated = true;
                    }
                }
            }
            if(O.isRef(value)) {
                e.ref = value;
            } else if(typeof(value) === "string") {
                e.string = value;
            } else if(typeof(value) === "object") {
                if(value instanceof $LabelList) {
                    e.refList = value;
                } else {
                    try {
                        e.pre = JSON.stringify(value, undefined, 2);
                    } catch(_) {
                        e.pre = 'ERROR JSON ENCODING';
                    }
                }
            } else {
                e.value = ""+value;
            }
            factDisplay.push(e);
        });
        factsAtTimes.push({
            from: row.xImplValidFrom,
            to: row.xImplValidTo,
            facts: factDisplay
        });
    });
    E.render({
        object: object,
        collection: collection,
        factsAtTimes: factsAtTimes
    }, "admin/collection-fact-lookup");
});
