/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Simple abstraction of the underlying renderer, so it can be replaced later.

var $haploTemplateFunctionFinder;

(function(root) {

    var render = /* for sealing */ O.$private.$handlebarsTemplateRender = function(view, callerOptions) {
        if(callerOptions) {
            console.log("Passing options to template render() is deprecated.");
        }
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

    var deferredRender = O.$private.$handlebarsTemplateDeferredRender = function(view) {
        var template = this;
        return new $GenericDeferredRender(function() {
            return template.render(view);
        });
    };

    O.$createPluginTemplate = function(plugin, templateName, template, kind) {
        var compiled = Handlebars.compile(template);
        // Fill in Template interface
        compiled.render = render;
        compiled.deferredRender = deferredRender;
        compiled.kind = kind;
        compiled.name = templateName;
        compiled.$plugin = plugin;
        return compiled;
    };

    $haploTemplateFunctionFinder = function(name) {
        var fnCache = $registry.$templateFnCache;
        if(!fnCache) { $registry.$templateFnCache = fnCache = {}; }
        var fn = fnCache[name];
        if(fn) { return fn; }
        var fnDictionaryList = $registry.$templateFnDictList;
        if(!fnDictionaryList) {
            $registry.$templateFnDictList = fnDictionaryList = [];
            var plugins = $registry.plugins, n = plugins.length, i, plugin;
            for(i = 0; i < n; i++) {
                plugin = plugins[i];
                var pd = plugin.templateFunctions;
                if(pd) { fnDictionaryList.push(pd); }
            }
        }
        var dlen = fnDictionaryList.length;
        for(var d = 0; d < dlen; ++d) {
            var fd = fnDictionaryList[d];
            fn = fd[name];
            if(fn) {
                fnCache[name] = fn;
                return fn;
            }
        }
    };

    // Standard templates in new format
    var hsvtStandardTemplates = O.$private.hsvtStandardTemplates = {};
    _.each(JSON.parse(root.$STANDARDTEMPLATES), function(template) {
        if(template.kind === 'hsvt') {
            var hsvt = new $HaploTemplate(template.template);
            hsvt.kind = 'html';
            hsvtStandardTemplates[template.name] = hsvt;
        }
    });

})(this);
