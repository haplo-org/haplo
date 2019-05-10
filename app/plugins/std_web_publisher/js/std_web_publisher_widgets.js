/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Private APIs
var GetterDictionaryBase = $GetterDictionaryBase;

// --------------------------------------------------------------------------

P.WIDGETS.object = function(object) {
    return new ObjectWidget(object, this.$plugin);
};

var ObjectWidget = function(object, plugin) {
    this.object = object;
    this._plugin = plugin;
};

// Public interface for setup
ObjectWidget.prototype.withoutAttributes = function(attrs) {
    return this._setAttributeList("$withoutAttributes", attrs);
};
ObjectWidget.prototype.onlyAttributes = function(attrs) {
    return this._setAttributeList("$onlyAttributes", attrs);
};

// Public interface for rendering
ObjectWidget.prototype.__defineGetter__("attributes", function() {
    if(this.$attributes) { return this.$attributes; }
    var options = {};
    if("$withoutAttributes" in this)    { options.without   = this.$withoutAttributes; }
    if("$onlyAttributes" in this)       { options.only      = this.$onlyAttributes; }
    this.$attributes = $StdWebPublisher.generateObjectWidgetAttributes(this.object, JSON.stringify(options));
    return this.$attributes;
});
ObjectWidget.prototype.__defineGetter__("first", function() {
    if(this.$first) { return this.$first; }
    var object = this.object,
        localSchema = $registry.pluginSchema[this._plugin.pluginName],
        attr = (localSchema ? localSchema.attribute : SCHEMA.ATTR) || SCHEMA.ATTR;
    this.$first = new GetterDictionaryBase(function(name, suffix) {
        return $StdWebPublisher.deferredRenderForFirstValue(object, attr[name]);
    }, null);
    return this.$first;
});
ObjectWidget.prototype.__defineGetter__("every", function() {
    if(this.$every) { return this.$every; }
    var object = this.object,
        localSchema = $registry.pluginSchema[this._plugin.pluginName],
        attr = (localSchema ? localSchema.attribute : SCHEMA.ATTR) || SCHEMA.ATTR;
    this.$every = new GetterDictionaryBase(function(name, suffix) {
        return $StdWebPublisher.deferredRendersForEveryValue(object, attr[name]);
    }, null);
    return this.$every;
});
// As various templates
ObjectWidget.prototype.__defineGetter__("asTable", function() {
    return P.template("object/table").deferredRender(this);
});
// Utility properties
ObjectWidget.prototype.__defineGetter__("title", function() {
    return this.object.title;
});

// Implementation
ObjectWidget.prototype._setAttributeList = function(list, types) {
    this[list] = _.map(_.compact(_.flatten([this[list], types])), function(a) { return 1*a; });
    return this;
};

// --------------------------------------------------------------------------

const SEARCH_PAGE_SIZE = 20;

P.publisherReplaceableTemplate("std:web-publisher:widget:search:form",      "widget/search/form");
P.publisherReplaceableTemplate("std:web-publisher:widget:search:results",   "widget/search/results");

P.WIDGETS.search = function(E, spec) {
    return new SearchWidget(E, spec);
};

// There are two levels of protection against SQL injection below this, but the error when
// someone tries an 'interesting' sort order raises a health event, which is annoying.
const ALLOWED_SEARCH_ORDERS = {
    date:       "date",
    date_asc:   "date_asc",
    relevance:  "relevance",
    title:      "title",
    title_desc: "title_desc"
};

var SearchWidget = function(E, spec) {
    this.E = E;
    this.spec = spec || {};
    this.renderingContext = P.getRenderingContext();
    var params = E.request.parameters;
    var q = params.q;
    if((!spec.formOnly && q && q.match(/\S/)) || spec.alwaysSearch) {
        this.query = q;
        this._storeQuery = q ? O.query(q) : O.query();
        if(spec.modifyQuery) {
            spec.modifyQuery(this._storeQuery);
        }
        this._sort = ALLOWED_SEARCH_ORDERS[params.sort] || (spec.hideRelevanceSort ? "date" : "relevance");
        this._results = this._storeQuery.sortBy(this._sort).setSparseResults(true).execute();
        this._pageSize = spec.pageSize || SEARCH_PAGE_SIZE;
        this._start = 0;
        this._end = (this._results.length > this._pageSize) ? this._pageSize : this._results.length;
        if(params.page) {
            this._pageNumber = parseInt(params.page, 10);
            this._start = (this._pageNumber - 1) * this._pageSize;
            this._end = this._start + this._pageSize;
            if(this._end > this._results.length) { this._end = this._results.length; }
        }
        // Load page of objects in one go
        this._results.ensureRangeLoaded(this._start, this._end);
        // Store page of objects
        this._page = [];
        for(var i = this._start; i < this._end; ++i) {
            this._page.push(this._results[i]);
        }
        // Make parameters for rendering links
        this._params = {
            q: this.query,
            page: this._pageNumber || 1,
            sort: this._sort
        };
        if(this._start !== 0) {
            this._prevPage = _.extend({}, this._params, {page: this._params.page - 1});
        }
        if(this._end < this._results.length) {
            this._nextPage = _.extend({}, this._params, {page: this._params.page + 1});
        }
        this._displayResults = true;
    }
};

// Public interface for rendering
SearchWidget.prototype.__defineGetter__("ui", function() {
    return P.template("widget/search/ui").deferredRender(this);
});
SearchWidget.prototype.__defineGetter__("form", function() {
    return this.renderingContext.publication.getReplaceableTemplate("std:web-publisher:widget:search:form").deferredRender(this);
});
SearchWidget.prototype.__defineGetter__("results", function() {
    return this.renderingContext.publication.getReplaceableTemplate("std:web-publisher:widget:search:results").deferredRender(this);
});

// Implementation
SearchWidget.prototype.__defineGetter__("_resultsCount", function() {
    // toString() avoids JS falsey comparison with 0
    return this._results ? this._results.length.toString() : undefined;
});
SearchWidget.prototype.__defineGetter__("_resultsRender", function() {
    return {
        results: this._page
    };
});
P.globalTemplateFunction("std:web-publisher:search:__sort__", function(widget, by, label) {
    var params = _.extend({}, widget._params, {sort:by});
    this.render(P.template("widget/search/sort-option").deferredRender({
        params: params,
        label: label,
        selected: widget._sort === by
    }));
});

// --------------------------------------------------------------------------
