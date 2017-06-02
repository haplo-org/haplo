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

P.WIDGETS.search = function(E) {
    return new SearchWidget(E);
};

var SearchWidget = function(E) {
    this.E = E;
    var q = E.request.parameters.q;
    if(q && q.match(/\S/)) {
        this.query = q;
        this._storeQuery = O.query(q);
        this._results = this._storeQuery.sortByRelevance().execute();
    }
};

// Public interface for rendering
SearchWidget.prototype.__defineGetter__("ui", function() {
    return P.template("widget/search/ui").deferredRender(this);
});
SearchWidget.prototype.__defineGetter__("form", function() {
    return P.template("widget/search/form").deferredRender(this);
});
SearchWidget.prototype.__defineGetter__("results", function() {
    return P.template("widget/search/results").deferredRender(this);
});

// Implementation
SearchWidget.prototype.__defineGetter__("_resultsCount", function() {
    // toString() avoids JS falsey comparison with 0
    return this._results ? this._results.length.toString() : undefined;
});
SearchWidget.prototype.__defineGetter__("_resultsRender", function() {
    return {
        results: this._results
    };
});

// --------------------------------------------------------------------------
