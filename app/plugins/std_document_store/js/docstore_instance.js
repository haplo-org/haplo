/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var DocumentInstance = P.DocumentInstance = function(store, key) {
    this.store = store;
    this.key = key;
    this.keyId = store._keyToKeyId(key);
};

// ----------------------------------------------------------------------------

DocumentInstance.prototype.__defineGetter__("forms", function() {
    // Don't cache the forms, so they can change as forms are committed
    return this.store._formsForKey(this.key, this);
});

DocumentInstance.prototype.__defineGetter__("currentDocument", function() {
    // Cached?
    var document = this.$currentDocument;
    if(document) { return document; }
    // Try current version first
    var current = this.store.currentTable.select().where("keyId","=",this.keyId);
    if(current.length > 0) {
        document = JSON.parse(current[0].json);
    }
    // Fall back to last committed version or a blank document
    if(document === undefined) {
        document = this.lastCommittedDocument;
    }
    // Cache found document
    this.$currentDocument = document;
    return document;
});

// Are there some edits outstanding?
DocumentInstance.prototype.__defineGetter__("currentDocumentIsEdited", function() {
    return this.store.currentTable.select().where("keyId","=",this.keyId).length > 0;
});

// If there isn't a current document, check the committed version
DocumentInstance.prototype.__defineGetter__("currentDocumentIsComplete", function() {
    var current = this.store.currentTable.select().where("keyId","=",this.keyId);
    if(current.length > 0) {
        return current[0].complete;
    }
    return this.committedDocumentIsComplete;
});

DocumentInstance.prototype.__defineGetter__("committedDocumentIsComplete", function() {
    var committed = this.store.versionsTable.select().
        where("keyId","=",this.keyId).
        order("version", true).
        limit(1);
    if(committed.length > 0) {
        var record = committed[0];
        var document = JSON.parse(record.json);
        var isComplete = true;
        var forms = this.forms;
        _.each(forms, function(form) {
            var instance = form.instance(document);
            if(!instance.documentWouldValidate()) {
                isComplete = false;
            }
        });
        return isComplete;
    } else {
        return false;
    }
});

DocumentInstance.prototype._notifyDelegate = function(fn) {
    var delegate = this.store.delegate;
    if(delegate[fn]) {
        var functionArguments = Array.prototype.slice.call(arguments, 0);
        functionArguments[0] = this;
        delegate[fn].apply(delegate, functionArguments);
    }
};

// ----------------------------------------------------------------------------

DocumentInstance.prototype.setCurrentDocument = function(document, isComplete) {
    var json = JSON.stringify(document);
    var current = this.store.currentTable.select().where("keyId","=",this.keyId);
    var row = (current.length > 0) ? current[0] :
        this.store.currentTable.create({keyId:this.keyId});
    row.json = json;
    row.complete = isComplete;
    row.save();
    // Invalidate cached current document (don't store given document because we don't own it)
    delete this.$currentDocument;
    this._notifyDelegate('onSetCurrentDocument', document, isComplete);
};

DocumentInstance.prototype.__defineSetter__("currentDocument", function(document) {
    this.setCurrentDocument(document, true /* assume complete */);
});

// ----------------------------------------------------------------------------

// Returns a blank document is there isn't a last committed version
DocumentInstance.prototype.__defineGetter__("lastCommittedDocument", function() {
    var lastVersion = this.store.versionsTable.select().
        where("keyId","=",this.keyId).order("version",true).limit(1);
    return (lastVersion.length > 0) ? JSON.parse(lastVersion[0].json) :
        this.store._blankDocumentForKey(this.key);
});

DocumentInstance.prototype.__defineGetter__("hasCommittedDocument", function() {
    return (0 < this.store.versionsTable.select().where("keyId","=",this.keyId).
        order("version",true).limit(1).length);
});

// ----------------------------------------------------------------------------

DocumentInstance.prototype.getAllVersions = function() {
    return _.map(this.store.versionsTable.select().where("keyId","=",this.keyId).
        order("version"), function(row) {
            return {
                version: row.version,
                date: new Date(row.version),
                user: row.user,
                document: JSON.parse(row.json)
            };
        }
    );
};

// ----------------------------------------------------------------------------

// Commit the editing version, maybe duplicating the last version or committing
// a blank document
DocumentInstance.prototype.commit = function(user) {
    // Invalidate current document cache
    delete this.$currentDocument;
    // Get JSON directly from current version?
    var current = this.store.currentTable.select().where("keyId","=",this.keyId);
    var json  = (current.length > 0) ? current[0].json : undefined;
    // Create a new version, if no current JSON, fall back to lastCommittedDocument
    // which may just be a blank document.
    this.store.versionsTable.create({
        keyId: this.keyId,
        json: json || JSON.stringify(this.lastCommittedDocument),
        version: Date.now(),
        user: user || O.currentUser
    }).save();
    // Delete any last version
    if(current.length > 0) {
        current[0].deleteObject();
    }
    this._notifyDelegate('onCommit', user);
};

// ----------------------------------------------------------------------------

DocumentInstance.prototype._displayForms = function(document) {
    var delegate = this.store.delegate;
    var key = this.key;
    var unfilteredForms = this.store._formsForKey(this.key, this);
    if(!delegate.shouldDisplayForm) { return unfilteredForms; }
    return _.filter(unfilteredForms, function(form) {
        return (delegate.shouldDisplayForm(key, form, document));
    });
};

// Render as document
DocumentInstance.prototype._renderDocument = function(document, deferred) {
    var html = [];
    var delegate = this.store.delegate;
    var key = this.key;
    var sections = [];
    var forms = this._displayForms(document);
    _.each(forms, function(form) {
        var instance = form.instance(document);
        if(delegate.prepareFormInstance) {
            delegate.prepareFormInstance(key, form, instance, "document");
        }
        sections.push({
            unsafeId: form.formId,
            title: form.formTitle,
            instance: instance
        });
    });
    var view = {sections:sections};
    var t = P.template("all_form_documents");
    return deferred ? t.deferredRender(view) : t.render(view);
};

DocumentInstance.prototype._selectedFormInfo = function(document, selectedFormId) {
    var delegate = this.store.delegate;
    var key = this.key;
    var forms = this.forms, form;
    if(selectedFormId) {
        form = _.find(forms, function(form) {
            return selectedFormId === form.formId;
        });
    }
    if(!form) { form = forms[0]; }
    var instance = form.instance(document);
    if(delegate.prepareFormInstance) {
        delegate.prepareFormInstance(key, form, instance, "document");
    }
    return {
        title: form.formTitle,
        instance: instance
    };
};

DocumentInstance.prototype.__defineGetter__("lastCommittedDocumentHTML", function() {
    return this._renderDocument(this.lastCommittedDocument);
});
DocumentInstance.prototype.deferredRenderLastCommittedDocument = function() {
    return this._renderDocument(this.lastCommittedDocument, true);
};

DocumentInstance.prototype.__defineGetter__("currentDocumentHTML",       function() {
    return this._renderDocument(this.currentDocument);
});
DocumentInstance.prototype.deferredRenderCurrentDocument = function() {
    return this._renderDocument(this.currentDocument, true);
};

// ----------------------------------------------------------------------------

// Edit current document
DocumentInstance.prototype.handleEditDocument = function(E, actions) {
    // The form ID is encoded into the request somehow
    var untrustedRequestedFormId = this.store._formIdFromRequest(E.request);
    // Set up information about the pages
    var instance = this,
        delegate = this.store.delegate,
        cdocument = this.currentDocument,
        forms,
        pages, isSinglePage,
        activePage;
    var updatePages = function() {
        forms = instance.store._formsForKey(instance.key, instance, cdocument);
        if(forms.length === 0) { throw new Error("No form definitions"); }
        pages = [];
        var j = 0; // pages indexes no longer match forms indexes
        for(var i = 0; i < forms.length; ++i) {
            var form = forms[i],
                formInstance = form.instance(cdocument);
            if(!delegate.shouldEditForm || delegate.shouldEditForm(instance.key, form, cdocument)) {
                if(delegate.prepareFormInstance) {
                    delegate.prepareFormInstance(instance.key, form, formInstance, "form");
                }
                pages.push({
                    index: j,
                    form: form,
                    instance: formInstance,
                    complete: formInstance.documentWouldValidate()
                });
                if(form.formId === untrustedRequestedFormId) {
                    activePage = pages[j];
                }
                j++;
            }
        }
        pages[pages.length - 1].isLastPage = true;
        isSinglePage = (pages.length === 1);
    };
    updatePages();
    // Default the active page to the first page
    if(!activePage) { activePage = pages[0]; }
    activePage.active = true;
    // What happens next?
    var showFormError = false;
    if(E.request.method === "POST") {
        // Update from the active form
        activePage.instance.update(E.request);
        activePage.complete = activePage.instance.complete;
        if(activePage.complete) {
            // delegate.formsForKey() may return different forms now document has changed
            updatePages();
        }
        var firstIncompletePage = _.find(pages, function(p) { return !p.complete; });
        this.setCurrentDocument(cdocument, !(firstIncompletePage) /* all complete? */);
        // Goto another form?
        var gotoPage = _.find(pages, function(p) {
            return p.form.formId === E.request.parameters.__goto;
        });
        if(gotoPage) {
            return actions.gotoPage(this, E, gotoPage.form.formId);
        } else {
            // If user clicked 'save for later', stop now
            if(E.request.parameters.__later === "s") {
                return actions.finishEditing(this, E, false /* not complete */);
            }
            // If the form is complete, go to the next form, or finish
            if(activePage.complete) {
                // Find next page, remembering indexes might have changed
                var nextIndex = -1, activeFormId = activePage.form.formId;
                for(var l = 0; l < pages.length; ++l) {
                    if(pages[l].form.formId === activeFormId) {
                        nextIndex = l+1;
                        break;
                    }
                }
                if(nextIndex >= 0 && nextIndex >= pages.length) {
                    return actions.finishEditing(this, E, true /* everything complete */);
                } else {
                    return actions.gotoPage(this, E,
                        pages[nextIndex].form.formId);
                }
            } else {
                showFormError = true;
            }
        }
    }
    // Render the form
    var navigation = null;
    if(!isSinglePage || (delegate.alwaysShowNavigation && delegate.alwaysShowNavigation(this.key, this, cdocument))) {
        navigation = P.template("navigation").deferredRender({pages:pages});
    }
    var additionalUI;
    if(delegate.getAdditionalUIForEditor) {
        additionalUI = delegate.getAdditionalUIForEditor(instance.key, instance, cdocument, activePage.form);
    }
    actions.render(this, E, P.template("edit").deferredRender({
        isSinglePage: isSinglePage,
        navigation: navigation,
        pages: pages,
        showFormError: showFormError,
        additionalUI: additionalUI,
        activePage: activePage
    }));
};

// ----------------------------------------------------------------------------

// Viewer UI
DocumentInstance.prototype.makeViewerUI = function(E, options) {
    return new P.DocumentViewer(this, E, options);
};
