/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function(root) {

    // Register the oForms helpers
    oForms.registerHandlebarsHelpers();
    // Remove the oforms_element helper, which won't work in a sealed environment. It's replaced below.
    delete Handlebars.helpers.oforms_element;

    // NOTE: Handlebars helper equivalents of the standard Ruby-implemented template are defined in ruby_templates.js

    // --------------------------------------------------------------------------------------------------------------------

    // Register Platform helpers
    // -- oForms integration
    var oFormHelper = function(helperName, functionName) {
        Handlebars.registerHelper(helperName, function(formInstance) {
            if(!O.$private.$isFormInstance(formInstance)) {
                throw new Error("You must pass a FormInstance object to the "+helperName+" Handlebars helper");
            }
            return new Handlebars.SafeString((formInstance[functionName])());
        });
    };
    oFormHelper('std:form',      'renderForm');
    oFormHelper('std:document', 'renderDocument');
    // Copy of oforms_element helper from oforms_server.js - modified slightly.
    Handlebars.registerHelper('oforms:element', function(element) {
        var rows = this.rows, row = ((rows && rows.length > 0) ? rows[0] : this), named = row.named;
        if(named) {
            return new Handlebars.SafeString(($registry.standardTemplates['oforms:element'])(named[element]));
        } else {
            return '';
        }
    });
    // Make an alias so the oForms version of the name works too.
    Handlebars.helpers['oforms_element'] = Handlebars.helpers['oforms:element'];

    // --------------------------------------------------------------------------------------------------------------------

    // Paragraph text helper (split on newlines, escaped text enclosed in p tags)
    Handlebars.registerHelper('std:text:paragraph', function(text) {
        if(!text) { return ''; }
        var output = [];
        var paras = text.toString().split(/\s*[\r\n]+\s*/);
        for(var i = 0; i < paras.length; ++i) {
            if(paras[i]) {
                output.push('<p>', _.escape(paras[i]), '</p>');
            }
        }
        return new Handlebars.SafeString(output.join(''));
    });

    // Form hidden input elements
    Handlebars.registerHelper("std:parameter_inputs", function(parameters) {
        if(!parameters) {
            return '';
        }
        var output = [];
        _.each(parameters, function(value, name) {
            output.push('<input type="hidden" name="', _.escape(name), '" value="', _.escape(value), '">');
        });
        return new Handlebars.SafeString(output.join(''));
    });

    // --------------------------------------------------------------------------------------------------------------------

    // Widgets
    Handlebars.registerHelper('std:ui:navigation:arrow', function(direction, link) {
        var output = [];
        if(link) {
            output.push('<a class="z__plugin_ui_nav_arrow" href="', _.escape(link), '">');
        } else {
            output.push('<span class="z__plugin_ui_nav_arrow">');
        }
        output.push((direction === "left") ? '&#xE016;' : '&#xE005;');
        output.push(link ? '</a>' : '</span>');
        return new Handlebars.SafeString(output.join(''));
    });

    // --------------------------------------------------------------------------------------------------------------------

    // Support for standard templates

    // indicator styles for UI elements like std:ui:choose and std:ui:panel
    var std_ui_indicator_styles = {
        "standard": "",     // default option is unstyled, any other key will use this too
        "primary": " z__ui_indicate_primary",
        "secondary": " z__ui_indicate_secondary",
        "terminal": " z__ui_indicate_terminal",
        "primary-forward": " z__ui_indicate_primary z__ui_indicate_arrow_forward",
        "secondary-forward": " z__ui_indicate_secondary z__ui_indicate_arrow_forward",
        "primary-back": " z__ui_indicate_primary z__ui_indicate_arrow_back",
        "secondary-back": " z__ui_indicate_secondary z__ui_indicate_arrow_back",
        "forward": " z__ui_indicate_arrow_forward",
        "back": " z__ui_indicate_arrow_back",
    };
    Handlebars.registerHelper('_internal__indicator_styles', function(style) {
        return std_ui_indicator_styles[style] || '';
    });

    // std:ui:panel styles for elements
    Handlebars.registerHelper('_internal__panel_block_styles', function() {
        var styles = [];
        if(this.spaceAbove) { styles.push(' z__plugin_ui_action_panel_separate_more'); }
        switch(this.highlight) {
            case "primary": styles.push(' z__plugin_ui_action_panel_primary'); break;
            case "secondary": styles.push(' z__plugin_ui_action_panel_secondary'); break;
        }
        return styles.join('');
    });
    Handlebars.registerHelper('_internal__panel_entry_styles', function() {
        var styles = [];
        if(this.disabled) { styles.push(" z__plugin_ui_action_panel_disabled"); }
        if(this.light) { styles.push(" z__plugin_ui_action_panel_light"); }
        return styles.join('');
    });

    // std:ui:notice -- implement helper
    Handlebars.registerHelper("std:ui:notice", function(message, dismissLink, dismissText) {
        return new Handlebars.SafeString(
            $registry.standardTemplates["std:ui:notice"]({
                message: message, // (but no support for 'html' key)
                dismissLink: (typeof(dismissLink) === "string") ? dismissLink : undefined,  // need type checks for optional arguments
                dismissText: (typeof(dismissText) === "string") ? dismissText : undefined
            })
        );
    });

    // --------------------------------------------------------------------------------------------------------------------

    // Prevent any more handlers and any partials being registered
    Handlebars.disableRegistration();

    // Parse standard template JSON for later use
    O.$private.STANDARDTEMPLATES = JSON.parse(root.$STANDARDTEMPLATES);
    delete root.$STANDARDTEMPLATES;

    // Function for the framework initialiser to call to get the templates
    // set up in each instance.
    O.$private.$setupRuntimeInstanceTemplates = function() {
        // Build standard template lookup for this instance
        var standardTemplates = $registry.standardTemplates = {};

        // Make compiled platform standard templates
        _.each(O.$private.STANDARDTEMPLATES, function(template) {
            if(template.kind === 'hsvt') { return; } // New templates are precompiled and mixed in later
            var compiled = Handlebars.compile(template.template);
            // Set properties to match template interface
            compiled.name = template.name;
            compiled.kind = template.kind;
            compiled.render = function(view) { return compiled(view); };
            // Store in standard templates
            standardTemplates[template.name] = compiled;
        });

        // Make compiled versions of the oForms templates
        _.each(oForms.getStandardTemplates(), function(template, name) {
            var compiled = Handlebars.compile(template);
            // Set properties to match template interface
            compiled.name = name;
            compiled.kind = 'html';
            compiled.render = function(view) { return compiled(view); };
            // Store in standard templates
            standardTemplates[name] = compiled;
        });

        // Mix in ruby templates
        _.extend(standardTemplates, O.$private.rubyTemplates);

        // Mix in new templates
        _.extend(standardTemplates, O.$private.hsvtStandardTemplates);
    };

})(this);
