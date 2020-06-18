/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

/* jshint moz:true */ /* mozilla extensions for the catch(e if ...) filter */

var $Plugin = function(pluginName) {
    this.pluginName = pluginName;   // public property
    this.$pluginName = pluginName;  // internal property
    this.$templates = {};
    this.db = $host.nextPluginUsesDatabase() ? (new $DbNamespace()) : (new O.$private.$DummyDb());
    // this.data filled in by $host.registerPlugin
};

// NOTE: $Plugin is extended by plugin_*.js files

(function() {

    var ALLOWED_HTTP_METHODS = {GET:true, POST:true, PUT:true};
    var STANDARD_TEMPLATE_REGEXP = /^(std|oforms)\:/;

    // ----------------------------------------------------------------------------------------------------------

    // Implement plugin:static:* templates
    var staticTemplateNameRegExp = /^plugin\:static\:([a-zA-Z0-9_\.\-]+)$/;
    var makeStaticFileInclusionTemplate = function(pluginName, filename) {
        var render = function(view) {
            $host.renderRTemplate('_plugin_static', pluginName, filename);
            return ''; // don't output anything - this template is just a marker for the requirement
        };
        render.render = render;
        render.name = 'plugin:static:'+filename;
        render.kind = 'html';
        return render;
    };

    // ----------------------------------------------------------------------------------------------------------

    // Exceptions if the argument declaractions are bad.
    // returns false (meaning don't handle) if the input from the HTTP client is bad.
    // returns true if the plugin's handler was called.
    var callHandlerWithArguments = function(plugin, E, handler, argDeclarations) {
        var args = [E], i, l = argDeclarations.length, a, stringValue = null, decoded;
        // TODO: log all reasons for failing to call a JavaScript request handler because of failures of input data
        for(i = 0; i < l; ++i) {
            a = argDeclarations[i];
            // Retrieve the value as a string
            if(a.pathElement != undefined) {
                stringValue = E.request.extraPathElements[a.pathElement];
            } else if(a.parameter != undefined) {
                stringValue = E.request.parameters[a.parameter];
            } else if(a.body === "body") {
                if(a.as === "binaryData") {
                    stringValue = $host.fetchRequestBodyAsBinaryData();
                } else {
                    stringValue = E.request.body;
                    if(stringValue.length === 0) { stringValue = null; }
                }
            } else {
                throw new Error("No argument source declared when preparing arguments for handler call: "+JSON.stringify(a));
            }
            if(stringValue === undefined) { stringValue = null; }
            if(stringValue === null || stringValue === '') {
                // Special case for uploaded files - need to be collected separately
                if(a.as == "file") {
                    stringValue = $host.fetchRequestUploadedFile(a.parameter);
                    if(stringValue === '') {
                        // Has form field, but user didn't fill in it (some browsers send empty string value in this case)
                        stringValue = null;
                    }
                }
            }
            // Got something?
            if(stringValue === null) {
                if(a.optional) {
                    args.push(null);
                } else {
                    // Required parameter not provided: don't handle the request
                    return false;
                }
            } else {
                switch(a.as) {
                    // ------- STRING -------
                    case "string":
                        if(a.validate) {
                            if(typeof(a.validate) == 'function') {
                                if(!(a.validate(stringValue))) {
                                    return false;   // validation function rejected the argument
                                }
                            } else if(_.isRegExp(a.validate)) {
                                if(!(a.validate.test(stringValue))) {
                                    return false;   // didn't match regexp
                                }
                            } else {
                                // Don't understand the validation method
                                return false;
                            }
                        }
                        args.push(stringValue);
                        break;

                    // ------- INTEGER -------
                    case "int":
                        if(!(/^\-?\d+$/.test(stringValue))) {
                            return false;       // not a string representation of an integer
                        }
                        decoded = parseInt(stringValue, 10);
                        if(a.validate) {
                            if(!(a.validate(decoded))) {
                                return false;   // validation function failed
                            }
                        }
                        args.push(decoded);
                        break;

                    // ------- OBJECT REFERENCE -------
                    case "ref":
                        decoded = O.ref(stringValue);
                        if(decoded === null) { return false; }   // failed to convert, so must be bad
                        args.push(decoded);
                        break;

                    // ------- OBJECT -------
                    case "object":
                        decoded = O.ref(stringValue);
                        if(decoded === null) { return false; }   // failed to convert, so must be bad
                        try {
                            decoded = decoded.load();
                        } catch(e) {
                            return false;                       // bad object load, probably failed permission check
                        }
                        if(!decoded) { return false; }          // object store didn't return anything, object doesn't exist
                        args.push(decoded);
                        break;

                    // ------- WORK UNIT ----------
                    case "workUnit":
                        if(!(/^\d+$/.test(stringValue))) {
                            return false;       // not a string representation of a positive integer
                        }
                        decoded = parseInt(stringValue, 10);
                        var workUnit = null;
                        try {
                            workUnit = O.work.load(decoded);
                        } catch(e) {
                            return false;                       // bad object load, incorrect ID?
                        }
                        if(a.workType && a.workType !== workUnit.workType) { return false; }  // must be a certain workType
                        if(a.allUsers || workUnit.isActionableBy(O.currentUser)) {
                            args.push(workUnit);
                        } else {
                            return false;                       // Unless explicitly allowed, workunit must be actionable by current user.
                        }
                        break;

                    // ------- DATABASE ROW -------
                    case "db":
                        if(!(/^\d+$/.test(stringValue))) {
                            return false;       // not a string representation of a positive integer
                        }
                        decoded = parseInt(stringValue, 10);
                        try {
                            decoded = plugin.db[a.table].load(decoded);
                            if(decoded === null) {
                                return false;                   // row doesn't exist
                            }
                        } catch(e2) {
                            return false;                       // bad database row load, probably because the table doesn't exist
                        }
                        args.push(decoded);
                        break;

                    // ------- JSON -------
                    case "json":
                        try {
                            args.push(JSON.parse(stringValue));
                        } catch(e) {
                            console.log("Failed to parse JSON: ", stringValue);
                            return false;
                        }
                        break;

                    // ------- FILE -------
                    case "file":
                        // Already collected in the special case above - just check it then push it onto the arguments
                        if(!(stringValue instanceof $UploadedFile)) {
                            throw new Error("Uploaded file was expected in a form field, but found other field type in request.");
                        }
                        args.push(stringValue);
                        break;

                    // ------- BINARY DATA -------
                    case "binaryData":
                        if(a.body !== "body") {
                            throw new Error("Bad use of binaryData in request handler arguments");
                        }
                        args.push(stringValue);
                        break;

                    // ------- BAD SPECIFICATION -------
                    default:
                        throw new Error("Bad 'as' specification when converting parameter for handler call: "+JSON.stringify(a));
                }
            }
        }
        if(args.length != (1 + l)) { throw new Error("logic error in decoding request arguments"); }
        handler.apply(plugin, args);
        return true;
    };

    _.extend($Plugin.prototype, {
        // Declare that a plugin responds to a request
        respond: function(methods, path, argDeclarations, handlerFunction) {
            var that = this;
            if(!(/^\/[\/a-zA-Z0-9_\-]*[a-zA-Z0-9_\-]$/.test(path))) {
                throw new Error("Bad path ('"+path+"') when declaring a handler function. Must start with /, only contain /a-zA-Z0-9_-, and must not end with a /");
            }
            _.each(methods.split(','), function(method) {
                // Check HTTP method is valid
                if(!ALLOWED_HTTP_METHODS[method]) {
                    throw new Error(method+" is not a supported HTTP method when declaring a handler function.");
                }
                // Make a handler function
                that[method+" "+path] = function(E) {
                    return callHandlerWithArguments(this, E, handlerFunction, argDeclarations);
                };
            });
            // Check for file arguments, and store the list of parameter names if there are any
            var fileArgs = [];
            _.each(argDeclarations, function(a) {
                if(a.as == "file") {
                    if(a.parameter == undefined) {
                        throw new Error("Bad declaration for a file argument to a handler. Must be a parameter.");
                    }
                    if(!(/^[a-zA-Z0-9_\-]+$/.test(a.parameter))) {
                        throw new Error("Parameter names for file uploads can only contain [a-zA-Z0-9_-].");
                    }
                    fileArgs.push(a.parameter);
                } else if(a.as == "binaryData" && a.body === "body") {
                    if(!$registry.largeRequestBodyAllowed) { $registry.largeRequestBodyAllowed = []; }
                    _.each(methods.split(','), function(method) {
                        $registry.largeRequestBodyAllowed.push(method+" "+path);
                    });
                }
            });
            if(fileArgs.length !== 0) {
                this["FILE_UPLOAD_INSTRUCTIONS "+path] = fileArgs.join(',');
            }
        },

        // "Feature" support for code sharing
        provideFeature: function(featureName, injectFunction) {
            featureName = featureName.toString();
            if(!/^[A-Za-z0-9:_-]+$/.test(featureName)) {
                throw new Error("Invalid name for feature: "+featureName);
            }
            if(featureName in $registry.featureProviders) {
                throw new Error("Feature '"+featureName+"' is already registered.");
            }
            $registry.featureProviders[featureName] = {plugin:this, injectFunction:injectFunction};
            return this;
        },
        use: function(featureName) {
            var provider = $registry.featureProviders[featureName];
            if(!provider) {
                throw new Error("Feature '"+featureName+"' is not provided by any plugin. Do you need to install or adjust the loadPriority of the providing plugin?");
            }
            provider.injectFunction.call(provider.plugin, this);
            return this;
        },

        // Declare that a plugin implements a service, returning number of services registered for that name.
        implementService: function(name, serviceFunction) {
            return O.$private.$registerService(name, serviceFunction, this);
        },

        registerHandlebarsHelper: function(name, helper) {
            if(!this.$handlebarsHelpers) {
                this.$handlebarsHelpers = {};
            }
            this.$handlebarsHelpers[name] = helper;
        },

        onInstall: function() {
            // NOTE: Never actually called because KHost only looks in the plugin object, not the prototype
        },

        onLoad: function() {
            // Called after all plugins have been loaded in a new JavaScript runtime.
            // This implementation of the function is unlikely to be called by plugins overriding it.
        },

        // Set a hook handler, or add an additional responder.
        hook: function(hookName, responder) {
            var existingHook = this[hookName];
            // If there's no responder yet, set the given function without doing anything fancy.
            // If there is one, set it to a function which calls the existing one and the additional responder.
            this[hookName] = (!existingHook) ? responder : function() {
                existingHook.apply(this, arguments);
                responder.apply(this, arguments);
            };
        },

        getFileUploadInstructions: function(path) {
            var instructionsName = "FILE_UPLOAD_INSTRUCTIONS "+path, nextInstructionsName;
            while(this[instructionsName] === undefined) {
                // Remove the last path component from the name
                nextInstructionsName = instructionsName.replace(/\/([^\/ ]*)$/,'');
                if(nextInstructionsName == instructionsName) {
                    return null; // No instructions found
                }
                instructionsName = nextInstructionsName;
            }
            return this[instructionsName];
        },

        // Callbacks for request handling
        requestBeforeHandle: function(E) {},   // return false or render something to stop the rest of the request
        requestBeforeRender: function(E, view, templateName) {},
        requestAfterHandle: function(E) {},

        // Request handler
        handleRequest: function(method, path) {
            var E, result, handlerName = method+" "+path, nextHandlerName, extraPathElements = [];
            while(this[handlerName] === undefined) {
                // Remove the last path component from the method, and store it in the extraElements array for later.
                nextHandlerName = handlerName.replace(/\/([^\/ ]*)$/,function(str, p1) { extraPathElements.unshift(p1); return ""; });
                if(nextHandlerName == handlerName) {
                    // No handler found
                    return null;
                }
                handlerName = nextHandlerName;
            }
            E = new $Exchange(this, handlerName, method, path, extraPathElements);
            // Testing integration
            var testingHook = $registry.$testingRequestHook;
            if(testingHook) {
                testingHook(handlerName, method, path, extraPathElements, E);
            }
            try {
                // Before handle callback
                var beforeCallbackResult = this.requestBeforeHandle(E);
                if(E.response["body"]) { // written this way to cope with Rhino's undefined property warning
                    return E.response; // Before handle callback rendered something
                }
                if(beforeCallbackResult === false) {
                    // Callback aborted the handling, but didn't provide an alternative response
                    E.response.statusCode = HTTP.FORBIDDEN;
                    E.response.body = "Forbidden";
                    E.response.kind = "text";
                }
                // Normal request handling. If a template is rendered, requestBeforeRender() will be called.
                result = this[handlerName](E);
/* jshint -W118 */
            } catch(e if "$haploStopError" in e) {
/* jshint +W118 */
                // O.stop() was called in the response handler.
                // Use the catch(e if ...) construction so that we don't have to re-throw other exceptions, which would lose the stack trace.
                var stopView = e.$haploStopError.view;
                if(O.PLUGIN_DEBUGGING_ENABLED) {
                    // TODO: Prettier display of stack for O.stop() without platform internals
                    stopView.__STOP_STACK = e.stack;
                }
                E.render(stopView, e.$haploStopError.template);
                result = true;
            }
            if(result === false) {
                // Failed to decode the arguments
                E.response.statusCode = HTTP.BAD_REQUEST;
                E.response.body = "Bad request (failed validation)";
                E.response.kind = "text";
            }
            // After handle callback
            this.requestAfterHandle(E);
            return E.response;
        },

        hasFile: function(pathname) {
            return $host.hasFileForPlugin(this.$pluginName, pathname);
        },

        loadFile: function(pathname) {
            return $host.loadFileForPlugin(this.$pluginName, pathname);
        },

        template: function(templateName) {
            var templates = this.$templates;
            if(STANDARD_TEMPLATE_REGEXP.test(templateName)) {
                return $registry.standardTemplates[templateName];
            }
            if(templates[templateName] === undefined) {
                var m = staticTemplateNameRegExp.exec(templateName);
                if(m !== null) {
                    // It's a special template for including the static file as a client side resource
                    templates[templateName] = makeStaticFileInclusionTemplate(this.$pluginName, m[1]);
                } else {
                    // Template in the 'template' directory
                    // Note that Handlebars converts '/' in partial template names to '.', so convert them back
                    // TODO: More robust way of enabling partials to be in subdirectories
                    templates[templateName] = $host.loadTemplateForPlugin(this, this.$pluginName, templateName.replace(/\./g, "/"));
                }
            }
            return templates[templateName];
        },

        globalTemplateFunction: function(name, templateFunction) {
            if(!((typeof(name) === 'string') && (-1 !== name.indexOf(':')))) {
                throw new Error("Bad template function name '"+name+"', must be a string containing at least one ':' character");
            }
            if(typeof(templateFunction) !== 'function') {
                throw new Error("Bad implementation function passed to P.globalTemplateFunction()");
            }
            $registry.$templateFunctions[name] = templateFunction;
        },

        rewriteCSS: function(css) {
            return $host.pluginRewriteCSS(this.$pluginName, css);
        },

        // Auditing
        declareAuditEntryOptionalWritePolicy: function(policy) {
            var plugin = this;
            this.hook('hAuditEntryOptionalWritePolicy', function(response) {
                if(typeof(policy) === 'function') {
                    response.policies.push(policy.call(plugin));
                } else {
                    response.policies.push(policy.toString());
                }
            });
        },

        // Generic callback registry: register a function, and return a callback object
        // that can be passed to O.$private.invokeCallback to call it later.
        callback: function(name, fn) {
            if ($registry.pluginLoadFinished) {
                throw new Error("Plugin callbacks can only be declared while the plugin is being loaded");
            }
            var callback = new $Plugin.$Callback(this, name, fn);
            if(callback.$name in $registry.callbacks) {
                throw new Error("Callback "+callback.$name+" has already been registered.");
            }
            $registry.callbacks[callback.$name] = callback;
            return callback;
        },

        // i18n support
        locale: function(localeId) {
            if(!localeId) { localeId = $host.i18n_getCurrentLocaleId(); }
            var locales = this.$locales;
            if(!locales) { this.$locales = locales = {}; }
            var locale = locales[localeId],
                defaultForPlugin = (localeId === this.defaultLocaleId);
            if(!locale) { locales[localeId] = locale = new $Locale(this, localeId, defaultForPlugin); }
            return locale;
        },

        defaultLocaleId: "en"   // TODO: Allow plugins to have a different default locale, set on creation from localeId in plugin.json?
    });

    $Plugin.$Callback = function(plugin, name, fn) {
        this.$plugin = plugin;
        this.$name = plugin.$pluginName + ':' + name;
        this.$fn = fn;
    };
    $Plugin.$Callback.prototype.apply = function(args) {
        return this.$fn.apply(this.$plugin, args);
    };

    $Plugin.prototype.__defineGetter__('staticDirectoryUrl', function() {
        if(undefined != this.$staticDirectoryUrl) { return this.$staticDirectoryUrl; }
        var url = this.$staticDirectoryUrl = $host.pluginStaticDirectoryUrl(this.$pluginName);
        return url;
    });

    $Plugin.$callOnLoad = function() {
        // Prepare other parts of the runtime...
        O.$private.$callBeforePluginOnLoad.forEach(function(fn) { fn(); });
        // ... then call all the onLoad callback functions.
        var plugins = $registry.plugins, n = plugins.length, i;
        for(i = 0; i < n; i++) {
            try {
                plugins[i].onLoad();
            } catch(e) {
                // TODO: Log plugin onLoad expection a bit better and report to developer in plugin tool if possible.
                console.log("When calling onLoad() for "+plugins[i].$pluginName+", got exception: ", e);
            }
        }
        $registry.pluginLoadFinished = true;
    };

    $Plugin.$callOnInstall = function() {
        var plugins = $registry.plugins, n = plugins.length, i;
        for(i = 0; i < n; i++) {
            plugins[i].onInstall();
        }
    };

    $Plugin.$requestLargeBodySpillAllowed = function(method, path) {
        var t = method+" "+path;
        return !!_.find($registry.largeRequestBodyAllowed||[], function(a) { return t.startsWith(a); });
    };

    O.enforcePluginPrivilege = function(plugin, privilege, action) {
        if(!(plugin instanceof $Plugin)) { throw new Error("Not a plugin"); }
        $host.enforcePluginPrivilege(plugin.pluginName, privilege, action);
    };

    O.getPluginInstance = function(pluginName) {
        var plugin = $registry.$runtimeScope[pluginName];
        if(!(plugin instanceof $Plugin)) {
            throw new Error("Unknown plugin: "+pluginName);
        }
        return plugin;
    };

    O.plugin = function(pluginName, methods) {
        var plugin = new $Plugin(pluginName);
        if(methods) { _.extend(plugin, methods); }
        $host.registerPlugin(pluginName, plugin);
        $registry.plugins.push(plugin);
        return plugin;
    };

})();
