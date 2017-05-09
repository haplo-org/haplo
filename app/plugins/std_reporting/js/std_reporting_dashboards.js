/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.dashboardConstructors = {};

// --------------------------------------------------------------------------

P.REPORTING_API.dashboard = function(E, specification) {
    if(!(specification.name && /^[a-zA-Z_]+$/.test(specification.name))) {
        throw new Error("Invalid specification name: "+specification.name);
    }

    var collection = P.getCollection(specification.collection);
    if(!collection) {
        throw new Error("Unknown reporting collection: "+specification.collection);
    }

    var DashboardConstructor = P.dashboardConstructors[specification.kind];
    if(!DashboardConstructor) {
        throw new Error("Unknown dashboard kind: "+specification.kind);
    }

    var dashboard = (new DashboardConstructor())._setupBase(specification.name, collection);
    dashboard.E = E;
    dashboard.specification = specification;
    // dashboard filters on specification.filter
    dashboard.isExporting = (E.request.method === "POST");

    // Collect extra columns and other configuration in a standardised way
    var callServices = [
            // Wildcard 'all dashboards'
            "std:reporting:dashboard:*:setup",
            // A service for any dashboard using this collection, eg, for global filtering
            // (service implementors can check isExporting property)
            "std:reporting:collection_dashboard:"+collection.name+":setup",
            // A service for this dashboard in particular
            "std:reporting:dashboard:"+specification.name+":setup"
        ];
    // A service for all dashboards of a collection category, eg, for columns added to all dashboards of a collection
    collection.$categories.forEach(function(category) {
        callServices.push("std:reporting:collection_category_dashboard:"+category+":setup");
    });
    if(dashboard.isExporting) {
        // A service for when the dashboard is exported
        callServices.push("std:reporting:dashboard:"+specification.name+":setup_export");
    }
    // Call each of the services
    callServices.forEach(function(serviceName) { O.serviceMaybe(serviceName, dashboard); });
    // Store a 'final' version of services names to allow customisations which might depend
    // on what other plugins did.
    dashboard.$finalCallServices = callServices.map(function(n) { return n+'_final'; });

    return dashboard;
};

// --------------------------------------------------------------------------

P.Dashboard = function() {};

P.Dashboard.prototype._setupBase = function(name, collection) {
    this.name = name;
    this.collection = collection;
    this.$summaryDisplay = [];
    this.$navigationUI = [];
    this.$properties = {};  // inheritance implemented by property()
    return this;
};

P.Dashboard.prototype._callFinalServices = function() {
    if(this.$finalCallServices) {
        var dashboard = this;
        this.$finalCallServices.forEach(function(serviceName) { O.serviceMaybe(serviceName, dashboard); });
        delete this.$finalCallServices;
    }
};

P.Dashboard.prototype.isDashboard = true;

P.Dashboard.prototype.property = function(name, value) {
    if(arguments.length === 1) {
        // Properties inherit from the collection's properties
        return this.$properties[name] || this.collection.property(name);
    }
    if(name in this.$properties) {
        throw new Error("Property already defined: "+name);
    }
    this.$properties[name] = value;
    return this;
};

P.Dashboard.prototype.use = function(name /* arguments */) {
    P.useReportingFeature(this, arguments);
    return this;
};

P.Dashboard.prototype.setTime = function(date) {
    if(!(date && (date instanceof Date))) {
        throw new Error("Must call setTime() with a JavaScript Date object");
    }
    this.selectFactsAtTime = date;
};

P.Dashboard.prototype.setTimeFromRequestParameter = function(name) {
    var p = this.E.request.parameters[name];
    if(p) {
        var msFromEpoch = Date.parse(p);
        if(isNaN(msFromEpoch)) {
            this.invalidFactsAtRequested = true;
        } else {
            this.selectFactsAtTime = new Date(msFromEpoch);
        }
    }
    return this;
};

// Specify order of rows in the dashboard
// Each argument is either columnName, or [columnName, descending]
P.Dashboard.prototype.order = function(/* orders */) {
    if(!("$orders" in this)) { this.$orders = []; }
    var orders = Array.prototype.slice.call(arguments);
    this.$orders.push(function(select) {
        orders.forEach(function(order) {
            if(typeof(order) === "string") {
                select.order(order);
            } else {
                select.order.apply(select, order);
            }
        });
    });
    return this;
};

P.Dashboard.prototype.filter = function(fn) {
    if(!("$filters" in this)) { this.$filters = []; }
    this.$filters.push(fn);
    return this;
};

P.Dashboard.prototype.selectWithoutOrder = function() {
    var select = this.collection.selectAllRowsAtTime(this.selectFactsAtTime, this.specification.filter, this);
    if(this.$filters) { this.$filters.forEach(function(fn) { fn(select); }); }
    return select;
};

P.Dashboard.prototype.select = function() {
    var select = this.selectWithoutOrder();
    if(this.$orders) { this.$orders.forEach(function(fn) { fn(select); }); }
    return select;
};

P.Dashboard.prototype.calculateStatistic = function(statistic, displayOptions) {
    var dashboard = this;
    // Make sure the full dashboard definition is available for defaultDisplayOptions
    statistic = this.collection.statisticDefinition(statistic);
    displayOptions = displayOptions || statistic.defaultDisplayOptions || {};
    return this.collection.calculateStatistic(statistic, {
        context: dashboard,
        $select: function() {
            // Mustn't add order() clauses as it'll mess up statistic groupBy.
            return dashboard.selectWithoutOrder();
        },
        groupBy: displayOptions.groupBy
    });
};

P.Dashboard.prototype.display = function(where, deferred) {
    if(!deferred) { return; }
    if(!where) { where = "above"; }
    if(!O.isDeferredRender(deferred)) {
        throw new Error("Second argument to where() must be a deferred render.");
    }
    var displays = this.$displays;
    if(!displays) { displays = this.$displays = {}; }
    if(!(where in displays)) { displays[where] = []; }
    displays[where].push(deferred);
    return this;
};

P.Dashboard.prototype.summaryStatistic = function(sort, statistic, displayOptions) {
    return this.summaryDisplay(sort, function(dashboard) {
        var calculated = dashboard.calculateStatistic(statistic, displayOptions);
        var groupJSON;
        if(calculated.groups) {
            groupJSON = JSON.stringify(_.map(calculated.groups, function(g) {
                if(!g.title) { g.title = "Not specified"; }
                return [g.value,g.title];
            }));
        }
        return P.template("dashboard/common/summary-statistic").deferredRender({calculated:calculated, title: calculated.statistic.description, groupJSON:groupJSON});
    });
};

// fn() must return a deferred render
P.Dashboard.prototype.summaryDisplay = function(sort, fn) {
    this.$summaryDisplay.push({sort:sort, fn:fn});
    return this;
};
P.Dashboard.prototype.__defineGetter__("_hasSummaryDisplay", function() { return this.$summaryDisplay.length > 0; });
P.Dashboard.prototype.__defineGetter__("_summaryDisplayDeferreds", function() {
    var dashboard = this;
    var sortedDisplay = _.sortBy(this.$summaryDisplay, "sort");
    return _.map(sortedDisplay, function(d) { return d.fn(dashboard); });
});

// fn() must return a deferred render
P.Dashboard.prototype.navigationUI = function(fn) {
    this.$navigationUI.push(fn);
    return this;
};
P.Dashboard.prototype.__defineGetter__("_hasNavigationUI", function() { return this.$navigationUI.length > 0; });
P.Dashboard.prototype.__defineGetter__("_deferredNavigationUI", function() {
    var dashboard = this;
    return _.map(this.$navigationUI, function(fn) { return fn(dashboard); });
});
