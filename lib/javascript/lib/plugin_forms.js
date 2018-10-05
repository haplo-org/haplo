/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Implements the integration and wrappers for the oForms system.

(function() {

    // Create a place within O for all the private functions and classes, so they get sealed.
    O.$private.oForms = {};

    // ----------------------------------------------------------------------------------------------------------------------
    // oForms data source support

    $Plugin.prototype['$dsConstruct object-lookup'] = function(name, defn) {
        // The argument should always be an array
        if(!_.isArray(defn)) { defn = [defn]; }
        // Make list of type strings
        var types = [];
        _.each(defn, function(t) {
            if(!(t instanceof $Ref)) {
                throw new Error("Bad object type used to create data source "+name+", must be object reference");
            }
            types.push(t.toString());
        });
        if(types.length === 0) {
            throw new Error("No types given to create data source "+name);
        }
        // Return data source object
        return {
            endpoint: '/api/oforms/src_objects?t='+types.join(','), // implemented in the Ruby code
            displayNameForValue: function(value) {
                // Value is a string for an objref, decode then load the object
                var ref = O.ref(value);
                if(!ref) { return; }
                var object = ref.load();
                // Handle bad refs
                if(!object) { 
                    return {display:"????"};
                }
                return {
                    display: object.title,
                    href: object.url()
                };
            }
        };
    };

    $Plugin.prototype.dataSource = function(name, kind, defn) {
        if(arguments.length !== 3) {
            // Just in case a caller forgets the [] around an array for defn
            throw new Error("Wrong number of arguments to dataSource() for "+name);
        }
        var dsConstructor = this['$dsConstruct '+kind];
        if(!dsConstructor) { throw new Error("No such data source kind: "+kind); }
        var ds = dsConstructor.call(this, name, defn);
        if(!ds) { throw new Error("Internal error creating data source"); }
        var dataSources = this.$dataSources;
        if(!dataSources) { this.$dataSources = dataSources = {}; }
        if(dataSources[name]) {
            throw new Error("Data source "+name+" has already been created");
        }
        dataSources[name] = ds;
    };

    // ----------------------------------------------------------------------------------------------------------------------
    // Use a plugin delegate object rather than implementing the methods on the plugin itself,
    // to encapsulate and stop plugin authors messing things up. If they want more control, they
    // can use the oForms system directly.

    var PluginFormDelegate = O.$private.oForms.pfd = function(plugin) {
        this.plugin = plugin;
        // Store a reference to the runtime global custom validate functions
        this.customValidationFunctions = $registry.$oFormsCustomValidationFunctions;
    };
    _.extend(PluginFormDelegate.prototype, {
        formGetDataSource: function(name) {
            var dataSources = this.plugin.$dataSources;
            return dataSources ? dataSources[name] : undefined;
        },
        formTemplateRendererSetup: function() {
            // Don't do anything - templating has already been set up.
        },
        formPushRenderedTemplate: function(templateName, view, output) {
            // Render the template via the plugin rendering system to allow use of custom templates.
            // oForms templates are merged into the Platform standard templates on JavaScript initialisation.
            var template = this.plugin.template(templateName);
            if(!template) {
                throw new Error("When rendering form, template "+templateName+" could not be found");
            }
            output.push(template.render(view));
        },
        // File support
        formFileElementValueRepresentsFile: function(value) {
            return !!value && value.digest && (typeof(value.fileSize) === "number");
        },
        formFileElementRenderForForm: function(value) {
            return O.file(value)._oFormsFileHTML("form");
        },
        formFileElementRenderForDocument: function(value) {
            return O.file(value)._oFormsFileHTML("document");
        },
        formFileElementEncodeValue: function(value) {
            var file = O.file(value);
            return JSON.stringify({d:file.digest, s:file.fileSize, x:file.secret});
        },
        formFileElementDecodeValue: function(encoded) {
            var d = JSON.parse(encoded);
            var value = {digest:d.d, fileSize:d.s};
            if(!this.formFileElementValueRepresentsFile(value)) { return undefined; }
            var file = O.file(value);
            file.checkSecret(d.x); // Check secret so that user can't sneak in a digest to a file they want to read
            value.filename = file.filename; // And add in the filename into the document as it's useful
            return value;
        }
    });


    // ----------------------------------------------------------------------------------------------------------------------
    // Instance wrapper, to present the required API to plugin callers

    var FormInstanceWrapper = O.$private.oForms.fiw = function(plugin, instance) {
        this.plugin = plugin;
        this.instance = instance;
        this.document = instance.document;
    };
    _.extend(FormInstanceWrapper.prototype, {
        complete: false,    // make the complete property return a proper false value by default
        update: function(request) {
            // If the form has been submitted, update the document
            if(request.method === "POST") {
                var parameters = request.parameters; // get it into a local var for efficiency
                this.instance.update(function(name) { return parameters[name]; });
                if(this.instance.valid) {
                    this.complete = true;
                }
            }
            return this.complete;
        },
        documentWouldValidate: function() {
            return this.instance.documentWouldValidate();
        },
        renderForm: function() {
            // Include the oForms CSS in the response
            $host.renderRTemplate("_client_side_resource", "oforms_styles");
            // Is a bundle or client side support required?
            var description = this.instance.description;
            if(description.requiresClientUIScripts) {
                // Include the oForms client side JavaScript
                $host.renderRTemplate("_client_side_resource", "oforms_support");
                if(description.requiresClientFileUploadScripts) {
                    $host.renderRTemplate("_client_side_resource", "oforms_file_support");
                }
            }
            if(description.requiresBundle) {
                // Include the bundle JavaScript resource
                // Use the pluginStaticDirectoryUrl() to include the appearance serial number (so the bundle is invalidated
                // on upgrades and on plugin installation and developer loader plugin updates) and plugin path component
                // (to identify the plugin in a short format).
                // Bundles are per-user, so add current user ID to the end of the URL so login out then in or impersonation
                // doesn't use a cached copy and confuse the user.
                var user = O.currentUser;
                var uid = (user ? O.currentUser.id : 0);
                var bundleUrlPath = '/api/oforms/bundle'+$host.pluginStaticDirectoryUrl(this.plugin.$pluginName)+'/'+description.formId+'/'+uid;
                // TODO: More efficient way of generating the bundleUrlPath, include a serial number which can be invalidated (automatically?) should any of the sources change
                $host.renderRTemplate("_client_side_resource_path", 'javascript', bundleUrlPath);
            }
            return this.instance.renderForm();
        },
        deferredRenderForm: function() {
            var wrapper = this;
            return new $GenericDeferredRender(function() { return wrapper.renderForm(); });
        },
        renderDocument: function() {
            // Include the oForms CSS in the response, then return the rendered document
            $host.renderRTemplate("_client_side_resource", "oforms_styles");
            // Enclose it in a div with the correct class so it gets the form styles
            return ['<div class="oform">', this.instance.renderDocument(), '</div>'].join('');
        },
        deferredRenderDocument: function() {
            var wrapper = this;
            return new $GenericDeferredRender(function() { return wrapper.renderDocument(); });
        },
        setIncludeUniqueElementNamesInHTML: function(include) {
            this.instance.setIncludeUniqueElementNamesInHTML(include);
            return this;
        },
        choices: function(name, choices) {
            this.instance.choices(name, choices);
        },
        customValidation: function(name, fn) {
            this.instance.customValidation(name, fn);
        },
        externalData: function(externalData) {
            this.instance.externalData(externalData);
        },
        makeView: function() {
            return this.instance.makeView();
        }
    });


    // ----------------------------------------------------------------------------------------------------------------------
    // Description wrapper, to present the required API to plugin callers

    var FormDescriptionWrapper = O.$private.oForms.fdw = function(plugin, formId, specification, specificationFilename) {
        this.plugin = plugin;
        this.formId = formId;
        // this.formTitle implemented by getter below because it may be translated
        this.$specification = specification;
        this.$specificationFilename = specificationFilename;
    };
    _.extend(FormDescriptionWrapper.prototype, {
        // Because it can take a little while to create form descriptions where there are lots of forms defined
        // by a plugin, the underlying oForms object is created lazily. The _ensureDescriptionCreated() function
        // must be called by all functions in this object before they do anything with the description.
        _ensureDescriptionCreated: function() {
            if(!this.description) {
                // Create the underlying form description
                this.description = oForms.createDescription(this.specification, this.plugin.$formDelegate);
                this.description.$haploPlugin = this.plugin;    // for custom elements
            }
        },

        instance: function(document) {
            if(this.$replaceable) {
                if(O.serviceImplemented("std:form:replace")) {
                    var replacement = O.service("std:form:replace", this, document);
                    if(replacement) {
                        return replacement._instanceWithoutReplace(document);
                    }
                }
            }
            return this._instanceWithoutReplace(document);
        },

        _instanceWithoutReplace: function(document) {
            this._ensureDescriptionCreated();
            return new FormInstanceWrapper(this.plugin, this.description.createInstance(document));
        },

        handle: function(document, request) {
            this._ensureDescriptionCreated();
            var wrappedInstance = this.instance(document);
            wrappedInstance.update(request);
            return wrappedInstance;
        },

        _getBundleJavaScriptResponse: function() {
            this._ensureDescriptionCreated();
            // Generate the JavaScript to send to the browser. Shouldn't be cached, as each user
            // may have different bundles depending on permissions and data source criteria.
            var bundle = this.description.generateBundle();
            return [
                'oForms.client.registerBundle("', this.description.formId, '",',
                JSON.stringify(bundle),
                ');'
            ].join('');
        }
    });

    // Lazy load specification from plugin bundled file, if it wasn't specified as a literal.
    FormDescriptionWrapper.prototype.__defineGetter__("specification", function() {
        // Load the specification from a plugin data file if it wasn't a literal.
        var specification = this.$specification;
        if(!specification) {
            specification = this.$specification = this.plugin.loadFile(this.$specificationFilename).readAsJSON();
            if(this.$specification.formId !== this.formId) {
                throw new Error("Unexpected formId in specification when loading "+this.$specificationFilename+
                    ", expected "+this.formId+", got "+this.$specification.formId);
            }
        }
        return specification;
    });

    // Lazy load of form title, including translation
    FormDescriptionWrapper.prototype.__defineGetter__("formTitle", function() {
        var t = this.$formTitle;
        if(!t) { t = this.$formTitle = formsTextTranslate(this.specification.formTitle); }
        return t;
    });

    // Lazy load of short form title, including translation & defaulting to form title
    FormDescriptionWrapper.prototype.__defineGetter__("formTitleShort", function() {
        var t = this.$formTitleShort;
        if(!t) {
            t = this.$formTitleShort = formsTextTranslate(this.specification.formTitleShort || this.specification.formTitle);
        }
        return t;
    });

    // ----------------------------------------------------------------------------------------------------------------------
    // Implementation of the hook to get the bundled information

    var hPlatformInternalOFormsBundleImpl = O.$private.oForms.hpiofbi = function(response, pluginName, formId) {
        var wrappedDescription;
        if(     pluginName === this.$pluginName &&
                this.$formLookupById &&
                (wrappedDescription = this.$formLookupById[formId]) ) {
            response.bundle = wrappedDescription._getBundleJavaScriptResponse();
        }
    };

    // ----------------------------------------------------------------------------------------------------------------------
    // Integration into the rest of the platform

    O.$private.$isFormInstance = function(formInstance) {
        return formInstance && (formInstance instanceof FormInstanceWrapper);
    };

    // ----------------------------------------------------------------------------------------------------------------------
    // Creation of forms via plugin

    $Plugin.prototype.globalFormsCustomValidationFunction = function(name, fn) {
        var r = $registry.$oFormsCustomValidationFunctions;
        if(name in r) {
            throw new Error("Validation function "+name+" is already registered");
        }
        if(typeof(fn) !== 'function') {
            throw new Error("Must pass a function as second argument to globalFormsCustomValidationFunction()");
        }
        r[name] = fn;
    };

    $Plugin.prototype.form = function(arg0, arg1) {
        // Can only create forms while plugins are being loaded, so that the bundle IDs are known to all
        // instances of the runtime. If they could be created "on demand", then there's a reasonable chance
        // that a request for a bundle would fail because that runtime hadn't had that form created yet.
        if($registry.pluginLoadFinished) {
            throw new Error("Forms can only be created while the plugin is being loaded.");
        }
        // Create the plugin delegate object, if it hasn't been created already
        var delegate = this.$formDelegate;
        if(!delegate) {
            this.$formDelegate = delegate = new PluginFormDelegate(this);
        }
        // Decode arguments
        var formId, specification, specificationFilename;
        if(typeof(arg0) === "string") {
            formId = arg0;
            if(typeof(arg1) !== "string") {
                throw new Error("P.form() with ID and filename must have a string as a second argument");
            }
            specificationFilename = arg1;
        } else {
            specification = arg0;
            formId = specification.formId;
            if(arguments.length !== 1) {
                throw new Error("P.form() with specification must not have any other arguments");
            }
        }
        // Check the ID in the given specification
        if(!formId) {
            throw new Error("Form specification must include a formId.");
        }
        // Validate the formId to make sure bundle URLs don't break
        if(!(formId.match(/^[a-zA-Z0-9_\-]+$/))) {
            throw new Error("Form ID can only contain a-zA-Z0-9_-");
        }
        // Make the wrapper for the description, which lazily creates the oForms description
        var wrappedDescription = new FormDescriptionWrapper(this, formId, specification, specificationFilename);
        // Make sure the hook is implemented
        this.hPlatformInternalOFormsBundle = hPlatformInternalOFormsBundleImpl;
        // Set up lookup tabels in the plugin object
        if(!this.$formLookupById) {
            this.$formLookupById = {};
        }
        // Check that a form of this ID hasn't already been created, then store the wrapper for later
        if(this.$formLookupById[formId]) {
            throw new Error("Form ID "+formId+" has already been defined.");
        }
        this.$formLookupById[formId] = wrappedDescription;
        return wrappedDescription;
    };

    // Like form(), but the forms are marked as replaceable.
    $Plugin.prototype.replaceableForm = function() {
        var form = this.form.apply(this, arguments);
        form.$replaceable = true;
        return form;
    };

    // ----------------------------------------------------------------------------------------------------------------------
    // Use NAME() in oForms text

    var formsTextTranslate = O.$private.$interpolateNAMEinString;
    oForms.setTextTranslate(formsTextTranslate);

    // ----------------------------------------------------------------------------------------------------------------------
    // Implementation of document-text element type

    oForms._makeElementType("document-text", {

        _initElement: function(specification, description) {
            this.allowWidgets = ("allowWidgets" in specification) ? !!(specification.allowWidgets) : false;
        },

        _pushRenderedHTML: function(instance, renderForm, context, nameSuffix, validationFailure, output) {
            var value = this._getValueFromDoc(context);
            if(renderForm) {
                output.push(
                    '<div class="z__oforms_docedit" data-widgets="', (this.allowWidgets ? 'yes' : 'no'), '">',
                        '<input type="hidden" name="', this.name, nameSuffix, '">',
                        $host.renderRTemplate("document_text_control", "doc_"+this.name+nameSuffix, value ? value : '<doc></doc>'),
                    '</div>'
                );
            } else {
                if(value) {
                    output.push($host.renderRTemplate("document_text", value));
                }
            }
        },

        _decodeValueFromFormAndValidate: function(instance, nameSuffix, submittedDataFn, validationResult) {
            var text = submittedDataFn(this.name + nameSuffix);
            if(text.length === 0 || text === '<doc></doc>') {
                return undefined;
            }
            return text;
        }
    });

    // ----------------------------------------------------------------------------------------------------------------------
    // Implementation of render-template element type

    oForms._makeElementType("render-template", {

        _initElement: function(specification, description) {
            this._template = specification.template;
            this._view = specification.view;
        },

        _pushRenderedHTML: function(instance, renderForm, context, nameSuffix, validationFailure, output) {
            var template = instance.description.$haploPlugin.template(this._template);
            output.push(template.render({
                view: this._view,
                externalData: instance.getExternalData(),
                context: context
            }));
        },

        _updateDocument: function(instance, context, nameSuffix, submittedDataFn) {
            // Do nothing - static elements don't affect the document
        }
    }, true /* valuePathOptional */);

})();
