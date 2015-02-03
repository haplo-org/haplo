/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// std_action_panel implementation, loaded into shared runtime

(function() {

    O.$private.$createActionPanelPluginInRuntime = function(std_action_panel) {
        std_action_panel.hElementDiscover = hElementDiscoverImpl;
        std_action_panel.hElementRender = hElementRenderImpl;
        std_action_panel.$priorityDecode = priorityDecodeImpl;
        std_action_panel.$renderFail = renderFailImpl;
    };

    var DEFAULT_PRIORITIES = {
        "top":     10,
        "default": 100,
        "action":  200,
        "bottom":  1000
    };

    var priorityDecodeImpl = function(value) {
        var p;
        switch(typeof(value)) {
            case "number":
                p = value;
                break;
            case "string":
                p = this.$priorityLookup[value];
                if(!p) {
                    throw new Error("Unknown priority '"+value+"': std:action_panel_priorities service should define it.");
                }
                break;
            default:
                throw new Error("Bad priority: "+value);
        }
        return p;
    };

    // -----------------------------------------------------------------------------------------------------

    var renderFailImpl = function(response, message) {
        response.title = "";
        response.html = this.template("std:ui:notice").render({message: message});
        response.stopChain();
    };

    // -----------------------------------------------------------------------------------------------------

    var hElementDiscoverImpl = function(response) {
        response.elements.push(["std:action_panel", "Standard Action Panel user interface"]);
    };

    // -----------------------------------------------------------------------------------------------------

    var STYLE_TO_TEMPLATE_NAME = {
        DEFAULT:"std:ui:panel",
        links:  "std:ui:panel_links",
        tiles:  "std:ui:panel_tiles",
        menu:   "std:ui:panel_menu"
    };

    var hElementRenderImpl = function(response, name, path, object, style, options) {
        if(name !== "std:action_panel") { return; }

        // Build priority lookups?
        if(!this.$priorityLookup) {
            this.$priorityLookup = _.extend({}, DEFAULT_PRIORITIES);
            if(O.serviceImplemented("std:action_panel_priorities")) {
                O.service("std:action_panel_priorities", this.$priorityLookup);
            }
        }

        // Decode options
        var optionsDecoded = options ? JSON.parse(options) : {};
        // Check options
        if(!("panel" in optionsDecoded)) {
            return this.$renderFail(response, "No panel specified in element options");
        }
        var elementTitle = optionsDecoded.title || "";
        var panelStyle = optionsDecoded.style;
        // Check something implements the renderer
        var serviceName = "std:action_panel:"+optionsDecoded.panel;
        if(!O.serviceImplemented(serviceName)) {
            return this.$renderFail(response, "Actions not available");
        }
        // Set up the default builder, which is used as a gateway to builders for other panels
        var builders = {};
        var defaultBuilder = new ActionPanelBuilder(this, builders, optionsDecoded.highlight);
        builders[this.$priorityDecode("default")] = defaultBuilder;
        // Ask other plugins to add the entries to the action panel, along with the context in which the panel is being displayed
        var display = {
            path: path,
            object: object,
            style: style,
            testingButtonLink: !!(optionsDecoded.buttonLink),
            options: optionsDecoded
        };
        O.service(serviceName, display, defaultBuilder);
        // Special case for when the panel style is a link to another page, if the action panel has entries
        if(optionsDecoded.buttonLink) {
            var shouldDisplay = false;
            _.each(builders, function(builder, key) {
                if(builder._shouldBeRendered()) { shouldDisplay = true; }
            });
            if(shouldDisplay) {
                response.title = '';
                response.html = this.template("std:ui:panel").render({
                    highlight: optionsDecoded.highlight,
                    elements: [{label:elementTitle, href:optionsDecoded.buttonLink}]
                });
            }
        } else {
            // Render panels in order
            var template = this.template(STYLE_TO_TEMPLATE_NAME[panelStyle] || STYLE_TO_TEMPLATE_NAME.DEFAULT);
            var renderedPanels = [];
            _.each(_.keys(builders).sort(), function(key) {
                var builder = builders[key];
                if(builder._shouldBeRendered()) {
                    renderedPanels.push(template.render(builder.$view));
                }
            });
            if(renderedPanels.length > 0) {
                response.title = elementTitle;
                response.html = renderedPanels.join('');
            }
        }
        response.stopChain();
    };

    // -----------------------------------------------------------------------------------------------------

    // Implementation of action panel builder

    var ActionPanelBuilder = function(plugin, builders, defaultHighlight) {
        this.$plugin = plugin;
        this.$builders = builders;
        this.$elements = [];
        this.$defaultHighlight = defaultHighlight;
        this.$view = {elements:this.$elements, highlight:defaultHighlight};
    };
    _.extend(ActionPanelBuilder.prototype, {
        // Get another builder, by priority
        panel: function(priority) {
            var p = this.$plugin.$priorityDecode(priority);
            var otherBuilder = this.$builders[p];
            if(!otherBuilder) {
                this.$builders[p] = otherBuilder = new ActionPanelBuilder(this.$plugin, this.$builders, this.$defaultHighlight);
            }
            return otherBuilder;
        },
        // ----------------------------------------------------------
        // Panel options
        spaceAbove: function() {
            this.$view.spaceAbove = true;
            return this;
        },
        title: function(title) {
            this.$view.title = title;
            return this;
        },
        highlight: function(highlight) {
            this.$view.highlight = highlight;
            return this;
        },
        // ----------------------------------------------------------
        // Create various entries, first arguement is always priority
        element: function(priority, element) {
            this._pushElement(priority, element);
            return this;
        },
        status: function(priority, text) {
            this._pushElement(priority, {title:"Status", label:text});
            return this;
        },
        link: function(priority, href, label, indicator) {
            var element = {label:label};
            if(href) {
                element.href = href;
            } else {
                element.disabled = true;
            }
            if(indicator) { element.indicator = indicator; }
            this._pushElement(priority, element);
            return this;
        },
        relatedInfo: function(priority, href, label, heading) {
            if(href) {
                this._pushElement(priority, {heading:heading, innerLink:{href:href, label:label}, light:true});
            } else {
                this._pushElement(priority, {heading:heading, innerText:label, light:true});
            }
            return this;
        },
        // ----------------------------------------------------------
        // Should this be rendered?
        _shouldBeRendered: function() {
            return (this.$elements.length > 0);
        },
        // Push entry given priority
        _pushElement: function(priority, element) {
            var p = this.$plugin.$priorityDecode(priority);
            element.priority = p;
            var elements = this.$elements;
            var i = elements.length - 1;
            for(; i >= 0; --i) {
                if(elements[i].priority <= p) {
                    break;
                }
            }
            elements.splice((i < 0) ? 0 : i+1, 0, element);
        },
    });
    ActionPanelBuilder.prototype.__defineGetter__("empty", function() {
        return (this.$elements.length === 0);
    });

})();
