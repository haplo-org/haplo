/*global confirm,KApp,KSchema,KAttrObjChoices,KUserHomeCountry,KTaxonomies,KControl,KFileUpload,KTree,KTreeSource,KCtrlText,KCtrlTextarea,KCtrlDocumentTextEdit,KCtrlDocumentTextEditSingleLine,KCtrlDropdownMenu,KCtrlTextWithInnerLabel,KCtrlDateTimeEditor,KFocusProxy,KCtrlFormAttacher,escapeHTML,Ks:true */

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var KEditor;
var KEditorSchema;
var KEdSubject;
var KEdType;

// ----------------------------------------------------------------------------------------------------

/*CONST*/ FILE_FIRST_VERSION_STRING = '1'; // Sync with kidentifer_file.rb

// Internal pseudo types
/*CONST*/ T_PSEUDO_TYPE_OBJREF_UISTYLE_MAX = -60;
/*CONST*/ T_PSEUDO_TYPE_OBJREF_DROPDOWN = -60; // = T_PSEUDO_TYPE_OBJREF_DROPDOWN
/*CONST*/ T_PSEUDO_TYPE_OBJREF_RADIO = -61;
/*CONST*/ T_PSEUDO_TYPE_OBJREF_CHECKBOX = -62;

// Array locations for value definition
/*CONST*/ VL_TYPE         = 0;    // as T_*
/*CONST*/ VL_QUALIFIER    = 1;
/*CONST*/ VL__START       = 2;    // index of first type specific bit of data

// Root type info in schema
/*CONST*/ SCHEMATYPE_ROOT_SUBTYPES            = 0;
/*CONST*/ SCHEMATYPE_ROOT_ROOT_REF            = 1;
/*CONST*/ SCHEMATYPE_ROOT_DEFAULT_REF         = 2;
/*CONST*/ SCHEMATYPE_ROOT_ATTRIBUTES          = 3;
// Sub-type info in schema (includes root type)
/*CONST*/ SCHEMATYPE_SUBTYPE_REF              = 0;
/*CONST*/ SCHEMATYPE_SUBTYPE_NAME             = 1;
/*CONST*/ SCHEMATYPE_SUBTYPE_IN_MENU          = 2;
/*CONST*/ SCHEMATYPE_SUBTYPE_REMOVE_ATTR      = 3;

(function($) {

var OBJREF_UI_STYLE_TO_PSEUDO_TYPE = {
    "dropdown":     T_PSEUDO_TYPE_OBJREF_DROPDOWN,
    "radio":        T_PSEUDO_TYPE_OBJREF_RADIO,
    "checkbox":     T_PSEUDO_TYPE_OBJREF_CHECKBOX
};

// ****************************************** NOTE - use tabindex="1" on all form elements ******************************************

var escapeBackquote = function(str) {
    return str.replace(/\\/g, '\\\\').replace(/`/g,'\\,');
};

var stripString = function(string) {
    return string.replace(/^\s+/, '').replace(/\s+$/, '');
};

var j__focusOnFirstInputBelow = function(i) {
    if(typeof i === 'string') { i = $('#'+i)[0]; }
    $('input[type="text"]:not(.z__no_default_focus),[contenteditable=true]', i).first().each(function() { KApp.j__focusNicely(this); });
};

// ----------------------------------------------------------------------------------------------------
//   Editor Schema class
// ----------------------------------------------------------------------------------------------------

// Format of the schema output by the server
// These define the properities on the attribute definitions.
var KEditorSchemaDCols = ['p__desc','p__allowedQualifiers','p__normalDataType','p__typeSpecifics','p__name','p__aliasOf'];
var KEditorSchemaTypeSpecifics = {}; // needs to be a dictionary, not an array, because one of the values is -1
    // Needs to be kept in sync with info in schema_controller.rb
    KEditorSchemaTypeSpecifics[T_OBJREF] = ['p__controlByTypes','p__controlRelaxed','p__uiOptions'];
    KEditorSchemaTypeSpecifics[T_PSEUDO_TAXONOMY_OBJREF] = ['p__controlByTypes'];
    KEditorSchemaTypeSpecifics[T_DATETIME] = ['p__uiOptions'];
    KEditorSchemaTypeSpecifics[T_TEXT_PERSON_NAME] = ['p__uiOptions'];
    KEditorSchemaTypeSpecifics[T_TEXT_PLUGIN_DEFINED] = ['p__pluginDataType'];
    KEditorSchemaTypeSpecifics[T_ATTRIBUTE_GROUP] = ['p__groupType'];

/* global */ KEditorSchema = {
    // Properties:
    //  p__allAttrDefns  - all the attribute descriptors
    //  p__allQualifierDescs  - all the qualifier descriptors
    //  p__schema - raw schema object

    j__prepare: function(schema) {
        if(this.p__schema) {
            // Only allow preparation once
            return;
        }

        // Default to the main schema
        var s = schema || KSchema;

        // Create attribute definitions
        var as = [];
        var i = [];
        var a = s.attr;
        var l;
        for(var x = 0; x < a.length; x++) {
            var defn = {};
            // Normal attributes
            for(l = 0; l < KEditorSchemaDCols.length; l++) {
                defn[KEditorSchemaDCols[l]] = a[x][l];
            }
            // Only administrators can edit configured behaviours
            if(defn.p__desc === A_CONFIGURED_BEHAVIOUR) {
                if(!KSchema.p__userCanEditConfigurableBehaviours) {
                    continue;
                }
            }
            // Make sure aliased value is null if not set
            if(!defn.p__aliasOf) {defn.p__aliasOf = null;}
            // Qualifiers?
            defn.p__chooseQualifier = (defn.p__allowedQualifiers.length != 1);
            // Extra attributes for this type
            var specifics = KEditorSchemaTypeSpecifics[defn.p__normalDataType];
            if(specifics) {
                for(l = 0; l < specifics.length; l++) {
                    defn[specifics[l]] = defn.p__typeSpecifics[l];
                }
            }
            // Adjust normal data type for objref values, as each UI style uses it's own value editor
            if(defn.p__normalDataType === T_OBJREF) {
                var pseudoDataType = OBJREF_UI_STYLE_TO_PSEUDO_TYPE[defn.p__uiOptions];
                if(pseudoDataType) {
                    defn.p__normalDataType = pseudoDataType;
                }
            }
            // How to create a new blank value
            defn.p__newCreationData = [defn.p__normalDataType,
                (defn.p__allowedQualifiers.length > 0) ? defn.p__allowedQualifiers[0] : Q_NULL];
            // Store defn indexed by desc
            i[defn.p__desc] = defn;
            // And in order
            as.push(defn);
        }
        this.p__allAttrDefns = as;
        this.q__descToAttrDefn = i;

        // Set up qualifier information from the schema
        var d = [];
        var n = [];
        var q = s.qual;
        for(var z = 0; z < q.length; z++) {
            d.push(q[z][0]);
            n[q[z][0]] = q[z][1];
        }
        this.p__allQualifierDescs = d;
        this.q__allQualifierNames = n;

        // Store schema, marking prepation as complete
        this.p__schema = s;
    },
    j__attrDefn: function(desc) {
        return this.q__descToAttrDefn[desc];
    },
    j__qualifierName: function(qual) {
        return this.q__allQualifierNames[qual];
    }
};


// ----------------------------------------------------------------------------------------------------
//   Value base class
// ----------------------------------------------------------------------------------------------------

// Suffixes on DOM ids:
//   _d  - delete button
//   _dc - delete button container
//   _u  - undo button
//   _uc - undo button container
//   _c  - container for control (also necessary for IE to display it properly)
//   _s  - container for strikethrough
//   _q  - qualifier text
//   _qc - qualifier select dropdown container span
//   _qs - qualifier select dropdown
//   _e  - container for extras, hidden on lose focus
//   _r  - validation error message
//
// Properties:
//   p__parentContainer - parent KAttrContainer

var makeKEdValueContructor = function() {
    return function(parent,desc,data) {
        this.p__parentContainer = parent;
        this.q__desc = desc;
        this.q__defn = KEditorSchema.j__attrDefn(desc);
        this.q__data = data;
        this.q__qualifier = data[VL_QUALIFIER];
        // Make the control
        this.q__control = new (this.p__controlClass)(data[VL__START]);
        // Tell the control about this node
        this.q__control.p__keditorValueControl = this;
        // Apply any additional data to the control (expects the control to be happy with this direct sending approach)
        var c = this.p__controlData;
        if(c) {
            for(var l = 0; l < c.length; l++) {
                this.q__control[c[l]] = data[VL__START+1+l];
            }
        }
    };
};
var KEdValue = function() {};
KEdValue.p__withFocus = null;      // which of these controls has focus at the moment
_.extend(KEdValue.prototype, KControl.prototype);
_.extend(KEdValue.prototype, {
    j__generateHtml2: function(i) {
        // Make the basics
        // note that KAttrContainer depends on the construction here
        var h = '<div id="'+i+'" class="z__keyvalue_row">';
        if(!this.p__parentContainer.p__singleValue) {
            // Include the _dragPosition in the handle, set by KAttrContainer
            h += '<div class="z__editor_value_buttons"><div id="'+i+'_dc" class="z__editor_delete_button"><a id="'+i+'_d" href="#"><img src="/images/clearbut.gif" height="14" width="14" alt="delete" title="delete"></a></div><div id="'+i+'_uc" class="z__editor_undo_button" style="display:none;"><a id="'+i+'_u" href="#"><img src="/images/clearbut.gif" height="14" width="14" alt="undelete" title="undelete"></a></div><div data-kvalueposition="'+this._dragPosition+'" class="z__editor_value_order_drag_handle">drag</div></div>';
        }
        // Qualifiers?
        if(this.q__defn.p__chooseQualifier) {
            h += '<div class="z__keyvalue_col1_qualifer"><span id="'+i+'_q">';
            if(this.q__qualifier === 0) {
                // No qualifier, use a blank placeholder
                h += '&nbsp;';
            } else {
                // Lookup qualifier
                h += KEditorSchema.j__qualifierName(this.q__qualifier);
            }
            h += '</span><span id="'+i+'_qc" style="display:none;"><select id="'+i+'_qs" tabindex="1">';
            // Add selector dropdown
            var opts = this.q__defn.p__allowedQualifiers;
            if(opts.length === 0) {
                // Use all the qualifiers
                opts = KEditorSchema.p__allQualifierDescs;
            }
            opts = _.map(opts, function(qualifier) {
                return [qualifier, KEditorSchema.j__qualifierName(qualifier)];
            });
            opts = _.sortBy(opts, function(e) { return e[1]; });
            for(var o = 0; o < opts.length; o++) {
                var qualInfo = opts[o];
                h += '<option value="' + qualInfo[0] + '"' +
                    ((this.q__qualifier == qualInfo[0]) ? ' selected' : '') + '>' + escapeHTML(qualInfo[1]) + '</option>';
            }
            // col2 is here so things are shown full width if there's no qualifier to choose
            h += '</select></span></div><div class="z__keyvalue_col2">';
        } else {
            h += '<div class="z__keyvalue_col2_full">';
        }

        // Add the HTML for the value control.
        // Must be contained in some block level container within the main z__keyvalue_col2 otherwise IE gets it
        // in the wrong place. Use this oppourtunity to have a div for making deletion easier.
        h += '<div id="'+i+'_c">';
        h += this.q__control.j__generateHtml();
        return h+'</div></div></div>';
    },
    j__attach2: function(i) {
        this.q__control.j__attach();
        // Attach handlers
        $('#'+i+'_d').click(_.bind(this.j__handleDelete, this));
        $('#'+i+'_u').click(_.bind(this.j__handleUndo, this));
        this.j__attachHandlersToControls();
    },
    // Control classes can call j__attachHandlersToControls() if they change their controls.
    j__attachHandlersToControls: function() {
        // Attach focus handlers on all elements which look like they're part of the control
        $('#'+this.q__domId+' input, #'+this.q__domId+' textarea, #'+this.q__domId+' select').focus(
            _.bind(this.j__handleFocus, this)
        );
        // NOTE: Doesn't appear to be possible to attach an onChange handler to the SELECT element in IE.
        // Fires only if its done as an onchange="" in the HTML. Helpful.
    },
    j__hasValue: function() {
        // Overridden below for KCtrlDocumentTextEdit
        var v = this.q__control.j__value();
        return v && v !== '' && !(this.q__deleted);
    },
    j__getValue: function() {
        // TODO: Write more efficient version for KCtrlDocumentTextEdit
        return escapeBackquote(this.q__control.j__value());
    },
    j__value: function() {
        // Update qualifier
        var qdd = $('#'+this.q__domId+'_qs');
        if(qdd.length !== 0) {
            this.q__qualifier = qdd.val() * 1;
        }

        // Return the value
        return (this.j__hasValue()) ? ('V`'+this.q__qualifier+'`'+this.p__dataType+'`'+this.j__getValue()) : null;
    },
    j__getControl: function() {
        return this.q__control;
    },

    // --------------------------------------------------------------------------------------
    // Value validation, uses control class
    j__validate: function() {
        if(this.q__deleted) {return null;}  // if it's deleted, validation passes
        // Call the control class' validate function, if it implements one. Otherwise assume validation worked.
        var v = this.q__control.j__validate;
        return v ? this.q__control.j__validate() : null;
    },

    j__getBusyMessage: function() {
        if(this.q__deleted) {return null;}
        var v = this.q__control.j__getBusyMessage;
        return v ? this.q__control.j__getBusyMessage() : null;
    },

    j__validationWithUi: function() {
        var i = this.q__domId;

        // Validate
        var error = this.j__validate();

        // Error display?
        var error_display = $('#'+i+'_r');

        // Hide display and finish if control validated OK
        if(!error) {
            error_display.hide();
            return null;
        }

        // Value doesn't validate

        // Create the UI, if it's not already there
        if(error_display.length === 0) {
            // Create error display
            var e = document.createElement('div');
            e.className = 'z__editor_value_error_display';
            e.id = i+'_r';
            e.style.display = 'none';
            // Add to document
            this.q__domObj.appendChild(e);
            error_display = $(e);
        }

        // Set the error text, and show it
        error_display.text(error).show();

        // Return error message to caller
        return error;
    },

    // --------------------------------------------------------------------------------------
    // Container for extra bits
    j__getExtrasContainer: function() {
        var i = this.q__domId;
        var e = $('#'+i+'_e');
        if(e.length !== 0) { return e[0]; } // return if exists
        // Create if not already in DOM
        e = document.createElement('div');
        e.className = 'z__editor_value_extras_container';
        e.id = i+'_e';
        e.style.display = 'none';
        // Insert into row
        $('#'+i).append(e);
        return e;
    },

    // --------------------------------------------------------------------------------------
    // Overrideable means of showing inactive view for the controls
    j__textForUndoableDeleted: function() {
        return this.j__getValue();
    },
    j__showAsUndoableDeleted: function() {
        // Hide the control
        this.q__control.j__hide();

        // Is there a DOM element for the strike-through thingy?
        var i = this.q__domId;
        var e = $('#'+i+'_s');
        if(e.length === 0) {
            e = document.createElement('div');
            e.id = i+'_s';
            e.className = 'z__editor_undoable_deleted_value';
            // insert relative to the control container
            var r = $('#'+i+'_c')[0];
            r.parentNode.insertBefore(e,r);
            e = $(e); // to jQuery
        }
        // Fill the contents of the element and make sure it's showing
        e.html('<p>'+escapeHTML(this.j__textForUndoableDeleted()).replace(/[\r\n]+/g,'</p><p>')+'</p>').show();
    },
    j__showEditableControlAfterUndo: function() {
        // Hide the strike through value
        $('#'+this.q__domId+'_s').hide();
        // Show the control
        this.q__control.j__show();
    },

    // --------------------------------------------------------------------------------------
    // overrideable notifications
    j__wasAdded: function() {
    },
    j__wasDeleted: function() {
    },
    j__wasUndeleted: function() {
    },

    // --------------------------------------------------------------------------------------
    // Handlers
    j__handleDelete: function(event) {
        event.preventDefault();
        this.j__deleteValue();
    },
    // Separate function so can be called by other things
    j__deleteValue: function() {
        // Got a value?
        if(!this.j__hasValue() && this.j__deleteShouldRemoveValueFromDisplay()) {
            // No value, no need to undo, so just hide this row
            this.j__hide();
        } else {
            var i = this.q__domId;

            // Mark has not having focus, if it did have it
            this.j__lostFocus();

            // Show the undo button, hide the delete button
            $('#'+i+'_uc').show();
            $('#'+i+'_dc').hide();

            // Display the undoable thing
            this.j__showAsUndoableDeleted();

            // Set the strikethrough classname on the toplevel to make sure other things get strike
            $('#'+i).addClass('z__editor_strikethrough');
        }

        // Mark as deleted
        this.q__deleted = true;

        // Callback
        this.j__wasDeleted();
    },
    j__deleteShouldRemoveValueFromDisplay: function() {
        // By default, elements without a value are just removed from display entirely
        return true;
    },
    j__handleUndo: function(event) {
        event.preventDefault();

        // Show the delete button, hide the undo button
        var i = this.q__domId;
        $('#'+i+'_uc').hide();
        $('#'+i+'_dc').show();

        // Hide the control
        this.j__showEditableControlAfterUndo();

        // Unset the strikethrough classname on the toplevel
        $('#'+i).removeClass('z__editor_strikethrough');

        // Mark as not deleted
        this.q__deleted = false;

        // Callback?
        this.j__wasUndeleted();
    },
    j__handleFocus: function(evt) {
        if(KEdValue.p__withFocus == this) {
            // Nothing more to do
            return;
        }

        // Tell the previously focused control that it's lost the focus
        if(KEdValue.p__withFocus) {
            KEdValue.p__withFocus.j__lostFocus();
        }

        // Go to focused mode on this control
        var i = this.q__domId;

        // Qualifiers?
        if(this.q__defn.p__chooseQualifier) {
            // Hide qualifier text, show select box
            $('#'+i+'_q').hide();
            $('#'+i+'_qc').show();
        }

        // Hide any error validation messages
        $('#'+i+'_r').hide();

        // Mark this one as focused
        KEdValue.p__withFocus = this;
    },
    j__lostFocus: function()   // not an event handler like the above, not specifically bound to any control
    {
        if(KEdValue.p__withFocus != this) {return;}
        KEdValue.p__withFocus = null;

        // Update for losing focus
        var i = this.q__domId;

        // Qualifiers?
        if(this.q__defn.p__chooseQualifier) {
            // Update and show qualifier text, hide select box
            $('#'+i+'_q').text(KEditorSchema.j__qualifierName($('#'+i+'_qs').val() * 1));
            $('#'+i+'_q').show();
            $('#'+i+'_qc').hide();
        }

        // Hide extras container?
        $('#'+i+'_e').hide();

        // Show error messages for validation?
        this.j__validationWithUi();

        // Tell the control?
        if(this.q__control.j__lostFocus) {
            this.q__control.j__lostFocus();
        }
    }
});
KEdValue.j__unfocusCurrentValue = function() {
    if(KEdValue.p__withFocus) {
        KEdValue.p__withFocus.j__lostFocus();
        KEdValue.p__withFocus = null;
    }
};


// ----------------------------------------------------------------------------------------------------
//   Value classes
// ----------------------------------------------------------------------------------------------------

var KEdClasses = {};
function j__makeKeditorValueClass(data_type,ctrl_class,ctrl_data,extend) {
    var k = makeKEdValueContructor();
    _.extend(k.prototype, KEdValue.prototype);
    k.prototype.p__dataType = data_type;
    k.prototype.p__controlClass = ctrl_class;
    if(ctrl_class) {k.prototype.p__controlData = ctrl_data;}
    if(extend !== undefined) {
        _.extend(k.prototype,extend);
    }
    KEdClasses[data_type] = k;
}

// Basic value classes
j__makeKeditorValueClass(T_TEXT,KCtrlText);
j__makeKeditorValueClass(T_TEXT_PARAGRAPH,KCtrlTextarea);

// Document editor value classes (full document and single line text)
var documentEditorValueFunctions = {
    j__showAsUndoableDeleted: function() {
        this.q__control.j__setEditable(false,'z__strike');
    },
    j__showEditableControlAfterUndo: function() {
        this.q__control.j__setEditable(true,'z__strike');
    },
    j__hasValue: function() {
        // Override this funciton so empty documents are not treated as having values
        // Not necessarily the most efficient implementation, but good enough.
        var v = this.q__control.j__value();
        return v && v != '<doc></doc>' && v != '<fl></fl>' && !(this.q__deleted);
    }
};
j__makeKeditorValueClass(T_TEXT_DOCUMENT,       KCtrlDocumentTextEdit,           null, documentEditorValueFunctions);
j__makeKeditorValueClass(T_TEXT_FORMATTED_LINE, KCtrlDocumentTextEditSingleLine, null, documentEditorValueFunctions);


// ----------------------------------------------------------------------------------------------------
//   Value editor widgets
// ----------------------------------------------------------------------------------------------------

// Suffixes on DOM ids:
//   _i  - input for lookup value
//   _u  - uncontrolled menu option
//   _c  - create menu option

/*CONST*/ KEDOBJREF_CHECK_LOOKUP_TIMER = 500;

// Seperate function to set values in constructors for objrefs, as used by KEdObjRef
// and the subclasses.
var KEdObjRef_SetVarsInConstructor = function(objref) {
    this.p__objref = objref;
};

var KEdObjRef = function(/* objref */) {
    KEdObjRef_SetVarsInConstructor.apply(this, arguments);
};
_.extend(KEdObjRef.prototype, KControl.prototype);
_.extend(KEdObjRef.prototype, {
    // p__keditorValueControl -- should be set to KEdValue object containing this (done by default)
    // p__objref -- currently selected objref (init by constructor)
    // p__objectTitle -- currently selected object title (init by KEdValue)
    //
    // q__lookupRequest -- Ajax.Request
    j__generateHtml2: function(i) {
        var h = '<div class="z__editor_objref_ctrl_container" id="'+i+'">';
        if(this.p__objref) {
            h += this.j__htmlForLinkDisplay();
        } else {
            h += '<div class="z__editor_objref_lookup_text"><input id="'+i+'_i" type="text" tabindex="1" autocomplete="off"></div>';
        }
        return h+'</div>';
    },
    j__attach2: function(i) {
        if(!this.p__objref) {
            // To avoid recreating these bound functions all the time, and using more memory
            this.q__checkLookupTextOnKeypress = _.bind(this.j__checkLookupText, this, false, false);
            this.q__checkLookupTextOnTimer = _.bind(this.j__checkLookupText, this, true, false);
            this.q__lookupReceived = _.bind(this.j__lookupReceived, this);
            this.q__lookupFailed = _.bind(this.j__lookupFailed, this);
            // Set first timer
            window.setTimeout(this.q__checkLookupTextOnTimer, KEDOBJREF_CHECK_LOOKUP_TIMER);
            // Set event handler for keypresses
            $('#'+this.q__domId+'_i').keydown(_.bind(this.j__handleKeypressInLookupText, this));
        }
        if(this.q__focusproxy) {
            this.q__focusproxy.j__attach();
        }
    },
    j__value: function() {
        return this.p__objref;
    },
    j__validate: function() {
        // If there's some text in the field which hasn't been looked up and selected, it's an error
        var v = $('#'+this.q__domId+'_i').val();
        if(!this.p__objref && v && v !== '') {
            return KApp.j__text('EditorErrSelectChoice');
        }
        return null;
    },

    // --------------------------------------------------------------------------------------
    // Utilities
    j__htmlForLinkDisplay: function() {
        if(!this.q__focusproxy) {
            this.q__focusproxy = new KFocusProxy(this.q__domId+'_x');
        }
        return this.q__focusproxy.j__generateHtml() +
            '<div class="z__editor_link_control" id="'+this.q__domId+'_x"><div class="z__editor_link_control_container">' +
            escapeHTML(this.p__objectTitle) + '</div></div>';
    },

    // --------------------------------------------------------------------------------------
    // Handlers -- lookup style
    j__checkLookupText: function(is_called_on_timer, disable_server_call) {
        // TODO: Optimise autocomplete on KObjRef fields by looking for previously returned results for shorter strings, and if there are less than the max items returns, filter down client side instead of asking the server again.

        // Find the input field
        var lookup_input = $('#'+this.q__domId+'_i');

        // Check lookup_input because this could be called on a timer after the option has been selected
        if(lookup_input.length !== 0) {
            // Get a cleaned up version of the text
            var text = stripString(lookup_input.val()).toLowerCase();

            // If the text isn't the same as the currently displayed lookup, change it
            if(this.q__resultsShownForLookup != text) {
                // Need to display something... got items for this text in the cache?
                var cache = this.p__keditorValueControl.q__defn.q__kobjrefLookup;
                if(!cache) {
                    cache = {};
                    this.p__keditorValueControl.q__defn.q__kobjrefLookup = cache;
                }
                var cached_items = cache[text];

                // Display items, or request from from the server
                if(cached_items) {
                    // Display the lookup
                    this.j__displayLookupChoices(cached_items, text);
                } else if(!disable_server_call) {
                    // Make a request to the server if there isn't one already in progress
                    if(!this.q__lookupRequestText && text !== '') {
                        // Try seeing if a plugin wants to take over the query
                        var queryUrl;
                        for(var f = 0; f < KEditor.p__refLookupRedirectorFunctions.length; ++f) {
                            queryUrl = KEditor.p__refLookupRedirectorFunctions[f](this.p__keditorValueControl.q__defn.p__desc, text);
                            if(queryUrl) { break; }
                        }

                        // Check that truncated versions of the text haven't returned zero results
                        var ok_to_ask_server = true;
                        for(var n = text.length - 1; n > 0; n--) {
                            var x = cache[text.substring(0,n)];
                            if(x && x.length === 0) {
                                ok_to_ask_server = false;
                                break;
                            }
                        }

                        // Make the request from the server if it's worth doing
                        // If there is a queryUrl set now, a plugin has overriden the query, and the assumption about truncated text is not valid
                        if(queryUrl || ok_to_ask_server) {
                            // Fire off the request
                            if(!queryUrl) {
                                queryUrl = '/api/edit/controlled_lookup?desc='+this.p__keditorValueControl.q__defn.p__desc+
                                    '&text='+encodeURIComponent(text)+this.j__extraInfoForControlledLookupRequest();
                            }
                            $.ajax(queryUrl,
                                {
                                    dataType:"json",
                                    success:this.q__lookupReceived,
                                    error:this.q__lookupFailed
                                }
                            );

                            // Flag where it came from
                            this.q__lookupRequestText = text;
                        } else {
                            // Display nothing
                            this.j__displayLookupChoices([], text);
                        }
                    }

                    // But if there's been some outstanding lookup, display that now as it's good enough
                    if(this.q__lastLookupRequestResults) {
                        this.j__displayLookupChoices(cache[this.q__lastLookupRequestResults], this.q__lastLookupRequestResults);
                    }
                }
            }
        }

        // Unflag the results of the last lookup, so it's not erroniously displayed later
        this.q__lastLookupRequestResults = null;

        // Set next timer?
        if(is_called_on_timer && !this.p__objref) {
            window.setTimeout(this.q__checkLookupTextOnTimer, KEDOBJREF_CHECK_LOOKUP_TIMER);
        }
    },

    // For overriding in derived class
    j__extraInfoForControlledLookupRequest: function() {
        return '';
    },

    j__handleKeypressInLookupText: function(event) {
        var k = event.keyCode;
        if(k == 40 /* KEY_DOWN */ || k == 38 /* KEY_UP */ || k == 13 /* KEY_RETURN */) {
            // No browser handling please
            event.preventDefault();
            // Find the selected item
            var opts = this.p__keditorValueControl.j__getExtrasContainer().getElementsByTagName('a');
            var opts_length = opts.length;
            if(opts_length > 0) {
                // Find the selected item
                var sel = -1;
                for(var n = 0; n < opts_length; n++) {
                    if($(opts[n]).hasClass('z__selected')) {
                        sel = n;
                        $(opts[n]).removeClass('z__selected');
                        break;
                    }
                }

                // Do something depending on the key
                if(k == 13 /* KEY_RETURN */) {
                    // Perform the action for the selected item
                    if(sel != -1) {
                        var sel_element = opts[sel];
                        // Make sure it's not highlighted
                        $(sel_element).removeClass('z__selected');
                        // Run the appropraite handler
                        if($(sel_element).hasClass('z__editor_objref_cmd_uncontrolled')) {
                            this.j__handleUncontrolledClick(event);
                        } else if($(sel_element).hasClass('z__editor_objref_cmd_new')) {
                            this.j__handleNewClick(event);
                        } else {
                            this.j__handleItemClick(sel, event);
                        }
                    }
                } else {
                    // Move selected item
                    sel += (k == 40 /* KEY_DOWN */) ? 1 : -1;
                    // Clamp
                    if(sel < 0) { sel = 0; }
                    if(sel >= opts_length) { sel = opts_length - 1; }
                    // Select the item
                    $(opts[sel]).addClass('z__selected');
                }
            }
        }

        // Wait a little while before doing a text lookup, just in case something else is typed in that time.
        window.setTimeout(this.q__checkLookupTextOnKeypress, 150);
    },

    j__handleItemClick: function(item_num, event) {
        event.preventDefault();
        var l = this.q__displayedLookupItems;
        if(l && item_num >= 0 && item_num < l.length) {
            // Looks good, set this item as the value of this control
            this.p__objref = l[item_num][0];
            this.p__objectTitle = l[item_num][1];
            this.j__notifySelectionListener();
            var i = this.q__domId;
            // Display the link
            $('#'+i).html(this.j__htmlForLinkDisplay());
            // Attach the handlers to the proxy and set the focus
            var focus_proxy = this.q__focusproxy; // scope
            focus_proxy.j__attach();
            window.setTimeout(function() { focus_proxy.j__focus(); }, 10);  // IE needs a little time to catch up before the focus is set
            // Hide all the list of items.
            $(this.p__keditorValueControl.j__getExtrasContainer()).hide();
        }
    },
    j__handleUncontrolledClick: function(event) {
        event.preventDefault();

        // Get the definition
        // TODO: Neaten uncontrolled fields up a bit? The current method is a little ugly.
        var d = this.p__keditorValueControl.q__defn;
        var initial_data = d.p__newCreationData.slice(0); // copy
        initial_data.push($('#'+this.q__domId+'_i').val());    // add text value
        this.p__keditorValueControl.p__parentContainer.j__addNewValue(d.p__controlRelaxed,initial_data);
        this.p__keditorValueControl.j__hide();
        // Stop the field from giving validation errors
        $('#'+this.q__domId+'_i').val('');
    },
    j__handleNewClick: function(event) {
        event.preventDefault();

        // How many possible types?
        var d = this.p__keditorValueControl.q__defn;
        var t = d.p__controlByTypes;
        var u = (t.length == 1)?('/do/edit?pop=1&new='+t[0]):('/do/edit/pop_type?desc='+d.p__desc);

        // Spawn a new task
        KApp.j__spawn(_.bind(this.j__newObjSpawnCallback, this),'','o',
            {p__maxwidth:748,
             p__url:u+'&data['+A_TITLE+']='+encodeURIComponent($('#'+this.q__domId+'_i').val())});
        // Code in app/views/edit/~finish_pop.js causes the callback be triggered.
    },
    j__newObjSpawnCallback: function(type,objref) {
        // Store info
        this.p__objref = objref;
        this.p__objectTitle = KApp.j__objectTitle(objref);
        this.j__notifySelectionListener();
        // Show link on display
        this.q__domObj.innerHTML = this.j__htmlForLinkDisplay();
        // Hide UI
        $(this.p__keditorValueControl.j__getExtrasContainer()).hide();
    },

    j__notifySelectionListener: function() {
        if(this.p__notifySelectionListener) {
            this.p__notifySelectionListener(this.p__objref, this.p__objectTitle);
        }
    },

    // --------------------------------------------------------------------------------------
    // Responding to info
    j__lookupReceived: function(items) {
        // Store it in the cache
        if(items) {
            this.p__keditorValueControl.q__defn.q__kobjrefLookup[this.q__lookupRequestText] = items;
        }

        // Store text from last request, and flag as no request in progress
        this.q__lastLookupRequestResults = this.q__lookupRequestText;
        this.q__lookupRequestText = null;

        // Display by checking the lookup text again, but disabling server calls
        this.j__checkLookupText(false, true);
    },

    j__lookupFailed: function() {
        // Unset state from failure
        this.q__lastLookupRequestResults = null;
        this.q__lookupRequestText = null;
    },

    j__displayLookupChoices: function(items, looked_up_text) {
        var i = this.q__domId;

        // Make the html for display
        var h = '<div class="z__editor_objref_lookup_results_container">';// close /div on innerHTML property setting
        if(items.length === 0) {
            h += '<div class="z__editor_objref_lookup_results_not_found_message"><i>'+KApp.j__text('EditorLookupNoItems')+'</i></div>';
        } else {
            _.each(items, function(i) {
                // 0 objref, 1 title of object, 2 optional alternative title for autocomplete list
                h += '<div class="z__editor_objref_lookup_result"><a href="#" class="z__editor_objref_lookup_result_link">'+escapeHTML(i[2] || i[1])+'</a>';
                h += '</div>';
            });
        }

        // Add extra choices for editing values, unless it's been disabled in the editor
        if(!this.p__keditorValueControl.p__parentContainer.p__keditor.q__noCreateNewObjects) {
            h += '<div class="z__editor_objref_lookup_commands_container">';
            if(this.p__keditorValueControl.q__defn.p__controlRelaxed) {
                h += '<div><a href="#" id="'+i+'_u" class="z__editor_objref_cmd_uncontrolled">'+KApp.j__text('EditorLookupCreateUnctl')+'</a></div>';
            }
            // Check create new is generally allowed, then that the attribute is in the list of objref attributes that the user
            // has permission to create at least one of the types. List calculated by schema controller.
            if(!this.p__disablePopUpsToCreateNewObjects &&
                (-1 !== _.indexOf(KEditorSchema.p__schema.p__userAttrCreateNewAllowed, this.p__keditorValueControl.q__defn.p__desc))) {
                h += '<div><a href="#" id="'+i+'_c" class="z__editor_objref_cmd_new">'+
                        KApp.j__text('EditorLookupCreateNew', {TYPE:escapeHTML(this.p__keditorValueControl.q__defn.p__name)})+
                    '</a></div>';
            }
            h += '</div>';
        }

        // Store items for later
        this.q__displayedLookupItems = items;

        // Display the info on the lookup
        var e = this.p__keditorValueControl.j__getExtrasContainer();
        e.innerHTML = h+'</div>';
        $(e).show();

        // Set up click handlers on the results
        var e_th = this;    // for visibility
        var n = 0;
        $('.z__editor_objref_lookup_result_link', e).each(function() {
            $(this).click(_.bind(e_th.j__handleItemClick, e_th, n++));
        });
        $('#'+i+'_u').click(_.bind(this.j__handleUncontrolledClick, this));
        $('#'+i+'_c').click(_.bind(this.j__handleNewClick, this));

        // Store the text which was looked up to cause this items to be displayed
        this.q__resultsShownForLookup = looked_up_text;
    }
});

// Value class
j__makeKeditorValueClass(T_OBJREF,KEdObjRef,['p__objectTitle'],{
    j__textForUndoableDeleted: function() {
        return this.q__control.p__objectTitle;
    }
});

// ----------------------------------------------------------------------------------------------------

// make a value for pseudo objref classes, which need common setup
var j__makeKeditorValueClassPseudoObjRef = function(t,c,extras) {
    j__makeKeditorValueClass(t, c, ['p__objectTitle'].concat(extras || []), {
        p__dataType:T_OBJREF,
        j__textForUndoableDeleted: function() {
            return this.q__control.p__objectTitle;
        }
    });
};

// ----------------------------------------------------------------------------------------------------

// Variation on KEdObjRef for the A_PARENT class

var KEdObjRefParent = function(/* ... */) {
    KEdObjRef_SetVarsInConstructor.apply(this, arguments);
};
_.extend(KEdObjRefParent.prototype, KEdObjRef.prototype);
_.extend(KEdObjRefParent.prototype, {
    // Never allow new objects to be created
    p__disablePopUpsToCreateNewObjects: true,
    // Tell the server what type of object this is, so it looks up the right thing
    j__extraInfoForControlledLookupRequest: function() {
        // TODO: Get the type of the object for controlled lookup of parent fields in a more sensible manner
        return '&parent_lookup_type='+KEdType.q__defaultTypeObjref;
    }
});

j__makeKeditorValueClassPseudoObjRef(T_PSEUDO_PARENT_OBJREF,KEdObjRefParent);

// ----------------------------------------------------------------------------------------------------

// Generate options for objref list types.
// Returns array of
//    [objref, title, selected]
var makeObjRefListOptions = function(valueEditor) {
    // Get options from schema
    var schemaOptions = KAttrObjChoices[valueEditor.p__keditorValueControl.q__defn.p__controlByTypes.sort().join(',')] || [];
    var selectedItem = valueEditor.p__objref;
    // Generate output options for given options
    var options = [];
    _.each(schemaOptions, function(o) {
        // o is [objref, title]
        var selected = false;
        if(o[0] === selectedItem) {
            selected = true;
            selectedItem = undefined;
        }
        options.push([o[0], o[1], selected]);  // make array so we don't corrupt the schema definitions
    });
    // If the selected item isn't in the list, prepend it to the options
    if(selectedItem) {
        options.unshift([selectedItem, valueEditor.p__objectTitle, true /* must be selected */]);
    }
    return options;
};

// ----------------------------------------------------------------------------------------------------

// Dropdown type objref

// Suffixes on DOM ids:
//   _d  - select input for dropdown ui style

var KEdObjRefDropDown = function(/* ... */) {
    KEdObjRef_SetVarsInConstructor.apply(this, arguments);
};
_.extend(KEdObjRefDropDown.prototype, KControl.prototype);
_.extend(KEdObjRefDropDown.prototype, {
    // p__keditorValueControl -- should be set to KEdValue object containing this (done by default)
    // p__objref -- currently selected objref (init by constructor)
    // p__objectTitle -- currently selected object title (init by KEdValue)
    //
    j__generateHtml2: function(i) {
        // Work out options for this editor, determine whether selected, and add the value if it isn't in the list.
        var options = makeObjRefListOptions(this);
        // Write HTML output
        var h = [
            '<div class="z__editor_objref_ctrl_container" id="', i, '">',
            '<div class="z__editor_objref_list_ui_styles"><select id="', i, '_d" tabindex="1"><option value="">  '+KApp.j__text('EditorDropdownChoose')+' </option>'
        ];
        _.each(options, function(o) {
            // o is [objref, title, selected]
            h.push(
                '<option value="', o[0], (o[2] ? '" selected="1">' : '">'),
                    escapeHTML(o[1]),
                '</option>'
            );
        });
        h.push('</select></div></div>');
        return h.join('');
    },
    j__attach2: function(i) {
        // Get select
        var dropdown_select = $('#'+this.q__domId+'_d');
        // Attach a handler so that change stick the objref in p__objref value
        var t = this; // scoping
        dropdown_select.change(function() {
            var v = dropdown_select.val();
            if(v === "") {
                t.p__objref = null; t.p__objectTitle = "";
            } else {
                t.p__objref = v;    t.p__objectTitle = dropdown_select[0].options[dropdown_select[0].selectedIndex].text;
            }
        });
        // Reimplement min-width in IE, because it seems to ignore it for HTML written as document.write().
        // As a bonus this makes it work in IE6 as well, I suppose.
        // Because this may result in a short display of the non-resized elements, do it both ways, with
        // CSS for sensible browsers, and Javascript for IE.
        if(KApp.p__runningMsie) {
            if(dropdown_select[0].offsetWidth < 250) {
                dropdown_select[0].style.width='250px';
            }
        }
    },
    j__value: function() {
        return this.p__objref;
    }
});

j__makeKeditorValueClassPseudoObjRef(T_PSEUDO_TYPE_OBJREF_DROPDOWN, KEdObjRefDropDown);


// ----------------------------------------------------------------------------------------------------

// Radio buttons type objref

// NOTE: Requires hack on WebKit to get focus so qualifiers work -- see end of j__onPageLoad function.

var KEdObjRefRadio = function(/* ... */) {
    KEdObjRef_SetVarsInConstructor.apply(this, arguments);
};
_.extend(KEdObjRefRadio.prototype, KControl.prototype);
_.extend(KEdObjRefRadio.prototype, {
    // p__keditorValueControl -- should be set to KEdValue object containing this (done by default)
    // p__objref -- currently selected objref (init by constructor)
    // p__objectTitle -- currently selected object title (init by KEdValue)
    //
    j__generateHtml2: function(i) {
        // Work out options for this editor, determine whether selected, and add the value if it isn't in the list.
        var options = makeObjRefListOptions(this);
        // Write HTML output
        var h = [
            '<div class="z__editor_objref_ctrl_container" id="', i, '">',
            '<div class="z__editor_objref_list_ui_styles">'
        ];
        _.each(options, function(o) {
            // o is [objref, title, selected]
            h.push(
                '<label><input name="',i,'_r" type="radio" tabindex="1" value="', o[0], (o[2] ? '" checked="1">' : '">'),
                    escapeHTML(o[1]),
                '</label>'
            );
        });
        h.push('</div></div>');
        return h.join('');
    },
    j__attach2: function(i) {
        // Add handler to update properties in this object when radio buttons clicked.
        var t = this;
        $('#'+this.q__domId).on('change', function() {
            var sel = $('#'+t.q__domId+' input:checked');
            t.p__objref = sel.val();
            t.p__objectTitle = sel.parent().text();
        });
    },
    j__value: function() {
        return this.p__objref;
    }
});

j__makeKeditorValueClassPseudoObjRef(T_PSEUDO_TYPE_OBJREF_RADIO, KEdObjRefRadio);


// ----------------------------------------------------------------------------------------------------

// Checkboxes type objref

// NOTE: Requires hack on WebKit to get focus so qualifiers work -- see end of j__onPageLoad function.

var KEdObjRefCheckbox = function(/* ... */) {
    KEdObjRef_SetVarsInConstructor.apply(this, arguments);
};
_.extend(KEdObjRefCheckbox.prototype, KControl.prototype);
_.extend(KEdObjRefCheckbox.prototype, {
    // p__keditorValueControl -- should be set to KEdValue object containing this (done by default)
    // p__objref -- currently selected objref (init by constructor)
    // p__objectTitle -- currently selected object title (init by KEdValue)
    //
    j__generateHtml2: function(i) {
        // Write HTML output
        return [
            '<div class="z__editor_objref_ctrl_container_checkbox" id="', i, '"><label>',
            '<input name="',i,'_c','" type="checkbox" tabindex="1" value="', this.p__objref, (this.p__isFakeValue ? '">' : '" checked="1">'),
                escapeHTML(this.p__objectTitle),
            '</label></div>'
        ].join('');
    },
    j__attach2: function(i) {},
    j__value: function() {
        return ($('#'+this.q__domId+' input:checked').length > 0) ? this.p__objref : undefined;
    }

});

// Attribute rewriter function for object editor construction.
// If it's a checkbox data type, we need to add some fake values in so
// all possible values are represented. But not checked by default
var KEdObjRefCheckbox_rewriteAttrOnEditorInit = function(axx, defn) {
    var newAttrs = [];
    var selectedObjects = {};
    for(var j = 0; j < axx.length; ++j) {
        var entry = axx[j];
        if(axx[j][VL_TYPE] !== T_PSEUDO_TYPE_OBJREF_CHECKBOX) {
            // Put all non-objref values at the top of the list
            newAttrs.push(entry);
        } else {
            // Store this attribute looked up by it's type
            selectedObjects[entry[VL__START]] = entry;
        }
    }
    // Rebuild from list of all possible values
    var allValues = KAttrObjChoices[defn.p__controlByTypes.sort().join(',')] || [];
    _.each(allValues, function(o) {
        var existing = selectedObjects[o[0]];
        if(existing) {
            delete selectedObjects[o[0]];
            newAttrs.push(existing);
        } else {
            // Push a fake, unselected, value
            newAttrs.push([T_PSEUDO_TYPE_OBJREF_CHECKBOX, Q_NULL, o[0], o[1], true /* is fake */]);
        }
    });
    // Push any remaining selected objects so nothing is lost
    _.each(selectedObjects, function(a) { newAttrs.push(a); });
    // Use the new attributes instead
    return newAttrs;
};


// p__isFakeValue is implemented by the attribute rejigging in KEditor's constructor
j__makeKeditorValueClassPseudoObjRef(T_PSEUDO_TYPE_OBJREF_CHECKBOX, KEdObjRefCheckbox, ['p__isFakeValue']);


// ----------------------------------------------------------------------------------------------------

// Suffixes on DOM ids:
//   _s  - drop down selector
//   _i  - primary/secondary indicator

/* global */ KEdType = function(type_objref) {
    this.p__typeObjref = type_objref;
    // Find the root objref
    var root = null;
    if(type_objref) {
        // Search for root in the schema
        root = this.j__findRootTypeFor(type_objref);
    }
    // Make sure there's a default root
    if(!KEdType.q__defaultTypeRoot) {
        KEdType.q__defaultTypeRoot = root ? root : this.j__findRootTypeFor(KEdType.q__defaultTypeObjref);
    }
    // Choose a root for this attribute
    this.q__typeRoot = root || KEdType.q__defaultTypeRoot;
    if(!type_objref) {
        // Use default sub-type if nothing is specified
        this.p__typeObjref = this.q__typeRoot[SCHEMATYPE_ROOT_DEFAULT_REF];
    }
};
// KEdType.q__defaultTypeObjref is set to the type's objref by j__keditor
// NOTE: Also used by KEdObjRefParent
KEdType.q__defaultTypeRoot = null;

_.extend(KEdType.prototype, KControl.prototype);
_.extend(KEdType.prototype, {
    j__findRootTypeFor: function(ref) {
        var r = null;
        _.each(KEditorSchema.p__schema.types, function(e) {
            if(e[SCHEMATYPE_ROOT_ROOT_REF] == ref) {
                r = e;
            } else {
                _.each(e[SCHEMATYPE_ROOT_SUBTYPES], function(t) {
                    if(t[SCHEMATYPE_SUBTYPE_REF] == ref) {
                        r = e;
                    }
                });
            }
        });
        return r;
    },
    j__generateHtml2: function(i) {
        var ref = this.p__typeObjref;  // scoping
        var h = '<div id="'+i+'"><span id="'+i+'_i" class="z__editor_type_ind_null">0</span> <select id="'+i+'_s" tabindex="1"><option value=""></option>';
        _.each(this.q__typeRoot[SCHEMATYPE_ROOT_SUBTYPES], function(t) {
            var selected = (t[SCHEMATYPE_SUBTYPE_REF] == ref);
            if(t[SCHEMATYPE_SUBTYPE_IN_MENU] || selected) {
                h += '<option value="'+t[SCHEMATYPE_SUBTYPE_REF]+'"'+
                    (selected?' selected':'')+ // selected
                    '>'+escapeHTML(t[SCHEMATYPE_SUBTYPE_NAME])+'</option>';
            }
        });
        return h + '</select></div>';
    },
    j__attach2: function() {
        $('#'+this.q__domId+'_s').change(_.bind(this.j__onChange, this));
    },
    j__value: function() {
        return $('#'+this.q__domId+'_s').val();
    },

    // Indicator display
    j__updateIndicator: function() {
        var ind = $('#'+this.q__domId+'_i')[0];
        if(this.j__value() === '') {
            ind.innerHTML = '0';
            ind.className = 'z__editor_type_ind_null';
        } else {
            var is_primary = this.q__isPrimaryType;
            ind.innerHTML = is_primary?'1':'2';
            ind.className = is_primary?'z__editor_type_ind_primary':'z__editor_type_ind_secondary';
        }
    },

    // Primary type handling
    j__setIsPrimaryType: function(is_primary) {
        var first_time = (this.q__isPrimaryType == '!');
        this.q__isPrimaryType = is_primary;

        // Update the display on the field
        this.j__updateIndicator();
    },

    // Event handlers
    j__onChange: function()    // also called by delete/undelete handlers
    {
        // Show/hide attributes
        this.p__keditorValueControl.p__parentContainer.p__keditor.j__updateEditorStateForTypes();

        // Make sure the indicator is up to date
        this.j__updateIndicator();
    },

    // For displaying deleted text
    j__textOfSelectedValue: function() {
        var select = $('#'+this.q__domId+'_s')[0];
        return select.options[select.selectedIndex].text;
    },

    // For working out which to hide
    j__getAttributesToHide: function() {
        var ref = this.j__value();
        var r = _.detect(this.q__typeRoot[SCHEMATYPE_ROOT_SUBTYPES], function(t) {return t[SCHEMATYPE_SUBTYPE_REF] == ref;});
        return r ? (r[SCHEMATYPE_SUBTYPE_REMOVE_ATTR]) : [];
    }
});

// Value class
var j__kedtypeUpdateHiddenAttrFn = function() {this.q__control.j__onChange();};
j__makeKeditorValueClass(T_PSEUDO_TYPE_OBJREF,KEdType,null,{
    p__dataType:T_OBJREF,
    j__textForUndoableDeleted: function() {
        return this.q__control.j__textOfSelectedValue();
    },
    j__wasAdded: j__kedtypeUpdateHiddenAttrFn,
    j__wasDeleted: j__kedtypeUpdateHiddenAttrFn,
    j__wasUndeleted: j__kedtypeUpdateHiddenAttrFn
});

// ----------------------------------------------------------------------------------------------------

// Suffixes on DOM ids:
//   _t  - link for subject title

/* global */ KEdSubject = function(objref) {
    this.p__objref = objref;
};
KEdSubject.p__minSelectDepth = 1; // can't select taxonomy roots
_.extend(KEdSubject.prototype, KControl.prototype);
_.extend(KEdSubject.prototype, {
    // p__keditorValueControl -- should be set to KEdValue object containing this (done by default)
    // p__objref -- currently selected objref (init by constructor)
    // p__objectTitle -- currently selected object title (init by KEdValue)
    j__generateHtml2: function(i) {
        var h = '<div class="z__editor_link_control" id="'+i+'"><div class="z__editor_link_control_container"><a href="#" id="'+i+'_t">';
        var t = this.p__objectTitle;
        if(!t) {
            h += '<i>'+KApp.j__text('EditorClickToSet')+'</i>';
        } else {
            h += escapeHTML(t);
        }
        return h+'</a></div></div>';
    },
    j__attach2: function(i) {
        // Get clicks on the DIV and the A -- more reliable
        $('#'+this.q__domId).click(_.bind(this.j__handleClick, this));
        $('#'+this.q__domId+'_t').click(_.bind(this.j__handleClick, this));
    },
    j__value: function() {
        return this.p__objref;
    },

    // --------------------------------------------------------------------------------------
    // Utility
    j__ensureTreeSource: function() {
        // Get a tree source from somewhere?
        if(!KEdSubject.p__treeSource) {
            // TODO: Create a default tree source in a rather nicer manner
            KEdSubject.p__treeSource = new KTreeSource('/api/taxonomy/fetch?v='+KEditorSchema.p__schema.user_version+'&', KTaxonomies);
        }
    },

    // --------------------------------------------------------------------------------------
    // Handlers
    j__handleClick: function(event)  // also called when it's just been added to open the tree view, with evt === undefined
    {
        if(event !== undefined) {event.preventDefault();}

        // Take the focus
        this.p__keditorValueControl.j__handleFocus();

        // Setup the container for the extras
        var e = this.p__keditorValueControl.j__getExtrasContainer();

        // Got a tree control?
        var tree_init = false;
        if(!this.q__tree) {
            // No, create it
            this.j__ensureTreeSource();
            this.q__tree = new KTree(KEdSubject.p__treeSource,this,{p__size:KTREE_SMALL});
            this.q__tree.j__setTypeFilter(this.p__keditorValueControl.q__defn.p__controlByTypes);
            e.innerHTML = this.q__tree.j__generateHtml();
            tree_init = true; // attach and init the control after it has been displayed
        }

        // Show the control
        $(e).show();

        // Attachment of tree control needs to wait until the tree is visible. Don't you just love browsers?
        if(tree_init) {
            this.q__tree.j__attach();
            this.q__tree.j__setSelection(this.p__objref);
            if(!this.p__objref) {
                this.q__tree.j__setSelectionToLevel0NodeIfOnlyOne();
            }
        }

        // Highlight the container
        $('#'+this.q__domId).addClass('z__editor_link_control_focused');
    },
    j__lostFocus: function()  // not proper handler as such, called by value control
    {
        // Unhighlight the container
        $('#'+this.q__domId).removeClass('z__editor_link_control_focused');
    },

    // --------------------------------------------------------------------------------------
    // KTree delegate methods
    j__treeSelectionChange: function(tree, ref, depth) {
        if(depth <= KEdSubject.p__minSelectDepth) {return;}    // ignore if not deep enough
        this.p__objref = ref;
        var t = this.q__tree.j__displayNameOf(ref);
        this.p__objectTitle = t;
        $('#'+this.q__domId+'_t').text(t);
    }
});

// Value class
j__makeKeditorValueClass(T_PSEUDO_TAXONOMY_OBJREF,KEdSubject,['p__objectTitle'],{
    p__dataType:T_OBJREF,
    j__textForUndoableDeleted: function() {
        return this.q__control.p__objectTitle;
    },
    j__wasAdded: function() {
        this.q__control.j__handleClick();
    }
});


// ----------------------------------------------------------------------------------------------------

var splitFilename = function(filename) {
    var m = filename.match(/^(.+)\.([^\.]+?)$/);
    if(!m) { return {f:filename,e:''}; }
    return {f:m[1], e:m[2]};
};

var FILE_COMPONENT_EDIT = {
    'filename': {
        j__prompt: function(value) {
            var f = splitFilename(value.p__fileInfo.filename);
            return [KApp.j__text('EditorFileEditName', {EXT:f.e}), f.f];
        },
        j__adjustText: function(value, text) {
            return text.replace(/[\s+]/g,' ') + '.' +splitFilename(value.p__fileInfo.filename).e;
        }
    },
    'version': {
        j__prompt: function(value) {
            return [KApp.j__text('EditorFileEditVer'), value.p__fileInfo.version];
        },
        j__adjustText: function(value, text) {
            return text.replace(/[^A-Za-z0-9\.]/g,'.');
        }
    }
};

var KEdFile = function(fileJson) { this.j__initialize(fileJson); };
_.extend(KEdFile.prototype, KControl.prototype);
_.extend(KEdFile.prototype, {
    // p__keditorValueControl -- should be set to KEdValue object containing this (done by default)
    // p__encodedFileJson -- encoded string of JSON representing this file
    // p__fileInfo -- parsed JSON representing this file
    // p__iconHTML -- HTML for icon, sent from server
    j__initialize: function(fileJson) {
        if(typeof(fileJson) === "string") {
            this.j__setFromJson(fileJson);
        } else {
            // When new value is created by file upload, fileJson is a JS File object
            this.q__uploadingFile = fileJson;
        }
    },
    j__generateHtml2: function(i) {
        // Div contains a span so the strikethrough can be applied accurately when the file is deleted
        var html = ['<div id="'+i+'" class="z__editor_attached_file'];
        if(!this.p__encodedFileJson) { html.push(" z__editor_attached_file_uploading"); }
        html.push('">',
            (this.q__uploadingFile ? '' : '<div class="z__editor_attached_file_version_holder"><input type="file">'+KApp.j__text('EditorFileNewVer')+'</div>'),
            this.p__iconHTML, '<span><a href="#" data-edit="filename">',
                escapeHTML(this.q__uploadingFile ? this.q__uploadingFile.name : this.p__fileInfo.filename),
            '</a></span> &nbsp; <span class="z__editor_attached_file_version">(<a href="#" data-edit="version">',
                escapeHTML(this.q__uploadingFile ? FILE_FIRST_VERSION_STRING : this.p__fileInfo.version),
            '</a>)</span></div>');
        return html.join('');
    },
    j__attach2: function(i) {
        var value = this; // scoping
        $('#'+this.q__domId+' a').on('click', function(evt) {
            evt.preventDefault();
            // Only do renaming if:
            //   there's a JSON encoder available
            //   and the file has been uploaded (because otherwise the filename will be overwritten)
            if(window.JSON && value.p__encodedFileJson) {
                var editName = this.getAttribute('data-edit');
                var edit = FILE_COMPONENT_EDIT[editName];
                if(edit) {
                    var args = edit.j__prompt(value);
                    var newValue = window.prompt(args[0], args[1]); // can't use apply() on window.prompt in old IEs
                    if(newValue && newValue.length > 0) {
                        value.p__fileInfo[editName] = edit.j__adjustText(value, newValue);
                        value.p__encodedFileJson = JSON.stringify(value.p__fileInfo);
                        $('#'+value.q__domId+' span a[data-edit='+editName+']').text(value.p__fileInfo[editName]);
                    }
                }
            }
        });
        var fileInput = $('#'+this.q__domId+' input[type=file]').on('change', function(evt) {
            evt.preventDefault();
            if(KFileUpload.j__browserFullSupportCheckWithAlert()) {
                if(this.files.length === 1) {
                    value.p__keditorValueControl.p__parentContainer.q__fileUploadTarget.j__uploadFiles(this.files, value);
                    $('#'+value.q__domId+' .z__editor_attached_file_version_holder').hide();
                    $('#'+value.q__domId).addClass("z__editor_attached_file_uploading");
                    value.p__savedFileJson = value.p__encodedFileJson;
                    value.p__encodedFileJson = undefined; // prevent editor being saved until it's uploaded
                }
            }
            this.value = '';    // remove file for later
        });
        if(!KFileUpload.p__haveFullBrowserSupport) {
            fileInput.on('click', function(evt) {
                evt.preventDefault();
                KFileUpload.j__browserFullSupportCheckWithAlert();
            });
        }
    },
    j__value: function() {
        return this.p__encodedFileJson;
    },
    j__deletedDisplay: function(del) {
        // for when it's deleted but undoable
        if(del) {
            $('#'+this.q__domId).addClass('z__editor_attached_file_deleted');
        } else {
            $('#'+this.q__domId).removeClass('z__editor_attached_file_deleted');
        }
        if(KApp.p__runningMsie) {
            // IE can't fade images in a standards compliant manner
            var i = $('#'+this.q__domId)[0].getElementsByTagName('img');
            i[0].style.filter=(del?'alpha(opacity=50)':'');
        }
    },
    j__uploadFinished: function(json) {
        this.j__setFromJson(json);
        $('#'+this.q__domId).removeClass('z__editor_attached_file_uploading');
    },
    j__uploadFailed: function(file) {
        $('#'+this.q__domId).
            removeClass('z__editor_attached_file_uploading').
            addClass('z__editor_attached_file_upload_failed').
            text("Upload failed: "+file.name);
    },
    j__newVersionUploadFinish: function(json) {
        var nextVersion = KFileUpload.j__nextVersionNumber(this.p__fileInfo.version || FILE_FIRST_VERSION_STRING);
        var tracking = this.p__fileInfo.trackingId;
        this.j__uploadFinished(json);
        this.p__fileInfo.trackingId = tracking;
        this.p__fileInfo.version = nextVersion;
        this.p__encodedFileJson = JSON.stringify(this.p__fileInfo);
        // Update filename display and version number
        $('#'+this.q__domId+' a[data-edit=filename]').text(this.p__fileInfo.filename);
        $('#'+this.q__domId+' a[data-edit=version]').text(this.p__fileInfo.version);
    },
    j__newVersionUploadFailed: function() {
        $('#'+this.q__domId).removeClass("z__editor_attached_file_uploading");
        $('#'+this.q__domId+' .z__editor_attached_file_version_holder').show();
        this.p__encodedFileJson = this.p__savedFileJson;
    },
    j__setFromJson: function(json) {
        this.p__fileInfo = $.parseJSON(json);
        this.p__encodedFileJson = json;
    },
    j__getBusyMessage: function() {
        // If there's no JSON, a file is being uploaded
        return this.p__encodedFileJson ? null : KApp.j__text('EditorErrFileUploading');
    }
});

var j__KEdFile_setupForFileUploadsOnContainer = function(container) {
    var values = {};
    var delegate = {
        j__onStart: function(id, file, icon, userData) {
            if(userData) { return; }
            // New file value
            values[id] = container.j__addNewValue(T_IDENTIFIER_FILE, [T_IDENTIFIER_FILE, Q_NULL, file, icon]);
            // Use the filename to set the object title?
            if(container.p__keditor.j__getTitle() === null) {
                // Set title to tidied up filename
                container.p__keditor.j__setTitle(
                    stripString(file.name.replace(/\.[a-zA-Z0-9]+$/g,'').replace(/([A-Z][a-z])/g,' $1').replace(/[_\-]/g,' ').replace(/\s+/g,' '))
                );
            }
        },
        j__onFinish: function(id, file, json, userData) {
            if(userData) {
                userData.j__newVersionUploadFinish(json);
            } else {
                values[id].q__control.j__uploadFinished(json);
            }
        },
        j__onUploadFailed: function(id, file, error, userData) {
            if(userData) {
                userData.j__newVersionUploadFailed();
            } else {
                values[id].q__control.j__uploadFailed(file);
            }
        }
    };
    container.q__fileUploadTarget = KFileUpload.j__newTarget(delegate);
    return container.q__fileUploadTarget.j__generateHTML();
};

// Value class
j__makeKeditorValueClass(T_IDENTIFIER_FILE,KEdFile,['p__iconHTML'],{
    j__showAsUndoableDeleted: function() {
        this.q__control.j__deletedDisplay(true);
    },
    j__showEditableControlAfterUndo: function() {
        this.q__control.j__deletedDisplay(false);
    },
    j__deleteShouldRemoveValueFromDisplay: function() {
        // Delete shouldn't hide file elements which are uploading,
        // but allow delete of failed uploads.
        return $('#'+this.q__control.q__domId).hasClass('z__editor_attached_file_upload_failed');
    }
});

// ----------------------------------------------------------------------------------------------------

var KEdDate = function(dateStart) {
    this.p__dateTimeStart = dateStart;
    // this.p__dateTimeEnd set by KEdValue constructor
    // this.p__dateTimePrecision set by KEdValue constructor
    // this.p__dateTimeZone set by KEdValue constructor
};
_.extend(KEdDate.prototype, KControl.prototype);
_.extend(KEdDate.prototype, {
    // q__control - KCtrlDateTimeEditor
    // p__dateTimeStart, p__dateTimeEnd -- unparsed input
    // p__dateTimePrecision - given precision of the input
    j__generateHtml2: function(i) {
        // Get UI options
        var uiOptions = (this.p__keditorValueControl.q__defn.p__uiOptions || DEFAULT_UI_OPTIONS_DATETIME).split(',');
        // Get a datetime editor and generate HTML
        this.q__control = new KCtrlDateTimeEditor(this.p__dateTimeStart, this.p__dateTimeEnd, this.p__dateTimePrecision, this.p__dateTimeZone,
            uiOptions[0],           // default precision for this field
            (uiOptions[1] === 'y'), // user can choose precision
            (uiOptions[2] === 'y'), // it's a range control
            (uiOptions[3] === 'y')  // time zones should be displayed
        );
        return '<div id="'+i+'">'+this.q__control.j__generateHtml()+'</div>';
    },
    j__attach2: function(i) {
        this.q__control.j__attach();
    },
    j__value: function() {
        return this.q__control.j__value();
    },
    j__validate: function() {
        return this.q__control.j__getErrorMessage();
    }
});

// Value class
j__makeKeditorValueClass(T_DATETIME,KEdDate,['p__dateTimeEnd','p__dateTimePrecision','p__dateTimeZone'],{
    j__textForUndoableDeleted: function() {
        // Reach inside the KEdDate object to get the KCtrlDateTimeEditor control
        return this.q__control.q__control.j__dateAsText();
    }
});

// ----------------------------------------------------------------------------------------------------

// Suffixes on DOM ids:
    // _f - fields

var KEdPersonName = function(encoded_name) {
    this.q__encodedName = encoded_name;
};
_.extend(KEdPersonName.prototype, KControl.prototype);
// Order of fields for the cultures
var q__PERSON_NAME_CULTURE_ORDER = {w:['t','f','m','l','s'],L:['l','f','m','t','s'],e:['t','l','m','f','s']};
// For working out the widths
var q__PERSON_NAME_FIELD_SIZES = {t:1,f:4,m:3,l:4,s:2};
// Implementation
_.extend(KEdPersonName.prototype, {
    // p__keditorValueControl -- should be set to KEdValue object containing this (done by default)
    j__generateHtml2: function(i) {
        // Decode UI options -- here so the schema definition can be reached
        var ui_options = (this.p__keditorValueControl.q__defn.p__uiOptions || DEFAULT_UI_OPTIONS_PERSON_NAME).split(',');
        this.q__offerCultures = ui_options.shift().split('');
        var cf = [];
        _.each(ui_options, function(e) {
            var s = e.split('=');
            var f = [];
            _.each(s[1].split(''), function(x) {f[x] = 1;});
            cf[s[0]] = f;
        });
        this.q__cultureFields = cf;
        // Make a default encoded name?
        if(!this.q__encodedName || this.q__encodedName === '') {
            this.q__encodedName = this.q__offerCultures[0];
        }
        // Decode name
        var elements = this.q__encodedName.split("\x1f");
        var decoded = [];
        this.q__culture = elements.shift();
        _.each(elements, function(e) {
            if(e.length > 1) {
                decoded[e.substr(0,1)] = e.substr(1);
            }
        });
        this.q__fields = decoded;
        // Need a drop down for the culture?
        var d = '';
        if(this.q__offerCultures.length > 1) {
            this.q__cultureSelector = new KCtrlDropdownMenu(_.bind(this.j__cultureMenuContents, this),
                _.bind(this.j__selectCulture, this), this.q__culture);
            d = '<div style="float:right">'+this.q__cultureSelector.j__generateHtml()+'</div>';
        }
        // Output the html
        return '<div id="'+i+'">'+d+'<span id="'+i+'_f">'+this.j__generateFieldsHtml()+'</span></div>';
    },
    j__attach2: function(i) {
        // Fields
        this.j__attachFieldControls();
        // Culture selection
        if(this.q__cultureSelector) {
            this.q__cultureSelector.j__attach();
        }
    },
    j__value: function() {
        var encoded = this.q__culture;
        for(var i = 0; i < this.q__controls.length; i++) {
            var v = this.q__controls[i].j__value();
            if(v !== '') {
                encoded += "\x1f"+this.q__controlFields[i]+v;
            }
        }
        return (encoded.length > 1)?encoded:''; // if no fields are filled in, don't output anything
    },
    j__valueAsText: function()        // for deleted text
    {
        var h = '';
        for(var i = 0; i < this.q__controls.length; i++) {
            var v = this.q__controls[i].j__value();
            if(v !== '') {
                h += " "+v;
            }
        }
        return h;
    },

    // Fields
    j__generateFieldsHtml: function() {
        var t = this;   // for scoping
        var controls = [];
        var fields = [];
        var size_total = 1;
        _.each(q__PERSON_NAME_CULTURE_ORDER[this.q__culture], function(field_name) {
            var v = t.q__fields[field_name];
            if(v || t.q__cultureFields[t.q__culture][field_name]) {
                // Create a control for this field
                var fieldNameKey = 'PNameField_'+((t.q__culture === 'L') ? 'w' : t.q__culture)+'_'+field_name; // L uses w keys
                var c = new KCtrlTextWithInnerLabel(v || '', KApp.j__text(fieldNameKey), 15);
                controls.push(c);
                fields.push(field_name);
                size_total += q__PERSON_NAME_FIELD_SIZES[field_name];
            }
        });
        // Generate HTML from the controls
        var h = '';
        for(var i = 0; i < controls.length; i++) {
            var c = controls[i];
            c.p__width = Math.round((q__PERSON_NAME_FIELD_SIZES[fields[i]] * 76) / size_total);
            h += c.j__generateHtml();
            if(i < (controls.length - 1)) {
                // With a little special knowledge about the various cultures...
                h += ((this.q__culture == 'L' || (this.q__culture == 'e' && fields[i] == 'l'))?', ':' ');
            }
        }
        this.q__controls = controls;
        this.q__controlFields = fields;
        return h;
    },
    j__attachFieldControls: function() {
        _.each(this.q__controls, function(c) {
            c.j__attach();
        });
    },

    // Culture selection
    j__cultureMenuContents: function() {
        var h = '';
        _.each(this.q__offerCultures, function(c) {
            h += '<a href="#C'+c+'">'+KApp.j__text('PNameCulture_'+c)+'</a>';
        });
        return h;
    },
    j__selectCulture: function(a) {
        var new_culture = a.href.substr(a.href.length-1);   // get in IE compatible way
        if(new_culture == this.q__culture) {return;}    // stop now
        // Retrieve the existing field values
        var fields = [];
        for(var i = 0; i < this.q__controls.length; i++) {
            var v = this.q__controls[i].j__value();
            if(v !== '') { fields[this.q__controlFields[i]] = v; }
        }
        this.q__fields = fields;

        // Set new culture var
        this.q__culture = new_culture;

        // Update caption
        this.q__cultureSelector.j__setCaption(new_culture);

        // Rebuild...
        $('#'+this.q__domId+'_f').html(this.j__generateFieldsHtml());
        this.j__attachFieldControls();

        // Fix up handlers on the input fields so the qualfier display works
        this.p__keditorValueControl.j__attachHandlersToControls();
    }
});

// Value class
j__makeKeditorValueClass(T_TEXT_PERSON_NAME,KEdPersonName,null,{
    j__textForUndoableDeleted: function() {
        return this.q__control.j__valueAsText();
    }
});


// ----------------------------------------------------------------------------------------------------
// GENERIC COUNTRY INFO
// Generate with script/runner "KCountry.keditor_javascript_definitions()" and copy in manually.
var q__COUNTRIES = [["AD","Andorra","376"],["AX","\u00c5land Islands",null],["AF","Afghanistan","93"],["AL","Albania","355"],["DZ","Algeria","213"],["AS","American Samoa","1"],["AO","Angola","244"],["AI","Anguilla","1"],["AQ","Antarctica",null],["AG","Antigua and Barbuda","1"],["AR","Argentina","54"],["AM","Armenia","374"],["AW","Aruba","297"],["247","Ascension","247"],["AU","Australia","61"],["AT","Austria","43"],["AZ","Azerbaijan","994"],["BS","Bahamas","1"],["BH","Bahrain","973"],["BD","Bangladesh","880"],["BB","Barbados","1"],["BY","Belarus","375"],["BE","Belgium","32"],["BZ","Belize","501"],["BJ","Benin","229"],["BM","Bermuda","1"],["BT","Bhutan","975"],["BO","Bolivia","591"],["BA","Bosnia and Herzegovina","387"],["BW","Botswana","267"],["BV","Bouvet Island",null],["BR","Brazil","55"],["IO","British Indian Ocean Territory",null],["BN","Brunei Darussalam","673"],["BG","Bulgaria","359"],["BF","Burkina Faso","226"],["BI","Burundi","257"],["KH","Cambodia","855"],["CM","Cameroon","237"],["CA","Canada","1"],["CV","Cape Verde","238"],["KY","Cayman Islands","1"],["CF","Central African Republic","236"],["TD","Chad","235"],["CL","Chile","56"],["CN","China","86"],["CX","Christmas Island",null],["CC","Cocos (Keeling) Islands",null],["CO","Colombia","57"],["KM","Comoros","269"],["CG","Congo","242"],["CD","Congo, The Democratic Republic of The","243"],["CK","Cook Islands","682"],["CR","Costa Rica","506"],["HR","Croatia","385"],["CU","Cuba","53"],["CY","Cyprus","357"],["CZ","Czech Republic","420"],["CI","C\u00f4te d'Ivoire","225"],["DK","Denmark","45"],["246","Diego Garcia","246"],["DJ","Djibouti","253"],["DM","Dominica","1"],["DO","Dominican Republic","1"],["EC","Ecuador","593"],["EG","Egypt","20"],["SV","El Salvador","503"],["GQ","Equatorial Guinea","240"],["ER","Eritrea","291"],["EE","Estonia","372"],["ET","Ethiopia","251"],["FK","Falkland Islands (Malvinas)","500"],["FO","Faroe Islands","298"],["FJ","Fiji","679"],["FI","Finland","358"],["FR","France","33"],["GF","French Guiana","594"],["PF","French Polynesia","689"],["TF","French Southern Territories",null],["GA","Gabon","241"],["GM","Gambia","220"],["GE","Georgia","995"],["DE","Germany","49"],["GH","Ghana","233"],["GI","Gibraltar","350"],["GR","Greece","30"],["GL","Greenland","299"],["GD","Grenada","1"],["GP","Guadeloupe","590"],["GU","Guam","1"],["GT","Guatemala","502"],["GG","Guernsey",null],["GN","Guinea","224"],["GW","Guinea-Bissau","245"],["GY","Guyana","592"],["HT","Haiti","509"],["HM","Heard Island and Mcdonald Islands",null],["HN","Honduras","504"],["HK","Hong Kong","852"],["HU","Hungary","36"],["IS","Iceland","354"],["IN","India","91"],["ID","Indonesia","62"],["IR","Iran, Islamic Republic of","98"],["IQ","Iraq","964"],["IE","Ireland","353"],["IM","Isle of Man",null],["IL","Israel","972"],["IT","Italy","39"],["JM","Jamaica","1"],["JP","Japan","81"],["JE","Jersey",null],["JO","Jordan","962"],["KZ","Kazakhstan","7"],["KE","Kenya","254"],["KI","Kiribati","686"],["KP","Korea, Democratic People's Republic of","850"],["KR","Korea, Republic of","82"],["XK","Kosovo, Republic of","381"],["KW","Kuwait","965"],["KG","Kyrgyzstan","996"],["LA","Lao People's Democratic Republic","856"],["LV","Latvia","371"],["LB","Lebanon","961"],["LS","Lesotho","266"],["LR","Liberia","231"],["LY","Libya","218"],["LI","Liechtenstein","423"],["LT","Lithuania","370"],["LU","Luxembourg","352"],["MO","Macao","853"],["MK","Macedonia, The Former Yugoslav Republic of","389"],["MG","Madagascar","261"],["MW","Malawi","265"],["MY","Malaysia","60"],["MV","Maldives","960"],["ML","Mali","223"],["MT","Malta","356"],["MH","Marshall Islands","692"],["MQ","Martinique","596"],["MR","Mauritania","222"],["MU","Mauritius","230"],["YT","Mayotte","269"],["MX","Mexico","52"],["FM","Micronesia, Federated States of","691"],["MD","Moldova, Republic of","373"],["MC","Monaco","377"],["MN","Mongolia","976"],["ME","Montenegro","382"],["MS","Montserrat","1"],["MA","Morocco","212"],["MZ","Mozambique","258"],["MM","Myanmar","95"],["NA","Namibia","264"],["NR","Nauru","674"],["NP","Nepal","977"],["NL","Netherlands","31"],["AN","Netherlands Antilles",null],["NC","New Caledonia","687"],["NZ","New Zealand","64"],["NI","Nicaragua","505"],["NE","Niger","227"],["NG","Nigeria","234"],["NU","Niue","683"],["NF","Norfolk Island",null],["MP","Northern Mariana Islands","1"],["NO","Norway","47"],["OM","Oman","968"],["PK","Pakistan","92"],["PW","Palau","680"],["PS","Palestine",null],["PA","Panama","507"],["PG","Papua New Guinea","675"],["PY","Paraguay","595"],["PE","Peru","51"],["PH","Philippines","63"],["PN","Pitcairn",null],["PL","Poland","48"],["PT","Portugal","351"],["PR","Puerto Rico","1"],["QA","Qatar","974"],["RO","Romania","40"],["RU","Russian Federation","7"],["RW","Rwanda","250"],["RE","R\u00e9union","262"],["BL","Saint Barth\u00e9lemy",null],["SH","Saint Helena","290"],["KN","Saint Kitts and Nevis","1"],["LC","Saint Lucia","1"],["MF","Saint Martin",null],["PM","Saint Pierre and Miquelon","508"],["VC","Saint Vincent and The Grenadines","1"],["WS","Samoa","685"],["SM","San Marino","378"],["ST","Sao Tome and Principe","239"],["SA","Saudi Arabia","966"],["SN","Senegal","221"],["RS","Serbia","381"],["SC","Seychelles","248"],["SL","Sierra Leone","232"],["SG","Singapore","65"],["SK","Slovakia","421"],["SI","Slovenia","386"],["SB","Solomon Islands","677"],["SO","Somalia","252"],["ZA","South Africa","27"],["GS","South Georgia and The South Sandwich Islands",null],["ES","Spain","34"],["LK","Sri Lanka","94"],["SD","Sudan","249"],["SR","Suriname","597"],["SJ","Svalbard and Jan Mayen",null],["SZ","Swaziland","268"],["SE","Sweden","46"],["CH","Switzerland","41"],["SY","Syrian Arab Republic","963"],["TW","Taiwan, Province of China",null],["TJ","Tajikistan","992"],["TZ","Tanzania, United Republic of","255"],["TH","Thailand","66"],["TL","Timor-Leste","670"],["TG","Togo","228"],["TK","Tokelau","690"],["TO","Tonga","676"],["TT","Trinidad and Tobago","1"],["TN","Tunisia","216"],["TR","Turkey","90"],["TM","Turkmenistan","993"],["TC","Turks and Caicos Islands","1"],["TV","Tuvalu","688"],["UG","Uganda","256"],["UA","Ukraine","380"],["AE","United Arab Emirates","971"],["GB","United Kingdom","44"],["US","United States","1"],["UM","United States Minor Outlying Islands",null],["UY","Uruguay","598"],["UZ","Uzbekistan","998"],["VU","Vanuatu","678"],["VA","Vatican City State (Holy See)","39"],["VE","Venezuela","58"],["VN","Viet Nam","84"],["VG","Virgin Islands, British","1"],["VI","Virgin Islands, U.S.","1"],["WF","Wallis and Futuna","681"],["EH","Western Sahara",null],["YE","Yemen","967"],["ZM","Zambia","260"],["ZW","Zimbabwe","263"]];


// ----------------------------------------------------------------------------------------------------
// TELEPHONE COUNTRY INFO
// Generate with script/runner "KTelephone.keditor_javascript_definitions()" and copy in manually.
var q__PHONE_NANP_NON_US = {"819": "CA", "226": "CA", "709": "CA", "204": "CA", "787": "PR", "403": "CA", "876": "JM", "809": "DO", "514": "CA", "613": "CA", "778": "CA", "250": "CA", "767": "DM", "867": "CA", "306": "CA", "581": "CA", "438": "CA", "647": "CA", "416": "CA", "284": "VG", "450": "CA", "604": "CA", "780": "CA", "340": "VI", "868": "TT", "758": "LC", "418": "CA", "902": "CA", "506": "CA", "649": "TC", "869": "KN", "473": "GD", "242": "BS", "264": "AI", "705": "CA", "441": "BM", "519": "CA", "905": "CA", "289": "CA", "784": "VC", "807": "CA", "587": "CA", "939": "PR", "664": "MS", "829": "DO", "345": "KY", "246": "BB", "268": "AG"};


// Suffixes on DOM ids:
//  _c - country select
//  _n - number field
//  (extension is separate control)
var q__PHONE_FIELDS = ['q__country','q__number','q__extension'];
var KEdPhone = function(encoded) {
    // Default?
    if(!encoded) {encoded = KUserHomeCountry+"\x1f";}    // phone fields default to user's home country
    // Split
    var a = encoded.split(/\x1f/);
    for(var z = 0; z < 3; z++) {
        this[q__PHONE_FIELDS[z]] = a[z] || '';
    }
};
_.extend(KEdPhone.prototype, KControl.prototype);
_.extend(KEdPhone.prototype, {
    // p__keditorValueControl -- should be set to KEdValue object containing this (done by default)
    j__generateHtml2: function(i) {
        this.q__extControl = new KCtrlTextWithInnerLabel(this.q__extension,'ext',10);
        var h = '<span id="'+i+'"><select id="'+i+'_c" tabindex="1" style="width:40%">';
        var sel = this.q__country;
        _.each(q__COUNTRIES, function(c) {
            if(c[2]) {
                h += '<option value="'+c[0]+'"'+((sel == c[0])?' selected':'')+'>'+c[1]+' +'+c[2]+'</option>';
            }
        });
        return h + '</select> <input type="text" tabindex="1" id="'+i+'_n" style="width:35%" value="'+escapeHTML(this.q__number)+'"> '+this.q__extControl.j__generateHtml()+'</span>';
    },
    j__attach2: function(i) {
        this.q__extControl.j__attach();
        $('#'+i+'_n').
            blur(_.bind(this.j__handleBlur, this)).
            keyup(_.bind(this.j__handleKeyup, this));
    },
    j__value: function() {
        var number = stripString($('#'+this.q__domId+'_n').val());
        var extension = this.q__extControl.j__value().replace(/\s/g,'');
        if(number === '') {return '';}
        var v = stripString($('#'+this.q__domId+'_c').val())+"\x1f"+number;
        if(extension !== '') { v += "\x1f"+extension; }
        return v;
    },
    j__validate: function() {
        var number = stripString($('#'+this.q__domId+'_n').val());
        var extension = stripString(this.q__extControl.j__value());
        if(number === '' && extension !== '') {
            return KApp.j__text('EditorErrPhoneNum');
        }
        if(number.match(/\+/)) {
            return KApp.j__text('EditorErrPhoneNoPlus');
        }
        if(number.match(/[^0-9.,:\(\) \-]/)) {
            return KApp.j__text('EditorErrPhoneChars');  // not strictly true
        }
        if(extension.match(/[^0-9a-zA-Z_ \-]/)) {
            return KApp.j__text('EditorErrPhoneInvalidExt');
        }
        return null;
    },
    // -- handlers
    j__handleKeyup: function(evt) {
        var o = $('#'+this.q__domId+'_n')[0];
        var v = o.value;
        if(v.substring(0,1) == '+') {
            var phone_code = v.substring(1);
            var country_code = null;
            if(phone_code == '1') {
                // Special case for US, as +1 is used by NANP countries
                country_code = 'US';
            } else if(phone_code == '39') {
                // Don't default to the Vatican, which shares the code.
                country_code = 'IT';
            } else {
                _.each(q__COUNTRIES, function(c) {
                    if(c[2] == phone_code) { country_code = c[0]; }
                });
            }
            if(country_code) {
                var cselect = $('#'+this.q__domId+'_c')[0];
                cselect.value = country_code;
                o.value = '';
                o.select(); // for IE
                // Flash the country control to draw user's attention.
                cselect.style.color='red';
                window.setTimeout(function() {cselect.style.color='';},1000);
            }
        }
    },
    j__handleBlur: function() {
        // Check US / NANP code?
        var c = $('#'+this.q__domId+'_c')[0];
        if(c.options[c.selectedIndex].text.match(/\+1$/)) {
            // NANP code... what's the area code?
            var m = $('#'+this.q__domId+'_n').val().match(/^\D*1?\D*(\d\d\d)/);
            if(m) {
                var area_code = m[1];
                // Check we're in the right area
                var expected_county = q__PHONE_NANP_NON_US[area_code] || 'US';
                if(c.value != expected_county) {
                    // Need to change it
                    c.value = expected_county;
                    // Tell the user
                    var n = null;
                    _.each(q__COUNTRIES, function(c) {
                        if(c[0] == expected_county) {n = c[1];}
                    });
                    alert("Area code "+area_code+" is in "+n+"\n\nThe country has been changed.");
                }
            }
        }
    }
});

// Value class
j__makeKeditorValueClass(T_IDENTIFIER_TELEPHONE_NUMBER,KEdPhone,null,{
    j__textForUndoableDeleted: function() {
        var x = this.q__control.j__value().split(/\x1f/);
        var t = null;
        if(x.length > 1) {
            t = x[1];
        }
        if(x.length > 2) {
            t += ' ext '+x[2];
        }
        return t;
    }
});


// ----------------------------------------------------------------------------------------------------


// Suffixes on DOM ids:
    // _c - country

var KEdAddress = function(encoded) {
    var a = null;
    if(encoded) {
        // Split fields -- use this convoluted method so that IE doesn't cause
        // problems by missing out empty fields.
        a = _.map(encoded.replace(/\x1f/g,"\x1f ").split(/\x1f/), stripString);
        // Remove and check version field
        if(a.shift() != ADDRESS_CURRENT_VERSION) {a = null;}    // BAD
    }
    if(!a) {
        // Set up blank address with fields
        a = _.map(this.q__MAIN_FIELDS, function() {return '';});
        a.push(KUserHomeCountry);  // default to user's home country
    }
    // Store
    this.p__fields = a;
};
/*CONST*/ ADDRESS_POSTCODE = 4;
/*CONST*/ ADDRESS_COUNTRY = 5;
/*CONST*/ ADDRESS_CURRENT_VERSION = '0';
_.extend(KEdAddress.prototype, KControl.prototype);
_.extend(KEdAddress.prototype, {
    // p__keditorValueControl -- should be set to KEdValue object containing this (done by default)
    q__MAIN_FIELDS: KApp.j__text('EditorAddressFields').split('|'),
    j__generateHtml2: function(i) {
        var html = '<div id="'+i+'" class="z__editor_address_field">';
        // Make the controls
        var fields = this.p__fields;    // scope into iterator
        var n = -1;
        this.q__controls = _.map(this.q__MAIN_FIELDS, function(field_label) {
            n++;
            return new KCtrlTextWithInnerLabel(fields[n], field_label, (n == ADDRESS_POSTCODE)?35:90);
        });
        html += _.map(this.q__controls, function(c) {return c.j__generateHtml();}).join('<br>');
        // Countries
        html += '<select id="'+i+'_c" tabindex="1" style="width:55%">';
        var sel = fields[ADDRESS_COUNTRY];
        _.each(q__COUNTRIES, function(c) {
            html += '<option value="'+c[0]+'"'+((sel == c[0])?' selected':'')+'>'+c[1]+'</option>';
        });
        // Finish country select and containing DIV
        return html+'</select></div>';
    },
    j__attach2: function(i) {
        // Attach all the labelled field boxes
        _.each(this.q__controls, function(control) {
            control.j__attach();
        });
    },
    j__value: function() {
        // Get the values from the controls, detecting any text in them
        var have_text = false;
        var f = _.map(this.q__controls, function(c) {
            var value = c.j__value();
            if(value && value !== '') {
                have_text = true;
            }
            return value || '';
        });
        // If there were no bits of text in the main fields, assume the country field is worthless too and return now
        if(!have_text) {return null;}
        // Otherwise assemble into a string and return
        f.unshift(ADDRESS_CURRENT_VERSION);
        f.push($('#'+this.q__domId+'_c').val());
        return f.join("\x1f");
    }
});

j__makeKeditorValueClass(T_IDENTIFIER_POSTAL_ADDRESS,KEdAddress,null,{
    j__textForUndoableDeleted: function() {
        var v = this.q__control.j__value();
        if(!v) {return null;}
        var x = v.split(/\x1f/);
        x.shift();x.pop();  // remove version and country
        return _.select(x, function(v) {return v !== '';}).join(', ');
    }
});

// ----------------------------------------------------------------------------------------------------

// To make a simple version of KCtrlText for validated fields, implement
//  j__processValue(value) -- take a value, and do whatever transforms are needed
//  j__validate() -- usual validation function
function j__makeValidatedKctrltext(identifier,fns) {
    // Editor class
    var klass = function(initial_contents) {
        KCtrlText.call(this, initial_contents);
    };
    _.extend(klass.prototype, KCtrlText.prototype);
    klass.prototype.j__valueSuper = klass.prototype.j__value;    // for inheritance
    klass.prototype.j__value = function() {
        return this.j__processValue(this.j__valueSuper());
    };
    _.extend(klass.prototype, fns);
    // Value class
    j__makeKeditorValueClass(identifier,klass);
}

// ----------------------------------------------------------------------------------------------------

// Email address value
j__makeValidatedKctrltext(T_IDENTIFIER_EMAIL_ADDRESS, {
    j__processValue: function(value) {
        // Strip leading and trailing whitespace from the value
        return stripString(value);
    },
    j__validate: function() {
        // Very simple regex should do the job well enough, don't want to be too strict
        var v = this.j__value();
        if(!(v.match(/\w/))) { return null; }   // don't complain about empty strings
        return (v.match(/^[^\@\s]+\@[^\.\@\s]+\.[^\s\@]+$/)) ? null : KApp.j__text('EditorErrPhoneInvalidEmail');
    }
});

// ----------------------------------------------------------------------------------------------------

// URL value -- don't do any validation
j__makeValidatedKctrltext(T_IDENTIFIER_URL,{
    j__processValue: function(value) {
        var v = stripString(value);
        // Add https: if the address contains a word characeter and doesn't begin with a URL scheme
        return (!(v.match(/\w/)) || v.match(/^\w+:/)) ? v : 'https://'+v;
    }
});


// ----------------------------------------------------------------------------------------------------

// UUID value
j__makeValidatedKctrltext(T_IDENTIFIER_UUID, {
    j__processValue: function(value) {
        // Strip leading and trailing whitespace from the value
        return stripString(value);
    },
    j__validate: function() {
        var v = this.j__value();
        if(!(v.match(/\w/))) { return null; }   // don't complain about empty strings
        return (v.match(/^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$/)) ? null : "This is not a valid UUID";
    }
});


// ----------------------------------------------------------------------------------------------------

// Special configuration names
j__makeValidatedKctrltext(T_IDENTIFIER_CONFIGURATION_NAME, {
    j__processValue: function(value) {
        // Strip leading and trailing whitespace from the value
        return stripString(value);
    },
    j__validate: function() {
        var v = this.j__value();
        return (!(v) || (v.match(/^[a-zA-Z0-9_-]+\:[:a-zA-Z0-9_-]+$/))) ? null : KApp.j__text('EditorErrPhoneInvalidConfigName');
    }
});

// ----------------------------------------------------------------------------------------------------

j__makeValidatedKctrltext(T_INTEGER,{
    j__processValue: function(value) {
        var v = value.replace(/\D+/g,'');
        if(v === '') {return null;}
        return v;
    },
    j__validate: function() {
        var v = this.j__valueSuper();
        if(!v || v.match(/^\s*\d*\s*$/)) {return null;}    // empty string, all whitespace, or valid number
        return KApp.j__text('EditorErrPhoneInvalidNumber');
    }
});

// ----------------------------------------------------------------------------------------------------

j__makeValidatedKctrltext(T_NUMBER,{
    j__processValue: function(value) {
        var v = value.replace(/[^\d\.]+/g,'');
        if(v === '') {return null;}
        return v;
    },
    j__validate: function() {
        var v = this.j__valueSuper();
        if(!v || v.match(/^\s*\d*(\.\d+)?\s*$/)) {return null;}    // empty string, all whitespace, or valid number
        return 'This is not a number. Do not use symbols.';
    }
});

// ----------------------------------------------------------------------------------------------------

var KEdPluginDefinedText = function(pluginDataType) {
    this.q__pluginDataType = pluginDataType;
};
_.extend(KEdPluginDefinedText.prototype, KControl.prototype, {
    j__generateHtml2: function(i) {
        // Fill in type name, if it doesn't exist already (too early to do this in the constructor)
        if(!this.q__pluginDataType) {
            this.q__pluginDataType = this.p__keditorValueControl.q__defn.p__pluginDataType;
        }
        // Set JSON encoded value
        this.q__json = this.p__jsonFromServer || '{}';
        // JSON encoder required to be able to edit values
        if(window.JSON) {
            // Create the UI using the registered adaptor
            var constructFn = this.q__pluginDataType ? KEditor.p__pluginTextTypeValueConstructor[this.q__pluginDataType] : undefined;
            if(constructFn) {
                this.q__pluginUserInterface = constructFn(JSON.parse(this.q__json), this.p__keditorValueControl.q__desc);
                this.q__pluginUserInterface.q__keditorPluginDefinedTextValueObject = this;
                return this.q__pluginUserInterface.j__generateHtml2(i);
            } else {
                return '<b>This value cannot be edited because the required plugin is not installed.</b>';
            }
        } else {
            return '<b>Your browser is too old to be able to edit this value.</b>';
        }
    },
    j__attach2: function(i) {
        if(this.q__pluginUserInterface) {
            this.q__pluginUserInterface.j__attach2(i);
        }
    },
    j__value: function() {
        if(!this.q__pluginUserInterface) {
            // Preserve any data sent from the server if a UI could not be created.
            return this.p__jsonFromServer ? (this.q__pluginDataType + "\x1f" + this.p__jsonFromServer) : null;
        }
        var v = this.q__pluginUserInterface.j__getValue(this.q__domId);
        return v ? (this.q__pluginDataType + "\x1f" + JSON.stringify(v)) : null;
    }
});
j__makeKeditorValueClass(T_TEXT_PLUGIN_DEFINED, KEdPluginDefinedText, ['p__jsonFromServer'], {
    j__textForUndoableDeleted: function() {
        var ui = this.q__control.q__pluginUserInterface;
        return ui ? ui.j__undoableDeletedText(this.q__control.q__domId) : "(Deleted value)";
    }
});


// ----------------------------------------------------------------------------------------------------

// Negative group IDs are used to signal to the server that they need to be replaced by random numbers
var q__attributeGroupNextId = -1;

// Suffixes on DOM ids:

var KEdAttributeGroup = function(attributeValues) {
    this.q__initialAttributeValues = attributeValues;
};
_.extend(KEdAttributeGroup.prototype, KControl.prototype);
_.extend(KEdAttributeGroup.prototype, {
    // p__keditorValueControl -- should be set to KEdValue object containing this (done by default)
    j__generateHtml2: function(i) {
        var groupDesc = this.p__keditorValueControl.q__defn.p__desc;
        var groupTypeRef = this.p__keditorValueControl.q__defn.p__groupType;
        var groupType = _.find(KEditorSchema.p__schema.types, function(t) { return t[SCHEMATYPE_ROOT_ROOT_REF] === groupTypeRef; });
        var attributes = [];
        if(groupType) {
            attributes = groupType[SCHEMATYPE_ROOT_ATTRIBUTES];
        }

        var controls = this.q__controls = [];
        var html = '<div id="'+i+'" class="z__editor_attribute_group">';

        var parentContainer = this.p__keditorValueControl.p__parentContainer;
        var keditor = parentContainer.p__keditor;

        if(attributes.length === 0) {
            // Make it very obvious when schema isn't set up correctly. This will generally only
            // happen when a plugin sets up an object incorrectly.
            html += '<div style="color:red">Schema not valid for attribute group with desc '+_.escape(''+groupDesc)+'</div>';
        }

        var initialAttributeValues = this.q__initialAttributeValues;
        if(initialAttributeValues === undefined) {
            // If no initial values set, create empty list so pseudo attributes types are initialised properly.
            initialAttributeValues = _.map(attributes, function(desc) { return [desc, []]; });
        }
        var initialValuesByDesc = {};
        _.each(initialAttributeValues, function(v) {
            KEditor.j__adjustAttribute(v);
            initialValuesByDesc[v[0]] = v[1];
        });

        var first = true;
        _.each(attributes, function(desc) {
            var defn = KEditorSchema.j__attrDefn(desc);
            var val = initialValuesByDesc[desc];
            if(!val) {
                val = (defn.p__normalDataType === T_IDENTIFIER_FILE) ? [] : [defn.p__newCreationData];
            }
            var nestedContainer = new KAttrContainer(keditor, desc, val);
            nestedContainer.p__singleValue = true;
            if(first) {
                nestedContainer.p__omitAttributeName = true;
                first = false;
            }
            controls.push(nestedContainer);
            html += nestedContainer.j__generateHtml();
        });

        // Modify parentContainer to override the value generation, using values from the nested containers
        parentContainer.j__value = function() {
            var values = [];
            _.each(parentContainer.q__values, function(attributeGroupValue) {
                // Need to send a group start, even if it has been deleted, so that
                // deletion works properly on the server side.
                values.push('G`'+groupDesc+'`'+(attributeGroupValue.q__control.j__getGroupId()));
                if(!attributeGroupValue.q__deleted) {
                    _.each(attributeGroupValue.q__control.q__controls, function(c) {
                        values.push(c.j__value());
                    });
                }
                values.push('g');
            });
            return values.join('`');
        };

        // TODO: Modify parentContainer to override busy/error state functions

        return html+'</div>';
    },
    j__attach2: function(i) {
        _.each(this.q__controls, function(control) {
            control.j__attach();
        });
    },
    j__getGroupId: function() {
        // New group IDs are special negative IDs which are replaced on the server
        if(!this.q__attributeGroupId) {
            this.q__attributeGroupId = q__attributeGroupNextId;
            q__attributeGroupNextId--; // more negative
        }
        return this.q__attributeGroupId;
    }
    // doesn't have a j__value() method, as it's been implemented/overridden at the container level
});

j__makeKeditorValueClass(T_ATTRIBUTE_GROUP, KEdAttributeGroup, ['q__attributeGroupId'], {
    j__deleteShouldRemoveValueFromDisplay: function() {
        return false;
    },
    j__textForUndoableDeleted: function() {
        // TODO: Better display of deleted attribute group
        return "(deleted)";
    }
});

// ----------------------------------------------------------------------------------------------------

// Suffixes on DOM ids:

// Value class

// TODO: Implement values properly in KEditor
j__makeKeditorValueClass(T_IDENTIFIER_ISBN,KCtrlText);
j__makeKeditorValueClass(T_IDENTIFIER_POSTCODE,KCtrlText);
j__makeKeditorValueClass(T_TEXT_MULTILINE,KCtrlTextarea);


// ----------------------------------------------------------------------------------------------------
//   Attribute values
// ----------------------------------------------------------------------------------------------------

// p__keditor - parent editor
// p__top_html - HTML to insert at top of file (set by plugin_adaptor.js)
// p__bottom_html - HTML to insert at top of file (set by plugin_adaptor.js)
// p__singleValue - only allow a single value (set by plugin_adaptor.js)
// p__defaultEmptyValue - whether there's an empty value by default (set by plugin_adaptor.js)
var KAttrContainer = function(keditor,desc,values) {
    this.p__keditor = keditor;
    this.q__desc = desc;
    // Get the definition from the schema
    this.q__defn = KEditorSchema.j__attrDefn(this.q__desc);
    // Checkbox values shouldn't have an add attribute button
    if(this.q__defn.p__normalDataType === T_PSEUDO_TYPE_OBJREF_CHECKBOX) {
        this.p__singleValue = true;
    }
    // Store values
    this.q__initialValues = values;
};
_.extend(KAttrContainer.prototype, KControl.prototype);
_.extend(KAttrContainer.prototype, {
    // Defaults for the various options available to client side editor plugins
    // Values may be overridden in instance of these objects by the code in plugin_adaptor.js
    p__top_html: '',
    p__bottom_html: '',
    p__singleValue: false,
    p__defaultEmptyValue: true,

    // Interface
    j__generateHtml2: function(i) {
        // INITIALIZE VALUES -- as late as possible so client side plugins have a change to set options
        var isFileContainer = (this.q__defn.p__normalDataType === T_IDENTIFIER_FILE);
        // Empty values?
        var values = this.q__initialValues;
        if(values.length === 0 && this.p__defaultEmptyValue && !(isFileContainer)) {
            // Make a default empty value
            values = this.q__initialValues = [this.q__defn.p__newCreationData];
        }
        // Create the value controls
        var container = this;
        this.q__values = _.map(values, function(val) {
            var valueControlConstructor = KEdClasses[val[VL_TYPE]];
            return new valueControlConstructor(container, container.q__desc, val);
        });
        // Add in the current position so the order can be retrieved from the DOM later
        _.each(this.q__values, function(value, index) { value._dragPosition = index; });

        // GENERATE HTML
        // Main div, with add button and header row with name of attr, and cataloguing example
        var n = escapeHTML(this.q__defn.p__name);
        var h = '<div class="z__keyvalue_section" id="'+i+'">';
        if(!(this.p__singleValue || isFileContainer)) {
            // Add the 'add' button
            h += '<div class="z__editor_add"><a id="'+i+'_a" href="#"><img src="/images/clearbut.gif" height="14" width="14" alt="add" title="add '+n.toLowerCase()+'"></a></div>';
        }
        h += '<div class="z__keyvalue_row">';
        if(!this.p__omitAttributeName) {
            h += '<div class="z__keyvalue_col1" id="desc-label-'+this.q__desc+'">'+n+'</div>';
        }
        h += '</div>' + this.p__top_html; // include HTML from plugins

        // Containers of file values need a target for uploading new files
        if(isFileContainer) {
            h += '<div style="clear:both">'+j__KEdFile_setupForFileUploadsOnContainer(this)+'</div>';
        }

        // Special case warning for configuration names
        if(this.q__defn.p__normalDataType === T_IDENTIFIER_CONFIGURATION_NAME) {
            h += '<div class="z__keyvalue_row"><i>Warning: This attribute affects the behaviour of this application.</i></div>';
        }

        // Output all the values
        h += '<div class="z__editor_attr_container_value_container">';
        _.each(this.q__values, function(v) {
            h += v.j__generateHtml();
        });
        h += '</div>';

        // HTML from plugins, then divider and close the section div
        return h + this.p__bottom_html + '<div class="z__keyvalue_divider"></div></div>';
    },
    j__attach2: function(i) {
        // Attach values, and make sure that if there were dodgy values, the validation failure messages are shown on form display
        _.each(this.q__values, function(v) {
            v.j__attach();
            v.j__validationWithUi();
        });
        // Attach add button
        $('#'+this.q__domId+'_a').click(_.bind(this.j__handleAdd, this));
        // Make elements sortable
        $('#'+i+' .z__editor_attr_container_value_container').sortable({
            handle: '.z__editor_value_order_drag_handle',
            axis: 'y'
        });
        this.j__applyAriaAttributesToControls();
    },
    j__value: function() {
        // Copy values, will set elements to undefined as they're picked
        var valueControls = Array.prototype.slice.call(this.q__values);
        // Use order from DOM
        var orderedValueControls = [];
        $('.z__editor_value_order_drag_handle',this.q__domObj).each(function() {
            var pos = this.getAttribute('data-kvalueposition');
            if(pos) {
                var i = pos*1;
                if(valueControls[i]) {
                    orderedValueControls.push(valueControls[i]);
                    valueControls[i] = undefined;
                }
            }
        });
        // Any remaining? (being paranoid about not losing them)
        orderedValueControls = orderedValueControls.concat(_.compact(valueControls));
        // Get values from the controls, discarding anything falsey
        var attributeValues = _.compact(_.map(orderedValueControls, function(c) { return c.j__value(); }));
        // Serialize for the server
        if(attributeValues.length === 0) {return 'A`'+this.q__desc;}// wipe all values - not including this just means nothing is changed
        return 'A`'+this.q__desc+'`'+attributeValues.join('`');
    },

    // All values null (ie no data entered)
    j__allValuesNull: function() {
        var all_null = true;
        _.each(this.q__values, function(v) {if(v.j__value()) {all_null = false;}});
        return all_null;
    },

    j__allValidate: function() {
        // Check that all non-deleted values validate
        var ok = true;
        _.each(this.q__values, function(v) {
            if(v.j__validate()) {ok = false;}
        });
        return ok;
    },

    j__getFirstControlBusyMessage: function() {
        var m = null;
        _.each(this.q__values, function(v) {
            if(!m) {m = v.j__getBusyMessage();}
        });
        return m;
    },

    j__getAllValueControls: function() {
        return this.q__values;
    },

    // Handlers
    j__handleAdd: function(event) {
        // Stop the click doing anything annoying
        event.preventDefault();
        // Add value
        this.j__addNewValue();
    },

    // Utility methods
    j__applyAriaAttributesToControls: function() {
        var labelId = 'desc-label-'+this.q__desc;
        if($('#'+labelId).length) {
            $('input[type=text], input[type=file], textarea, .z__editor_link_control', this.q__domObj).each(function() {
                if(!(this.title || this.getAttribute('aria-labelledby') || this.getAttribute('aria-label'))) {
                    this.setAttribute('aria-labelledby', labelId);
                }
            });
        }
    },

    // Called by plugin_adaptor.js -- in addAttributes() and addLink()
    j__addNewValue: function(data_type,create_data) {
        // Add a new object at the end of this container
        var d = this.q__defn;
        // Default to normal data type - must use typeof to test because T_OBJREF == false.
        if(typeof(data_type) != 'number') { data_type = d.p__normalDataType; }
        var t = KEdClasses[data_type];
        if(!t) {return;}
        var v = new t(this,this.q__desc,create_data || d.p__newCreationData);
        v._dragPosition = this.q__values.length; // drag position of the new object
        this.q__values.push(v);

        // Add the control HTML at the end of the values container
        // The first() is required because containers may be nested
        $('.z__editor_attr_container_value_container', this.q__domObj).first().append(v.j__generateHtml());

        // Attach control
        v.j__attach();

        this.j__applyAriaAttributesToControls();

        // Tell the control it just got added
        v.j__wasAdded();

        // Set keyboard focus on the control - but after a little delay so Safari has a chance to catch up!
        window.setTimeout(function() { j__focusOnFirstInputBelow(v.q__domId); }, 10);

        // Caller is interested in the value generated
        return v;
    },
    j__firstValue: function() {
        var v = _.detect(this.q__values, function(a) {return a.j__hasValue();});
        return v ? v.j__getValue() : null;
    }
});

// ----------------------------------------------------------------------------------------------------
//   Protection against the user clicking away with unsaved data
// ----------------------------------------------------------------------------------------------------

var q__editorToCheckOnNavigateAway;

var EDITOR_OK_FOR_NAV_AWAY_CLICKS = {
    z__help_tab: true,
    z__heading_back_nav: true,  // cancel button
    z__spawn_close: true,       // spawn close button
    z__covering_close_button: true, // covering close button (fallback file uploads)
    z__dropdown_menu: true,     // widgets with drop down menus
    z__ktree_search_results_dropdown: true, // tree browser find
    z__spawn_fade_dialogue: true,   // during pop up for "create new"
    z__aep_tools_tab: true,     // menu button
    z__ctrl_date_popup: true,   // popup calendar
    z__keditor_form: true,      // container for form controls
    z__editor_container: true   // container for editor itself
};

var j__keditorCheckNavigateAway = function(event) {
    // Check to see if the user should be allowed to navigate away without a warning
    var scan = this;
    while(scan) {
        if(EDITOR_OK_FOR_NAV_AWAY_CLICKS[scan.id] === true || EDITOR_OK_FOR_NAV_AWAY_CLICKS[scan.className]) {
            // Inside the editor controls or form, or an OK button to click to navigate away
            return;
        }
        scan = scan.parentNode;
    }
    // Ask for confirmation if unsaved data
    if(q__editorToCheckOnNavigateAway && q__editorToCheckOnNavigateAway.j__shouldConfirmNavigateAway()) {
        if(!confirm(KApp.j__text('EditorChangesNotSaved')+"\n\n"+KApp.j__text('EditorDiscardChanges'))) {
            KApp.p__disableScripedNavigateAway = true;
            event.preventDefault();
            return false;
        }
    }
    KApp.p__disableScripedNavigateAway = false;
    return true;
};

KApp.j__onPageLoad(function() {
    // Set handlers for confirmation before navigating away from the editor with unsaved data
    $(document.body).
        on('click', 'a', j__keditorCheckNavigateAway).
        on('submit', 'form', j__keditorCheckNavigateAway);
});

// ----------------------------------------------------------------------------------------------------
//   Shortcut keys
// ----------------------------------------------------------------------------------------------------

var q__keditorShortcutsCreated = false;
var j__ensureKeditorShortcutsCreated = function() {
    // Happens only once
    if(q__keditorShortcutsCreated) {return;}
    q__keditorShortcutsCreated = true;

    // Make an off-screen div which will contain the buttons.
    var shortcut_div = document.createElement('div');
    shortcut_div.style.position = 'absolute';
    shortcut_div.style.top = '0';
    shortcut_div.style.left = '-9999px';        // so it's off screen, but at the top of the window
    document.body.appendChild(shortcut_div);

    // Fill it with buttons
    shortcut_div.innerHTML = '<input type="submit" name="Add value" id="z__keditor_shortcut_add_button" accesskey="e">';

    // Attach handlers
    $('#z__keditor_shortcut_add_button').click(function(event) {
        event.preventDefault();
        var focused_control = KEdValue.p__withFocus;
        if(focused_control) {
            focused_control.p__parentContainer.j__addNewValue();
        }
    });

    // Scroll the shortcuts with the window, so they don't get in the way
    $(window).scroll(function() {
        shortcut_div.style.top = $(window).scrollTop()+'px';
    });
};

// ----------------------------------------------------------------------------------------------------
//   Main KEditor class
// ----------------------------------------------------------------------------------------------------

// Suffixes on DOM ids:
//   _e  - show examples button
//   _m  - main editor container
//   _p  - preview container
//   _w  - preview wait container
//   _t  - 'toolbar' at the bottom
//   _a  - add button for attribute
//   _d  - attribute selector (desc)
//
// Methods
//  j__getTitle() - return the first title object in the editor, or null

// Options keys:
//  q__withPreview (boolean)
//  q__disableAddUi (boolean)
//  q__noCreateNewObjects (boolean)

/* global */ KEditor = function(attr, options) {
    // Make sure the schema is prepared (will only actually do something once)
    KEditorSchema.j__prepare();

    // Merge in options
    _.extend(this, options);

    // Adjust the ObjRef attributes to use pseudo types based on their UI options
    _.each(attr, KEditor.j__adjustAttribute);

    // Initialise this object
    this.q__initialAttr = attr;

    // Create any plugin delegates
    if(options.plugins) {
        var delegates = [];
        var editor = this; // for visibility in iterator
        _.each(options.plugins, function(data, delegateName) {
            var delegate;
            var delegateConstructor = KEditor.p__delegate_constructors[delegateName];
            if(delegateConstructor) {
                try {
                    delegate = delegateConstructor(editor, data);
                } catch(err) {
                    // ignore
                }
            }
            if(delegate) {
                delegates.push(delegate);
            } else {
                alert("Couldn't start plugin "+delegateName+". Some functionality may not be available.");
            }
        });
        if(delegates.length > 0) {
            this.q__delegates = delegates;
        }
    }

    // Build array of attribute container controls
    var c = [];
    var type_attr_desc = null;
    for(var i = 0; i < attr.length; i++) {
        var attr_defn = KEditorSchema.j__attrDefn(attr[i][0]);
        if(attr_defn)    // make sure it exists!
        {
            var a = new KAttrContainer(this,attr[i][0],attr[i][1]);
            c.push(a);
            this.j__callDelegates('j__setupAttribute', a);
            // Find the first attribute which is the equivalent of A_TYPE
            if(!type_attr_desc) {
                // Use the data type to see if it's A_TYPE or an alias -- no other attributes will use this data type
                if(attr_defn.p__normalDataType == T_PSEUDO_TYPE_OBJREF) {
                    type_attr_desc = attr_defn.p__desc;
                }
            }
        }
    }
    this.q__attrContainers = c;
    this.q__typeAttrDesc = type_attr_desc || A_TYPE;
};
KEditor.j__adjustAttribute = function(ax) {
    var defn = KEditorSchema.j__attrDefn(ax[0]);
    var axx = ax[1];    // attributes
    var dataType = defn.p__normalDataType;
    if(dataType <= T_PSEUDO_TYPE_OBJREF_UISTYLE_MAX) {
        // It's one of the special objref values for a particular UI style - change
        // any T_OBJREF types to this pseudo type in the attributes.
        for(var i = 0; i < axx.length; ++i) {
            if(axx[i][VL_TYPE] === T_OBJREF) {
                axx[i][VL_TYPE] = dataType;
            }
        }
        // Special handling for checkboxes
        if(dataType === T_PSEUDO_TYPE_OBJREF_CHECKBOX) {
            ax[1] = KEdObjRefCheckbox_rewriteAttrOnEditorInit(axx, defn);
        }
    }
};
_.extend(KEditor.prototype, KControl.prototype);
_.extend(KEditor.prototype, {
    j__generateHtml2: function(i) {
        // Container div
        var h = '<div class="z__editor_container" id="'+i+'"><div class="z__editor_container_editor_inner" id="'+i+'_m">';

        // Collect HTML for the containers
        _.each(this.q__attrContainers, function(a) {
            h += a.j__generateHtml();
        });

        // Start of UI components at end
        h += '<div id="'+i+'_t" class="z__editor_tool_bar">';

        // Add attribute UI
        if(!this.q__disableAddUi) {
            h += '<select id="'+i+'_d" tabindex="1"><option value=""> -- field --</option>';
            var attrs = KEditorSchema.p__allAttrDefns;
            for(var l = 0; l < attrs.length; l++) {
                var d = attrs[l];
                // Aliases shouldn't be offered on the add field menu, because they're for specific types only.
                // And more importantly, it won't behave as the user expects because only aliases specified for the
                // specific type you're editing will be displayed as aliases.
                if(!d.p__aliasOf) {
                    h += '<option value="'+d.p__desc+'">'+escapeHTML(d.p__name)+'</option>';
                }
            }
            h += '</select> <input type="submit" value="Add" id="'+i+'_a">&nbsp; &nbsp; &nbsp;';
        }

        return h+'</div></div><div id="'+i+'_p" class="z__editor_preview_container" style="display:none"></div><div id="'+i+'_w" style="display:none;padding:32px 32px">'+KApp.p__spinnerHtml+' '+KApp.j__text('EditorLoadingPreview')+'</div></div>';
    },
    j__attach2: function(i) {
        // Attach controls
        if(this.q__withPreview) {
            $('.z__editor_buttons_preview').click(_.bind(this.j__previewButtonClick, this));
        }
        // Add field button
        if(!this.q__disableAddUi) {
            $('#'+i+'_a').click(_.bind(this.j__addAttrButtonHandler, this));
        }
        // Attach all the containers
        _.each(this.q__attrContainers, function(a) {
            a.j__attach();
        });
        // Hide any irrelevant attributes and set state for the types
        this.j__updateEditorStateForTypes(true /* prevent delegate notifications */);

        // Check this editor when the user navigates away
        q__editorToCheckOnNavigateAway = this;
        this.q__unmodifiedValue = this.j__value();

        // Focus into the first input.
        // But not in IE because pressing tab will move to the address bar! (if focus set with click, everything is fine)
        // Assuming people who use keyboards will use a better browser.
        if(!KApp.p__runningMsie) {
            j__focusOnFirstInputBelow(i);
        }

        // Ensure shortcuts set up
        j__ensureKeditorShortcutsCreated();

        // Call the delgates
        this.j__callDelegates('j__startEditor');
    },
    j__value: function() {
        // Read values from attribute containers
        var v = [];
        _.each(this.q__attrContainers, function(a) {var t=a.j__value(); if(t){v.push(t);}});
        return v.join('`');
    },

    // Call when the editor is removed from the DOM
    j__cleanUpPostRemoval: function() {
        // Don't check this editor when the user navigates away
        if(q__editorToCheckOnNavigateAway == this) {
            q__editorToCheckOnNavigateAway = undefined;
        }
    },

    // --------------------------------------------------------------------------------------
    // Delegate support
    j__callDelegates: function(functionName /* , ... arguments */) {
        if(this.q__delegates) {
            var args = _.rest(arguments); // omit the delegate name from the arguments passed to the delegate function
            _.each(this.q__delegates, function(delegate) {
                var fn = delegate[functionName];
                if(fn) {
                    fn.apply(delegate, args);
                }
            });
        }
    },

    // --------------------------------------------------------------------------------------
    // Check when navigating away that it's OK
    j__shouldConfirmNavigateAway: function() {
        return this.j__value() != this.q__unmodifiedValue;
    },

    // --------------------------------------------------------------------------------------
    // Control showing the preview
    j__previewButtonClick: function(event) {
        event.preventDefault();
        this.j__setForPreview(!this.j__currentlyShowingPreview);
    },

    j__setForPreview: function(showPreview) {
        var t = this;   // scoping
        var i = t.q__domId;
        if(showPreview) {
            // Get encoded version of values in the current editor
            var obj_to_preview = t.j__value();
            if(obj_to_preview == t.q__lastPreviewObj) {
                // Show the last preview
                $('#'+i+'_w').hide();
                $('#'+i+'_p').show();
                $('#'+i+'_m').hide();
            } else {
                // Ask the server to preview!
                $('#'+i+'_w').show();
                $('#'+i+'_p').hide();
                $('#'+i+'_m').hide();
                // Create get parameters to send to the server from the form
                // TODO: Less reliance on the HTML sent from the server when doing previews in the javascript editor?
                var edit_form = $('#z__keditor_form');
                var params = edit_form.serialize();
                params += '&obj='+encodeURIComponent(obj_to_preview);
                // Add the last part of the form URL to the post URL
                var form_action = edit_form[0].action;
                var url = '/api/edit/preview' + form_action.substring(form_action.lastIndexOf('/'), form_action.length);
                // Request the preview from the server
                $.ajax(url, {
                    type: 'POST',
                    data: params,
                    success: function(rtext) {
                        // Update preview with the returned HTML
                        $('#'+i+'_p').html(rtext);
                        // Make sure that clicking a link doesn't break anything.
                        // A warning message is displayed to tell the user what just happened.
                        $('#'+i+'_p a').each(function() { this.target = '_blank'; this.rel = "noopener"; }).
                            click(function(event) {
                                if(!confirm(KApp.j__text('EditorPreviewOfItemNotSaved')+"\n\n"+KApp.j__text('EditorPreviewOpenLink'))) { event.preventDefault(); }
                            });
                        // Show it?
                        if(t.j__currentlyShowingPreview) {
                            // Only actually show the preview if the user hasn't flipped back to the edit screen
                            $('#'+i+'_w').hide();
                            $('#'+i+'_p').show();
                        }
                        // Set as current preview
                        t.q__lastPreviewObj = obj_to_preview;
                    }
                });
            }
        } else {
            // Otherwise, show the editor
            $('#'+i+'_w').hide();
            $('#'+i+'_p').hide();
            $('#'+i+'_m').show();
        }

        // Store flag
        this.j__currentlyShowingPreview = showPreview;
        // Show button accordingly
        $('.z__editor_buttons_preview').val(KApp.j__text(this.j__currentlyShowingPreview ? 'EditorButtonEdit' : 'EditorButtonPreview'));
    },

    // --------------------------------------------------------------------------------------
    // Show relevant attr for the selected type
    j__updateEditorStateForTypes: function(doNotNotifyDelegates) {
        var hide_attrs = [];
        var is_first = true;
        var container = this.j__getAttrContainer(this.q__typeAttrDesc);
        if(!container) {return;} // will be the case for MARC21 editing
        var editor = this;
        _.each(container.j__getAllValueControls(), function(value) {
            if(value.p__dataType == T_OBJREF) {
                if(value.j__hasValue()) {
                    // Tell the type control whether or not it's the primary type
                    value.q__control.j__setIsPrimaryType(is_first);

                    // Work out the smallest set of combined attributes to remove -- an attribute
                    // must be mentioned in every single one of the types for it to be removed
                    var h = [];
                    _.each(value.q__control.j__getAttributesToHide(), function(desc) {
                        // Use 'a'+desc so that very long arrays aren't created
                        if(is_first || (hide_attrs['a'+desc])) {
                            h['a'+desc] = true;
                        }
                    });
                    hide_attrs = h;

                    // Notify client side plugins
                    if(is_first && !doNotNotifyDelegates) {
                        editor.j__callDelegates('j__onTypeChange', value.q__control.j__value());
                    }

                    // Next!
                    is_first = false;
                } else {
                    // Make sure it doesn't think it's the primary type
                    value.q__control.j__setIsPrimaryType(false);
                }
            }
        });
        if(is_first) {
            // Notify plugins with the default type
            if(!doNotNotifyDelegates) {
                this.j__callDelegates('j__onTypeChange', KEdType.q__defaultTypeObjref);
            }
        }
        // Hide the containers if they have no values in them, otherwise show them so
        // that updates work.
        _.each(this.q__attrContainers, function(a) {
            if(hide_attrs['a'+(a.q__desc)] && a.j__allValuesNull()) {
                a.j__hide();
            } else {
                a.j__show();
            }
        });
    },

    // --------------------------------------------------------------------------------------
    // Validation
    // -- returns true if every field validates
    j__allValidate: function() {
        var ok = true;
        _.each(this.q__attrContainers, function(a) {
            if(!a.j__allValidate()) {
                ok = false;
            }
        });
        return ok;
    },

    // Busy?
    j__getFirstControlBusyMessage: function() {
        var m = null;
        _.each(this.q__attrContainers, function(a) {
            if(!m) { m = a.j__getFirstControlBusyMessage(); }
        });
        return m;
    },

    // Called on form submission
    // TODO: refactor j__validateWithErrorUi to handle alert error messages and tab selector switches more neatly (didn't do it when adding code as too near launch)
    j__validateWithErrorUi: function() {
        // Stop the current field having focus, so it displays any relevant error message
        KEdValue.j__unfocusCurrentValue();
        // Anything busy?
        var busy_message = this.j__getFirstControlBusyMessage();
        if(busy_message) {
            alert(busy_message);
            this.j__setForPreview(false);
            return false;
        }
        // Validate
        if(!(this.j__allValidate())) {
            alert(KApp.j__text('EditorErrFieldsNotFilled')+"\n\n"+KApp.j__text('EditorErrCheckFieldsWithErrs'));
            this.j__setForPreview(false);
            return false;
        }
        // Check there's a title
        if(!(this.j__getTitle())) {
            var container = this.j__getTitleContainer();
            // Might not be a container if the title field is read only, and if there is no container,
            // then an error message should not be displayed.
            if(container) {
                // Tell user, using the name of the title/alias of title container.
                alert(KApp.j__text('EditorErrTitleReq', {TITLE:container.q__defn.p__name.toLowerCase()}));
                this.j__setForPreview(false);
                return false;
            }
        }
        return true;
    },

    // --------------------------------------------------------------------------------------
    // Non-KControl additional methods
    j__getTitle: function() {
        var t, c = this.j__getTitleContainer();
        return (c && (t = c.j__firstValue())) ? t : null;
    },

    // Set title, if there's a title in the editor form
    j__setTitle: function(value) {
        var c = this.j__getTitleContainer();
        if(c) {
            var controls = c.j__getAllValueControls();
            if(controls.length > 0) {
                if(controls[0].q__control.j__setTextValue) {
                    controls[0].q__control.j__setTextValue(value);
                }
            }
        }
    },

    // Return title container, may be an alias of title
    j__getTitleContainer: function() {
        var containers = this.q__attrContainers;
        for(var i = 0; i < containers.length; ++i) {
            if(_.contains(KSchema.title_descs, containers[i].q__desc)) {
                return containers[i];
            }
        }
        return null;
    },

    // Called by plugin_adaptor.js
    j__getAttrContainer: function(desc) {
        return _.detect(this.q__attrContainers, function(a) {return a.q__desc == desc;});
    },

    // Delete the current focused value if it doesn't actually have a value
    j__cleanupFocusedValue: function() {
        var focused = KEdValue.p__withFocus;
        if(focused && !(focused.j__hasValue())) {
            focused.j__deleteValue();
        }
    },

    // --------------------------------------------------------------------------------------
    // Add attribute handler
    j__addAttrButtonHandler: function(event) {
        event.preventDefault();
        // Get the descriptor from the SELECT
        var desc = $('#'+this.q__domId+'_d').val();
        if(desc === '') {return;}
        // If the attribute is A_TYPE, it might have been aliased, and it's important to use that alias.
        // So special case it to use whatever alias was detected on starting the editor.
        if(desc == A_TYPE) {
            desc = this.q__typeAttrDesc;
        }
        // Is there a container for this desc already?
        var c = _.detect(this.q__attrContainers, function(a) {return a.q__desc == desc;});
        if(!c) {
            // Add new container and attach
            c = new KAttrContainer(this,desc,[]);
            var div = document.createElement('div');
            div.className = 'z__editor_new_container_container';
            var posobj = $(this.q__domId+'_t');
            posobj.parentNode.insertBefore(div, posobj);
            div.innerHTML = c.j__generateHtml();
            c.j__attach();
            // Store in list
            this.q__attrContainers.push(c);
        } else {
            // Add field in existing container
            c.j__addNewValue(null);
        }
        // If a type has been added, this needs special handling
        if(desc == this.q__typeAttrDesc) {
            this.j__updateEditorStateForTypes();
        }
    },
});


// Hooks for plugin_adaptor.js
KEditor.p__delegate_constructors = {};
KEditor.p__pluginTextTypeValueConstructor = {};
KEditor.p__KAttrContainer = KAttrContainer;
KEditor.p__KEdObjRef = KEdObjRef;
KEditor.p__refLookupRedirectorFunctions = [];


// ----------------------------------------------------------------------------------------------------
//   Labelling UI
// ----------------------------------------------------------------------------------------------------

var KLabellingUI = function() {
};
_.extend(KLabellingUI.prototype, KControl.prototype, {
    j__attach2: function() {},
    j__value: function() {
        var labels = [], labelSet = $('#z__editor_labelling .z__editor_labelling_set input:checked').val() || "NONE";
        $('#z__editor_labelling .z__editor_labelling_additional input:checked').each(function() { labels.push(this.value); });
        return labelSet + "/" + labels.join(",");
    }
});

// ----------------------------------------------------------------------------------------------------
//   Helper code for main editor
// ----------------------------------------------------------------------------------------------------

var q__keditor;
KApp.j__onPageLoad(function() {
    // Attempt to find editor encoded details in document
    var editorData = $('#z__keditor_data');
    if(editorData.length === 1) {
        var type_objref = editorData[0].getAttribute("data-type");
        var attr = $.parseJSON(editorData[0].getAttribute("data-attr"));
        var options = $.parseJSON(editorData[0].getAttribute("data-opts"));

        KEdType.q__defaultTypeObjref = type_objref;   // NOTE: Also used by KEdObjRefParent & notifications for client side plugins
        var options2 = _.clone(options);
        options2.q__withPreview = true; /* always want a preview in a normal editor */
        q__keditor = new KEditor(attr, options2);
        // Put the HTML in the document
        editorData.html(q__keditor.j__generateHtml());
    }

    if(q__keditor) {
        q__keditor.j__attach();
        var a = new KCtrlFormAttacher('z__keditor_form');
        a.p__allowSubmitCallback = _.bind(q__keditor.j__validateWithErrorUi, q__keditor);
        a.j__attach(q__keditor,'obj');

        // Read only values need to be transformed client side, there isn't a format that neatly round-trips.
        // This is a bit of a hack; the object editor rewrite should handle all these cases properly.
        var readOnlyValues = editorData[0].getAttribute("data-read-only-values");
        if(readOnlyValues) {
            var keditorReadOnly = new KEditor($.parseJSON(readOnlyValues), {});
            var readOnlyElement = $('<div style="display:none"/>');
            $(document.body).append(readOnlyElement);
            readOnlyElement.html(keditorReadOnly.j__generateHtml());
            keditorReadOnly.j__attach();
            a.j__attach(keditorReadOnly,'obj_read_only');
        }

        // Labelling
        var labellingUi = $('#z__editor_labelling');
        if(labellingUi.length > 0) {
            a.j__attach(new KLabellingUI(), "labelling");
        }

        // WebKit doesn't focus on radio and checkboxes when you click on them, so we need to
        // add in support for this so qualifiers can be set on checkbox and radio fields.
        // Firefox only focuses if you click on the label, but oddly, it doesn't if you click
        // the actual checkbox or radio.
        if(/(webkit|firefox)/.test(navigator.userAgent.toLowerCase())) {
            $('.z__editor_container').on('click', 'input[type=radio],input[type=checkbox]', function() {
                this.focus();
            });
        }
    }
});

})(jQuery);
