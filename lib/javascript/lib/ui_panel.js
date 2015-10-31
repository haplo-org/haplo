/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
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
        // ------------------------------------------------------------------
        render: function() {
            var template = $registry.standardTemplates[
                STYLE_TO_TEMPLATE_NAME[this.$style || this.$root.$options.style] ||
                STYLE_TO_TEMPLATE_NAME.DEFAULT];

            var builders = this.$root.$builders;
            var renderedPanels = [];
            _.each(_.keys(builders).sort(compareNumbers), function(key) {
                var builder = builders[key];
                if(builder._shouldBeRendered()) {
                    renderedPanels.push(template.render(builder.$view));
                }
            });

            return renderedPanels.join('');
        },
        // ------------------------------------------------------------------
        // Should this be rendered?
        _shouldBeRendered: function() {
            return (this.$elements.length > 0) && !(this.$hidePanel);
        },
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
    // Support for std_action_panel plugin
    PanelBuilder.prototype.__defineGetter__("__builders", function() {
        return this.$builders;
    });

    var STYLE_TO_TEMPLATE_NAME = O.$private.$panelBuilderStyleToTemplateName = {
        DEFAULT:"std:ui:panel",
        links:  "std:ui:panel_links",
        tiles:  "std:ui:panel_tiles",
        menu:   "std:ui:panel_menu"
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
