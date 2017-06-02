/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Private platform APIs
var Exchange = $Exchange;

// --------------------------------------------------------------------------

P.$webPublisherHandle = function(host, method, path) {
    if(method !== "GET") { throw new Error("Only GET requests expected for web publisher"); }
    var publication = publications[host.toLowerCase()] || publications[DEFAULT];
    if(!publication) { return null; }
    return P.renderingWithPublication(publication, function() {
        return publication._handleRequest(method, path);
    });
};

P.$generateRobotsTxt = function(host) {
    var publication = publications[host.toLowerCase()] || publications[DEFAULT];
    return publication ? publication._generateRobotsTxt() : null;
};

// --------------------------------------------------------------------------

var publications = {};

var DEFAULT = "$default$";

P.FEATURE = {
    DEFAULT: DEFAULT,
    register: function(name) {
        if(typeof(name) !== "string") {
            throw new Error("Name passed to P.webPublication.register() must be a hostname or P.webPublication.DEFAULT");
        }
        if(name in publications) {
            throw new Error(
                (name === DEFAULT) ? "Default publication already registered." : "Publication "+name+" already registered."
            );
        }
        var publication = new Publication(name, this.$plugin);
        publications[name] = publication;
        return publication;
    }
};
var Feature = function(plugin) { this.$plugin = plugin; };
Feature.prototype = P.FEATURE;

P.WIDGETS = {};
var Widgets = function(plugin) { this.$plugin = plugin; };
Widgets.prototype = P.WIDGETS;

P.provideFeature("std:web-publisher", function(plugin) {
    var feature = new Feature(plugin);
    feature.widget = new Widgets(plugin);
    plugin.webPublication = feature;
});

// --------------------------------------------------------------------------

var ACCEPTABLE_PATH = /^\/(|[a-z0-9\/\-]*[a-z0-9\-])\/?$/;

var checkHandlerArgs = function(path, handlerFunction) {
    if(!(path && path.match(ACCEPTABLE_PATH))) {
        throw new Error("Web published path is not acceptable: "+path);
    }
    if(typeof(handlerFunction) !== "function") {
        throw new Error("Web publisher handlers must be functions");
    }
};

// --------------------------------------------------------------------------

var Publication = function(name, plugin) {
    this.name = name;
    this._implementingPlugin = plugin;
    this._paths = [];
    this._objectTypeHandler = O.refdictHierarchical();
    this._searchResultsRenderers = O.refdictHierarchical(); // also this._defaultSearchResultRenderer
};

Publication.prototype.DEFAULT = {};

Publication.prototype.respondToExactPath = function(path, handlerFunction) {
    checkHandlerArgs(path, handlerFunction);
    this._paths.push({
        path: path,
        robotsTxtAllowPath: path,
        matches: function(t) { return t === path; },
        fn: handlerFunction
    });
};

Publication.prototype.respondToDirectory = function(path, handlerFunction) {
    checkHandlerArgs(path, handlerFunction);
    var pathPrefix = path+"/";
    this._paths.push({
        path: path,
        robotsTxtAllowPath: pathPrefix,
        matches: function(t) { return t.startsWith(pathPrefix); },
        fn: handlerFunction
    });
};

Publication.prototype.respondWithObject = function(path, types, handlerFunction) {
    checkHandlerArgs(path, handlerFunction);
    var allowedTypes = O.refdictHierarchical();
    var pathPrefix = path+"/";
    var handler = {
        path: path,
        robotsTxtAllowPath: pathPrefix,
        matches: function(t) { return t.startsWith(pathPrefix); },
        fn: function(E) {
            var ref, pe = E.request.extraPathElements;
            if(!(pe.length && (ref = O.ref(pe[0])))) {
                return null;
            }
            if(!O.currentUser.canRead(ref)) {
                console.log("Web publisher: user not allowed to read", ref);
                return null;    // 404 if user can't read object
            }
            var object = ref.load();
            // Check object is correct type, and 404 if not
            if(!allowedTypes.get(object.firstType())) {
                console.log("Web publisher: object has wrong type for this path", object);
                return null;
            }
            return handlerFunction(E, object);
        },
        urlForObject: function(object) {
            return path+"/"+object.ref+"/"+object.title.toLowerCase().replace(/[^a-z0-9]+/g,'-');
        }
    };
    var objectTypeHandler = this._objectTypeHandler;
    types.forEach(function(type) {
        allowedTypes.set(type, true); // for checking
        objectTypeHandler.set(type, handler);   // for lookups by object type
    });
    this._paths.push(handler);
};

Publication.prototype.searchResultRendererForTypes = function(types, renderer) {
    if(types === this.DEFAULT) {
        this._defaultSearchResultRenderer = renderer;
    } else {
        var renderers = this._searchResultsRenderers;
        _.each(types, function(type) {
            renderers.set(type, renderer);
        });
    }
};

// --------------------------------------------------------------------------

Publication.prototype._handleRequest = function(method, path) {
    // Find handler from paths this publication responds to:
    var handler;
    for(var l = 0; l < this._paths.length; ++l) {
        var h = this._paths[l];
        if(h.matches(path)) {
            handler = h;
            break;
        }
    }
    if(!handler) { return null; }
    // Set up exchange and call handler
    var pathElements = path.substring(handler.path.length+1).split('/');
    var E = new Exchange(this._implementingPlugin, handler.path, method, path, pathElements);
    handler.fn(E);
    if(!E.response.body) {
        return null;    // 404
    }
    E.response.headers["Server"] = "Haplo Web Publisher";
    return E.response;
};

Publication.prototype._urlPathForObject = function(object) {
    var handler = this._objectTypeHandler.get(object.firstType());
    if(handler) {
        return handler.urlForObject(object);
    }
};

Publication.prototype._generateRobotsTxt = function() {
    var lines = ["User-agent: *"];
    for(var l = 0; l < this._paths.length; ++l) {
        var allow = this._paths[l].robotsTxtAllowPath;
        if(allow) {
            lines.push("Allow: "+allow);
        }
    }
    lines.push("Disallow: /", "");  // must be last for maximum compatibility
    return lines.join("\n");
};
