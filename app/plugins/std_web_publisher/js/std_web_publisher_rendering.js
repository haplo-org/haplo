/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */



// --------------------------------------------------------------------------
// Rendering into the 'blocks' object passed into the layout

P.globalTemplateFunction("std:web-publisher:block", function(name) {
    var context = P.getRenderingContext();
    if(name in context._blocks) {
        // TODO: Maybe this should allow more than one render?
        throw new Error("block "+name+" has already been rendered");
    }
    context._blocks[name] = this.deferredRenderBlock();
});


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
    var context = P.getRenderingContext();
    this.render(P.template("object/link").deferredRender({
        href: context ? context.publication._urlPathForObject(object) : undefined,
        title: title ? title : object.title,
        block: this.deferredRenderBlock()
    }));
});

// --------------------------------------------------------------------------
// Search result rendering

P.globalTemplateFunction("std:web-publisher:widget:query:list:search-result", function(specification) {
    var publication = P.getRenderingContext().publication;
    var renderers = publication._searchResultsRenderers;
    var defaultRenderer = publication._defaultSearchResultRenderer;
    var fallbackRenderer = function(object) {
        return P.template("widget/query/list-search-result-item-fallback").deferredRender(object);
    };
    var context = P.getRenderingContext();
    this.render(P.template("widget/query/list-search-result").deferredRender({
        results: _.map(specification.results ? specification.results : specification.query.execute(),
                function(object) {
                    var r = renderers.get(object.firstType()) || defaultRenderer || fallbackRenderer;
                    return r(object, context);
                }
            )
    }));
});

// --------------------------------------------------------------------------
// Files

P.globalTemplateFunction("std:web-publisher:file:thumbnail", function(fileOrIdentifier) {
    if(fileOrIdentifier) {
        this.render(P.template("value/file/thumbnail").deferredRender(
            P.makeThumbnailViewForFile(P.getRenderingContext().publication, O.file(fileOrIdentifier))
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
// Replaceable templates

var replaceableTemplates = {
    // Default replaceable templates
    "std:web-publisher:error:internal": ["error/internal", P],
    "std:web-publisher:error:stop":     ["error/stop", P]
};

P.publisherReplaceableTemplate = function(code, templateName) {
    replaceableTemplates[code] = [templateName, P];
};

P.FEATURE.registerReplaceableTemplate = function(code, templateName) {
    if(code in replaceableTemplates) {
        throw new Error("Replaceable template already registered: "+code);
    }
    replaceableTemplates[code] = [templateName, this.$plugin];
};

P.Publication.prototype.replaceTemplate = function(code, templateName) {
    if(!(code in replaceableTemplates)) {
        throw new Error("Attempt to replace a replaceable template which has not been registered: "+code);
    }
    this._replacedTemplates[code] = [templateName, this.implementingPlugin];
};

P.Publication.prototype.getReplaceableTemplate = function(code) {
    var cached = this._cachedReplaceableTemplates;
    if(!cached) { cached = this._cachedReplaceableTemplates = {}; }
    if(code in cached) { return cached[code]; }
    var [templateName, plugin] = this._replacedTemplates[code] || replaceableTemplates[code] || [];
    if(!templateName) {
        throw new Error("Replaceable template not found: "+code);
    }
    var template = plugin.template(templateName);
    if($host.templateDebuggingEnabled) {
        template.addDebugComment("replaceable with "+code);
    }
    cached[code] = template;
    return template;
};

// For --turbo option in developer mode
P.__removeCachedTemplates = function() {
    _.each(P.allPublications, function(publication) {
        delete publication._cachedReplaceableTemplates;
    });
};

P.globalTemplateFunction("std:web-publisher:template", function(code) {
    var publication = P.getRenderingContext().publication;
    this.renderIncludedTemplate(publication.getReplaceableTemplate(code));
});
