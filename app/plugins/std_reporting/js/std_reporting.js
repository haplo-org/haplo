/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Terminology:
//   * Facts - a set of facts & figures about a store object, implemented as fields in a database table
//   * Collection - facts about objects
//   * Collection category - a collection is in one or more categories, allowing setup of common functionality
//   * Statistic - a single value derived from a subset of rows in the collection, optionally grouped by other facts
//   * Dashboard - a subset of facts from a collection displayed on a web page, with a potentially different set of facts generated for a spreadsheet export

// Filtering
//   It is useful to define subsets of the collection for reporting.
//   The filter() function on a Collection defines a named subset, and can also define filters
//   which apply to all selects of collection data for implementing permissions.
//   Named filters can be used when:
//     * defining a Dashboard, to select a named subset of data
//     * calculating a statistic on a collection with calculateStatistic()
//   In addition, there are ways of setting anonymous filters defined by functions at various
//   levels:
//     * Dashboards have a filter() function to define additional filters for selecting based
//       on choices made in the UI. These apply in addition to the named filter.
//     * Statistic definitions have a filter property, and the sample when calculating a
//       statistic can also define an additional filter.

// --------------------------------------------------------------------------

var REPORT_UNEXPECTED_CHANGES = !!(O.application.config["std_reporting:report_unexpected_changes"]);
var reportNextExceptionFromUpdates = true; // for limiting number of reports from same runtime

// --------------------------------------------------------------------------

P.REPORTING_API = {}; // appears as P.reporting in plugins using the std:reporting feature

// --------------------------------------------------------------------------

var FILTER_DEFAULT = "$DEFAULT";        // filters to use if no filter explicitly specified
var FILTER_ALL = "$ALL";                // special filter list to use which are always applied (except for unfiltered)
var FILTER_UNFILTERED = "$UNFILTERED";  // special name for no filters to be applied, not even the ALL list.

var ALLOWED_NAME_REGEXP = /^[a-z0-9][a-z0-9_]+[a-z0-9]$/;

var PROHIBITED_DATA_TYPES = ['link', 'user', 'file'];

// Fields required for the implementation of the collection. Prefixed with xImpl to minimise naming collisions.
var IMPL_COLLECTION_FIELDS = Object.seal({
    xImplValidFrom: {type:"datetime"},
    xImplValidTo: {type:"datetime", nullable:true, indexedWith:['xImplValidFrom']}
    // also, a required 'ref' fact is created in _ensureSpecGathered()
});

var collectionNameToDatabaseTableFragment = function(name) {
    // Encode the database name using a stable transform which only uses a-zA-X0-9
    return name.replace(/([^a-zA-Y])/g, function(match, p1) { return 'Z'+p1.charCodeAt(0); });
};

// --------------------------------------------------------------------------

// NOTE: Platform support requires this table name
P.db.table("rebuilds", {
    collection: {type:"text"},
    requested: {type:"datetime"},
    object: {type:"ref", nullable:true},    // full table rebuild required if NULL
    changesNotExpected: {type:"boolean"}
});

// --------------------------------------------------------------------------

var reportingFeatures = {};

P.REPORTING_API.registerReportingFeature = P.registerReportingFeature = function(name, feature) {
    if(name in reportingFeatures) { throw new Error("Feature '"+name+"' already registered"); }
    reportingFeatures[name] = feature;
};

P.useReportingFeature = function(object, args) {
    var feature = reportingFeatures[args[0]];
    if(!feature) { throw new Error("No reporting feature: "+args[0]); }
    var featureArguments = Array.prototype.slice.call(args, 0);
    featureArguments[0] = object;
    feature.apply(object, featureArguments);
};

// --------------------------------------------------------------------------

var getCollection = P.REPORTING_API.collection = P.getCollection = function(name) {
    P.ensureCollectionsDiscovered();
    var collection = P._collections[name];
    return collection ? collection._ensureSetup() : undefined;
};

P.ensureCollectionsDiscovered = function() {
    if("_collections" in P) { return; }
    P._collections = {};
    if(O.serviceImplemented("std:reporting:discover_collections")) {
        O.service("std:reporting:discover_collections", function(name, description, categories) {
            if(!(name in P._collections)) {
                P._collections[name] = new Collection(name, description, categories || []);
            }
        });
    }
};

// --------------------------------------------------------------------------

// Database rows need a 'object' property for getting underlying object
var DB_OBJECT_GETTER = function() {
    return this.ref.load();
};
var setupDbPrototype = function(prototype) {
    prototype.__defineGetter__("object", DB_OBJECT_GETTER);
};
// TODO: It'd be nice if all the objects could be loaded in one efficient query when the first was loaded, so if it's needed, they were all efficiently available.

// Some column types don't match the types in the database
var FACT_TYPE_DB_TYPE_EXCEPTIONS = {
    "end-date": "date"
};

// --------------------------------------------------------------------------

var Collection = function(name, description, categories) {
    if(!(ALLOWED_NAME_REGEXP.test(name))) {
        throw new Error("Bad collection name: "+name);
    }
    this.name = name;
    this.description = description;
    this.$categories = categories;
    this.$properties = {};
};
// Do minimal work to get enough enough info about the collection info so hooks execute as quickly as possible
Collection.prototype._ensureSpecGathered = function() {
    if(this.$factFieldDefinition) { return this; }

    // Initialise the fact definitions with the required 'ref' fact
    this.$factFieldDefinition = {ref:{type:"ref"}};
    this.$factType = {ref:"ref"};
    this.$factDescription = {ref:"Reporting object"};

    this.$filters = {"$DEFAULT":[],"$ALL":[]};
    this.$statistics = {"count": {
        name: "count",
        description: this.description,
        calculate: function(select) { return select.count(); }
    }};
    var serviceNames = [
        "std:reporting:collection:*:setup",
        "std:reporting:collection:"+this.name+":setup"
    ];
    this.$categories.forEach(function(category) {
        serviceNames.push("std:reporting:collection_category:"+category+":setup");
    });
    var collection = this;
    serviceNames.forEach(function(serviceName) {
        if(O.serviceImplemented(serviceName)) {
            O.service(serviceName, collection);
        }
    });
    return this;
};
// Do the full setup work for the collection.
Collection.prototype._ensureSetup = function() {
    if(this.$table) { return this; }
    this._ensureSpecGathered();
    this.$table = P.db._dynamicTable("d"+collectionNameToDatabaseTableFragment(this.name),
        _.extend({}, IMPL_COLLECTION_FIELDS, this.$factFieldDefinition),
        setupDbPrototype);
    if(this.$table.databaseSchemaChanged) {
        // Either the table was created, or new facts were defined.
        // Therefore, a rebuild is required to make sure that all the facts for this collection are stored.
        this.collectAllFactsInBackground();
    }
    return this;
};

Collection.prototype.isCollection = true;

Collection.prototype.property = function(name, value) {
    if(arguments.length === 1) {
        return this.$properties[name];
    }
    if(name in this.$properties) {
        throw new Error("Property already defined: "+name);
    }
    this.$properties[name] = value;
    return this;
};

Collection.prototype.fact = function(name, type, description) {
    if(-1 !== PROHIBITED_DATA_TYPES.indexOf(type)) {
        throw new Error("Data type not permitted for facts: "+type);
    }
    this.$factFieldDefinition[name] = {type:FACT_TYPE_DB_TYPE_EXCEPTIONS[type] || type, nullable:true};
    this.$factType[name] = type;
    this.$factDescription[name] = description;
    return this;
};

Collection.prototype.indexedFact = function(name, type, description) {
    this.fact(name, type, description);
    this.$factFieldDefinition[name].indexed = true;
    return this;
};

// Special filters should be access through symbolic names
Collection.prototype.FILTER_DEFAULT = FILTER_DEFAULT;
Collection.prototype.FILTER_ALL = FILTER_ALL;
Collection.prototype.FILTER_UNFILTERED = FILTER_UNFILTERED;

Collection.prototype.filter = function(name, fn) {
    if((typeof(name) !== "string") || (name === FILTER_UNFILTERED)) {
        throw new Error("Bad filter name: "+name);
    }
    if(typeof(fn) !== "function") {
        throw new Error("Must pass a function to filter()");
    }
    var filters = this.$filters[name];
    if(!filters) { filters = this.$filters[name] = []; }
    filters.push(fn);
    return this;
};

Collection.prototype.statistic = function(statistic) {
    if(typeof(statistic.name) !== "string") {
        throw new Error("Collection statistic must have a name");
    }
    this.$statistics[statistic.name] = statistic;
    return this;
};

// Pass in a function which returns an array of objects...
Collection.prototype.currentObjects = function(finder) {
    this.$currentObjectsFinder = finder;
    return this;
};
// ... and optionally a function which verifies an object should be in the collection.
Collection.prototype.objectIsValidForCollection = function(verifier) {
    this.$objectVerifier = verifier;
    return this;
};
// Alternatively, this function implements both functions for the common case
// of a list of types, and sets up the implicit update rules.
Collection.prototype.currentObjectsOfType = function(/* types */) {
    var types = _.flatten(arguments); // allow single Ref, arrays or Refs, etc
    if(types.length === 0) {
        throw new Error("No types passed to currentObjectsOfType()");
    }
    // Implicit update rules
    var collectionName = this.name;
    _.each(types, function(type) { addUpdateRule(collectionName, type); });
    // Default implementations of membership functions
    return this.currentObjects(function() {
        return O.withoutPermissionEnforcement(function() {
            return ((types.length === 1) ?
                O.query().link(types[0], ATTR.Type) :
                O.query().or(function(or) {
                    _.each(types, function(t) { or.link(t, ATTR.Type); });
                })
            ).sortByDateAscending().execute();
        });
    }).objectIsValidForCollection(function(object) {
        for(var i = types.length - 1; i >= 0; --i) {
            if(object.isKindOf(types[i])) {
                return true;
            }
        }
        return false;
    });
};

Collection.prototype.collectAllFactsInBackground = function() {
    P.db.rebuilds.create({
        collection: this.name,
        requested: new Date(),
        object: null,
        changesNotExpected: false
    }).save();
    $StdReporting.signalUpdatesRequired();
};

Collection.prototype.__defineGetter__("isUpdatingFacts", function() {
    return 0 < P.db.rebuilds.select().where("collection","=",this.name).count();
});

// --------------------------------------------------------------------------

Collection.prototype.selectAllCurrentRows = function(filterName, context) {
    this._ensureSetup();
    return this.$applyFilter(filterName, context || this,
        this.$table.select().where("xImplValidTo","=",null));
};

Collection.prototype.selectAllRowsAtTime = function(date, filterName, context) {
    if(date === undefined) {
        return this.selectAllCurrentRows(filterName, context);
    }
    this._ensureSetup();
    if(!(date && (date instanceof Date))) {
        throw new Error("Must call selectAllRowsAtTime() with a JavaScript Date object");
    }
    var select = this.$table.select().where("xImplValidFrom","<=",date).or(function(c) {
        c.where("xImplValidTo",">",date).where("xImplValidTo","=",null);
    });
    return this.$applyFilter(filterName, context || this, select);
};

Collection.prototype.$applyFilter = function(filterName, context, select) {
    // Explicit check for a special "unfiltered" filter which doesn't do anything
    if(filterName === FILTER_UNFILTERED) { return select; }
    // Otherwise filters must be specified for the given name
    var filters = this.$filters[filterName || FILTER_DEFAULT];
    if(filters === undefined) {
        throw new Error("No filters defined for filter name: "+filterName);
    }
    if(!context) { context = this; }
    var apply = function(filter) { filter(select, context); };
    this.$filters[FILTER_ALL].forEach(apply);
    filters.forEach(apply);
    return select;
};

// Get statistic definition, either looking up by name or return "inline" definition
Collection.prototype.statisticDefinition = function(statistic) {
    this._ensureSetup();
    if(typeof(statistic) === "string") { statistic = this.$statistics[statistic]; }
    if(!statistic || !statistic.name) {
        throw new Error("Bad statistic requested");
    }
    return statistic;
};

// Returns object with properties value & statistic (definition)
Collection.prototype.calculateStatistic = function(statistic, sample, filterName) {
    statistic = this.statisticDefinition(statistic);
    if(!sample) { sample = {}; }
    // Select applicable rows
    var select = sample.$select ?
        sample.$select() :
        this.selectAllRowsAtTime(sample.factsAtTime, filterName, this);
    if(statistic.filter) { statistic.filter(select); }
    if(sample.filter) { sample.filter(select); }
    // Calculate value of statistic
    var value, groups;
    if(statistic.calculate) {
        value = statistic.calculate(select);
    } else if((statistic.aggregate === "COUNT") && !("groupBy" in sample) && !("fact" in statistic)) {
        value = select.count();
    } else if(statistic.aggregate) {
        if(sample.groupBy) {
            groups = select.aggregate(statistic.aggregate, statistic.fact || "ref", sample.groupBy);
            value = 0;
            _.each(groups, function(g) {
                // Sum all values for headline stat
                value += g.value;
                // Add in a display title to the group
                var gv = g.group;
                g.title = O.isRef(gv) ? gv.load().title : ((gv === null) ? null : ""+gv);
            });
        } else {
            // Simple case
            value = select.aggregate(statistic.aggregate, statistic.fact || "ref");
        }
    } else {
        throw new Error("Can't calculate statistic");
    }
    var calculated = {
        value: value,
        statistic: statistic
    };
    if(groups) { calculated.groups = groups; }
    // The value might need to be formatted for presentation (eg if it's a percentage)
    calculated.display = (statistic.displayFormat) ?
        _.sprintf(statistic.displayFormat, value):
        ""+value;
    return calculated;
};

// --------------------------------------------------------------------------

var dateToDayPart = function(f) {
    var d = new Date(f.getTime());
    d.setHours(0); d.setMinutes(0); d.setSeconds(0); d.setMilliseconds(0);
    return d;
};

// Comparison value are only called if a & b are non-null
var factValueComparisonFunctions = {
    "ref": function(a,b) { return a == b; }, // Refs can't be compared with === or !== .
    "labelList": function(a,b) { return a == b; }, // LabelLists can't be compared with === or !== .
    "json": function(a,b) { return _.isEqual(a,b); }, // deep comparison of nested JS objects
    "datetime": function(a,b) { return a.getTime() === b.getTime(); },   // compare ms from epoch
    "date": function(a,b) { return dateToDayPart(a).getTime() === dateToDayPart(b).getTime(); }, // compare adjusted dates
    "time": function(a,b) { return a.getTime() === b.getTime(); }   // compare ms from epoch
};

var updateFacts = function(collection, object, existingRow, timeNow) {
    if($StdReporting.shouldStopUpdating()) {
        var e = new Error("Updates interrupted");
        e.$isPlatformStopUpdating = true;
        throw e;
    }
    if(!timeNow) { timeNow = new Date(); }
    if(!existingRow) {
        // Attempt to load existing row if it wasn't passed into this functon
        var q = collection.$table.select().where("ref","=",object.ref).where("xImplValidTo","=",null);
        if(q.length) {
            existingRow = q[0];
        }
    }
    // Verify object is not deleted, and belongs in this collection
    if(object.deleted || (collection.$objectVerifier && !(collection.$objectVerifier(object)))) {
        var logExtra = '';
        if(existingRow) {
            existingRow.xImplValidTo = timeNow;
            existingRow.save();
            logExtra = "and marking end of validity for existing facts";
        }
        console.log("Object is not part of collection", collection.name, "or deleted, not collecting facts for", logExtra, object);
        return false;
    }
    // Create a blank row
    var row = collection.$table.create({
        ref: object.ref,
        xImplValidFrom: timeNow
    });
    // Ask other plugins to update the values
    var serviceNames = [
        "std:reporting:collection:*:get_facts_for_object",
        "std:reporting:collection:"+collection.name+":get_facts_for_object"
    ];
    collection.$categories.forEach(function(category) {
        serviceNames.push("std:reporting:collection_category:"+category+":get_facts_for_object");
    });
    serviceNames.forEach(function(serviceName) {
        if(O.serviceImplemented(serviceName)) {
            O.service(serviceName, object, row, collection);
        }
    });
    // New rows are just saved, updates checked to see if they actually need updating
    if(existingRow) {
        var needUpdate = false;
        _.each(collection.$factFieldDefinition, function(defn, name) {
            // Some value types need special comparison, as JavaScript has
            // interesting views on equality.
            var comparisonFn = factValueComparisonFunctions[defn.type];
            var a = existingRow[name], b = row[name];
            if(a === undefined) { a = null; }
            if(b === undefined) { b = null; }
            if(comparisonFn) {
                if(a === null && b === null) { // no update needed
                } else if(a === null || b === null) { needUpdate = true; // one is not null
                } else if(!(comparisonFn(a,b))) { needUpdate = true; }
            } else {
                if(a !== b) { needUpdate = true; }
            }
        });
        if(needUpdate) {
            existingRow.xImplValidTo = timeNow;
            existingRow.save();
            row.save();
            return true;
        }
    } else {
        row.save();
        return true;
    }
    return false;
};

// --------------------------------------------------------------------------

var doFullRebuildOfCollection = function(collectionName, changesExpected) {
    var timeNow = new Date();
    O.impersonating(O.SYSTEM, function() {
        var collection = getCollection(collectionName);
        if(!collection) {
            console.log("When running job to collect all facts, collection "+collectionName+" not found.");
            return;
        }
        console.log("Collecting all facts for:", collection.name);

        var wasUpdated, updated = 0, updatedRefs = [];

        if(!changesExpected) {
            console.log("Changes are NOT expected in this full update.");
            wasUpdated = function(ref) {
                updated++; updatedRefs.push(ref);
            };
        } else {
            wasUpdated = function() { updated++; };
        }

        // Find all the objects that should be in this collection
        var objects = collection.$currentObjectsFinder ? collection.$currentObjectsFinder() : [];
        var objectLookup = O.refdict();
        _.each(objects, function(obj) { objectLookup.set(obj.ref, obj); });

        // Find all the current rows
        var seenRowForObject = O.refdict();
        var currentRows = collection.$table.select().where("xImplValidTo","=",null);
        _.each(currentRows, function(row) {
            var ref = row.ref;
            seenRowForObject.set(ref, true);
            var object = objectLookup.get(ref);
            if(object) {
                // Update the row
                if(updateFacts(collection, object, row, timeNow)) {
                    wasUpdated(ref);
                }
            } else {
                // Object is no longer in the list, stop the row from being valid.
                row.xImplValidTo = timeNow;
                row.save();
                wasUpdated(ref);
            }
        });
        // Create new rows for any objects which weren't there already
        objectLookup.each(function(ref, object) {
            if(!seenRowForObject.get(ref)) {
                if(updateFacts(collection, object, undefined, timeNow)) {
                    wasUpdated(ref);
                }
            }
        });
        if(!changesExpected && (updated > 0)) {
            if(REPORT_UNEXPECTED_CHANGES) {
                O.reportHealthEvent("Unexpected update in std_reporting collection: "+collectionName,
                    "Expected 0 updated, got "+updated+". This implies that plugins are not updating facts when they should.\n\nObjects updated: "+
                    _.map(updatedRefs, function(r) { return r.toString(); }).join(' '));
            }
        }
        console.log("Updated:", updated);
    });
};

var doUpdateFactsForObjects = function(collectionName, updates) {
    var collection = getCollection(collectionName);
    if(!collection) { return; }
    var timeNow = new Date();
    O.impersonating(O.SYSTEM, function() {
        console.log("Updating facts for:", collectionName, ' ('+_.map(updates, function(r) { return r.toString(); }).join(',')+')');
        var updated = 0;
        _.each(updates, function(ref) {
            var object = ref.load();
            if(object) {
                if(updateFacts(collection, object, undefined, timeNow)) { updated++; }
            }
        });
        console.log("Updated:", updated);
    });
};

// NOTE: Platform runs this callback in a special thread, and requires this name.
P.backgroundCallback("update", function() {
    // Determine what needs to be rebuilt
    var rebuilds = P.db.rebuilds.select();
    var fullRebuilds = {};
    var updateForObject = {};
    _.each(rebuilds, function(row) {
        if(row.object === null) {
            // Use negated changesNotExpected so a "not expected" and an "expected" turns into "expected"
            fullRebuilds[row.collection] = (fullRebuilds[row.collection] || !row.changesNotExpected);
        } else {
            if(!updateForObject[row.collection]) { updateForObject[row.collection] = O.refdict(); }
            if(row.changesNotExpected) { throw new Error("Logic error: not expected"); }
            updateForObject[row.collection].set(row.object, true);
        }
    });
    try {
        // Do full updates
        _.each(fullRebuilds, function(changesExpected, collectionName) {
            doFullRebuildOfCollection(collectionName, changesExpected);
        });
        // Do partial updates
        _.each(updateForObject, function(refs, collectionName) {
            if(!fullRebuilds[collectionName]) { // as it will have just be done
                var updates = [];
                refs.each(function(ref,t) { updates.push(ref); });
                doUpdateFactsForObjects(collectionName, updates);
            }
        });
    } catch(e) {
        if("$isPlatformStopUpdating" in e) {
            console.log("Reporting update terminated early, updates not cleared and will be rerun");
        } else {
            console.log("Updating, caught error: "+e.message);
            if(reportNextExceptionFromUpdates) {
                O.reportHealthEvent("Exception in std_reporting collection update",
                    "Exception thrown when updating facts for an object. NOTE: Future exceptions in this runtime will not be reporting. Check server logs.\n\nException: "+e.message);
                reportNextExceptionFromUpdates = false; // don't send too many, just one per runtime gives the right idea
            }
        }
        return; // prevent clearing of update in table
    }
    // Delete all the rebuild row used to determine data AFTER they've been completed.
    // But if reporting updates stopped early or there was an error, then the table won't be cleared so it'll retry.
    _.each(rebuilds, function(row) {
        row.deleteObject();
    });
});

// --------------------------------------------------------------------------

// Implement declarative rules on how objects should be updated
var needToCollecteUpdateRules = true,
    updateCollectionRules = O.refdictHierarchical(function() { return []; }),
    addUpdateRule = function(collection, type, desc) {
        var rule = {collection:collection};
        if(desc) { rule.desc = desc; }
        updateCollectionRules.get(type).push(rule);
    };

P.hook('hPostObjectChange', function(response, object, operation, previous) {
    // Collect all the rules from the implementing plugins on the first call
    if(needToCollecteUpdateRules) {
        // Gathering the spec about collections may generate implicit update rules.
        // Use _ensureSpecGathered() to avoid doing too much work here.
        P.ensureCollectionsDiscovered();
        _.each(P._collections, function(collection) { collection._ensureSpecGathered(); });
        // And then find all the other rules.
        if(O.serviceImplemented("std:reporting:gather_collection_update_rules")) {
            O.service("std:reporting:gather_collection_update_rules", addUpdateRule);
        }
        needToCollecteUpdateRules = false;
    }
    // Work out which rules apply
    var relevantTypes = O.refdict();
    object.everyType(function(v) { relevantTypes.set(v,true); });
    if(previous) {
        previous.everyType(function(v) { relevantTypes.set(v,true); });
    }
    var rules = [];
    relevantTypes.each(function(type) {
        var rulesForType = updateCollectionRules.getAllInHierarchy(type);
        if(rulesForType.length > 0) {
            rules.push(rulesForType);
        }
    });
    rules = _.flatten(rules);
    // Don't do anything else if there aren't any rules which apply to the object
    if(rules.length === 0) { return; }
    // Determine which rows need updating
    var collectionsToUpdate = {};
    var determineUpdatesFor = function(o) {
        _.each(rules, function(rule) {
            var refs = collectionsToUpdate[rule.collection];
            if(!refs) {
                refs = collectionsToUpdate[rule.collection] = O.refdict();
            }
            if(rule.desc) {
                o.each(rule.desc, function(v,d,q) {
                    if(O.isRef(v)) {
                        refs.set(v,true);
                    }
                });
            } else {
                refs.set(o.ref,true);
            }
        });
    };
    determineUpdatesFor(object);
    if(previous) {
        determineUpdatesFor(previous);
    }
    // Request updates
    var now = new Date();
    var haveUpdates = false;
    _.each(collectionsToUpdate, function(refs, collectionName) {
        refs.each(function(ref) {
            P.db.rebuilds.create({
                collection: collectionName,
                requested: now,
                object: ref,
                changesNotExpected: false
            }).save();
            haveUpdates = true;
        });
    });
    if(haveUpdates) {
        $StdReporting.signalUpdatesRequired();
    }
});

// --------------------------------------------------------------------------

P.implementService("std:reporting:update_entire_collection", function(collectionName) {
    var collection = getCollection(collectionName);
    if(!collection) { return; }
    collection.collectAllFactsInBackground();
});

// Assumes that only objects which should be in the collection are passed to this service
P.implementService("std:reporting:update_required", function(collectionName, updates) {
    if(!getCollection(collectionName)) { return; }
    _.each(updates, function(ref) {
        if(ref && O.isRef(ref)) {
            P.db.rebuilds.create({
                collection: collectionName,
                requested: new Date(),
                object: ref,
                changesNotExpected: false
            }).save();
        }
    });
    $StdReporting.signalUpdatesRequired();
});

// --------------------------------------------------------------------------

// TODO: Change frequency of rebuild all collections scheduled to weekly. Or make it configurable for dev systems?

var rebuildAllToCheckFactsHaveBeenKeptUpToDate = function() {
    console.log("Rebuilding all collections to check that other plugins have been keeping their facts up to date.");
    P.ensureCollectionsDiscovered();
    _.each(P._collections, function(collection, name) {
        P.db.rebuilds.create({
            collection: name,
            requested: new Date(),
            object: null,
            changesNotExpected: true    // because this is a scheduled update
        }).save();
    });
    $StdReporting.signalUpdatesRequired();
};

P.hook('hScheduleDailyMidnight', function(response, year, month, dayOfMonth, hour, dayOfWeek) {
    rebuildAllToCheckFactsHaveBeenKeptUpToDate();
});

// --------------------------------------------------------------------------

P.provideFeature("std:reporting", function(plugin) {
    plugin.reporting = P.REPORTING_API;
});
