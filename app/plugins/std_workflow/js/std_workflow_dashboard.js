/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Use platform private API
var interpolateNAMEinString = O.$private.$interpolateNAMEinString;

// --------------------------------------------------------------------------

var CanViewAllDashboards = O.action("std:workflow:admin:view-all-dashboards").
    title("Workflow: View all dashboards").
    allow("group", Group.Administrators);

// --------------------------------------------------------------------------

var DashboardBase = function() { };
DashboardBase.prototype = {

    setup: function(E) {
        this._queryFilters = [];
        // Update spec?
        if(this.spec.configurationService) {
            var configuredSpec = _.clone(this.spec);
            O.service(this.spec.configurationService, configuredSpec);
            this.spec = configuredSpec;
        }
        // Permissions
        var canView = O.currentUser.allowed(CanViewAllDashboards);
        if(!canView && this.spec.canViewDashboard) {
            if(this.spec.canViewDashboard(this, O.currentUser)) { canView = true; }
        }
        if(!canView) { O.stop("Not authorised."); }
        // Per-dashboard setup
        if(this.spec.setup) {
            this.spec.setup(this, E);
        }
        return this;
    },

    addHeaderDeferred: function(deferred) {
        if(!("_headerDeferreds" in this)) { this._headerDeferreds = []; }
        this._headerDeferreds.push(deferred);
        return this;
    },

    addLinkParameter: function(key, value) {
        if(!("_linkParameters" in this)) { this._linkParameters = {}; }
        this._linkParameters[key] = value;
        return this;
    },

    addQueryFilter: function(fn) {
        this._queryFilters.push(fn);
        return this;
    },

    // Override title for a particular dashboard with particular options
    setTitle: function(instanceTitle) {
        this.$instanceTitle = instanceTitle;
    },

    // State name lookup. This uses default text lookup directly because the text system
    // requires a workflow instance.
    _displayableStateName: function(state) {
        var textLookup = this.workflow.$instanceClass.prototype.$textLookup;
        var text = textLookup["dashboard-status:"+state] || textLookup["status:"+state] || '????';
        // Need to do the NAME interpolation for dashboard states
        return interpolateNAMEinString(text);
    },

    _mergeStatesInCounts: function(counts) {
        var mergeStates = this.spec.mergeStates;
        if(!mergeStates) { return; }
        _.each(mergeStates, function(sourceStates, destState) {
            if(!(destState in counts)) { counts[destState] = 0; }
            sourceStates.forEach(function(s) {
                if(s in counts) {
                    counts[destState] = counts[destState] + counts[s];
                    delete counts[s];
                }
            });
        });
    },

    _mergeStatesInCountsWithColumnTag: function(counts) {
        var mergeStates = this.spec.mergeStates;
        if(!mergeStates) { return; }
        _.each(mergeStates, function(sourceStates, destState) {
            if(!(destState in counts)) { counts[destState] = {}; }
            var d = counts[destState];
            sourceStates.forEach(function(s) {
                if(s in counts) {
                    _.each(counts[s], function(v,col) {
                        if(!(col in d)) { d[col] = 0; }
                        d[col] += v;
                    });
                    delete counts[s];
                }
            });
        });
    },

    _generateCounts: function() {
        var dashboard = this;
        var counts, columns, rows = [];
        var view = {rows:rows};
        if("columnTag" in this.spec) {
            // Break down counts by a particular tag
            var columnTag = this.spec.columnTag;
            counts = this._makeQuery().countByTags("state", columnTag);
            dashboard._mergeStatesInCountsWithColumnTag(counts);
            var columnTagValues = {};
            _.each(counts, function(counts, state) {
                _.each(counts, function(value, key) {
                    columnTagValues[key] = true;
                });
            });
            columns = _.map(_.keys(columnTagValues), function(value) {
                return {
                    value: value,
                    name: dashboard._columnTagToName(value)
                };
            });
            columns = view.columns = _.sortBy(columns, "name");
            this.spec.states.forEach(function(state) {
                var rowCounts = counts[state] || {};
                var total = 0;
                var countsForState = _.map(columns, function(column) {
                    var count = rowCounts[column.value] || 0;
                    total += count;
                    var countParams = {};
                    if(column.value) {
                        countParams[columnTag] = column.value;
                    } else {
                        countParams.__empty_tag = "1";
                    }
                    return {
                        count: count,
                        countParams: countParams
                    };
                });
                countsForState.push({count:total});
                rows.push({
                    state: state,
                    stateName: dashboard._displayableStateName(state),
                    counts: countsForState
                });
            });
            view.hasHeaderRow = true; // can't just rely on columns being non-empty
        } else {
            // Just the total for each state
            counts = this._makeQuery().countByTags("state");
            this._mergeStatesInCounts(counts);
            this.spec.states.forEach(function(state) {
                rows.push({
                    state: state,
                    stateName: dashboard._displayableStateName(state),
                    counts: [
                        {count:(counts[state] || 0)}  // states with count==0 won't be in the counts dictionary
                    ]
                });
            });
        }
        return view;
    },

    _columnTagToName: function(tagValue) {
        return this.spec.columnTagToName ? this.spec.columnTagToName(tagValue) : tagValue;
    },

    _makeQuery: function() {
        var q = O.work.query(this.workflow.fullName).isEitherOpenOrClosed();
        this._queryFilters.forEach(function(fn) { fn(q); });
        return q;
    }
};

DashboardBase.prototype.__defineGetter__("_displayableTitle", function() {
    return interpolateNAMEinString(this.$instanceTitle || this.spec.title);
});

// TODO: Remove query property when we're sure it's not used
DashboardBase.prototype.__defineGetter__("query", function() {
    console.log("Warning: Dashboard query property is deprecated");
    return this._makeQuery();
});

DashboardBase.prototype.__defineGetter__("_counts", function() {
    return this._generateCounts();
});

// --------------------------------------------------------------------------

P.registerWorkflowFeature("std:dashboard:states", function(workflow, spec) {
    var plugin = workflow.plugin;

    var Dashboard = function() { };
    Dashboard.prototype = new DashboardBase();
    Dashboard.prototype.workflow = workflow;
    Dashboard.prototype.spec = spec;

    // ----------------------------------------------------------------------

    // Main dashboard display
    plugin.respond("GET", spec.path, [
    ], function(E) {
        E.setResponsiblePlugin(P);  // template source etc
        var dashboard = (new Dashboard()).setup(E);
        E.render({
            layout: spec.layout,
            spec: dashboard.spec,
            dashboard: dashboard
        }, "dashboard/dashboard-states");
    });

    // ----------------------------------------------------------------------

    // Export dashboard counts
    plugin.respond("POST", spec.path+'/export', [
    ], function(E) {
        var dashboard = (new Dashboard()).setup(E);
        var title = dashboard._displayableTitle;
        var counts = dashboard._generateCounts();

        var xls = O.generate.table.xls(title);
        xls.newSheet(title, true);
        xls.cell(title);
        if(counts.columns) {
            counts.columns.forEach(function(column) { xls.cell(column.name); });
            xls.cell("TOTAL");
        }
        _.each(counts.rows, function(row) {
            xls.nextRow().cell(row.stateName);
            row.counts.forEach(function(count) {
                xls.cell((count.count === 0) ? null : count.count);
            });
        });
        E.response.body = xls;
    });

    // ----------------------------------------------------------------------

    // Show listing of all work units matching a given state
    plugin.respond("GET", spec.path+'/list', [
        {parameter:"state", as:"string"}
    ], function(E, state) {
        E.setResponsiblePlugin(P);  // template source etc
        var dashboard = (new Dashboard()).setup(E);
        // Filter work units
        var states = [state];
        var mergeStates = dashboard.spec.mergeStates;
        if(mergeStates && (state in mergeStates)) {
            states = states.concat(mergeStates[state]);
        }
        var list = [];
        var tagDisplayableName;
        var columnTag = dashboard.spec.columnTag;
        states.forEach(function(queryState) {
            var query = dashboard._makeQuery();
            query.tag("state", queryState);
            if(columnTag) {
                var columnTagValue = E.request.parameters[columnTag];
                if(columnTagValue) {
                    query.tag(columnTag, columnTagValue);
                    if(!tagDisplayableName) { tagDisplayableName = dashboard._columnTagToName(columnTagValue); }
                } else if(E.request.parameters.__empty_tag) {
                    // Empty column values have a special URL parameter
                    query.tag(columnTag, null);
                }
            }
            // Get information about each work unit matching the criteria
            _.each(query, function(workUnit) {
                var M = workflow.instance(workUnit);
                if(M) { list.push(M); }
            });
        });
        E.render({
            stateName: dashboard._displayableStateName(state),
            tagDisplayableName: tagDisplayableName,
            dashboard: dashboard,
            list: list
        }, "dashboard/dashboard-listing");
    });

});
