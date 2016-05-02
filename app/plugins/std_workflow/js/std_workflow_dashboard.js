/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var DashboardBase = function() { };
DashboardBase.prototype = {

    setup: function(E) {
        // Permissions
        var canView = O.currentUser.isMemberOf(Group.Administrators);
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
        return P.interpolateNAME(undefined, text);
    },

    _generateCounts: function() {
        var dashboard = this;
        var counts, columns, rows = [];
        var view = {rows:rows};
        if("columnTag" in this.spec) {
            // Break down counts by a particular tag
            var columnTag = this.spec.columnTag;
            counts = this.query.countByTags("state", columnTag);
            var columnTagValues = {};
            _.each(counts, function(counts, state) {
                _.each(counts, function(value, key) {
                    columnTagValues[key] = true;
                });
            });
            var columnTagToName = this.spec.columnTagToName ? this.spec.columnTagToName : function(v) { return v; };
            columns = _.map(_.keys(columnTagValues), function(value) {
                return {
                    value: value,
                    name: columnTagToName(value)
                };
            });
            columns = view.columns = _.sortBy(columns, "name");
            this.spec.states.forEach(function(state) {
                var rowCounts = counts[state] || {};
                var total = 0;
                var countsForState = _.map(columns, function(column) {
                    var count = rowCounts[column.value] || 0;
                    total += count;
                    var countParams = {}; countParams[columnTag] = column.value;
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
            counts = this.query.countByTags("state");
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
    }

};

DashboardBase.prototype.__defineGetter__("_displayableTitle", function() {
    return this.$instanceTitle || this.spec.title;
});

DashboardBase.prototype.__defineGetter__("query", function() {
    if(this.$query) { return this.$query; }
    var q = this.$query = O.work.query(this.workflow.fullName).isEitherOpenOrClosed();
    return q;
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
            spec: spec,
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
        dashboard.query.tag("state", state);
        if("columnTag" in spec) {
            var columnTagValue = E.request.parameters[spec.columnTag];
            if(columnTagValue) { dashboard.query.tag(spec.columnTag, columnTagValue); }
        }
        // Get information about each work unit matching the criteria
        var list = _.map(dashboard.query, function(workUnit) {
            var M = workflow.instance(workUnit);
            return {
                M: M
            };
        });
        E.render({
            stateName: dashboard._displayableStateName(state),
            spec: spec,
            dashboard: dashboard,
            list: list
        }, "dashboard/dashboard-listing");
    });

});
