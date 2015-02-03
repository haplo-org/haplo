/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// TODO: Write ruby_templates.js interface code automatically from the descriptions in the Ruby code.

(function() {

    var rubyTemplates = O.$private.rubyTemplates = {};

    // Create a standard template object
    var template = function(name, render, kind) {
        // Extend function to meet Template interface
        render.render = render;
        render.name = name;
        render.kind = (kind || "html");
        // Store for later combination with other templates when the runtime is initialised
        rubyTemplates[name] = render;
    };

    var SafeString = Handlebars.SafeString;

    // Argument extraction functions
    var v = function(view, key) {
        var value = view[key];
        if(value === undefined || value === null) { return null; }
        return value;
    };
    var vString = function(view, key) {
        var value = view[key];
        if(!value) { return null; }
        return value.toString();
    };
    var vRef = function(view, key) {
        var value = view[key];
        if(value === undefined || value === null) { return null; }
        return (value instanceof $Ref) ? value : null;
    };
    var vObj = function(view, key) {
        var value = view[key];
        if(value === undefined || value === null) { return null; }
        if(value instanceof $Ref) { value = value.load(); }
        return value.$kobject;
    };
    var vBool = function(view, key, defaultValue) {
        var value = view[key];
        if(value === undefined || value === null) { return defaultValue; }
        return !!(value);
    };

    // Safe helper argument conversion functions
    var aObj = function(value) {
        if(value === undefined || value === null) { return null; }
        if(value instanceof $Ref) { value = value.load(); }
        return value.$kobject;
    };

    // Template definitions (some of which have Handlebars helper equivalents)
    template("std:form_csrf_token", function(view) {
        return $host.renderRTemplate("form_csrf_token");
    });
    Handlebars.registerHelper("std:form_csrf_token", function() {
        return new SafeString($host.renderRTemplate("form_csrf_token"));
    });
    // --------
    template("std:object", function(view) {
        return $host.renderRTemplate("object", vObj(view,"object"), v(view,"style"));
    });
    Handlebars.registerHelper("std:object", function(object, style) {
        return new SafeString($host.renderRTemplate("object", aObj(object), (typeof(style) === "string") ? style : "generic"));
    });
    // --------
    template("std:link_to_object", function(view) {
        return $host.renderRTemplate("link_to_object", vObj(view,"object"));
    });
    Handlebars.registerHelper("std:link_to_object", function(object) {
        return new SafeString($host.renderRTemplate("link_to_object", aObj(object)));
    });
    // --------
    template("std:link_to_object_descriptive", function(view) {
        return $host.renderRTemplate("link_to_object_descriptive", vObj(view,"object"));
    });
    Handlebars.registerHelper("std:link_to_object_descriptive", function(object) {
        return new SafeString($host.renderRTemplate("link_to_object_descriptive", aObj(object)));
    });
    // --------
    template("std:new_object_editor", function(view) {
        return $host.renderRTemplate("new_object_editor",
            vObj(view,"templateObject"), v(view,"successRedirect"));
    });
    // --------
    template("std:search_results", function(view) {
        return $host.renderRTemplate("search_results",
            vString(view,"query"), vString(view,"searchWithin"), vString(view,"sort"),
            vBool(view,"showResultCount",false),
            vBool(view,"showSearchWithinLink",true), vBool(view,"miniDisplay",false));
    });
    // --------
    template("std:element", function(view) {
        return $host.renderRTemplate("element", vString(view,"name"), vString(view,"options"), vObj(view,"object"));
    });
    Handlebars.registerHelper("std:element", function(name, options, object, path) {
        if(typeof(name) !== "string") { return ''; }
        return new SafeString($host.renderRTemplate("element",
            name,
            ((typeof(options) === "string") && (options.length > 0)) ? options : null,
            aObj(object)
        ));
    });
    // --------
    template("std:icon:type", function(view) {
        return $host.renderRTemplate("icon_type", vRef(view,"ref"), vString(view,"size"));
    });
    Handlebars.registerHelper("std:icon:type", function(typeRef, size) {
        return new SafeString($host.renderRTemplate("icon_type", vRef(arguments,0), vString(arguments,1)));
    });
    // *
    template("std:icon:object", function(view) {
        return $host.renderRTemplate("icon_object", vObj(view,"object"), vString(view,"size"));
    });
    Handlebars.registerHelper("std:icon:object", function(object, size) {
        return new SafeString($host.renderRTemplate("icon_object", vObj(arguments,0), vString(arguments,1)));
    });
    // *
    template("std:icon:description", function(view) {
        return $host.renderRTemplate("icon_description", vString(view,"description"), vString(view,"size"));
    });
    Handlebars.registerHelper("std:icon:description", function(description, size) {
        return new SafeString($host.renderRTemplate("icon_description", vString(arguments,0), vString(arguments,1)));
    });

    // Misc stuff
    template("std:treesource", function(view) {
        return $host.renderRTemplate("treesource", v(view,"root"), v(view,"type"));
    });
    template("std:render_doc_as_html", function(view) {
        return $host.renderRTemplate("render_doc_as_html", v(view,"text"));
    });

    // Resource 'pseudo-templates'
    template("std:resource:plugin_adaptor", function(view) {
        return $host.renderRTemplate("_client_side_resource", "plugin_adaptor");
    });
    template("std:resource:tree", function(view) {
        return $host.renderRTemplate("_client_side_resource", "tree");
    });

    // Resource inclusion template
    var RESOURCE_KINDS = ["css","javascript"];
    template("std:resources", function(view) {
        _.each(RESOURCE_KINDS, function(kind) {
            var r = v(view, kind);
            if(r !== null) {
                if(_.isArray(r)) {
                    _.each(r, function(e) { $host.renderRTemplate("_client_side_resource_path", kind, e); });
                } else {
                    $host.renderRTemplate("_client_side_resource_path", kind, r);
                }
            }
        });
        return '';
    });

    // Resource HTML tags template
    template("std:resources_html", function(view) {
       return $host.renderRTemplate("resources_html");
    });

})();
