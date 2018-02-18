/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// std_action_panel implementation, loaded into shared runtime

(function() {

    O.$private.$createActionPanelPluginInRuntime = function(std_action_panel) {
        std_action_panel.hElementDiscover = hElementDiscoverImpl;
        std_action_panel.hElementRender = hElementRenderImpl;
        std_action_panel.$renderFail = renderFailImpl;
        std_action_panel.implementService("std_action_panel:build_panel", buildPanelService);
        return std_action_panel;
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

    // Service needs to set up defaults for the display object, will modify the object passed in
    var buildPanelService = function(panelName, display) {
        if(!display)                        { display = {}; }
        if(!("options" in display))         { display.options = {}; }
        if(!("panel" in display.options))   { display.options.panel = panelName; }
        return buildPanel.call(this, panelName, display);
    };

    var buildPanel = function(panelName, display) {
        // Build priority lookups?
        if(!this.$priorityLookup) {
            this.$priorityLookup = _.extend({}, O.$private.$panelBuilderDefaultPriorities);
            if(O.serviceImplemented("std:action_panel_priorities")) {
                O.service("std:action_panel_priorities", this.$priorityLookup);
            }
            this.$priorityDecode = makePriorityDecode(this.$priorityLookup);
        }
        // Set up the default builder, which is used as a gateway to builders for other panels
        var defaultBuilder = O.ui.panel({
            defaultHighlight: display.options.highlight,
            style: display.style,
            priorityDecode: this.$priorityDecode
        });
        // Ask other plugins to add the entries to the action panel, passing the context in which the panel is being displayed
        var serviceNames = [
            "std:action_panel:"+panelName
        ];
        // Extra service if the panel has a category
        if("category" in display.options) {
            serviceNames.push("std:action_panel:category:"+display.options.category);
        }
        serviceNames.forEach(function(serviceName) {
            if(O.serviceImplemented(serviceName)) { 
                O.service(serviceName, display, defaultBuilder);
            }
        });
        return defaultBuilder;
    };

    var hElementRenderImpl = function(response, name, path, object, style, options) {
        if(name !== "std:action_panel") { return; }

        var optionsDecoded = options ? JSON.parse(options) : {};
        if(!("panel" in optionsDecoded)) {
            return this.$renderFail(response, "No panel specified in element options");
        }
        var elementTitle = optionsDecoded.title || "";

        var display = {
            path: path,
            object: object,
            testingButtonLink: !!(optionsDecoded.buttonLink),
            options: optionsDecoded
        };
        if("style" in optionsDecoded) { display.style = optionsDecoded.style; }

        var defaultBuilder = buildPanel.call(this, optionsDecoded.panel, display);

        // Special case for when the panel style is a link to another page, if the action panel has entries
        if(optionsDecoded.buttonLink) {
            if(defaultBuilder.anyBuilderShouldBeRendered()) {
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

})();
