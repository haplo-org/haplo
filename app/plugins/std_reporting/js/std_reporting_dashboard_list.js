/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var DashboardList = function() {
    this.columnGroups = [];
    this.$uiWidgetsTop = [];
    this.$rowAttributeFns = [];
};

P.dashboardConstructors["list"] = DashboardList;

// --------------------------------------------------------------------------

DashboardList.prototype = new P.Dashboard();

DashboardList.prototype.columns = function(priority, columns) {
    var collection = this.collection;
    this.columnGroups.push({
        priority: priority,
        columns: _.map(columns, function(c) {
            return makeColumn(collection, c);
        })
    });
    return this;
};

DashboardList.prototype._makeRenderableColumnList = function() {
    // Make sorted flat list of column objects, then prepare them use
    var dashboard = this;
    var columns = [];
    _.each(_.sortBy(this.columnGroups, "priority"), function(group) {
        columns = columns.concat(group.columns);
    });
    columns.forEach(function(c) { c._prepare(dashboard); });
    return columns;
};

DashboardList.prototype._makeDashboardView = function(hideExport) {
    var columns = this._makeRenderableColumnList();

    // Generate grouping header rows
    var groupHeaderRows = [];
    var groupIndex = 0;
    while(groupIndex < 32) {
        var lastCell = {colspan:0};
        var cells = [lastCell];
        var haveGroup = false;
        for(var c = 0; c < columns.length; ++c) {
            // Attempt to find a group ID and title of this column.
            // groups property of column is array of two element arrays, each of which is [id,title]
            var col = columns[c];
            var gs = col.groups;
            var ginfo = gs ? gs[groupIndex] : undefined;
            if(ginfo) { haveGroup = true; } else { ginfo = []; }
            var gid = ginfo[0];
            var gtitle = ginfo[1];
            // If ID is the same, extend previous group, otherwise create a new cell
            if(gid === lastCell.gid) {
                lastCell.colspan++;
            } else {
                lastCell = {gid:gid, title:gtitle, colspan:1};
                cells.push(lastCell);
            }
        }
        if(!haveGroup) { break; }
        if(cells[0].colspan === 0) { cells.shift(); } // delete zero width column if first was in group
        groupHeaderRows.unshift(cells);
        groupIndex++;
    }

    // Locally scoped copy of row attribute generator functions
    var rowAttributeFns = this.$rowAttributeFns;

    // Render rows of data
    var rowsHTML = [];
    _.each(this.select(), function(row) {
        var html = columns.map(function(column) {
            return column.renderCell(row);
        });
        var attributes = {};
        rowAttributeFns.forEach(function(fn) { fn(row, attributes); });
        rowsHTML.push({
            attributes: attributes,
            unsafeRowHTML: html.join('')
        });
    });

    return {
        pageTitle: this.specification.title,
        backLink: this.specification.backLink,
        backLinkText: this.specification.backLinkText,
        hideExport: hideExport,
        layout: "std:wide",
        dashboard: this,
        widgetsTop: _.map(this.$uiWidgetsTop, function(f) { return f(); }),
        groupHeaderRows: groupHeaderRows,
        columns: columns,
        rowsHTML: rowsHTML
    };
};

DashboardList.prototype.respond = function() {
    this.E.setResponsiblePlugin(P);
    // Export data rather than rendering?
    if(this.isExporting) { return this._respondWithExport(); }
    this.E.render(this._makeDashboardView(), "dashboard/list/list_dashboard");
    return this;
};

DashboardList.prototype.deferredRender = function() {
    return P.template("dashboard/list/list_dashboard").deferredRender(this._makeDashboardView(true /* Hide Export */));
};

DashboardList.prototype._respondWithExport = function() {
    var columns = this._makeRenderableColumnList();
    var xls = O.generate.table.xlsx(this.specification.title);
    xls.newSheet(this.specification.title, true);
    _.each(columns, function(c) {
        xls.cell(c.exportHeading);
        // Blank heading cells required?
        var w = c.exportWidth;
        while((--w) > 0) { xls.cell(''); }
    });
    _.each(this.select(), function(row) {
        xls.nextRow();
        columns.forEach(function(column) {
            column.exportCell(row, xls);
        });
    });
    O.audit.write({
        auditEntryType: "std_reporting:export",
        data: {
            collection: this.collection.name,
            dashboard: this.name,
            at: (this.selectFactsAtTime || new Date()).toString()
        }
    });
    this.E.response.body = xls;
};

// --------------------------------------------------------------------------

// Search widget
P.registerReportingFeature("std:row_text_filter", function(dashboard, spec) {
    if(!dashboard.$rowSearchWidgetIsSetup) {
        dashboard.$rowSearchWidgetIsSetup = true;
        var facts = dashboard.$rowTextFilterFacts = [];
        // Needs attributes added to the row to filter
        dashboard.$rowAttributeFns.push(function(row, attrs) {
            attrs['data-text-filter'] = facts.map(function(fact) {
                var value = row[fact], factType = dashboard.collection.$factType[fact];
                if(factType === "ref") { return (value === null) ? '' : value.load().title; }
                return (value === null) ? '' : value.toString();
            }).join(' ').toLowerCase();
        });
        // Needs a search widget rendered
        dashboard.$uiWidgetsTop.push(function() {
            return P.template("dashboard/list/widget_text_filter").deferredRender(spec);
        });
    }
    _.each(spec.facts || [], function(f) { dashboard.$rowTextFilterFacts.push(f); });
});

// --------------------------------------------------------------------------

// Filter drop down widget
P.registerReportingFeature("std:row_object_filter", function(dashboard, spec) {
    var fact = spec.fact, factType = dashboard.collection.$factType[fact];
    if(!(fact && (factType === "ref"))) {
        throw new Error("std:row_object_filter needs a fact specified, which must exist and be a ref.");
    }
    // Add attributes to the rows
    var attrName = 'data-'+fact.toLowerCase();
    dashboard.$rowAttributeFns.push(function(row, attrs) {
        var value = row[fact];
        if(value !== null) {
            attrs[attrName] = value.toString();
        }
    });
    // Add downdown filters to the list
    dashboard.$uiWidgetsTop.push(function() {
        // Obtain list of objects
        var objects = spec.objects || [];
        if(O.isRef(objects)) {
            objects = O.query().link(spec.objects, ATTR.Type).sortByTitle().execute();
        } else if(typeof(objects) === "function") {
            objects = objects();
        }
        // Placeholder defaults to description of fact
        var placeholder = spec.placeholder;
        if(!placeholder) {
            placeholder = '-- '+dashboard.collection.$factDescription[fact]+' --';
        }
        // Render!
        return P.template("dashboard/list/widget_object_filter").deferredRender({
            fact: fact.toLowerCase(),
            placeholder: placeholder,
            objects: objects
        });
    });
});

// --------------------------------------------------------------------------

var CELL_STYLE_TO_ATTRS = {
    success: ' class="z__std_workflow_success"',
    error: ' class="z__std_workflow_date_error"',
    warn: ' class="z__std_workflow_date_warn"'
};

// --------------------------------------------------------------------------

var ColumnBase = function() { };

ColumnBase.prototype._prepare = function(dashboard) {
    this.prepare(dashboard);
    // Export heading defaults to the column heading.
    if(!this.exportHeading) {
        this.exportHeading = this.heading || '????';
    }
};

ColumnBase.prototype.prepare = function(dashboard) {
};

ColumnBase.prototype.renderCell = function(row) {
    return '<td>'+this.renderCellInner(row)+'</td>';
};

ColumnBase.prototype.renderCellInner = function(row) {
    var value = row[this.fact];
    return (value === null) ? '' : _.escape(value.toString());
};

ColumnBase.prototype.exportWidth = 1;

ColumnBase.prototype.exportCell = function(row, xls) {
    xls.cell(row[this.fact]);
};

// --------------------------------------------------------------------------

// Accessed directly to set up aliases
var columnTypes = {};

var makeColumnType = function(info) {
    var t = function(collection, colspec) {
        this.fact = colspec.fact;
        this.heading = colspec.heading || '????';
        this.exportHeading = colspec.exportHeading;
        this.groups = colspec.groups;
        this.columnStyle = colspec.style;
        if(info.construct) { info.construct.call(this, collection, colspec); }
    };
    t.prototype = new ColumnBase();
    columnTypes[info.type] = t;
    return t;
};

var makeColumn = function(collection, colspec) {
    if(typeof(colspec) === "string") {
        // Column is simple string - make a default spec
        colspec = {fact:colspec};
    }
    // Use the definition to work out the type, if it wasn't specified
    if(!colspec.type && colspec.fact) {
        var factType = collection.$factType[colspec.fact];
        if(!factType) { throw new Error("Fact does not exist: "+colspec.fact); }
        colspec.type = factType;
    }
    if(!colspec.heading && colspec.fact) {
        var heading = collection.$factDescription[colspec.fact];
        if(heading) {
            colspec.heading = heading;
            colspec.$generatedDefaultHeading = true;
        }
    }
    var ColumnConstructor = columnTypes[colspec.type] || SimpleColumn;
    return new ColumnConstructor(collection, colspec);
};

// --------------------------------------------------------------------------

var SimpleColumn = makeColumnType({type:"simple"});

// --------------------------------------------------------------------------

var refColumnEscapedTitleFn = function(property) {
    return function(r) {
        return _.escape(r.load()[property]);
    };
};

var RefColumn = makeColumnType({
    type: "ref",
    construct: function(collection, colspec) {
        this.link = colspec.link;
        this.escapedTitles = O.refdict(
            refColumnEscapedTitleFn(colspec.shortestTitle ? "shortestTitle" : "title")
        );
    }
});

RefColumn.prototype.renderCellInner = function(row) {
    var value = row[this.fact];
    if(value) {
        var linkPath = this.link ? row[this.fact].load().url() : false;
        return linkPath ? '<a href="'+_.escape(linkPath)+'">'+this.escapedTitles.get(value)+'</a>' :
                          this.escapedTitles.get(value);
    } else {
        return '';
    }
};

// --------------------------------------------------------------------------

var refPersonNameColumnFieldsFn = function(r) {
    var object = r.load();
    if(!object) { return null; }
    var title = object.firstTitle();
    if(O.typecode(title) === O.T_TEXT_PERSON_NAME) {
        var fields = title.toFields();
        fields.url = object.url();
        return fields;
    } else {
        return {url:object.url(), last:title.toString()};
    }
};

var RefPersonNameColumn = makeColumnType({
    type: "ref-person-name",
    construct: function(collection, colspec) {
        this.link = colspec.link;
        this.objectFields = O.refdict(refPersonNameColumnFieldsFn);
    }
});

RefPersonNameColumn.prototype.renderCellInner = function(row) {
    var value = row[this.fact];
    if(value) {
        var fields = this.objectFields.get(value);
        var escapedName = _.escape(fields.first ? (''+fields.last+', '+fields.first) : fields.last);
        return this.link ? '<a href="'+_.escape(fields.url)+'">'+escapedName+'</a>' : escapedName;
    } else {
        return '';
    }
};

RefPersonNameColumn.prototype.exportWidth = 3;

RefPersonNameColumn.prototype.exportCell = function(row, xls) {
    var value = row[this.fact];
    if(value) {
        var fields = this.objectFields.get(value);
        xls.cell(fields.last).cell(fields.first).cell(fields.title);
    } else {
        xls.cell().cell().cell();
    }
};

// --------------------------------------------------------------------------

var DATE_FORMAT_DATETIME = "dd MMM yyyy HH:mm";
var DATE_FORMAT_DATE = "dd MMM yyyy";

var dateExportCellOutput = function(value, xls) {
    if(value) {
        switch(this.format) {
            case DATE_FORMAT_DATETIME: xls.cell(value); break;
            case DATE_FORMAT_DATE:     xls.cell(value, "date"); break;
            default:                   xls.cell((new XDate(value)).toString(this.format)); break;
        }
    } else {
        xls.cell(null);
    }
};

var dateExportCellImplementation = function(row, xls) {
    dateExportCellOutput.call(this, row[this.fact], xls);
};

// --------------------------------------------------------------------------

var makeDateColumnType = function(type, defaultFormat) {
    var Column = makeColumnType({
        type: type,
        construct: function(collection, colspec) {
            this.format = colspec.format || defaultFormat;
        }
    });

    Column.prototype.renderCell = function(row) {
        var value = row[this.fact];
        if(value === null) {
            return '<td data-sort="0"></td>';
        } else {
            var d = (new XDate(value));
            // Calling renderCellInner() is a bit inefficient, but allows renderCell() to be reused
            return '<td data-sort="'+d.toString("yyyyMMddHHmm")+'">'+this.renderCellInner(row)+'</td>';
        }
    };

    Column.prototype.renderCellInner = function(row) {
        var value = row[this.fact];
        return (value === null) ? '' : (new XDate(value)).toString(this.format);
    };

    Column.prototype.exportCell = dateExportCellImplementation;

    return Column;
};

var DateTimeColumn = makeDateColumnType("datetime", DATE_FORMAT_DATETIME);
var DateColumn =     makeDateColumnType("date",     DATE_FORMAT_DATE);

// --------------------------------------------------------------------------

// for columns that are the 'end' of a date range, so midnight of that day
// and therefore would display the day after what the user would expect
var EndDateColumn = makeColumnType({
    type: "end-date",
    construct: function(collection, colspec) {
        this.format = colspec.format || DATE_FORMAT_DATE;
    }
});

var endDateColumnXDate = function(value) {
    return value ? (new XDate(value)).addSeconds(-1) : null;
};

EndDateColumn.prototype.renderCell = DateTimeColumn.prototype.renderCell;

EndDateColumn.prototype.renderCellInner = function(row) {
    var endxdate = endDateColumnXDate(row[this.fact]);
    return (endxdate === null) ? '' : endxdate.toString(this.format);
};

EndDateColumn.prototype.exportCell = function(row, xls) {
    var endxdate = endDateColumnXDate(row[this.fact]);
    // HH:MM:SS must all be 0 otherwise Excel will display non-zero values unexpectedly when you edit the cell.
    dateExportCellOutput.call(this, endxdate ? endxdate.setHours(0).setMinutes(0).setSeconds(0).toDate() : null, xls);
};

// --------------------------------------------------------------------------

var DateWithAgeWarningsColumn = makeColumnType({
    type: "date-with-age-warning",
    construct: function(collection, colspec) {
        this.format = colspec.format || "dd MMM yyyy";  // different to datetime
        this.warnDate = colspec.warnDate || (new Date(0));  // epoch will be less than all other dates
        this.errorDate = colspec.errorDate || (new Date(0));
        this.successFact = colspec.successFact;
        this.determineCellStyle = colspec.determineCellStyle || dateWithAgeWarningsColumnDefaultDetermineCellStyle;
    }
});

var dateWithAgeWarningsColumnDefaultDetermineCellStyle = function(row) {
    var value = row[this.fact];
    if(this.successFact && row[this.successFact]) {
        return "success";
    } else {
        if(value && value < this.errorDate) {
            return "error";
        } else if(value && value < this.warnDate) {
            return "warn";
        }
    }
};

DateWithAgeWarningsColumn.prototype.renderCell = function(row) {
    var value = row[this.fact];
    var styling = this.determineCellStyle(row);
    var classAttr = styling ? CELL_STYLE_TO_ATTRS[styling] : '';
    if(value === null) {
        return '<td'+classAttr+'></td>';
    }
    var d = (new XDate(value));
    return '<td data-sort="'+d.toString("yyyyMMddHHmm")+'"'+classAttr+'>'+d.toString(this.format)+'</td>';
};

DateWithAgeWarningsColumn.prototype.renderCellInner = DateTimeColumn.prototype.renderCellInner;

DateWithAgeWarningsColumn.prototype.exportCell = dateExportCellImplementation;

// --------------------------------------------------------------------------

var NumberColumn = makeColumnType({type:"int"});
columnTypes['float'] = NumberColumn;
columnTypes['smallint'] = NumberColumn;
columnTypes['bigint'] = NumberColumn;

NumberColumn.prototype.renderCell = function(row) {
    var value = row[this.fact];
    if(value === null) {
        return '<td></td>';
    } else if(value === 0) {
        return '<td class="z__std_reporting_value_0"></td>';
    } else {
        return '<td>'+value+'</td>';
    }
};

NumberColumn.prototype.renderCellInner = function(row) {
    var value = row[this.fact];
    return (value === null) ? '' : value;
};

// --------------------------------------------------------------------------

var BooleanColumn = makeColumnType({
    type:"boolean",
    construct: function(collection, colspec) {
        this.truthFunction = colspec.truthFunction;
    }
});

BooleanColumn.prototype.renderCellInner = function(row) {
    var value = row[this.fact];
    if(this.truthFunction) {
        value = this.truthFunction(value);
    }
    return value ? '&#10003;' : '';
};

BooleanColumn.prototype.exportCell = function(row, xls) {
    var value = row[this.fact];
    if(this.truthFunction) {
        value = this.truthFunction(value);
    }
    xls.cell(value ? 'yes' : null);
};

// --------------------------------------------------------------------------

var JoinColumn = makeColumnType({
    type: "join",
    construct: function(collection, colspec) {
        this.joinWith = colspec.joinWith || ', ';
        this.columns = _.map(colspec.columns || [], function(c) {
            return makeColumn(collection, c);
        });
    }
});

JoinColumn.prototype.prepare = function(dashboard) {
    this.columns.forEach(function(c) {
        c.prepare(dashboard);
    });
};

JoinColumn.prototype.renderCellInner = function(row) {
    return _.reduce(this.columns, function(memo, column) {
        var cellValue = column.renderCellInner(row);
        if(cellValue !== '') { memo.push(cellValue); }
        return memo;
    }, []).join(this.joinWith);
};

JoinColumn.prototype.__defineGetter__("exportWidth", function() {
    var width = 0;
    this.columns.forEach(function(column) {
        width += column.exportWidth;
    });
    return width;
});

JoinColumn.prototype.exportCell = function(row, xls) {
    this.columns.forEach(function(column) {
        column.exportCell(row, xls);
    });
};

// --------------------------------------------------------------------------

var AttributeColumn = makeColumnType({
    type: "attribute",
    construct: function(collection, colspec) {
        if(!colspec.desc) {
            throw new Error("attribute dashboard columns need a 'desc' property");
        }
        this.desc = colspec.desc;
        if(colspec.$generatedDefaultHeading) {
            // Need to escape schema value because it's user controlled.
            this.heading = this.heading+" "+_.escape(SCHEMA.getAttributeInfo(this.desc).name);
        }
    }
});

AttributeColumn.prototype._getValueAsStringMaybe = function(row) {
    var value = row[this.fact];
    if(!value) { return null; }
    return ""+(value.load().first(this.desc) || "");  // value might not have toString() function
};

AttributeColumn.prototype.renderCellInner = function(row) {
    return _.escape(this._getValueAsStringMaybe(row) || "");
};

AttributeColumn.prototype.exportCell = function(row, xls) {
    xls.cell(this._getValueAsStringMaybe(row));
};

// --------------------------------------------------------------------------

var LinkedColumn = makeColumnType({
    type: "linked",
    construct: function(collection, colspec) {
        if(!colspec.column) {
            throw new Error("linked dashboard columns need a 'column' property");
        }
        this.column = makeColumn(collection, colspec.column);
        this.heading = this.column.heading;
        this.exportHeading = this.column.exportHeading;
        // TODO: Default object accessor is a bit slow if it's to be executed on every row, maybe optimistic loading needed in row object?
        this.link = colspec.link || function(row) {
            return row.object.url();
        };
    }
});

LinkedColumn.prototype.prepare = function(dashboard) {
    this.column.prepare(dashboard);
};

LinkedColumn.prototype.renderCellInner = function(row) {
    var cellHTML = this.column.renderCellInner(row);
    var linkPath = this.link(row);
    if(linkPath) {
        return '<a href="'+_.escape(linkPath)+'">'+cellHTML+'</a>';
    } else {
        return cellHTML;
    }
};

LinkedColumn.prototype.__defineGetter__("exportWidth", function() {
    return this.column.exportWidth;
});

LinkedColumn.prototype.exportCell = function(row, xls) {
    this.column.exportCell(row, xls);
};

// --------------------------------------------------------------------------

var HTMLColumn = makeColumnType({
    type: "html",
    construct: function(collection, colspec) {
        this.displayHTML = colspec.displayHTML;
        this.sortValue = colspec.sortValue;
        this.exportValue = colspec.exportValue || function() {
            return '????';
        };
        this.exportOptions = colspec.exportOptions;
    }
});

HTMLColumn.prototype.renderCell = function(row) {
    if(this.sortValue) {
        var sort = this.sortValue(row);
        return '<td data-sort="'+sort+'">'+this.renderCellInner(row)+'</td>';
    }
    return '<td>'+this.renderCellInner(row)+'</td>';
};

HTMLColumn.prototype.renderCellInner = function(row) {
    return this.displayHTML(row);
};

HTMLColumn.prototype.exportCell = function(row, xls) {
    xls.cell(this.exportValue(row), this.exportOptions);
};

// --------------------------------------------------------------------------

var JsonColumn = makeColumnType({
    type:"json",
    construct: function(collection, colspec) {
        this.valueProperty = colspec.valueProperty;
        // Does this JSON column delegate to another column for display?
        if("column" in colspec) {
            if(typeof(colspec.column.type) !== "string") {
                throw new Error("When using the column property for json columns, you must specify a column type");
            }
            var innerColspec = _.clone(colspec.column);
            innerColspec.fact = "_FAKEFACTVALUE";
            var column = makeColumn(collection, innerColspec);
            // Values need converting
            var valueConversion = function(v) { return (v === undefined) ? null : v; };
            // Dates need special handling
            if(colspec.column.type.indexOf("date") !== -1) {
                valueConversion = function(v) {
                    return v ? (new XDate(v, true)).toDate() : null;
                };
            } else if(column instanceof NumberColumn) {
                // Paranoid about numbers
                valueConversion = function(v) { return (typeof(v) !== "number") ? (v ? v*1 : null) : v; };
            }
            // Delegate this object to the column
            this.renderCell = function(row) {
                var obj = row[this.fact];
                return column.renderCell({_FAKEFACTVALUE:(obj ? valueConversion(obj[this.valueProperty]) : null)});
            };
            this.exportCell = function(row, xls) {
                var obj = row[this.fact];
                column.exportCell({_FAKEFACTVALUE:(obj ? valueConversion(obj[this.valueProperty]) : null)}, xls);
            };
            this.__defineGetter__("exportWidth", function() { return column.exportWidth; });
        }
    }
});

JsonColumn.prototype.prepare = function(dashboard) {
    if(!this.valueProperty) {
        this.valueProperty = dashboard.property("std:reporting:json_column:default_value_property");
    }
};

JsonColumn.prototype.renderCellInner = function(row) {
    var obj = row[this.fact];
    if(obj === null) {
        return '';
    } else {
        var value = obj[this.valueProperty];
        if((value === null) || (value === undefined)) {
            return '';
        } else {
            return _.escape(""+value);
        }
    }
};

JsonColumn.prototype.exportCell = function(row, xls) {
    var obj = row[this.fact];
    xls.cell((obj === null) ? null : obj[this.valueProperty]);
};

// --------------------------------------------------------------------------

var LookupColumn = makeColumnType({
    type:"lookup",
    construct: function(collection, colspec) {
        var lookup = colspec.lookup;
        switch(typeof(lookup)) {
            case "function":   this.lookup = lookup;                                break;
            case "object":     this.lookup = function(v) { return lookup[v]; };     break;
            default: throw new Error("Bad lookup passed to lookup column; must be function or object to use as dictionary");
        }
    }
});

LookupColumn.prototype.renderCellInner = function(row) {
    var value = this.lookup(row[this.fact], row);
    if((value === null) || (value === undefined)) {
        return '';
    } else {
        return _.escape(""+value);
    }
};

LookupColumn.prototype.exportCell = function(row, xls) {
    xls.cell(this.lookup(row[this.fact], row));
};
