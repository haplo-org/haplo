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
        std_action_panel.$renderFail = renderFailImpl;
    };

    var makePriorityDecode = function(priorityLookup) {
        return function(value) {
            var p;
            switch(typeof(value)) {
                case "number":
                    p = value;
                    break;
                case "string":
                    p = priorityLookup[value];
                    if(!p) {
                        throw new Error("Unknown priority '"+value+"': std:action_panel_priorities service should define it.");
                    }
                    break;
                default:
                    throw new Error("Bad priority: "+value);
            }
            return p;
        };
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

    var hElementRenderImpl = function(response, name, path, object, style, options) {
        if(name !== "std:action_panel") { return; }

        // Build priority lookups?
        if(!this.$priorityLookup) {
            this.$priorityLookup = _.extend({}, O.$private.$panelBuilderDefaultPriorities);
            if(O.serviceImplemented("std:action_panel_priorities")) {
                O.service("std:action_panel_priorities", this.$priorityLookup);
            }
            this.$priorityDecode = makePriorityDecode(this.$priorityLookup);
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
        var defaultBuilder = O.ui.panel({
            defaultHighlight: optionsDecoded.highlight,
            style: panelStyle,
            priorityDecode: this.$priorityDecode
        });
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
            _.each(defaultBuilder.__builders, function(builder, key) {
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
            var html = defaultBuilder.render();
            if(html.length > 0) {
                response.title = elementTitle;
                response.html = html;
            }
        }
        response.stopChain();
    };

    // -----------------------------------------------------------------------------------------------------

    // Implementation of action panel builder


})();
