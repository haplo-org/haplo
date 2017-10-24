/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

/* *********************************************
 *
 *  DO NOT MAKE CHANGES TO THIS FILE
 *
 *  UPDATE FROM THE OFORMS DISTRIBUTION USING
 *
 *    lib/tasks/update_oforms.sh
 *
 * ********************************************* */

/*! oForms | (c) Haplo Services Ltd 2012 - 2017 | MIT License */

/////////////////////////////// oforms_preamble.js ///////////////////////////////

(function(root) {

var oForms = root.oForms = {};

/////////////////////////////// utils.js ///////////////////////////////

// Utility functions

var escapeHTML = function(str) {
    return str.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
};

var paragraphTextToHTML = function(text) {
    var output = [];
    _.each((text||'').split(/[\r\n]+/), function(para) {
        output.push('<p>', escapeHTML(para), '</p>');
    });
    return output.join('');
};

var complain = function(code, message) {
    message = message || defaultComplaints[code];
    throw new Error("oForms/"+code+": "+message);
};

var defaultComplaints = {
    "internal": "Internal error"
};

// Output an attribute for HTML generation, if the value is defined.
// In _pushRenderedHTML use like
//    outputAttribute(output, ' id="', this._id);
// Remember the space, = and single quote! This is slightly clumsy, but efficient.
var outputAttribute = function(output, attributeStart, value) {
    if(value) {
        output.push(attributeStart, escapeHTML(value.toString()), '"');
    }
};

// If className defined, return it with a space prepended, otherwise return the empty string
var additionalClass = function(className) {
    return className ? ' '+className : '';
};

// Get a value from an arbitary path
var getByPath = function(context, path) {
    var route = path.split('.');
    var lastKey = route.pop();
    var position = context;
    for(var l = 0; l < route.length && undefined !== position; ++l) {
        position = position[route[l]];
    }
    return position ? position[lastKey] : undefined;
};

// A deep clone function which is good enough to work on the JSON documents we expect
var deepCloneForJSONinner = function(object, recusionLimit) {
    if(recusionLimit <= 0) { complain("clone", "Recursion limit reached, nesting of document too deep or has cycles"); }
    var copy = object;
    if(_.isArray(object)) {
        var len = object.length;
        copy = [];
        for(var i = 0; i < len; ++i) {
            copy[i] = deepCloneForJSONinner(object[i], recusionLimit - 1);
        }
    } else if(_.isObject(object)) {
        copy = {};
        for(var attr in object) {
            if(object.hasOwnProperty(attr)) {
                copy[attr] = deepCloneForJSONinner(object[attr], recusionLimit - 1);
            }
        }
    }
    return copy;
};
var deepCloneForJSON = function(object) {
    return deepCloneForJSONinner(object, 128 /* reasonable recusion limit */);
};

/////////////////////////////// text.js ///////////////////////////////

// Called to translate user visible text
var textTranslate = function(text) { return text; };

oForms.setTextTranslate = function(fn) {
    textTranslate = fn;
};

/////////////////////////////// std_templates ///////////////////////////////

var standardTemplates = {
    'oforms:default': '{{#unless rowsOnly}}{{#if sectionHeading}}<h2>{{sectionHeading}}</h2>{{/if}}<div class="oforms-append{{#if class}} {{class}}{{/if}}"{{#if id}} id="{{id}}"{{/if}}{{#if guidanceNote}} data-oforms-note="{{guidanceNote}}"{{/if}}>{{{extraTopUI}}}{{/unless}}{{#rows}}{{#if ../isRepeatingSection}}<div class="oforms-repetition{{#if ../../hasMultipleElements}} oforms-has-multiple{{/if}}">{{/if}}{{#elements}}<div class="oforms-row control-group{{#if validationFailure}} error{{/if}}">{{#if label}}<label class="control-label">{{label}}{{#if required}}<span class="oforms-required"> *</span>{{/if}}</label>{{/if}}<div class="controls">{{{html}}}{{#if validationFailure}}<div class="oforms-error-message help-block">{{validationFailure.message}}</div>{{/if}}</div></div>{{/elements}}{{#if ../allowDelete}}<a href="#" class="oforms-delete-btn btn btn-small" title="Delete this section"><i class="icon-minus-sign"></i>Delete</a>{{/if}}{{#if ../isRepeatingSection}}</div>{{/if}}{{/rows}}{{#unless rowsOnly}}</div>{{#if allowAdd}}<div><a href="#" class="oforms-add-btn btn btn-small{{#if displayingMaximumRows}} oform-add-btn-disabled{{/if}}" title="Add another section"><i class="icon-plus-sign"></i>Add another</a></div>{{/if}}{{/unless}}',
    'oforms:default:display': '{{#if sectionHeading}}<h2>{{sectionHeading}}</h2>{{/if}}{{#rows}}{{#if ../isRepeatingSection}}<div class="oforms-repetition{{#if ../../hasMultipleElements}} oforms-has-multiple{{/if}}">{{/if}}{{#elements}}<div class="oforms-display-row control-group" data-order="{{orderingIndex}}">{{#if label}}<label class="control-label">{{label}}</label>{{/if}}<div class="controls">{{{html}}}</div></div>{{/elements}}{{#if ../isRepeatingSection}}</div>{{/if}}{{/rows}}',
    'oforms:element': '{{#if renderForm}}<div class="control-group{{#if validationFailure}} error{{/if}}">{{{html}}}{{#if validationFailure}}<span class="oforms-error-message help-block">{{validationFailure.message}}</span>{{/if}}</div>{{else}}{{{html}}}{{/if}}',
    'oforms:grid': '{{#unless rowsOnly}}{{#if sectionHeading}}<h2>{{sectionHeading}}</h2>{{/if}}{{{extraTopUI}}}<table class="oforms-grid oforms-append table table-bordered{{#if class}} {{class}}{{/if}}"{{#if id}} id="{{id}}"{{/if}}{{#if guidanceNote}} data-oforms-note="{{guidanceNote}}"{{/if}}>{{#if options}}<thead><tr class="oforms-grid-headings-row"><th></th>{{#options.headings}}<th>{{this}}</th>{{/options.headings}}</tr></thead>{{/if}}{{/unless}}{{#rows}}{{#elements}}<tr class="oforms-row"><th class="oforms-grid-row-label">{{label}}</th>{{{html}}}</tr>{{/elements}}{{/rows}}{{#unless rowsOnly}}</table>{{/unless}}',
    'oforms:grid:display': '{{#if sectionHeading}}<h2>{{sectionHeading}}</h2>{{/if}}<table class="oforms-display-table oforms-grid table table-bordered">{{#if options}}<thead><tr class="oforms-display-table-headings oforms-grid-headings-row"><th></th>{{#options.headings}}<th>{{this}}</th>{{/options.headings}}</tr></thead>{{/if}}{{#rows}}{{#elements}}<tr class="oforms-row"><th class="oforms-grid-row-label">{{label}}</th>{{{html}}}</tr>{{/elements}}{{/rows}}</table>',
    'oforms:grid:row': '{{#rows}}{{#elements}}<td>{{#if validationFailure}}<span class="oforms-error">{{/if}}{{{html}}}{{#if required}}<span class="oforms-required"> *</span>{{/if}}{{#if validationFailure}}</span><br><span class="oforms-error-message">{{validationFailure.message}}</span>{{/if}}</td>{{/elements}}{{/rows}}',
    'oforms:grid:row:display': '{{#rows}}{{#elements}}<td>{{{html}}}</td>{{/elements}}{{/rows}}',
    'oforms:join': '{{#rows}}{{#elements}}{{#if validationFailure}}<span class="oforms-error">{{/if}}{{{html}}}{{#if validationFailure}}</span>{{/if}}{{/elements}}{{/rows}}{{#rows}}{{#elements}}{{#if validationFailure}}<span class="oforms-error-message help-block">{{validationFailure.message}}</span>{{/if}}{{/elements}}{{/rows}}',
    'oforms:join:display': '{{#rows}}{{#elements}}{{{html}}} {{/elements}}{{/rows}}',
    'oforms:table': '{{#unless rowsOnly}}{{#if sectionHeading}}<h2>{{sectionHeading}}</h2>{{/if}}{{{extraTopUI}}}<table class="oforms-append table table-bordered{{#if class}} {{class}}{{/if}}"{{#if id}} id="{{id}}"{{/if}}{{#if guidanceNote}} data-oforms-note="{{guidanceNote}}"{{/if}}><thead><tr>{{#definitions}}<th>{{label}}{{#if required}}<span class="oforms-required"> *</span>{{/if}}</th>{{/definitions}}{{#if allowDelete}}<th></th>{{/if}}</tr></thead>{{/unless}}{{#rows}}<tr class="oforms-row oforms-repetition">{{#elements}}<td><div class="control-group{{#if validationFailure}} error{{/if}}">{{{html}}}{{#if validationFailure}}<span class="oforms-error-message help-block">{{validationFailure.message}}</span>{{/if}}</div></td>{{/elements}}{{#if ../allowDelete}}<td><a href="#" class="oforms-delete-btn btn btn-small" title="Delete this section"><i class="icon-minus-sign"></i>Delete</a></td>{{/if}}</tr>{{/rows}}{{#unless rowsOnly}}</table>{{#if isRepeatingSection}}{{#if allowAdd}}<div><a href="#" class="oforms-add-btn oforms-table-add-btn btn btn-small{{#if displayingMaximumRows}} oform-add-btn-disabled{{/if}}" title="Add another section"><i class="icon-plus-sign"></i>Add another</a></div>{{/if}}{{/if}}{{/unless}}',
    'oforms:table:display': '{{#if sectionHeading}}<h2>{{sectionHeading}}</h2>{{/if}}<table class="oforms-display-table table table-bordered"><thead><tr class="oforms-display-table-headings">{{#definitions}}<th>{{label}}</th>{{/definitions}}</tr></thead>{{#rows}}<tr>{{#elements}}<td>{{{html}}}</td>{{/elements}}</tr>{{/rows}}</table>'
};

/////////////////////////////// template_impl/handlebars.js ///////////////////////////////

// Registration of the Handlebars helpers is a public API, so it can be used when the delegate takes over the rendering.
// Allow use of a different Handlebars object if required.
oForms.registerHandlebarsHelpers = function(_handlebars) {
    // Make sure the element partial is available and compiled
    var elementPartial = standardTemplates['oforms:element'];
    if(typeof(elementPartial) !== 'function') {
        elementPartial = Handlebars.compile(elementPartial);
    }

    // Use default Handlebars?
    if(!_handlebars) { _handlebars = Handlebars; }

    // Helper to make implementing custom templates a bit simplier.
    // Use like {{oforms_element "name"}} where name is the name of the element.
    // This either works for non-repeating sections, where you just have HTML and these oforms_element statements,
    // and for repeating sections, where you have surrounded them in {{#rows}} ... {{/rows}}
    // The oforms:element paritial is defined so that it works when rendering forms and documents.
    _handlebars.registerHelper('oforms_element', function(element) {
        // Need to pick out this.rows[0].named (by preference) or fall back on this.named
        var rows = this.rows, row = ((rows && rows.length > 0) ? rows[0] : this), named = row.named;
        if(named) {
            return new Handlebars.SafeString(elementPartial(named[element]));
        } else {
            return '';
        }
    });
};

// Renderer setup
var _templateRendererSetup = function() {
    // Register helpers
    oForms.registerHandlebarsHelpers();
    // Turn all the standard templates into compiled templates.
    var compiledStandardTemplates = {};
    _.each(standardTemplates, function(template, name) {
        compiledStandardTemplates[name] = Handlebars.compile(template);
    });
    standardTemplates = compiledStandardTemplates;
    // Don't do this again.
    _templateRendererSetup = function() {};
};

// Renderer implementation
var _templateRendererImpl = function(template, view, output) {
    // Compile the template?
    if(!(template instanceof Function)) {
        template = Handlebars.compile(template);
    }
    // Use the standard templates as partials
    output.push(template(view, {partials: standardTemplates}));
};

/////////////////////////////// template_impl/visibility.js ///////////////////////////////

// Make all the standard templates available to the caller. Useful for when the delegate takes
// over rendering by implementing the formPushRenderedTemplate() function.
var /* seal */ uncompiledStandardTemplates = standardTemplates;
oForms.getStandardTemplates = function() { return uncompiledStandardTemplates; };

/////////////////////////////// measurement_quantities.js ///////////////////////////////

// Tables of units and conversion factors for the measurement Element

// TODO: Allow measurement quanities to be adjusted and extended by users, using options on the FormDescription object

// Each quantity has properties:
//   units - look up of stored symbol to information:
//          display - (optional) text for the symbol is displayed if it is not idential to the stored symbol
//          add - (optional) add this before conversion multiplication
//          multiply - multiply by this to convert to canonical unit
//   canonicalUnit - which unit is canonical
//   defaultUnit - which unit is the default
//   choices - choices for the drop down choices, sets order. May use [string,...] and [[string,string],...] formats

var /* seal */ measurementsQuantities = {

    length: {
        units: {
            mm:   { multiply: 1000 },
            cm:   { multiply: 100 },
            m:    { multiply: 1 },
            km:   { multiply: 0.001 },
            'in': { multiply: 0.0254 },
            ft:   { multiply: 0.3048 },
            yd:   { multiply: 0.9144 },
            mile: { multiply: 1609.344 }
        },
        canonicalUnit: 'm',
        defaultUnit: 'm',
        choices: ['mm','cm','m','km','in','ft','yd','mile']
    },

    time: {
        units: {
            s:   { multiply: 1 },
            m:   { multiply: 60 },
            hr:  { multiply: 3600 },
            day: { multiply: 86400 }
        },
        canonicalUnit: 's',
        defaultUnit: 'hr',
        choices: ['s','m','hr','day']
    },

    mass: {
        units: {
            g:  { multiply: 0.001 },
            kg: { multiply: 1 },
            oz: { multiply: 0.0283495231 },
            lb: { multiply: 0.45359237 }
        },
        canonicalUnit: 'kg',
        defaultUnit: 'kg',
        choices: ['g','kg','oz','lb']
    },

    temperature: {
        units: {
            degC: {
                display: '\u00B0C',
                multiply: 1
            },
            degF: {
                display: '\u00B0F',
                add: -32,
                multiply: (5/9)
            }
        },
        canonicalUnit: 'degC',
        defaultUnit: 'degC',
        choices: [['degC','\u00B0C'],['degF','\u00B0F']]
    }

};

/////////////////////////////// element/base.js ///////////////////////////////

// Filled in as constructors are created
var /* seal */ elementConstructors = {};

// A function to generate the constructors
var makeElementType = oForms._makeElementType = function(typeName, methods, valuePathOptional) {
    var constructor = elementConstructors[typeName] = function(specification, description) {
        // First, copy the properties from the specification which apply to every element
        this.name = specification.name;
        this.label = textTranslate(specification.label);
        this.valuePath = specification.path;
        if(specification.required) {
            // Two flags set, allowing the template to render the marker, but allow the internal mechanism to be sidestepped by elements.
            this.required = true;   // shortcut flag for template rendering
            this._required = specification.required;  // statements used in _doValidation
        }
        this.defaultValue = specification.defaultValue;         // before _createGetterAndSetter() is called
        // And some properties which apply to many elements
        this._id = specification.id;
        this._class = specification["class"]; // reserved word
        this._placeholder = textTranslate(specification.placeholder);
        this._guidanceNote = textTranslate(specification.guidanceNote);
        this._inlineGuidanceNote = (typeof(specification.inlineGuidanceNote) === "string") ? 
            textTranslate(specification.inlineGuidanceNote) :   // simple text need to be translated
            specification.inlineGuidanceNote;                   // view for rendering template, or undefined
        if(this._guidanceNote || this._inlineGuidanceNote) {
            // Guidance notes require client side scripting support, but not bundle support, as they're stored
            // in data attributes or display:none HTML elements.
            description.requiresClientUIScripts = true;
        }
        // Make sure there is a unique name
        if(!this.name) {
            // Automatically generate a name if none is specified
            this.name = description._generateDefaultElementName(specification);
        }
        // Visibility
        if("include" in specification) {
            this.inDocument = this.inForm = specification.include;
        } else {
            this.inDocument = specification.inDocument;
            this.inForm = specification.inForm;
        }
        if(specification.deprecated) {
            if("inDocument" in specification || "inForm" in specification || this.required) {
                complain("spec", "Can't use deprecated with inDocument, inForm or required in element "+this.name);
            }
            this.inDocument = this.inForm = {path:specification.path, operation:"defined"};
        }
        // Make sure names don't include a '.', as this would break client side assumptions
        // unless they've been flagged as being part of a component element, where the dot
        // is needed to separate the name and the 'part' name.
        if(-1 !== this.name.indexOf('.') && !(specification._isWithinCompoundElement)) {
            complain("spec", "The name "+this.name+" shouldn't include a '.' character");
        }
        // Ensure there's a value path, create the getter and setter functions.
        if(this.valuePath) {
            this._createGetterAndSetter(this.valuePath); // after this.defaultValue set
        } else if(!valuePathOptional) {
            complain("spec", "No path specified for element "+this.name);
        }
        // Register element with description to enable lookup by name
        description._registerElement(this); // MUST be before _initElement() for correct ordering
        // Element specification initialisation
        this._initElement(specification, description);
    };
    _.extend(constructor.prototype, ElementBaseFunctions, methods);
    return constructor;
};

// TODO: Finish the conditional statements implementation, maybe just with validation which checks that statements don't refer to anything in a Element further down the form.
// Preliminary implementation has limitations when used as a conditional statement for a require or inForm property:
//  * Can only look at values inside the current context (so no peeking above the current "section with a path")
//  * Only works with values of elements declared *before* this element.
//  * Requires custom UI support (eg only showing * when actually required, or showing and hiding UI)
var evaluateConditionalStatement = function(conditionalStatement, context) {
    // If a simple boolean, return that value
    if(conditionalStatement === true || conditionalStatement === false) { return conditionalStatement; }
    // Otherwise evaluate the (possibly nested) required statements
    var check = function(statement) {
        if(typeof(statement) !== "object") {
            complain("Bad conditional statement: "+statement);
        }
        var r;
        switch(statement.operation) {
            case "defined":
                r = (getByPath(context, statement.path) !== undefined);
                break;
            case "not-defined":
                r = (getByPath(context, statement.path) === undefined);
                break;
            case "=": case "==": case "===":
                r = (getByPath(context, statement.path) === statement.value);
                break;
            case "!=": case "!==":
                r = (getByPath(context, statement.path) !== statement.value);
                break;
            case "AND":
                r = true;
                _.each(statement.statements || [], function(st) {
                    if(!check(st)) { r = false; }
                });
                break;
            case "OR":
                r = false;
                _.each(statement.statements || [], function(st) {
                    if(check(st)) { r = true; }
                });
                break;
            default:
                complain("Unknown required operation: "+statement.operation);
                break;
        }
        return r;
    };
    return check(conditionalStatement);
};

// Base functionality of Elements
var ElementBaseFunctions = {
    // Public properties -- available to templates in the 'definitions' property, eg label is used for column headings.
    //  name - name of element, suitable for outputing as an HTML name element
    //  label - optional label
    //  valuePath - path of the value within the document, relative to the context
    //  required - whether this is a required element
    //  defaultValue - the default value to use if there isn't an element in the document
    //
    // Properties copied from the specification which are used by more than one Element
    //  _id - the id="" attribute for the element - use this._outputCommonAttributes()
    //  _placeholder - the placeholder="" attribute for the element - use this._outputCommonAttributes()
    //  _class - the class="" attribute for the element (added to oForms classes) - use additionalClass(this._class) or this._outputCommonAttributes(output, true)

    // Called by the constructor to create the value getter and setter functions.
    _createGetterAndSetter: function(valuePath) {
        if(valuePath == '.') {
            // Special case for . path, used for repeating-sections over plain values in an array.
            // Get/sets the value from the '.' property, and repeating sections have a matching special case.
            // No support for default values.
            this._getValueFromDoc = function(context) {
                if(undefined === context) { return undefined; }
                return context['.'];
            };
            this._setValueInDoc = function(context, value) {
                if(undefined === value) {
                    delete context['.'];
                } else {
                    context['.'] = value;
                }
            };
        } else {
            // Normal getter and setters.
            // Getter will return the defaultValue if the value === undefined.
            var route = valuePath.split('.');
            var lastKey = route.pop();
            var defaultValue = this.defaultValue;
            this._getValueFromDoc = function(context) {
                var position = context;
                for(var l = 0; l < route.length && undefined !== position; ++l) {
                    position = position[route[l]];
                }
                if(undefined === position) { return undefined; }
                var value = position[lastKey];
                // If the value is undefined, return the default value instead. This may also be undefined.
                return (undefined === value) ? defaultValue : value;
            };
            this._setValueInDoc = function(context, value) {
                var position = context;
                for(var l = 0; l < route.length; ++l) {
                    var nextPosition = position[route[l]];
                    if(undefined === nextPosition) {
                        // Create a new element if there's nothing in the document at this point
                        nextPosition = position[route[l]] = {};
                    }
                    position = nextPosition;
                }
                if(undefined === value) {
                    delete position[lastKey];
                } else {
                    position[lastKey] = value;
                }
            };
        }
    },

    // Default getter function which returns null. This makes sure that every Element has a getter function, so
    // the section renderDocumentOmitEmpty option always has something to check and, for sections, it doesn't return
    // an undefined value which would cause the section to be ommitted.
    _getValueFromDoc: function() {
        return null; // do *NOT* return undefined
    },

    // Bundle up client side resources into a JSON structure.
    // Element information goes in bundle.elements[element_name]
    // emptyInstance is a FormInstance with an empty document, used for rendering.
    // The FormDescription can be accessed through emptyInstance.
    _bundleClientRequirements: function(emptyInstance, bundle) {
        // Do nothing
    },

    // Called by the constructor to initialize the element
    _initElement: function(specification, description) {
    },

    // Push rendered HTML strings to an output array, returns nothing.
    // Implemented this way for speed and space efficiency.
    // validationFailure is undefined for values which haven't failed validation or are the initial
    // values from the form, or the validation error message as a string.
    _pushRenderedHTML: function(instance, renderForm, context, nameSuffix, validationFailure, output) {
        complain("internal");
    },

    // For outputting common attributes
    _outputCommonAttributes: function(output, withClass) {
        outputAttribute(output, ' id="', this._id);
        outputAttribute(output, ' placeholder="', this._placeholder);
        outputAttribute(output, ' data-oforms-note="', this._guidanceNote);
        if(withClass) {
            outputAttribute(output, ' class="', this._class);
        }
    },

    // Must be called first in the _updateDocument function to check conditional in the context containing the element.
    _shouldExcludeFromUpdate: function(context) {
        return ((this.inForm !== undefined) && !(evaluateConditionalStatement(this.inForm, context)));
    },

    // Update the document
    // Returns true if the value should be considered as the user having entered something
    // for determining whether a user has entered in a field.
    _updateDocument: function(instance, context, nameSuffix, submittedDataFn) {
        if(this._shouldExcludeFromUpdate(context)) { return false; }
        // Results of validation are stored in this object by _decodeValueFromFormAndValidate. Keys:
        //    _failureMessage - message to display if it failed
        //    _isEmptyField - true if the field was an empty field
        var validationResult = {};
        // Decode the value and do validation, then store the result in the document.
        var value = this._decodeValueFromFormAndValidate(instance, nameSuffix, submittedDataFn, validationResult);
        this._setValueInDoc(context, value);
        // Handle validation results and required fields, storing any errors in the instance.
        var failureMessage = validationResult._failureMessage;
        if(this._required && !(failureMessage) && evaluateConditionalStatement(this._required, context)) {
            if(undefined === value || validationResult._isEmptyField) {
                failureMessage = 'Required field';
            }
        }
        if(failureMessage) {
            instance._validationFailures[this.name + nameSuffix] = failureMessage;
        }
        // If the value is the default value, assume the user didn't enter it
        return (value !== undefined) && (value !== this.defaultValue);
    },

    // Retrieve the value from the data entered into the form
    _decodeValueFromFormAndValidate: function(instance, nameSuffix, submittedDataFn, validationResult) {
        return undefined;
    },

    _valueWouldValidate: function(value) {
        return (value !== undefined);
    },

    // Elements which override need to check _shouldExcludeFromUpdate() and return true if excluded.
    _wouldValidate: function(instance, context) {
        if(this._shouldExcludeFromUpdate(context)) { return true; }
        var value = this._getValueFromDoc(context);
        if(value === undefined) {
            return !(this._required && evaluateConditionalStatement(this._required, context));
        }
        return this._valueWouldValidate(value);
    },

    _shouldShowAsRequiredInUI: function(context) {
        return this._required && evaluateConditionalStatement(this._required, context);
    },

    // Replace values in a document for the view
    _replaceValuesForView: function(instance, context) {
        // Do nothing in the base class - many elements are quite happy with the value in the document
        // being used as the display value.
    }
};

/////////////////////////////// element/section.js ///////////////////////////////

var SectionElementMethods = {

    _initElement: function(specification, description) {
        // Throw an error if there isn't an element property
        if(!specification.elements) {
            complain("spec", "No elements property specified for section '"+this.name+"'");
        }
        // TODO: Verification of section description - remember this can be the root of the form description
        this._elements = _.map(specification.elements, function(elementSpecification) {
            // Find the constructor for the element, defaulting to a simple text element.
            var Constructor = elementConstructors[elementSpecification.type] || elementConstructors.text;
            // Create the element with the same context as this element
            return new Constructor(elementSpecification, description);
        });
        // Rules for choosing the template:
        // If rendering the form, use template key from specification, or the default template.
        // If displaying the document, use templateDisplay key, but if not set, use what would be used for the form with ':display' appended.
        this._template = (specification.template || "oforms:default");
        this._templateDisplay = (specification.templateDisplay || (this._template + ':display'));
        // Sections can also have headings, as using a label can give results which aren't visually distinctive enough.
        this._heading = textTranslate(specification.heading);
        // When rendering the document, empty values can be omitted for clearer display of sparse data. If true and no values, omit section entirely.
        this._renderDocumentOmitEmpty = specification.renderDocumentOmitEmpty;
        // Pass options to templates
        this._templateOptions = specification.templateOptions;
    },

    _bundleClientRequirements: function(emptyInstance, bundle) {
        for(var m = 0; m < this._elements.length; ++m) {
            this._elements[m]._bundleClientRequirements(emptyInstance, bundle);
        }
    },

    _pushRenderedHTML: function(instance, renderForm, context, nameSuffix, validationFailure, output) {
        var elementsContext = this._getContextFromDoc(context);
        var elements;
        // Special case for when we're rendering the document, and the specification requires that empty values are omitted.
        if(!renderForm && this._renderDocumentOmitEmpty) {
            // Build a new elements array which only includes the elements which have a value
            elements = _.filter(this._elements, function(e) {
                // NOTE: Relies on the default _getValueFromDoc() function to return a non-undefined value for sections.
                return e._getValueFromDoc(elementsContext) !== undefined;
            });
            // If there are no elements which have a value, omit this section entirely.
            if(elements.length === 0) {
                return;
            }
        }
        // For non-repeating sections, there's just a single row.
        var rows = [this._renderRow(instance, renderForm, elementsContext, nameSuffix, elements)];
        this._pushRenderedRowsHTML(instance, renderForm, rows, output, false /* not rows only */, elements);
    },

    _updateDocument: function(instance, context, nameSuffix, submittedDataFn) {
        if(this._shouldExcludeFromUpdate(context)) { return false; }
        var elementsContext = this._getContextFromDoc(context, true /* callerWillBeWritingToTheContext */);
        // For non-repeating sections, there's just a single row.
        // Return the flag from the _updateDocumentRow function to show whether or not the user entered any data in this section
        return this._updateDocumentRow(instance, elementsContext, nameSuffix, submittedDataFn);
    },

    _replaceValuesForView: function(instance, context) {
        var elementsContext = this._getContextFromDoc(context);
        if(!elementsContext) { return; }
        for(var m = 0; m < this._elements.length; ++m) {
            this._elements[m]._replaceValuesForView(instance, elementsContext);
        }
    },

    // Render a row of elements into a view.
    // (Everything is considered a row, whether or not the view is a table.)
    _renderRow: function(instance, renderForm, context, nameSuffix, elements /* optional */) {
        if(!elements) { elements = this._elements; } // optional argument
        var named = {};
        var row = [];
        var validationFailures = instance._validationFailures;
        var conditionalKey = (renderForm ? 'inForm' : 'inDocument');
        for(var m = 0; m < elements.length; ++m) {
            var e = elements[m];
            // Check to see if this element should be rendered in this form or document
            // TODO: Better handling of conditional elements within table style displays -- will need to know about omitted elements and/or entire columns
            var statement = e[conditionalKey];
            if((statement === undefined) || evaluateConditionalStatement(statement, context)) {
                var output = [];
                var validationFailure = validationFailures[e.name+nameSuffix];
                if(renderForm && e._inlineGuidanceNote) {
                    output.push('<a href="#" class="oforms-inline-guidance-view">i</a>');
                }
                e._pushRenderedHTML(instance, renderForm, context, nameSuffix, validationFailure, output);
                if(renderForm && e._inlineGuidanceNote) {
                    output.push('<div class="oforms-inline-guidance" style="display:none">');
                    if(typeof(e._inlineGuidanceNote) === "string") {
                        output.push(paragraphTextToHTML(e._inlineGuidanceNote));
                    } else {
                        var template = instance.description.specification.inlineGuidanceNoteTemplate;
                        if(!template) { complain("spec", "inlineGuidanceNoteTemplate property required at root of specification"); }
                        instance._renderTemplate(template, e._inlineGuidanceNote, output);
                    }
                    output.push('</div>');
                }
                var info = {
                    renderForm: renderForm, // Let the oforms:element template know whether it's rendering a form or not
                    orderingIndex: e._orderingIndex,
                    name: e.name,
                    label: e.label,
                    required: e.required && e._shouldShowAsRequiredInUI(context),
                    validationFailure: validationFailure ? {message:validationFailure} : false,
                    html: output.join('')
                };
                named[e.name] = info;
                row.push(info);
            }
        }
        return {named:named, elements:row};
    },

    // Given rendered rows from _renderRow(), package them up into a view and render it.
    _pushRenderedRowsHTML: function(instance, renderForm, rows, output, rowsOnly, elements /* optional */) {
        if(!elements) { elements = this._elements; } // optional argument
        var view = {
            // Common attributes
            id: this._id, "class": this._class, guidanceNote: this._guidanceNote,
            // Section heading
            sectionHeading: this._heading,
            // Rendering flags
            rowsOnly: (rowsOnly || false),
            // Pass options to the template
            options: this._templateOptions,
            // Rows of elements and rendered values
            rows: rows,
            // Element definitions for headings etc
            definitions: elements
        };
        this._modifyViewBeforeRendering(view, rows);
        // Choose and render the template.
        var templateName = renderForm ? this._template : this._templateDisplay;
        instance._renderTemplate(templateName, view, output);
    },

    _modifyViewBeforeRendering: function(view, rows) {
        // Do nothing in the base class
    },

    // Returns true if any of the _updateDocument() calls returned true to show user has entered something in that element.
    _updateDocumentRow: function(instance, context, nameSuffix, submittedDataFn) {
        var userHasEnteredValue = false;
        for(var m = 0; m < this._elements.length; ++m) {
            if(this._elements[m]._updateDocument(instance, context, nameSuffix, submittedDataFn)) {
                userHasEnteredValue = true;
            }
        }
        return userHasEnteredValue;
    },

    _wouldValidate: function(instance, context) {
        if(this._shouldExcludeFromUpdate(context)) { return true; }
        var nestedContext = this._getContextFromDoc(context, false /* not writing */);
        for(var m = 0; m < this._elements.length; ++m) {
            if(!this._elements[m]._wouldValidate(instance, nestedContext)) {
                return false;
            }
        }
        return true;
    },

    _getContextFromDoc: function(context, callerWillBeWritingToTheContext) {
        if(this.valuePath) {
            // Doesn't use the current context, so get the nested context from the document
            var nestedContext = this._getValueFromDoc(context);
            if(undefined === nestedContext) {
                // If there's no context, make a new one so, when reading, there's something to read from,
                // and when writing, it actually goes in the document to return the values.
                nestedContext = {};
                if(callerWillBeWritingToTheContext) {
                    this._setValueInDoc(context, nestedContext);
                }
            }
            return nestedContext;
        }
        // If there's no value path for this section, then the section will just use the current context
        return context;
    }
};

var /* seal */ SectionElement = makeElementType("section", SectionElementMethods, true /* value path optional */);

/////////////////////////////// element/repeating_section.js ///////////////////////////////

var RepeatingSectionElementMethods = _.extend({}, SectionElementMethods, {

    // The forms system avoids deleting other data in the JSON document, so, to track this,
    // the array elements are held in a "shadow" row inside the instance, then the array in the
    // document formed from this.
    //
    // The shadow row is the definite source for the data, and the array in the document is
    // recreated from the data in the shadow row every time the document is updated.
    //
    // The shadow row contains objects, which have keys:
    //   _data - the original object/value from the JSON document, modified
    //   _inDocument - true if this row is in the document
    //
    // The code is very careful to use the original objects, and not recreate them, so that
    // references held by user code are still valid.

    // ------------------------------------------------------------------------------------------------------

    // Inherits methods from SectionElementMethods

    // Make base class methods available.
    _initElementSectionBase: SectionElementMethods._initElement,
    _bundleClientRequirementsBase: SectionElementMethods._bundleClientRequirements,

    // Normal repeating sections output an empty row so there's always something to fill in
    _shouldOutputEmptyRow: true,

    _initElement: function(specification, description) {
        this._initElementSectionBase(specification, description);
        // Flag bundle requirements in description
        description.requiresBundle = true;
        description.requiresClientUIScripts = true;
        // Options
        this._allowDelete = specification.allowDelete;
        this._allowAdd = ("allowAdd" in specification) ? specification.allowAdd : true;
        this._required = specification.required;    // slightly different handling to normal elements
        this._minimumCount = specification.minimumCount;
        this._maximumCount = specification.maximumCount;
        // Work out if this is an array of values (rather than an array of objects)
        this._isArrayOfValues = ((this._elements.length === 1) && (this._elements[0].valuePath === '.'));
        // TODO: Repeating section validation to ensure that the '.' value path is used correctly.
    },

    _bundleClientRequirements: function(emptyInstance, bundle) {
        // Render a blank row and bundle it in for use when a new row is added on the client side.
        // Use the _!_ marker for the suffix in names for search and replace with the correct
        // suffix for the new row.
        var blankRowHTML = [];
        this._pushRenderedRowsHTML(
            emptyInstance,
            true, // rendering form
            [this._renderRow(emptyInstance, true /* rendering form */, {}, '_!_' /* special marker for suffix */)],
            blankRowHTML,
            true /* only render the row */
        );
        var bundled = bundle.elements[this.name] = {blank: blankRowHTML.join('')};
        // Include relevant validation information
        if(undefined !== this._maximumCount) {
            bundled.maximumCount = this._maximumCount;
        }
        // Section base class
        this._bundleClientRequirementsBase(emptyInstance, bundle);
    },

    _pushRenderedHTML: function(instance, renderForm, context, nameSuffix, validationFailure, output) {
        // Setup for rendering
        var elementContexts = this._getValuesArrayFromDoc(context);
        if(undefined === elementContexts) { elementContexts = []; }
        // Omit empty repeating sections for display?
        if(!renderForm && elementContexts.length === 0 && this._renderDocumentOmitEmpty) {
            return;
        }
        // Get the shadow row
        var shadow = this._getShadowRows(instance, nameSuffix, elementContexts);
        // Work out the indicies of the rows output
        var indicies = [];
        for(var l = 0; l < shadow.length; ++l) {
            // Add the index of this row, only if the row is currently in the document
            // Be tolerant of missing entries in the shadow row.
            if(shadow[l] && shadow[l]._inDocument) {
                indicies.push(l);
            }
        }
        // The client side doesn't know what's the next index, because it can't see the shadow row
        var clientSideNextIndex = shadow.length;
        // Always output at least one row, unless overridden
        if((indicies.length === 0) && this._shouldOutputEmptyRow) {
            indicies.push(shadow.length);   // use an index which isn't already in use
            clientSideNextIndex++;          // to take into account this new blank row
        }
        // Output the containing DIV
        output.push('<div class="oforms-repeat">');
        // For forms, output a hidden value with the indicies of the rows (which must go first in that div)
        if(renderForm) {
            output.push('<input type="hidden" class="oforms-idx" name="', this.name, nameSuffix, '" value="0/',
                indicies.join(' '), '/', clientSideNextIndex, '">');
        }
        // Render each of the visible elements in this section
        var rows = [];
        for(l = 0; l < indicies.length; ++l) {
            var idx = indicies[l];
            var shadowEntry = shadow[idx];
            rows.push(this._renderRow(instance, renderForm, shadowEntry ? shadowEntry._data : {}, nameSuffix+'.'+idx));
        }
        this._pushRenderedRowsHTML(instance, renderForm, rows, output);
        // Finish the HTML output by closing the containing DIV
        output.push('</div>');
    },

    _updateDocument: function(instance, context, nameSuffix, submittedDataFn) {
        if(this._shouldExcludeFromUpdate(context)) { return false; }
        var isArrayOfValues = this._isArrayOfValues;
        var elementContexts = this._getValuesArrayFromDoc(context);
        var arrayWasCreated;
        if(elementContexts === undefined) {
            elementContexts = [];
            arrayWasCreated = true;
        }
        // Get the shadow row, which contains the actual data for rendering
        var shadow = this._getShadowRows(instance, nameSuffix, elementContexts);
        // Mark all the shadow row entries as not in the document
        for(var l = 0; l < shadow.length; ++l) {
            // Ensure there's an entry for each index into the shadow row, then set the flag to false
            if(!shadow[l]) { shadow[l] = {_data:{}}; }
            shadow[l]._inDocument = false;
        }
        // Get the list of rows in the form
        var formRowData = (submittedDataFn(this.name + nameSuffix) || '').split('/');
        var formRowIndicies = (!(formRowData[1]) || formRowData[1].length === 0) ? [] : formRowData[1].split(' '); // check first because "".split() returns [""] not []
        // Read back the rows, using the form row indicies given, and updating the elements
        // in the shadow row and rebuilding the original array object.
        elementContexts.length = 0; // truncate to the empty array
        var userHasEnteredValue = false;
        for(l = 0; l < formRowIndicies.length; ++l) {
            var rowIndex = formRowIndicies[l] * 1; // convert to int
            // Make sure there's a shadow row entry for this element, which might have been created on the client side
            var shadowEntry = shadow[rowIndex];
            if(undefined === shadowEntry) {
                shadow[rowIndex] = shadowEntry = {
                    _data: {},
                    _inDocument: false   // updated next
                };
            }
            // Store the current validation failures, so changes by this document row can be
            // discarded if it doesn't have any user entered values at all. This isn't the most
            // elegant or object orientated way of doing it, but avoids a heavyweight implementation.
            var currentValidationFailures = instance._validationFailures;
            instance._validationFailures = {};
            // Retrieve the value and update shadow row entry status
            if(this._updateDocumentRow(instance, shadowEntry._data, nameSuffix+'.'+rowIndex, submittedDataFn)) {
                // User has entered a value somewhere in the row, so mark it as being in the document
                shadowEntry._inDocument = true;
                // Push the value into the original array in the document.
                elementContexts.push(isArrayOfValues ? shadowEntry._data['.'] : shadowEntry._data);
                // Merge in the validation failures
                instance._validationFailures = _.extend(currentValidationFailures, instance._validationFailures);
                // Flag that the user has entered a value
                userHasEnteredValue = true;
            } else {
                // No values - discard validation failures in this row by simply putting back the
                // original set of validation failures.
                instance._validationFailures = currentValidationFailures;
            }
        }
        // Handle the case when the original document didn't contain an array.
        if(arrayWasCreated) {
            // Insert the array into the document - only works if there's a value path set for this
            // repeating section.
            this._setValueInDoc(context, elementContexts);
        }
        // Perform validation -- have to do it all 'manually' as we're overriding everything in the base class.
        var min = this._minimumCount, max = this._maximumCount;
        var failureMessage;
        if(undefined !== min && elementContexts.length < min) {
            // If there is required property, and it evaluates to false, ignore the minimum count
            if((this._required === undefined) || (evaluateConditionalStatement(this._required, context) !== false)) {
                failureMessage = 'Not enough entries, ' + min + ' required';
            }
        } else if(undefined !== max && elementContexts.length > max) {
            failureMessage = 'Too many entries, ' + max + ' maximum';
        }
        if(failureMessage) {
            instance._validationFailures[this.name + nameSuffix] = failureMessage;
        }
        // Return the user entered value flag
        return userHasEnteredValue;
    },

    _replaceValuesForView: function(instance, context) {
        var elementContexts = this._getValuesArrayFromDoc(context);
        if(!elementContexts) { return; }
        var c, m;
        for(c = 0; c < elementContexts.length; ++c) {
            for(m = 0; m < this._elements.length; ++m) {
                this._elements[m]._replaceValuesForView(instance, elementContexts[c]);
            }
        }
    },

    _getShadowRows: function(instance, nameSuffix, elementContexts) {
        // Ensure lookup dictionary in instance is created
        var shadowRows = instance._sectionShadowRows;
        if(undefined === shadowRows) {
            instance._sectionShadowRows = shadowRows = {};
        }
        // Make the shadow row, if it doesn't already exist
        var key = this.name+nameSuffix;
        var shadow = shadowRows[key];
        var isArrayOfValues = this._isArrayOfValues;
        if(undefined === shadow) {
            shadowRows[key] = shadow = [];
            for(var l = 0; l < elementContexts.length; ++l) {
                shadow[l] = {
                    _data: isArrayOfValues ? {'.':elementContexts[l]} : elementContexts[l], // Wrap simple values in objects
                    _inDocument: true
                };
            }
        }
        return shadow;
    },

    _getValuesArrayFromDoc: function(context) {
        return this.valuePath ? this._getValueFromDoc(context) : [context];
    },

    _modifyViewBeforeRendering: function(view, rows) {
        // Flag that this is a repeating section to the template
        view.isRepeatingSection = true;
        // Does it have more than one element?
        view.hasMultipleElements = (this._elements.length > 1);
        // Add options to view
        view.allowDelete = this._allowDelete;
        view.allowAdd = this._allowAdd;
        if(undefined !== this._maximumCount && rows.length >= this._maximumCount) {
            view.displayingMaximumRows = true;
        }
    },

    _wouldValidate: function(instance, context) {
        if(this._shouldExcludeFromUpdate(context)) { return true; }
        var elementContexts = this._getValuesArrayFromDoc(context);
        if(undefined === elementContexts) { elementContexts = []; }
        // Validate counts
        var min = this._minimumCount, max = this._maximumCount;
        if(undefined !== min && elementContexts.length < min) {
            // If there is required property, and it evaluates to false, ignore the minimum count
            if((this._required === undefined) || (evaluateConditionalStatement(this._required, context) !== false)) {
                return false;
            }
        } else if(undefined !== max && elementContexts.length > max) {
            return false;
        }
        // Validate rows
        var c, m;
        for(c = 0; c < elementContexts.length; ++c) {
            for(m = 0; m < this._elements.length; ++m) {
                if(!this._elements[m]._wouldValidate(instance, elementContexts[c])) {
                    return false;
                }
            }
        }
        return true;
    }
});

makeElementType("repeating-section", RepeatingSectionElementMethods);

/////////////////////////////// element/file_repeating_section.js ///////////////////////////////

var FileRepeatingSectionElementMethods = _.extend({}, RepeatingSectionElementMethods, {

    _initElementRepeating: RepeatingSectionElementMethods._initElement,
    _modifyViewBeforeRenderingRepeating: RepeatingSectionElementMethods._modifyViewBeforeRendering,

    // Because a file upload is expected, file repeating sections shouldn't output the empty row
    _shouldOutputEmptyRow: false,

    _initElement: function(specification, description) {
        this._initElementRepeating(specification, description);
        // Mark that this requires the file upload scripts (even though the nested file element will require this too)
        description.requiresClientFileUploadScripts = true;
    },

    _modifyViewBeforeRendering: function(view, rows) {
        this._modifyViewBeforeRenderingRepeating(view, rows);
        // Add a div to contain the UI, filled in on the client side
        view.extraTopUI = '<div class="oforms-repeat-file-ui"></div>';
    }
});

makeElementType("file-repeating-section", FileRepeatingSectionElementMethods);

/////////////////////////////// element/static.js ///////////////////////////////

makeElementType("static", {

    // Specification options:
    //   text - text to display within paragraph elements. Newlines start new paragraphs.
    //   html - HTML to output exactly as is
    //   display - where to display it: "form", "document" or "both" as shortcuts for inForm & inDocument

    _initElement: function(specification, description) {
        this._text = textTranslate(specification.text);
        this._html = specification.html;
        // Either use inForm & inDocument, or use display property to set them.
        if(("inForm" in specification) || ("inDocument" in specification)) {
            if("display" in specification) {
                complain("spec", "Can't use inForm or inDocument when you use display property in "+this.name);
            }
        } else {
            switch(specification.display) {
                case "both": /* do nothing, default is both */ break;
                case "document": this.inForm = false; break;
                default: this.inDocument = false; break;
            }
        }
    },

    _pushRenderedHTML: function(instance, renderForm, context, nameSuffix, validationFailure, output) {
        if(this._text) {
            output.push(
                '<p>',
                _.map(this._text.split(/[\r\n]+/), function(p) { return escapeHTML(p); }) .join('</p><p>'),
                '</p>'
            );
        }
        if(this._html) {
            output.push(this._html);
        }
    },

    _updateDocument: function(instance, context, nameSuffix, submittedDataFn) {
        // Do nothing - static elements don't affect the document
    },

    _wouldValidate: function(instance, context) {
        return true;
    }

}, true /* value path optional */);

/////////////////////////////// element/display_value.js ///////////////////////////////

makeElementType("display-value", {

    // Specification options:
    //   as - if "html", don't HTML escape the value

    _initElement: function(specification, description) {
        this._escapeHtml = (specification.as !== "html");
    },

    _pushRenderedHTML: function(instance, renderForm, context, nameSuffix, validationFailure, output) {
        var value = this._getValueFromDoc(context);
        if(value === null || value === undefined) { value = ""; }
        var outputText = this._escapeHtml ? escapeHTML(""+value) : ""+value;
        output.push(outputText);
    },

    _updateDocument: function(instance, context, nameSuffix, submittedDataFn) {
        if(this._shouldExcludeFromUpdate(context)) { return false; }
        // If there is a value in the document, it should count as the user having entered something.
        // This is so repeating sections won't delete rows with displayed data.
        var value = this._getValueFromDoc(context);
        return (value !== null) && (value !== undefined);
    }

});

/////////////////////////////// element/text.js ///////////////////////////////

var /* seal */ TEXT_WHITESPACE_FUNCTIONS = {
    trim: function(text) {
        // Removing leading and trailing whitespace
        return text.replace(/^\s+|\s+$/g,'');
    },
    minimise: function(text) {
        // Remove leading and trailing whitespace, and replace multiple whitespace characters with a single space.
        return text.replace(/^\s+|\s+$/g,'').replace(/\s+/g,' ');
    }
};
TEXT_WHITESPACE_FUNCTIONS.minimize = TEXT_WHITESPACE_FUNCTIONS.minimise;    // US English alternative

// ----------------------------------------------------------------------------------------------------------

makeElementType("text", {

    _initElement: function(specification, description) {
        // Options
        this._htmlPrefix = specification.htmlPrefix || '';
        this._htmlSuffix = specification.htmlSuffix || '';
        if(specification.whitespace) {
            this._whitespaceFunction = TEXT_WHITESPACE_FUNCTIONS[specification.whitespace];
            if(!this._whitespaceFunction) {
                complain("spec", "Text whitespace option "+specification.whitespace+" not known.");
            }
        }
        if(specification.validationRegExp) {
            this._validationRegExp = new RegExp(specification.validationRegExp, specification.validationRegExpOptions || '');
            this._validationFailureMessage = specification.validationFailureMessage || 'Incorrect format';
        }
    },

    _pushRenderedHTML: function(instance, renderForm, context, nameSuffix, validationFailure, output) {
        var value = this._getValueFromDoc(context);
        if(undefined === value) {
            value = '';
        } else if(typeof value !== "string") {
            value = value.toString();
        }
        if(renderForm) {
            output.push(this._htmlPrefix, '<input type="text" name="', this.name, nameSuffix, '" value="', escapeHTML(value), '"');
            this._outputCommonAttributes(output, true /* with class */);
            output.push('>', this._htmlSuffix);
        } else {
            output.push(this._htmlPrefix, escapeHTML(value), this._htmlSuffix);
        }
    },

    _decodeValueFromFormAndValidate: function(instance, nameSuffix, submittedDataFn, validationResult) {
        var text = submittedDataFn(this.name + nameSuffix);
        // Whitespace processing - must be performed first
        if(this._whitespaceFunction) {
            text = this._whitespaceFunction(text);
        }
        // Shortcut return now if text is empty, required field validation happens in base.js
        if(text.length === 0) {
            return undefined;
        }
        // Validation regexp?
        if(this._validationRegExp) {
            if(!(this._validationRegExp.test(text))) {
                validationResult._failureMessage = this._validationFailureMessage;
            }
        }
        return text;
    }
});

/////////////////////////////// element/paragraph.js ///////////////////////////////

makeElementType("paragraph", {

    _initElement: function(specification, description) {
        // Options
        this._rows = (specification.rows || 4) * 1; // default to 4, ensure it's a number to avoid accidental XSS, however unlikely
    },

    _pushRenderedHTML: function(instance, renderForm, context, nameSuffix, validationFailure, output) {
        var value = this._getValueFromDoc(context);
        if(undefined === value) {
            value = '';
        } else if(typeof value !== "string") {
            value = value.toString();
        }
        if(renderForm) {
            output.push('<textarea name="', this.name, nameSuffix, '" rows="', this._rows, '"');
            this._outputCommonAttributes(output, true /* with class */);
            output.push('>', escapeHTML(value), '</textarea>');
        } else {
            // Output escaped HTML with paragraph tags for each bit of the text
            _.each(value.split(/[\r\n]+/), function(para) {
                output.push('<p>', escapeHTML(para), '</p>');
            });
        }
    },

    _decodeValueFromFormAndValidate: function(instance, nameSuffix, submittedDataFn, validationResult) {
        var text = submittedDataFn(this.name + nameSuffix);
        // Turn any line endings into single \n -- including removing \r's from IE
        return (text.length > 0) ? text.replace(/[\r\n]+/g,"\n") : undefined;
    }
});

/////////////////////////////// element/boolean.js ///////////////////////////////

makeElementType("boolean", {

    _initElement: function(specification, description) {
        this._trueLabel  = escapeHTML(textTranslate(specification.trueLabel  || 'Yes'));
        this._falseLabel = escapeHTML(textTranslate(specification.falseLabel || 'No'));
        if(specification.style === "confirm") {
            this._isConfirmation = true;
            this._notConfirmedMessage = specification.notConfirmedMessage; // doesn't require escaping
            this._required = true;  // element is required (makes _wouldValidate() work)
        }
        if((specification.style === "checkbox") || this._isConfirmation) {
            this._checkboxStyle = true;
            // Move the label to the element
            this._cbLabel = this.label;
            this.label = '';
        }
    },

    _pushRenderedHTML: function(instance, renderForm, context, nameSuffix, validationFailure, output) {
        var value = this._getValueFromDoc(context);
        if(renderForm) {
            if(this._checkboxStyle) {
                output.push('<span class="oforms-checkbox', additionalClass(this._class), '"');
                this._outputCommonAttributes(output);
                output.push('><label class="checkbox"><input type="checkbox" name="', this.name, nameSuffix, '" value="t"', ((value === true) ? ' checked' : ''),
                    '>', this._cbLabel, '</span>');
            } else {
                output.push('<span class="oforms-boolean', additionalClass(this._class), '"');
                this._outputCommonAttributes(output);
                output.push(
                    '>',
                        '<label class="radio"><input type="radio" name="', this.name, nameSuffix, '" value="t"', ((value === true) ? ' checked' : ''),  '>', this._trueLabel,  '</label>',
                        '<label class="radio"><input type="radio" name="', this.name, nameSuffix, '" value="f"', ((value === false) ? ' checked' : ''), '>', this._falseLabel, '</label>',
                    '</span>'
                );
            }
        } else {
            if(value !== undefined) {
                output.push(value ? this._trueLabel : this._falseLabel);
            }
        }
    },

    _replaceValuesForView: function(instance, context) {
        var value = this._getValueFromDoc(context);
        if(undefined === value) { return; }
        this._setValueInDoc(context, value ? this._trueLabel : this._falseLabel);
    },

    _decodeValueFromFormAndValidate: function(instance, nameSuffix, submittedDataFn, validationResult) {
        var text = submittedDataFn(this.name + nameSuffix);
        if(text === 't') { return true; }
        // If it's a checkbox, it wasn't checked if we get this far. So if it's a style:"confirm" element, validation has failed.
        if(this._isConfirmation) {
            validationResult._failureMessage = this._notConfirmedMessage || 'Required';
            return undefined;
        }
        // If this is a checkbox, then no parameter means false
        if((text === 'f') || this._checkboxStyle) { return false; }
        return undefined;
    },

    _valueWouldValidate: function(value) {
        if(this._isConfirmation && (value !== true)) { return false; }
        return (value !== undefined);
    }
});

/////////////////////////////// element/number.js ///////////////////////////////

// Implements number and integer element types.

// Use class property in specification along with custom CSS to change field width.

var makeNumberElementType = function(typeName, validationRegExp, validationFailureMessage) {

    makeElementType(typeName, {

        _initElement: function(specification, description) {
            this._minimumValue = specification.minimumValue;
            this._maximumValue = specification.maximumValue;
            this._htmlPrefix = specification.htmlPrefix || '';
            this._htmlSuffix = specification.htmlSuffix || '';
        },

        _pushRenderedHTML: function(instance, renderForm, context, nameSuffix, validationFailure, output) {
            var value = this._getValueFromDoc(context);
            if(renderForm) {
                output.push(this._htmlPrefix, '<input type="text" class="oforms-number', additionalClass(this._class), '" name="', this.name, nameSuffix, '" value="');
                var enteredText = instance._rerenderData[this.name + nameSuffix];
                if(enteredText) {
                    // Repeat what the user entered when validation failed
                    output.push(escapeHTML(enteredText));
                } else if(typeof(value) === "number") {
                    // Output a number
                    output.push(value); // no escaping needed
                }
                output.push('"');
                this._outputCommonAttributes(output);
                output.push('>', this._htmlSuffix);
            } else {
                if(value !== undefined && value !== null) {
                    output.push(this._htmlPrefix, escapeHTML(value.toString()), this._htmlSuffix);
                }
            }
        },

        _decodeValueFromFormAndValidate: function(instance, nameSuffix, submittedDataFn, validationResult) {
            // Retrieve the text field from the document
            var text = submittedDataFn(this.name + nameSuffix);
            // Validate it against the regexp
            var m = text.match(validationRegExp);
            if(m && m[1].length > 0) {
                // The string is a valid number/integer - turn it into a number then check it against the min and max values
                var value = 1 * m[1];
                var min = this._minimumValue, max = this._maximumValue;
                if(undefined !== min && value < min) {
                    validationResult._failureMessage = 'Must be at least ' + min;
                } else if(undefined !== max && value > max) {
                    validationResult._failureMessage = 'Must be no more than ' + max;
                }
                return value;
            } else {
                // Value isn't valid. Store validation failure information so the base can decide what to do.
                if(text.length === 0) {
                    validationResult._isEmptyField = true;
                } else {
                    // Store the the entered text so it can be output in the re-rendered form
                    instance._rerenderData[this.name + nameSuffix] = text;
                    // Set failure message
                    validationResult._failureMessage = validationFailureMessage;
                }
                return undefined;
            }
        }
    });

};

makeNumberElementType("number",  /^\s*(\-?\d*\.?\d*)\s*$/, 'Number required, using numeric digits only');
makeNumberElementType("integer", /^\s*(\-?\d+)\s*$/,       'Whole number required');

/////////////////////////////// element/date.js ///////////////////////////////

var /* seal */ MONTH_NAMES_DISP = ['', 'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sept','Oct','Nov','Dec'];

var validateDate = function(dateStr) {
    var isValidDate = false;
    if(dateStr && dateStr.match(/^\d\d\d\d-\d\d-\d\d$/)) {
        // Attempt check the date is actually valid
        var c = dateStr.split('-');
        var testYear = 2000+((1*c[0]) % 1000);  // Work within supported range of dates
        var testMonth = (1*c[1]) - 1;
        var testDay = 1*c[2];
        try {
            var d = new Date(testYear, testMonth, testDay);
            if(d && (d.getFullYear() === testYear) && (d.getMonth() === testMonth) && (d.getDate() === testDay)) {
                isValidDate = true;
            }
        } catch(e) {
            // if there's an exception, isValidDate won't be set to true
        }
    }
    return isValidDate;
};

// ------------------------------------------------------------------------------------------------------------

makeElementType("date", {

    _initElement: function(specification, description) {
        description.requiresClientUIScripts = true;
    },

    _pushRenderedHTML: function(instance, renderForm, context, nameSuffix, validationFailure, output) {
        var value = this._getValueFromDoc(context);
        var displayDate;
        if(typeof value === "string" && validateDate(value)) {
            var ymd = value.split('-');
            // TODO: Support non-English date formats
            displayDate = ymd[2]+' '+MONTH_NAMES_DISP[1*ymd[1]]+' '+ymd[0];
        } else {
            value = '';
        }
        if(validationFailure) {
            // If re-rendering a form with invalid data, repeat the text the user entered
            displayDate = instance._rerenderData[this.name + nameSuffix] || '';
        }
        if(renderForm) {
            output.push('<span class="oforms-date', additionalClass(this._class), '"');
            outputAttribute(output, ' id="', this._id);
            output.push('><input type="hidden" name="', this.name, nameSuffix, '" value="', escapeHTML(value),
                // Note that displayDate could be any old string recieved from the user
                '"><input type="text" name="', this.name, '.d', nameSuffix, '" class="oforms-date-input" value="', escapeHTML(displayDate || ''), '"');
            outputAttribute(output, ' placeholder="', this._placeholder);
            outputAttribute(output, ' data-oforms-note="', this._guidanceNote);
            output.push('></span>');
        } else {
            if(displayDate) {
                output.push(escapeHTML(displayDate));
            }
        }
    },

    _decodeValueFromFormAndValidate: function(instance, nameSuffix, submittedDataFn, validationResult) {
        var dateStr = submittedDataFn(this.name + nameSuffix);
        if(validateDate(dateStr)) {
            return dateStr;
        } else if(dateStr) {
            // If the user entered something, tell them it was invalid.
            validationResult._failureMessage = 'Not a valid date';
            // And store their entered data for when it's rendered again.
            instance._rerenderData[this.name + nameSuffix] = submittedDataFn(this.name + '.d' + nameSuffix);
            return undefined;
        }
    },

    _replaceValuesForView: function(instance, context) {
        var value = this._getValueFromDoc(context);
        if(typeof value === "string" && validateDate(value)) {
            var ymd = value.split('-');
            // TODO: Support non-English date formats in date view representation
            var viewDate = ymd[2]+' '+MONTH_NAMES_DISP[1*ymd[1]]+' '+ymd[0];
            this._setValueInDoc(context, viewDate);
        }
    },

    _valueWouldValidate: function(value) {
        return (value !== undefined) && validateDate(value);
    }
});

/////////////////////////////// element/measurement.js ///////////////////////////////

makeElementType("measurement", {

    // Specification options:
    //   quantity - which quantity should be measured
    //   integer - true if the value should be an integer
    //   defaultUnit - which unit should be used by default
    //   includeCanonical - true if the value should include the measurement converted to the canonical units, with the unit name as property name

    // Implementation notes:
    //   * Composed of a number and choice element
    //   * When decoding from the form, the value object is presentated to the number and choice elements as their context
    //   * Some fun and games around handling the validation failures, see comments in _decodeValueFromFormAndValidate()
    //   * Choice of unit is stored for rerendering in every case.

    // TODO: Consider validating the units input. Currently if the browser sends something not in the list, exceptions about undefined values will be thrown.

    // TODO: Can minimum and maximum values be done nicely here? Would have to specify a unit and convert as appropraite. Error messages should use the units the user chose.

    _initElement: function(specification, description) {
        // Options
        this._includeCanonical = specification.includeCanonical;
        // Get quantity information
        var qi = this._quantityInfo = measurementsQuantities[specification.quantity];
        if(!(qi)) {
            complain("spec", "Measurement quantity "+specification.quantity+" not known");
        }
        // Build number and choice specifications for the elements forming this compound element
        var numberSpec = {
            name: this.name + ".v", _isWithinCompoundElement: true,
            required: this._required,   // see comments in _decodeValueFromFormAndValidate()
            id: this._id, placeholder: this._placeholder, // but not this._class
            path: 'value'
        };
        delete this._required;          // see comments in _decodeValueFromFormAndValidate()
        var choiceSpec = {
            name: this.name + ".u", _isWithinCompoundElement: true,
            path: 'units',
            prompt: false,
            choices: qi.choices,
            defaultValue: specification.defaultUnit || qi.defaultUnit
        };
        // Make number and choice elements -- specification might mean the number is an integer
        this._numberElement = new (elementConstructors[specification.integer ? "integer" : "number"])(numberSpec, description);
        this._choiceElement = new (elementConstructors["choice"])(choiceSpec, description);
    },

    _pushRenderedHTML: function(instance, renderForm, context, nameSuffix, validationFailure, output) {
        var value = this._getValueFromDoc(context);
        if(undefined === value) {
            value = {};
            var previouslySubmittedUnits = instance._rerenderData[this.name+nameSuffix];
            if(previouslySubmittedUnits) {
                value.units = previouslySubmittedUnits;
            }
        }
        output.push('<span class="oforms-measurement', additionalClass(this._class), '">');
        if(renderForm) {
            var validationFailures = instance._validationFailures;
            // Some day we might find a unit which needs the elements output in a different order.
            // Will add a flag into the measurement info to trigger this.
            this._numberElement._pushRenderedHTML(instance, renderForm, value /* context */, nameSuffix, validationFailures[this._numberElement.name+nameSuffix], output);
            this._choiceElement._pushRenderedHTML(instance, renderForm, value /* context */, nameSuffix, validationFailures[this._choiceElement.name+nameSuffix], output);
        } else {
            if(typeof(value.value) === "number") {
                output.push(value.value);
                if(typeof(value.units) === "string") {
                    // Output units using the display name, if it has one.
                    output.push(' ', escapeHTML(this._quantityInfo.units[value.units].display || value.units));
                }
            }
        }
        output.push('</span>');
    },

    _decodeValueFromFormAndValidate: function(instance, nameSuffix, submittedDataFn, validationResult) {
        // Fill in the value, which is an object, by presenting it to the two elements as their context
        var value = {};
        this._numberElement._updateDocument(instance, value /* context */, nameSuffix, submittedDataFn);
        this._choiceElement._updateDocument(instance, value /* context */, nameSuffix, submittedDataFn);
        // Store the units in case they're needed for rerendering
        instance._rerenderData[this.name+nameSuffix] = value.units;
        // Use the validation failure message from the number field so the message is displayed,
        // for this field.
        // The number field's validation failure isn't rendered by the template, as that element
        // is rendered here without going through the template.
        // Note that the number field also handles the "required" constraint, so the property is
        // moved to the number field specification and deleted from this element.
        var validationFailures = instance._validationFailures;
        var numberValidationFailure = validationFailures[this._numberElement.name+nameSuffix];
        if(numberValidationFailure) {
            validationResult._failureMessage = numberValidationFailure;
        }
        // Return quickly if the number wasn't decoded successfully
        if(undefined === value.value) { return undefined; }
        // Add value converted to canonical units?
        if(this._includeCanonical) {
            var qi = this._quantityInfo;
            var ui = qi.units[value.units];
            value[qi.canonicalUnit] = ui.add ? ((value.value + ui.add) * ui.multiply) : (value.value * ui.multiply);
        }
        return value;
    }
});

/////////////////////////////// element/choice.js ///////////////////////////////
//
// Features, constraints, etc:
//
//   Cannot use the empty string as an id.
//
//   Choices can be a string, which refers to an "instance choices" array (format as below) set with instance.choices(name, choices).
//   Instance choices cannot used within a repeating section.
//
//   Choices can be an array of:
//      Simple text choices, used for display and as the value
//      Arrays, in the form [id,display]
//      Objects, with 'id' and 'name' properties, unless overridden in specification with objectIdProperty and objectDisplayProperty.
//
//   If the id of the first element in the array is a number, then the value is converted to an number. Otherwise id is always a string.
//
//   If specification.prompt === false, there will not be a prompt as the first option in the <select>.
//
//   If using a radio style, radioGroups can be set to display the choices in the specified number of columns.
//

// ------------------------------------------------------------------------------------------------------------

// NOTE: These test functions return false if the choices array is empty, but this won't make a difference in the code below.
var choicesArrayOfArrays = function(choices) {
    return choices.length > 0 && _.isArray(choices[0]);
};
var choicesArrayOfObjects = function(choices) {
    return choices.length > 0 && typeof(choices[0]) === 'object';
};

// ------------------------------------------------------------------------------------------------------------

// The valid styles for choice Elements, which also translates the aliases.
var /* seal */ CHOICE_STYLES = {
    "select": "select",
    "multiple": "multiple",
    "radio": "radio-vertical", // short alias for the most likely radio form
    "radio-vertical": "radio-vertical",
    "radio-horizontal": "radio-horizontal"
};

// ------------------------------------------------------------------------------------------------------------

makeElementType("choice", {

    _initElement: function(specification, description) {
        // TODO: More flexible choices specification, local to instance, data source
        this._choices = specification.choices;
        this._style = CHOICE_STYLES[specification.style || 'select'];
        if(!this._style) {
            complain("spec", "Unknown choice style "+specification.style);
        }
        this._radioGroups = specification.radioGroups;
        if(this._radioGroups) {
            // If radio groups is used, force the style to radio-vertical, otherwise it won't look right
            this._style = 'radio-vertical';
        }
        // Determine the prompt for the first element of the <select> tag, using default if not set.
        var prompt = specification.prompt;
        if(prompt === false) {
            this._prompt = false;   // means no prompt
        } else if(typeof(prompt) === 'string') {
            this._prompt = escapeHTML(prompt);
        } else {
            this._prompt = ' -- select --'; // any other kind of value, just use the default
        }
        // Property names for objects
        // TODO: Get property names for objects from data source if not in specification
        this._objectIdProperty = specification.objectIdProperty || 'id';
        this._objectDisplayProperty = specification.objectDisplayProperty || 'name';
        // Validation (multiple style only)
        this._minimumCount = specification.minimumCount;
        this._maximumCount = specification.maximumCount;
    },

    _pushRenderedHTML: function(instance, renderForm, context, nameSuffix, validationFailure, output) {
        var value = this._getValueFromDoc(context);
        var style = this._style;
        if(renderForm) {
            var choices = this._getChoices(instance);

            // When rendering repeated sections for the bundle, the instance choices aren't known, and need to
            // be filled in client side.
            var emptyChoicesNeedFill = '';
            if(!choices) {
                if((typeof(this._choices) === 'string') && instance._isEmptyInstanceForBundling) {
                    if(style !== "select") {
                        // TODO: Allow non-select instance choices in repeated sections by completing the client side code
                        complain("Instance choices can only be used in a repeated section when they use the select style.");
                    }
                    choices = [];
                    emptyChoicesNeedFill = ' data-oforms-need-fill="1"';
                } else {
                    complain("Failed to determine choices");
                }
            }

            // Start the Element and set up the HTML snippets according to the style chosen
            var html1, htmlSelected, html2, endHTML,
                groupingCount,      // for radio style, how many of the choices go in a group
                groupingNext = -1;  // count of how many cells to go before outputting new cell. -1 means === 0 condition will never be met
            if(style === "select") {
                // Select style
                output.push('<select name="', this.name, nameSuffix, '"', emptyChoicesNeedFill);
                this._outputCommonAttributes(output, true /* with class */);
                output.push('>');
                // Only the select style uses a prompt
                if(this._prompt !== false) { // explicit check with false
                    output.push('<option value="">', this._prompt /* already HTML escaped */, '</option>');
                }
                html1 = '<option value="';
                htmlSelected = '" selected>';
                html2 = '</option>';
                endHTML = '</select>';
            } else if(style === "multiple") {
                // NOTE: Reuses radio-vertical styles
                output.push('<div class="oforms-radio-vertical', additionalClass(this._class), '">');
                var multipleHTMLStart = '<label class="radio"><input type="checkbox" name="'+this.name+nameSuffix+',';
                var multipleNameIndex = 0;
                html1 = function() { return multipleHTMLStart+(multipleNameIndex++)+'" value="'; };
                htmlSelected = '" checked>';
                html2 = '</label>';
                endHTML = '</div>';
                // Make sure the value is an array
                if(!value) {
                    value = [];
                } else if(!_.isArray(value)) {
                    value = [value];
                }
            } else {
                // Vertical or horizontal radio style
                var element = (style === 'radio-vertical') ? 'div' : 'span';
                output.push('<', element, ' class="oforms-', style, additionalClass(this._class), '"');
                this._outputCommonAttributes(output);
                output.push('>');
                html1 = '<label class="radio"><input type="radio" name="'+this.name+nameSuffix+'" value="';
                htmlSelected = '" checked>';
                html2 = '</label>';
                endHTML = '</'+element+'>';
                // Grouping?
                if(this._radioGroups) {
                    output.push('<table class="oforms-radio-grouping"><tr><td>');
                    groupingNext = groupingCount = Math.ceil(choices.length / (1 * this._radioGroups));
                    endHTML = '</td></tr></table>' + endHTML;
                }
            }

            // Mutiple style needs different test
            var valueIsSelected = (style === "multiple") ?
                function(v) { return -1 !== _.indexOf(value, v); } :
                function(v) { return v === value; };
            // Make a function to create the starting HTML
            var startHtml = (typeof(html1) === "function") ?
                html1 :
                function() { return html1; };

            // Output all the choices
            // NOTE: ids used in the value attribute need to use toString() before passing to escapeHTML as they could be numbers
            if(choicesArrayOfArrays(choices)) {
                // Elements are [id,display]
                _.each(choices, function(c) {
                    output.push(startHtml(), escapeHTML(c[0].toString()), (valueIsSelected(c[0]) ? htmlSelected : '">'), escapeHTML(c[1]), html2);
                    if((--groupingNext) === 0) { output.push('</td><td>'); groupingNext = groupingCount; }
                });
            } else if(choicesArrayOfObjects(choices)) {
                // Elements are objects with two named properties, defaulting to 'id' and 'name'
                var idProp = this._objectIdProperty, displayProp = this._objectDisplayProperty;
                _.each(choices, function(c) {
                    var id = c[idProp];
                    output.push(startHtml(), escapeHTML(id.toString()), (valueIsSelected(id) ? htmlSelected : '">'), escapeHTML(c[displayProp]), html2);
                    if((--groupingNext) === 0) { output.push('</td><td>'); groupingNext = groupingCount; }
                });
            } else {
                // Elements are strings, used for both ID and display text
                _.each(choices, function(c) {
                    var escaped = escapeHTML(c.toString());
                    output.push(startHtml(), escaped, (valueIsSelected(c) ? htmlSelected : '">'), escaped, html2);
                    if((--groupingNext) === 0) { output.push('</td><td>'); groupingNext = groupingCount; }
                });
            }
            output.push(endHTML);

        } else {
            // Display the document
            var values;
            if(this._style === "multiple") {
                var t = this;
                values = _.map(value || [], function(value) {
                    return t._displayNameForValue(instance, value);
                });
            } else {
                values = [this._displayNameForValue(instance, value)];
            }
            // Filter against undefined and null, as toString doesn't work on them. Just doing
            // if(display) would prevent some values we want to output from being displayed.
            values = _.filter(values, function(v) { return v !== undefined && v !== null; });
            // Output the display values, using toString() in case the value was an number
            // and it wasn't found in the lookup.
            switch(values.length) {
                case 0: /* do nothing */ break;
                case 1: output.push(escapeHTML(values[0].toString())); break;
                default:
                    // Multiple values need wrapping in block elements to put them on new lines
                    _.each(values, function(display) {
                        output.push('<div class="one-of-many">', escapeHTML(display.toString()), '</div>');
                    });
                    break;
            }
        }
    },

    _replaceValuesForView: function(instance, context) {
        var value = this._getValueFromDoc(context);
        if(undefined === value) { return; }
        this._setValueInDoc(context, this._displayNameForValue(instance, value));
    },

    _decodeValueFromFormAndValidate: function(instance, nameSuffix, submittedDataFn, validationResult) {
        var choices = this._getChoices(instance);
        var name = this.name + nameSuffix;
        // Need to convert the value to a number?
        var firstChoiceId;
        if(choicesArrayOfArrays(choices)) { firstChoiceId = choices[0][0]; }
        else if(choicesArrayOfObjects(choices)) { firstChoiceId = choices[0][this._objectIdProperty]; }
        var shouldConvertToNumber = (typeof(firstChoiceId) === 'number');
        // How to get a value
        var getValue = function(nameIndex) {
            var value = submittedDataFn((nameIndex !== undefined) ? (name+','+nameIndex) : name);
            if(!value || value.length === 0) { return undefined; } // Handle no value in the form
            return shouldConvertToNumber ? (value * 1) : value;
        };
        // "multiple" style needs different handling
        if(this._style === "multiple") {
            // Bit of an inefficient way of doing things, but doesn't require form parameter parsers to cope with multiple values.
            var values = [];
            for(var index = 0; index < choices.length; ++index) {
                var v = getValue(index);
                if(v) { values.push(v); }
            }
            // Validation
            var min = this._minimumCount, max = this._maximumCount;
            if(undefined !== min && values.length < min) {
                validationResult._failureMessage = 'Not enough options chosen, ' + min + ' required';
            } else if(undefined !== max && values.length > max) {
                validationResult._failureMessage = 'Too many options chosen, ' + max + ' maximum';
            }
            if(validationResult._failureMessage) {
                return values;  // can return empty array, unlike default behaviour below
            }
            // If empty, don't return anything so required validation catches it.
            return (values.length === 0) ? undefined : values;
        } else {
            return getValue();
        }
    },

    _getChoices: function(instance) {
        var choices = this._choices;
        if(typeof(choices) === 'string') {
            // Name of instance choices
            var instanceChoices = instance._instanceChoices;
            if(!instanceChoices) { return null; }   // this failure handled specially by caller
            choices = instanceChoices ? instanceChoices[choices] : undefined;
            if(!choices) {
                complain("instance", "Choices '"+this._choices+"' have not been set with instance.choices()");
            }
        }
        return choices;
    },

    _displayNameForValue: function(instance, value) {
        var choices = this._getChoices(instance);
        var display = value;
        // Lookup value for display, if the list of choices is not a simple array of strings
        if(choicesArrayOfArrays(choices)) {
            // Is [id,display] version of choices - attempt to find the display value
            var a = _.find(choices, function(c) { return c[0] === value; });
            if(a) { display = a[1]; }
        } else if(choicesArrayOfObjects(choices)) {
            // Is objects version of choices, attempt to find display value
            var idProp2 = this._objectIdProperty;
            var o = _.find(choices, function(c) { return c[idProp2] === value; });
            if(o) { display = o[this._objectDisplayProperty]; }
        }
        return display;
    }
});

/////////////////////////////// element/lookup.js ///////////////////////////////

makeElementType("lookup", {

    _initElement: function(specification, description) {
        if(typeof(this._dataSourceName = specification.dataSource) !== "string") {
            complain("spec", "No data source defined for "+this.name);
        }
        description._setRequirementsFlagsForDataSource(this._dataSourceName);
        description.requiresClientUIScripts = true;
    },

    _bundleClientRequirements: function(emptyInstance, bundle) {
        // Ensure information about the data source is included in the bundle
        emptyInstance.description._bundleDataSource(this._dataSourceName, bundle);
        // Client side information for this element
        bundle.elements[this.name] = {
            dataSource: this._dataSourceName
        };
    },

    _pushRenderedHTML: function(instance, renderForm, context, nameSuffix, validationFailure, output) {
        // Get the value, determine the display name using the data source
        var value = this._getValueFromDoc(context);
        if(undefined === value) {
            value = '';
        } else if(typeof value !== "string") {
            value = value.toString();
        }
        var displayName = this._displayNameForValue(instance, value);
        if(displayName === '') {
            // No display name, try and get one from the entered text in the previous form submission
            var enteredText = instance._rerenderData[this.name + nameSuffix];
            if(enteredText) { displayName = enteredText; }
        }
        // Build output HTML
        if(renderForm) {
            output.push('<span class="oforms-lookup', additionalClass(this._class), '"');
            outputAttribute(output, ' id="', this._id);
            output.push('><input type="hidden" name="', this.name, nameSuffix, '" value="', escapeHTML(value),
                '"><input type="text" name="', this.name, '.d', nameSuffix, '" autocomplete="off" class="oforms-lookup-input');
            if(value !== '') {
                // Add additional class to flag that the lookup is valid
                output.push(' oforms-lookup-valid');
            }
            output.push('" value="', escapeHTML(displayName), '"');
            outputAttribute(output, ' placeholder="', this._placeholder);
            outputAttribute(output, ' data-oforms-note="', this._guidanceNote);
            output.push('></span>');
        } else {
            output.push(escapeHTML(displayName));
        }
    },

    _replaceValuesForView: function(instance, context) {
        var value = this._getValueFromDoc(context);
        if(undefined === value) { return; }
        this._setValueInDoc(context, this._displayNameForValue(instance, value));
    },

    _decodeValueFromFormAndValidate: function(instance, nameSuffix, submittedDataFn, validationResult) {
        var text = submittedDataFn(this.name + nameSuffix);
        if(text.length === 0) {
            // Nothing was selected, preserve the entered value for rerendering
            instance._rerenderData[this.name + nameSuffix] = submittedDataFn(this.name + '.d' + nameSuffix);
        } else {
            return text;
        }
    },

    _displayNameForValue: function(instance, value) {
        var dataSource = instance.description._getDataSource(this._dataSourceName);
        return (value === '') ? '' : (dataSource.displayNameForValue(value) || value);
    }
});

/////////////////////////////// element/file.js ///////////////////////////////

makeElementType("file", {

    // Because uploading file is a bit tricky (at the very least, files must be stored outside the JSON documents),
    // the platform needs to implement much of the support via the delegate, which should implement:
    //   formFileElementValueRepresentsFile(value)      (returns boolean)
    //   formFileElementRenderForForm(value)            (returns HTML)
    //   formFileElementRenderForDocument(value)        (returns HTML)
    //   formFileElementEncodeValue(value)              (returns encoded)
    //   formFileElementDecodeValue(encoded)            (returns value)
    // Where 'encoded' is a text string for storage in an hidden input field, and 'value' is the representation of
    // the file as stored in the document.

    _initElement: function(specification, description) {
        description.requiresClientUIScripts = true;
        description.requiresClientFileUploadScripts = true;
    },

    _pushRenderedHTML: function(instance, renderForm, context, nameSuffix, validationFailure, output) {
        // Value is something handled by the platform integration, and is essentially opaque to the forms system
        var value = this._getValueFromDoc(context);
        // Build output HTML
        var delegate = instance.description.delegate;
        var haveFile = delegate.formFileElementValueRepresentsFile(value);
        if(renderForm) {
            output.push('<span class="oforms-file', additionalClass(this._class), '">');
            this._outputCommonAttributes(output);
            output.push('<span class="oforms-file-prompt"',
                haveFile ? ' style="display:none"' : '',
                '><a href="#">Upload file...</a><input type="file" name="', this.name, '.f', nameSuffix, '"></span>');
            if(haveFile) {
                output.push('<input type="hidden" name="', this.name, nameSuffix, '" value="',
                    escapeHTML(delegate.formFileElementEncodeValue(value)),
                    '"><span class="oforms-file-display">', delegate.formFileElementRenderForForm(value), '</span> <a href="#" class="oforms-file-remove">remove</a>');
            } else {
                output.push('<input type="hidden" name="', this.name, nameSuffix, '"><span class="oforms-file-display"></span> <a href="#" class="oforms-file-remove" style="display:none">remove</a>');
            }
            output.push('</span>');
        } else {
            if(haveFile) {
                output.push(delegate.formFileElementRenderForDocument(value));
            }
        }
    },

    _decodeValueFromFormAndValidate: function(instance, nameSuffix, submittedDataFn, validationResult) {
        var encoded = submittedDataFn(this.name + nameSuffix);
        if(encoded && encoded.length > 0) {
            return instance.description.delegate.formFileElementDecodeValue(encoded);
        }
    }
});

/////////////////////////////// form/description.js ///////////////////////////////

var /* seal */ FormDescription = function(specification, delegate, overrideID) {
    // TODO: Basic error checking on FormDescription arguments
    this.specification = specification;
    this.delegate = delegate;
    this.formId = overrideID || specification.formId;
    // Build form description out of Elements
    this._defaultElementName = 0;
    this._elements = {};    // name to element lookup
    this._dataSources = {}; // name to data source lookup
    this._root = new SectionElement(this.specification, this);
    // Set up the templating system when the first description is created, using built-in or delegate rendering
    if(delegate.formTemplateRendererSetup) {
        delegate.formTemplateRendererSetup();
    } else {
        _templateRendererSetup();
    }
};

_.extend(FormDescription.prototype, {
    // Properties, public to users of oForms
    //   specification - given specification
    //   delegate - delegate for this form
    //   formId - ID for the form (reflected in the HTML)

    // Requirements flags, public to users of oForms
    //   requiresBundle - whether a bundle is required
    //   requiresClientUIScripts - whether the output form needs client side scripting support
    // (These flags are set by _initElement() methods of Elements.)

    // Properties used by other objects in this system, but not by users of oForms
    //   _root - SectionElement at the root of the form

    // ----------------------------------------------------------------------------------------

    // Defaults for requirements
    requiresBundle: false,
    requiresClientUIScripts: false,

    // ----------------------------------------------------------------------------------------

    // Construct an instance of this form
    createInstance: function(document) {
        return new FormInstance(this, document);
    },

    // ----------------------------------------------------------------------------------------
    // Bundle support

    // Use the requiresBundle property to see if a bundle is required.

    // Generate the bundle, as a JSON compatible data structure. The caller should make it
    // available on the client side, and call oForms.client.registerBundle(id, bundle).
    generateBundle: function() {
        // Create an empty instance used for rendering things
        var emptyInstance = this.createInstance({});
        emptyInstance._isEmptyInstanceForBundling = true;
        // Create a blank bundle, ask the root to fill it in, return it
        var bundle = {elements:{}};
        this._root._bundleClientRequirements(emptyInstance, bundle);
        return bundle;
    },

    // ----------------------------------------------------------------------------------------
    // Functions for use by other parts of the forms system
    _generateDefaultElementName: function(specification) {
        // Generate default names using the labels, so the names don't change when forms are updated
        var proposed;
        if(specification.label) {
            proposed = specification.label.toLowerCase().replace(/[^a-z0-9]/g,'_').replace(/(^_+|_+$)/g,'');
            if(!this._elements[proposed]) {
                // Prefer not to add a numberic suffix when generating names from labels, so shortcut now
                // if there's no registered element with this name.
                return proposed;
            }
        }
        if(!proposed) {
            // If there's no label, use a generic prefix it won't clash with names generated by the path.
            proposed = '_ofe';
        }
        while(this._elements[proposed + this._defaultElementName]) {
            this._defaultElementName++;
        }
        return proposed + this._defaultElementName;
    },

    _registerElement: function(element) {
        if(this._elements[element.name]) {
            complain("spec", "Element name "+element.name+" is duplicated");
        }
        // Allocate ordering index for element, as this is the easiest place to do it centrally.
        // Code order of register before init ensures sections work as expected.
        var orderingIndex = this._nextOrderingIndex||0;
        element._orderingIndex = orderingIndex;
        this._nextOrderingIndex = orderingIndex+1;

        this._elements[element.name] = element;
    },

    // ----------------------------------------------------------------------------------------
    // Data source handling

    // Get the data source object, exceptioning if the source doesn't exist
    _getDataSource: function(name) {
        // Try the cache first
        var dataSource = this._dataSources[name];
        // If not there, ask delegate, checking for existence of function first
        if(!dataSource && this.delegate.formGetDataSource) {
            this._dataSources[name] = dataSource = this.delegate.formGetDataSource(name);
        }
        // Complain if it doesn't exist
        if(!dataSource) {
            complain("data-source", "Data source "+this._dataSourceName+" does not exist");
        }
        return dataSource;
    },

    // Set the requirement flags for a data source.
    // Called by Element _initElement() functions to set the flags for each give data source they use.
    _setRequirementsFlagsForDataSource: function(name) {
        // TODO: Work out if a data source doesn't actually require a bundle
        this.requiresBundle = true;
    },

    // Include information about the data source in the bundle
    _bundleDataSource: function(name, bundle) {
        if(!bundle.dataSource) { bundle.dataSource = {}; }
        if(!bundle.dataSource[name]) {
            var dataSource = this._getDataSource(name);
            var info = { name: name };
            if(dataSource.endpoint) {
                info.endpoint = dataSource.endpoint;
            }
            bundle.dataSource[name] = info;
        }
    }
});

// Public API for creating a description
oForms.createDescription = function(specification, delegate, overrideID) {
    return new FormDescription(specification, delegate, overrideID);
};

/////////////////////////////// form/instance.js ///////////////////////////////

var /* seal */ FormInstance = function(description, document) {
    this.description = description;
    this.document = document;
    this.valid = true;
    this._rerenderData = {};
    this._validationFailures = {};
    // Replace render template function with one which uses the delegate for rendering?
    var delegate = description.delegate;
    if(delegate.formPushRenderedTemplate) {
        this._renderTemplate = function() {
            delegate.formPushRenderedTemplate.apply(delegate, arguments);
        };
    }
};

_.extend(FormInstance.prototype, {
    // Public properties
    //  description - the form description object
    //  document - the document object this form reads and updates
    //  valid - true if the form passed validation (document may contain invalid data if this is not true)
    //
    // Properties used by other objects in this system, but not by users of oForms
    //   _isEmptyInstanceForBundling - flag set when bundling.
    //   _instanceChoices - look up of choices set by choices(). May not be defined.
    //   _rerenderData - look up of element name + suffix to any info required to render the form correctly,
    //                      for example, invalid data which cannot be stored in the document.
    //
    // Private properties - but some accessed directly by other parts of the code
    //   _validationFailures - look up of element name + suffix to validation failure message to display
    //                      to the user

    renderForm: function() {
        var output = ['<div class="oform" id="', escapeHTML(this.description.formId), '">'];
        var rootElement = this.description._root;
        rootElement._pushRenderedHTML(
                this,
                true,   // rendering form
                this.document,
                '',     // empty name suffix
                this._validationFailures[rootElement.name],
                output
            );
        output.push("</div>");
        return output.join("");
    },

    renderDocument: function() {
        var output = [];
        this.description._root._pushRenderedHTML(
                this,
                false,  // rendering document
                this.document,
                '',     // empty name suffix
                undefined, // no validation failures
                output
            );
        return output.join("");
    },

    documentWouldValidate: function() {
        return this.description._root._wouldValidate(this, this.document);
    },

    update: function(submittedDataFn) {
        this.valid = false;
        this._validationFailures = {};
        this._rerenderData = {};
        this.description._root._updateDocument(this, this.document, '' /* empty name suffix */, function(name) {
            // Wrap the given submittedDataFn so if it doesn't find a value for a given name, it returns the empty string.
            // This makes sure everthing works with Internet Explorer.
            return submittedDataFn(name) || '';
        });
        if(_.isEmpty(this._validationFailures)) { this.valid = true; }
    },

    choices: function(name, choices) {
        var c = this._instanceChoices;
        if(!c) { this._instanceChoices = c = {}; }
        c[name] = choices;
    },

    // Make a version of the document which contains displayable strings
    makeView: function() {
        var clonedDocument = deepCloneForJSON(this.document);
        this.description._root._replaceValuesForView(this, clonedDocument);
        return clonedDocument;
    },

    // ----------------------------------------------------------------------------------------
    // Functions for the other interfaces
    _renderTemplate: function(templateName, view, output) {
        // --------------------------
        // NOTE: This may be replaced entirely by the delegate if it implements the formPushRenderedTemplate() function.
        // --------------------------
        // Fetch the template
        var template;
        // First try the delegate, so the caller can specify their own templates and override the default templates
        var delegate = this.description.delegate;
        if(delegate.formGetTemplate) {
            template = delegate.formGetTemplate(templateName);
        }
        // Then try the standard templates
        if(!template) { template = standardTemplates[templateName]; }
        if(!template) { complain("template", "No such template: "+templateName); }
        // Render template using chosen template renderer
        _templateRendererImpl(template, view, output);
    }
});

/////////////////////////////// sealing.js ///////////////////////////////

// Collect together all the elements which need sealing and make them available for recursive sealing
oForms._seal = [uncompiledStandardTemplates,measurementsQuantities,elementConstructors,SectionElement,TEXT_WHITESPACE_FUNCTIONS,MONTH_NAMES_DISP,CHOICE_STYLES,FormDescription,FormInstance];

/////////////////////////////// oforms_postamble.js ///////////////////////////////

})(this);


