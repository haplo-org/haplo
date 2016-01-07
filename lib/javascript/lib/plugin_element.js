/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Implements standard handling for Elements, with a nicer interface than the raw hooks.

(function() {

    // Create a place within O for all the private elements, so they get sealed.
    O.$private.pluginElement = {};

    // ----------------------------------------------------------------------------------------------------------------------
    // Interface for the Element renderer object

    var $PluginElementRenderer = O.$private.pluginElement.per = function(plugin, unqualifiedName, name, path, object, style, options) {
        this.$plugin = plugin;
        this.$unqualifiedName = unqualifiedName;
        this.name = name;
        this.path = path;
        this.object = object;
        this.style = style;
        this.$rawOptions = options;
    };
    _.extend($PluginElementRenderer.prototype, {
        // Render a template
        render: function(view, templateName) {
            var template, m;
            if(undefined === view || null === view) {
                view = {};  // use null view as caller didn't specify one
            }
            if(undefined === templateName || null === templateName) {
                templateName = this.$unqualifiedName;   // use element name for the plugin if caller didn't specify
            }
            template = this.$plugin.template(templateName);
            this.$title = (undefined !== view.title && null !== view.title) ? view.title : "";  // "" means no title
            this.$html = template.render(view);
        },
        // Render a set of links, using a standard template
        renderLinks: function(links, title) {
            this.render({
                elements: _.map(links, function(a) { return {href:a[0], label:a[1]}; }),
                title: title
            }, "std:_element_render_links");
        },
        // Produce the output
        $finalise: function(response) {
            // Set the hook response, if something was rendered.
            if(undefined !== this.$html) {
                response.title = this.$title;
                response.html = this.$html;
                response.stopChain();
            }
        }
    });
    $PluginElementRenderer.prototype.__defineGetter__("options", function() {
        if(undefined != this.$options) { return this.$options; }
        var o = {}; // Default to empty options if the given string was empty or the decoding fails
        if(this.$rawOptions !== '') {
            // Attempt to JSON decode the options
            try {
                o = JSON.parse(this.$rawOptions);
            } catch(e) {
                // Log to console, but otherwise ignore
                console.log("Couldn't decode options for Element "+this.name+", invalid JSON: ", this.$rawOptions);
            }
        }
        // Cache for later, and return now.
        this.$options = o;
        return o;
    });

    // ----------------------------------------------------------------------------------------------------------------------
    // Default implementations for the Element hooks

    var hElementDiscoverImpl = O.$private.pluginElement.edi = function(response) {
        _.each(this.$elements, function(info, name) {
            response.elements.push([name, info.description]);
        });
    };

    var hElementRenderImpl = O.$private.pluginElement.eri = function(response, name, path, object, style, options) {
        // Does this plugin implement this element?
        var info = this.$elements[name];
        if(undefined === info) { return; }
        var L = new $PluginElementRenderer(this, info.unqualifiedName, name, path, object, style, options);
        info.renderer.apply(this, [L]);
        L.$finalise(response);
    };

    // ----------------------------------------------------------------------------------------------------------------------
    // Element defining function

    $Plugin.prototype.element = function(name, description, renderer) {
        if(undefined == this.$elements) {
            // First Element to be defined. Make sure we're not overwriting existing handlers.
            if(undefined != this.hElementDiscover) {
                throw new Error("When using element(), the hElementDiscover hook must not be defined.");
            }
            if(undefined != this.hElementRender) {
                throw new Error("When using element(), the hElementRender hook must not be defined.");
            }
            // Setup plugin for default Element handling
            this.$elements = {};
            this.hElementDiscover = hElementDiscoverImpl;
            this.hElementRender = hElementRenderImpl;
        }
        // Ensure given name does not include the plugin yet, then generate the full name
        if(-1 !== name.indexOf(":")) {
            throw new Error("When using element(), the given name should not include a ':' character. The plugin name is automatically added as a prefix to the element name.");
        }
        var fullName = this.$pluginName + ":" + name;
        // Store info about this Element
        this.$elements[fullName] = {unqualifiedName:name, fullName:fullName, renderer:renderer, description:description};
    };

})();
