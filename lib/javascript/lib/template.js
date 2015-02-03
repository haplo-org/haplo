/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Simple abstraction of the underlying renderer, so it can be replaced later.

(function() {

    var render = /* for sealing */ O.$private.$handlebarsTemplateRender = function(view, callerOptions) {
        // Use the partials in this plugin and the standard templates
        var options = {
            partials: new $TemplatePartialAutoLoader(this.$plugin)
        };
        // Add in any helpers registered with the plugin, or passed in the callerOptions to this function.
        var helpers;
        // TODO: Use a helper object for helpers which throws a nice exception if there's an attempt to use a helper which doesn't exist.
        if(callerOptions && callerOptions.helpers) {
            helpers = _.clone(callerOptions.helpers);
        }
        if(this.$plugin.$handlebarsHelpers) {
            helpers = (helpers ? _.extend(helpers, this.$plugin.$handlebarsHelpers) : this.$plugin.$handlebarsHelpers);
        }
        if(helpers) {
            _.extend(helpers, Handlebars.helpers); // Include the standard helpers
            options.helpers = helpers;
        }
        // Render the view
        return this(view, options);
    };

    O.$createPluginTemplate = function(plugin, templateName, template, kind) {
        var compiled = Handlebars.compile(template);
        // Fill in Template interface
        compiled.render = render;
        compiled.kind = kind;
        compiled.name = templateName;
        compiled.$plugin = plugin;
        return compiled;
    };

})();
