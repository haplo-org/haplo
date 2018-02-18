/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var DashboardAggregate = function() {
};

P.dashboardConstructors["aggregate"] = DashboardAggregate;

// --------------------------------------------------------------------------

var cells = function(s, defaultValue) {
    if(typeof(s) === "string") {
        return O.service(s);
    }
    return s || defaultValue;
};

var DEFAULT_X = [{}],
    DEFAULT_Y = [{}],
    DEFAULT_OUTER_X = [{}],
    DEFAULT_OUTER_Y = [{}],
    DEFAULT_FORMATTER = O.numberFormatter("0.##");

// --------------------------------------------------------------------------

DashboardAggregate.prototype = new P.Dashboard();

DashboardAggregate.prototype.kind = "aggregate";

DashboardAggregate.prototype._calculateValues = function() {
    var x = cells(this.specification.x, DEFAULT_X),
        y = cells(this.specification.y, DEFAULT_Y),
        outerX = cells(this.specification.outerX, DEFAULT_OUTER_X),
        outerY = cells(this.specification.outerY, DEFAULT_OUTER_Y);

    // Check dimensions have at least one entry, otherwise dashboard is empty
    [x, y, outerX, outerY].forEach(function(dimension) {
        if(!(_.isArray(dimension) && dimension.length > 0)) {
            O.stop("This dashboard cannot be displayed because the data which determines the rows and columns is missing.", "Cannot display dashboard");
        }
    });

    var yHasTitles = !!y[0].title,
        outerXhasTitles = !!outerX[0].title,
        outerYhasTitles = !!outerY[0].title;

    var aggregate = this.specification.aggregate || 'COUNT',
        fact = this.specification.fact || 'ref';

    var formatter = this.specification.formatter || DEFAULT_FORMATTER;

    var values = [];

    // Can a grouping query be used?
    var yGroupByFact = y[0].groupByFact,
        groupedLookup, foundIndex;
    if(yGroupByFact) {
        _.each(y, function(ys) {
            if(!("value" in ys)) { throw new Error("Dimension units must have value if groupByFact is used"); }
            if(ys.groupByFact !== yGroupByFact) { throw new Error("Dimension units have inconsistent groupByFact properties"); }
        });
        // Build an array of arrays of arrays to act as lookup for values.
        groupedLookup = [];
        for(var z0 = 0; z0 < outerY.length; ++z0) {
            var l = [];
            for(var z1 = 0; z1 < outerX.length; ++z1) {
                var m = [];
                for(var z2 = 0; z2 < x.length; ++z2) {
                    m.push([]);
                }
                l.push(m);
            }
            groupedLookup.push(l);
        }
    }

    // Titles along top
    if(outerXhasTitles) {
        var outerTitleRow = outerYhasTitles ? [{}] : [];
        if(yHasTitles) { outerTitleRow.push({}); }
        for(var toyx = 0; toyx < outerX.length; ++toyx) {
            outerTitleRow.push({th:outerX[toyx].title, colspan:x.length});
        }
        values.push(outerTitleRow);
    }
    if(x[0].title) {
        var titleRow = outerYhasTitles ? [{}] : [];
        if(yHasTitles) { titleRow.push({}); }
        for(var xtoyx = 0; xtoyx < outerX.length; ++xtoyx) {
            for(var z = 0; z < x.length; ++z) {
                titleRow.push({th:x[z].title});
            }
        }
        values.push(titleRow);
    }

    // Calcuate values in cells
    // Iterate over outer Y
    for(var oyi = 0; oyi < outerY.length; ++oyi) {
        var oys = outerY[oyi];

        // Iterate over inner Y
        for(var yi = 0; yi < y.length; ++yi) {
            var ys = y[yi];

            // Row started in inner Y
            var row = [];
            if(outerYhasTitles) {
                // Outer Y title goes in first cell of first row in each outer Y
                row.push((yi === 0) ? {th:oys.title} : {});
            }
            if(yHasTitles) {
                row.push({th:ys.title});
            }

            // Iterate over outer X
            for(var oxi = 0; oxi < outerX.length; ++oxi) {
                var oxs = outerX[oxi];

                // Iterate over inner X
                for(var xi = 0; xi < x.length; ++xi) {
                    var xs = x[xi];
                    var v;

                    if(yGroupByFact) {
                        // Use optimised aggregate
                        var lookup = groupedLookup[oyi][oxi][xi];
                        if(lookup.length === 0) {
                            var gq = this.select();
                            if(oys.filter) { oys.filter(gq); }
                            // Not the filter from y
                            if(oxs.filter) { oxs.filter(gq); }
                            if(xs.filter)  { xs.filter(gq); }
                            var gv = gq.aggregate(aggregate, fact, yGroupByFact);
                            for(var gi = 0; gi < gv.length; ++gi) {
                                var group = gv[gi];
                                // Find which index it is in the y. using == for comparison so refs work
                                foundIndex = undefined;
                                for(var search = 0; search < y.length; ++search) {
                                    if(y[search].value == group.group) {
                                        foundIndex = search;
                                        break;
                                    }
                                }
                                if(foundIndex !== undefined) {
                                    lookup[foundIndex] = group.value;
                                } else {
                                    this._droppedValuesFromGroupByAggregate = true;
                                }
                            }
                        }
                        v = lookup[yi] || 0;
                    } else {
                        // Use one query per cell
                        var q = this.select();
                        if(oys.filter) { oys.filter(q); }
                        if(ys.filter)  { ys.filter(q); }
                        if(oxs.filter) { oxs.filter(q); }
                        if(xs.filter)  { xs.filter(q); }
                        v = q.aggregate(aggregate, fact);
                    }
                    row.push({
                        v: v,
                        display: formatter(v),
                        isZero: v === 0
                    });
                }

            }

            values.push(row);

        }

    }

    return values;
};

DashboardAggregate.prototype._makeDashboardView = function() {
    return {
        dashboard: this,
        values: this._calculateValues()
    };
};

// Only renders the table
DashboardAggregate.prototype.deferredRender = function() {
    return P.template("dashboard/aggregate/aggregate-table").deferredRender(this._makeDashboardView());
};

DashboardAggregate.prototype._respondWithExport = function() {
    var values = this._calculateValues();
    var xls = O.generate.table.xlsx(this.specification.title);
    xls.newSheet(this.specification.title);
    values.forEach(function(row) {
        row.forEach(function(cell) {
            if(cell.th) {
                xls.cell(cell.th);
                if(cell.colspan) {
                    for(var i = 1; i < cell.colspan; ++i) { xls.cell(); }
                }
                xls.styleCells(xls.columnIndex, xls.rowIndex, xls.columnIndex, xls.rowIndex, "FONT", "BOLD");
            } else {
                xls.cell(cell.v);
            }
        });
        xls.nextRow();
    });
    this.E.response.body = xls;
};

DashboardAggregate.prototype.respond = function() {
    this._callFinalServices();
    this.E.setResponsiblePlugin(P);
    if(this.isExporting) { return this._respondWithExport(); }
    this.E.render(this._makeDashboardView(), "dashboard/aggregate/aggregate_dashboard");
    return this;
};
