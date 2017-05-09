/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Options:
//    version - version number to display (overrides version)
//    showVersions - true to allow user to select a version to view
//    showCurrent - allow the user to see the current version
//    hideFormNavigation - hide the interform links from the sidebar
//    uncommittedChangesWarningText - specify (or disable) the uncommitted changes warning text
//    style - specify the style of the viewer
//        currently only "tabs" supported, splits forms into tabs instead of showing on one page

var DocumentViewer = P.DocumentViewer = function(instance, E, options) {
    this.instance = instance;
    this.E = E;
    this.options = options || {};

    var store = instance.store;

    // Requested version?
    if("version" in this.options) {
        this.version = this.options.version;
    } else if(this.options.showVersions && ("version" in E.request.parameters)) {
        this.version = parseInt(E.request.parameters.version, 10);
    }

    if("style" in this.options) {
        this.style = this.options.style;
        this.options.hideFormNavigation = true;
        if(this.style === "tabs") {
            var selectedFormId = this.selectedFormId = E.request.parameters.form;
            var tabs = this.tabs = [];
            _.each(instance.forms, function(form, index) {
                var selected = (!selectedFormId && index === 0) || (selectedFormId === form.formId);
                tabs.push({
                    href: instance.keyId,
                    parameters: {form: form.formId},
                    label: form.formTitle,
                    selected: selected
                });
            });
        }
    }

    // Is there a current version of the document?
    var current = store.currentTable.select().where("keyId","=",instance.keyId);
    if(current.length > 0) {
        this.haveCurrent = true;
        // Should it be used as the document to render?
        if(!this.version && this.options.showCurrent) {
            this.document = JSON.parse(current[0].json);
            this.showingCurrent = true;
        }
    }

    // If the current document isn't the one to display, select the requested
    // version or use the latest version
    if(!this.document) {
        var requestedVersion = store.versionsTable.select().
            where("keyId","=",instance.keyId).order("version",true).limit(1);
        if(this.version) { requestedVersion.where("version","=",this.version); }
        if(requestedVersion.length === 0 && (this.version)) {
            O.stop("Requested version does not exist");
        }
        if(requestedVersion.length > 0) {
            this.document = JSON.parse(requestedVersion[0].json);
            this.version = requestedVersion[0].version;
        }
    }

    // Get any additional UI to display
    var delegate = this.instance.store.delegate;
    if(delegate.getAdditionalUIForViewer) {
        this.additionalUI = delegate.getAdditionalUIForViewer(this.instance.key, this.instance, this.document);
    }
};

// ----------------------------------------------------------------------------

DocumentViewer.prototype.__defineGetter__("hasDocumentToDisplay", function() {
    return !!(this.document);
});

DocumentViewer.prototype.__defineGetter__("documentHTML", function() {
    return P.template("viewer").render(this);
});

DocumentViewer.prototype.__defineGetter__("deferredDocument", function() {
    return P.template("viewer").deferredRender(this);
});

DocumentViewer.prototype.__defineGetter__("sidebarHTML", function() {
    return P.template("viewer_sidebar").render(this);
});

// ----------------------------------------------------------------------------

DocumentViewer.prototype.__defineGetter__("_viewerForms", function() {
    return this.instance._displayForms(this.document);
});

DocumentViewer.prototype.__defineGetter__("_viewerBody", function() {
    var viewerBodyTemplate = this.style ? "viewer_body_"+this.style : "viewer_body";
    return P.template(viewerBodyTemplate).deferredRender(this);
});

DocumentViewer.prototype.__defineGetter__("_viewerDocumentDeferred", function() {
    return this.instance._renderDocument(this.document, true);
});

DocumentViewer.prototype.__defineGetter__("_viewerSelectedForm", function() {
    return this.instance._selectedFormInfo(this.document, this.selectedFormId);
});

DocumentViewer.prototype.__defineGetter__("_uncommittedChangesWarningText", function() {
    return (this.options.uncommittedChangesWarningText === undefined) ?
        "You've made some changes, but they're not visible to anyone else yet." :
        this.options.uncommittedChangesWarningText;
});

DocumentViewer.prototype.__defineGetter__("_versionsView", function() {
    var viewer = this;
    var versions = _.map(viewer.instance.store.versionsTable.select().
        where("keyId","=",viewer.instance.keyId).order("version",true), function(row) {
            return {
                row: row,
                datetime: new Date(row.version),
                selected: (row.version === viewer.version)
            };
        }
    );
    if(viewer.options.showCurrent && viewer.haveCurrent) {
        versions.unshift({
            editedVersion: true,
            selected: viewer.showingCurrent
        });
    }
    return versions;
});

DocumentViewer.prototype.__defineGetter__("_showFormNavigation", function() {
    return (this.instance.forms.length > 1) && !(this.options.hideFormNavigation);
});
