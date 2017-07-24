/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// --------------------------------------------------------------------------
// Generic platform styling

P.globalTemplateFunction("std:web-publisher:platform-style-tag", function() {
    this.render(P.template("platform-style-tag").deferredRender({staticDirectoryUrl: P.staticDirectoryUrl}));
});

// --------------------------------------------------------------------------
// Links to objects

// If there's no page representing this object in the publication, an unlinked title will be rendered.
// title argument is optional, to allow links with text other than the object title to be generated.
// If an anonymous block is given, it's rendered instead of the title.
P.globalTemplateFunction("std:web-publisher:object:link", function(object, title) {
    this.render(P.template("object/link").deferredRender({
        href: currentPublication ? currentPublication._urlPathForObject(object) : undefined,
        title: title ? title : object.title,
        block: this.deferredRenderBlock()
    }));
});

// --------------------------------------------------------------------------
// Search result rendering

P.globalTemplateFunction("std:web-publisher:widget:query:list:search-result", function(specification) {
    var renderers = currentPublication._searchResultsRenderers;
    var defaultRenderer = currentPublication._defaultSearchResultRenderer;
    var fallbackRenderer = function(object) {
        return P.template("widget/query/list-search-result-item-fallback").deferredRender(object);
    };
    this.render(P.template("widget/query/list-search-result").deferredRender({
        results: _.map(specification.results ? specification.results : specification.query.execute(),
                function(object) {
                    var r = renderers.get(object.firstType()) || defaultRenderer || fallbackRenderer;
                    return r(object);
                }
            )
    }));
});

// --------------------------------------------------------------------------
// Files

P.globalTemplateFunction("std:web-publisher:file:thumbnail", function(fileOrIdentifier) {
    if(fileOrIdentifier) {
        this.render(P.template("value/file/thumbnail").deferredRender(
            P.makeThumbnailViewForFile(currentPublication, O.file(fileOrIdentifier))
        ));
    }
});

// --------------------------------------------------------------------------
// Rendering helper fns

P.globalTemplateFunction("std:web-publisher:utils:title:name", function(object) {
    this.assertContext("TEXT");
    var title = object.firstTitle();
    if(O.typecode(title) === O.T_TEXT_PERSON_NAME) {
        var fields = title.toFields();
        return fields.last + ", " + fields.first;
    } else {
        return title.toString();
    }
});

// --------------------------------------------------------------------------

// Global variable to keep track of current Publisher
var currentPublication;
P.renderingWithPublication = function(publication, f) {
    currentPublication = publication;
    try {
        return f();
    } finally {
        currentPublication = undefined;
    }
};

P.withCurrentPublication = function(fn) {
    if(!currentPublication) { throw new Error("Expected a publication to be rendering"); }
    return fn(currentPublication);
};

// --------------------------------------------------------------------------

// TODO: Better sevice, better name? Only works when rendering a public page
P.implementService("std:web-publisher:published-url-for-object", function(object) {
    return currentPublication ? currentPublication._urlPathForObject(object) : null;
});

// --------------------------------------------------------------------------

// Platform support
P.$renderObjectValue = function(object) {
    var href;
    if(currentPublication) {
        href = currentPublication._urlPathForObject(object);
    }
    return P.template("object/link").render({
        href: href,
        title: object.title
    });
};

P.$isRenderingForWebPublisher = function() {
    return !!currentPublication;
};
