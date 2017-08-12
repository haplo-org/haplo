/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Page Part object has properties:
//   name - API code style name
//   category - API code style name of category
//   sort - sort value for ordering parts within category
//   deferredRender(E, context, options)
P.FEATURE.pagePart = function(pagePart) {
    globalPageParts.add(pagePart);
};

// PREFER TO USE THIS FUNCTION LOCALLY ON PUBLICATION
// As for pagePart, except aliasOf:"name" instead of deferredRender()
// Note that options use aliased name, not original.
// Use to ising a part twice, with different options.
// To include in a category with potentially different sort order, use pagePartAddToCategory().
P.FEATURE.pagePartAlias = function(pagePartAlias) {
    globalPageParts.alias(pagePartAlias);
};

// PREFER TO USE THIS FUNCTION LOCALLY ON PUBLICATION
// Create page part, given a template name in calling plugin.
// As for partPart, except template:"tmpl" instead of deferredRender()
P.FEATURE.pagePartFromTemplate = function(pagePartTemplate) {
    globalPageParts.fromTemplate(pagePartTemplate);
};

// PREFER TO USE THIS FUNCTION LOCALLY ON PUBLICATION
// Add a part to a given category, optionally overriding sort.
// Properties: pagePart, category, sort
P.FEATURE.pagePartAddToCategory = function(add) {
    globalPageParts.addToCategory(add);
};

// Versions local to publication
P.Publication.prototype.pagePartAlias = function(pagePartAlias) {
    if(!this._pageParts) { this._pageParts = new PageParts(globalPageParts); }
    this._pageParts.alias(pagePartAlias);
};
P.Publication.prototype.pagePartFromTemplate = function(pagePartTemplate) {
    if(!this._pageParts) { this._pageParts = new PageParts(globalPageParts); }
    this._pageParts.fromTemplate(pagePartTemplate);
};
P.Publication.prototype.pagePartAddToCategory = function(add) {
    if(!this._pageParts) { this._pageParts = new PageParts(globalPageParts); }
    this._pageParts.addToCategory(add);
};

// --------------------------------------------------------------------------

var PageParts = function(parent) {
    this.parent = parent;
    this.parts = {}; // name -> Page Part object as registered with pagePart() function
    this.categories = {}; // category name -> [Page Parts] (sorted)
};

PageParts.prototype.add = function(pagePart) {
    if(typeof(pagePart.name) !== "string") { throw new Error("Page Part must have a name property"); }
    this.parts[pagePart.name] = pagePart;
    if(pagePart.category) {
        var categories = this.categories[pagePart.category];
        if(!categories) { this.categories[pagePart.category] = categories = []; }
        categories.push(pagePart);
    }
};

PageParts.prototype.alias = function(pagePartAlias) {
    var pp = this;
    var p = clonePagePartBasics(pagePartAlias);
    p.deferredRender = function(E, context, options) {
        return deferredRenderPagePart(context, pp.parts[pagePartAlias.aliasOf], pagePartAlias.name);
    };
    this.add(p);
};

PageParts.prototype.fromTemplate = function(pagePartTemplate) {
    var p = clonePagePartBasics(pagePartTemplate);
    p.deferredRender = function(E, context, options) {
        return context.publication.implementingPlugin.template(pagePartTemplate.template).deferredRender({
            E: E,
            context: context,
            options: options
        });
    };
    this.add(p);
};

var _addCount = 0;  // generating unique names
PageParts.prototype.addToCategory = function(add) {
    var pp = this;
    var pagePart = this.parts[add.pagePart] || {};
    var p = {
        name: '$add:'+(_addCount++)+':'+add.pagePart+':$->:'+add.category,
        category: add.category,
        sort: ('sort' in add) ? add.sort : pagePart.sort,
        deferredRender: function(E, context, options) {
            return deferredRenderPagePart(context, pp.parts[add.pagePart]);
        }
    };
    this.add(p);
};

PageParts.prototype._setup = function() {
    var pp = this;
    // Merge in parts and categories from parent
    if(this.parent) {
        pp.parts = _.extend({}, pp.parent.parts, pp.parts);
        var tc = pp.categories;
        _.each(this.parent.categories, function(a, k) {
            tc[k] = (tc[k]||[]).concat(a);
        });
    }
    // Sort each category ready for rendering
    // Avoids mutation during iteration
    _.keys(pp.categories).forEach(function(category) {
        pp.categories[category] = _.sortBy(pp.categories[category], 'sort');
    });
};

PageParts.prototype._getPart = function(name) {
    return this.parts[name];
};

PageParts.prototype._getCategory = function(category) {
    return this.categories[category];
};

// --------------------------------------------------------------------------

var globalPageParts = new PageParts();

P.setupPageParts = function() {
    globalPageParts._setup();
    _.each(P.allPublications, function(publication, value) {
        if(publication._pageParts) {
            publication._pageParts._setup();
        } else {
            publication._pageParts = globalPageParts;
        }
    });
};

// --------------------------------------------------------------------------

P.globalTemplateFunction("std:web-publisher:page-part:render", function(name) {
    var context = P.getRenderingContext();
    var pp = context.publication._pageParts;
    maybeRenderPagePartForTemplateFunction(context,this, pp._getPart(name));
});

P.globalTemplateFunction("std:web-publisher:page-part:render-category", function(category) {
    var context = P.getRenderingContext();
    var pp = context.publication._pageParts;
    var categoryParts = pp._getCategory(category);
    var fnthis = this;
    if(categoryParts) {
        categoryParts.forEach(function(pagePart) {
            maybeRenderPagePartForTemplateFunction(context, fnthis, pagePart);
        });
    }
});

// --------------------------------------------------------------------------

var deferredRenderPagePart = function(context, pagePart, nameForOptions) {
    if(pagePart) {
        if(!nameForOptions) { nameForOptions = pagePart.name; }
        var options = context._pagePartOptions[nameForOptions] ||
            context.publication._pagePartOptions[nameForOptions] ||
            {};
        return pagePart.deferredRender(context.$E, context, options);
    }
};

var maybeRenderPagePartForTemplateFunction = function(context, fnthis, pagePart) {
    var deferred = deferredRenderPagePart(context, pagePart);
    if(deferred) {
        fnthis.render(deferred);
    }
};

// --------------------------------------------------------------------------

var clonePagePartBasics = function(pagePart) {
    var p = {name:pagePart.name};
    if('category'   in pagePart) { p.category   = pagePart.category; }
    if('sort'       in pagePart) { p.sort       = pagePart.sort; }
    return p;
};
