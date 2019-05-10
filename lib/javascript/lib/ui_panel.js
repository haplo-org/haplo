/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function() {

    O.ui.panel = function(options) {
        return new PanelBuilder(undefined, options);
    };

    // ----------------------------------------------------------------------

    var PanelBuilder = O.$private.$PanelBuilder = function(root, options) {
        if(root) {
            this.$root = root;
        } else {
            this.$root = this;
            this.$builders = {};
            this.$options = options || {};
            this.$builders[(this.$options.priorityDecode || defaultPriorityDecode)("default")] = this;
        }
        this.$elements = [];
        this.$view = {elements:this.$elements, highlight:this.$root.$options.defaultHighlight};
    };
    PanelBuilder.prototype = {
        // Get another builder, by priority
        panel: function(priority) {
            var p = (this.$root.$options.priorityDecode || defaultPriorityDecode)(priority);
            var otherBuilder = this.$root.$builders[p];
            if(!otherBuilder) {
                this.$root.$builders[p] = otherBuilder = new PanelBuilder(this.$root);
            }
            return otherBuilder;
        },
        // ------------------------------------------------------------------
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
        style: function(style) {
            this.$style = style;
            return this;
        },
        // ------------------------------------------------------------------
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
        // ------------------------------------------------------------------
        hidePanel: function() {
            this.$hidePanel = true;
            return this;
        },
        hideAllPanels: function() {
            this.$root.$hideAllPanels = true;
            return this;
        },
        // ------------------------------------------------------------------
        render: function() {
            if(this.$root.$hideAllPanels) { return ""; }

            var rootStyle = this.$style || this.$root.$options.style;

            var builders = this.$root.$builders;

            // Only use columns if there's a builder which has more than two entries
            // and there are enough menus to make it worthwhile
            var shouldSetupColumns = false;
            if(rootStyle === "menu") {
                var maxEntries = 0, numPanels = 0;
                _.each(builders, function(builder) {
                    var numElements = builder.$elements.length;
                    if(numElements > 0) {
                        numPanels++;
                        if(maxEntries < numElements) {
                            maxEntries = numElements;
                        }
                    }
                });
                if((numPanels > 2) && (maxEntries > 2)) {
                    shouldSetupColumns = true;
                }
            }

            // Render panels
            var renderedPanels = [];
            _.each(_.keys(builders).sort(compareNumbers), function(key) {
                var builder = builders[key];
                if(builder.shouldBeRendered()) {
                    if(shouldSetupColumns) { builder._setupForColumns(); }
                    renderedPanels.push(builder._renderThisPanel());
                }
            });

            return renderedPanels.join('');
        },
        _renderThisPanel: function() {
            var style = this.$style || this.$root.$options.style;
            var template = $registry.standardTemplates[
                STYLE_TO_TEMPLATE_NAME[style] ||
                STYLE_TO_TEMPLATE_NAME.DEFAULT];
            return template.render(this.$view);
        },
        deferredRender: function() {
            var panel = this;
            return new $GenericDeferredRender(function() {
                return panel.render();
            });
        },
        _setupForColumns: function() {
            // Menus have two columns, requires some logic to set the column break
            var len = this.$elements.length;
            if(len > 1) {
                this.$elements[Math.ceil(len/2)].$colbreak = true;
            }
        },
        // ------------------------------------------------------------------
        // Should this be rendered?
        shouldBeRendered: function() {
            return (this.$elements.length > 0) && !(this.$hidePanel);
        },
        anyBuilderShouldBeRendered: function() {
            var shouldRender = false;
            _.each(this.$builders, function(builder, key) {
                if(builder.shouldBeRendered()) { shouldRender = true; }
            });
            return shouldRender;
        },
        // ------------------------------------------------------------------
        // Push entry given priority
        _pushElement: function(priority, element) {
            var p = (this.$root.$options.priorityDecode || defaultPriorityDecode)(priority);
            element.priority = 1*p;
            var elements = this.$elements;
            var i = elements.length - 1;
            for(; i >= 0; --i) {
                if(elements[i].priority <= p) {
                    break;
                }
            }
            elements.splice((i < 0) ? 0 : i+1, 0, element);
        }
    };
    PanelBuilder.prototype.__defineGetter__("empty", function() {
        return (this.$elements.length === 0);
    });

    var STYLE_TO_TEMPLATE_NAME = O.$private.$panelBuilderStyleToTemplateName = {
        DEFAULT:    "std:ui:panel",
        special:    "std:ui:panel_special",
        links:      "std:ui:panel_links",
        tiles:      "std:ui:panel_tiles",
        statistics: "std:ui:panel_statistics",
        menu:       "std:ui:panel_menu"
    };

    var DEFAULT_PRIORITIES = O.$private.$panelBuilderDefaultPriorities = {
        "top":     10,
        "default": 100,
        "action":  200,
        "bottom":  1000
    };

    var defaultPriorityDecode = O.$private.$panelBuilderDefaultPriorityDecode = function(priority) {
        return DEFAULT_PRIORITIES[priority] || priority;
    };

    var compareNumbers = function(a, b) {
        return (1*a)  - (1*b);
    };

})();
