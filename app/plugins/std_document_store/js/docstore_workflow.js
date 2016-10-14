/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Optional implementation
if(!O.featureImplemented("std:workflow")) { return; }
P.use("std:workflow");

// workflow.use("std:document_store", spec)
//
// where spec is an object with properties:
//    name: document store name
//    title: Title of this form
//    titleLowerCase: Title to use when the lower case version of title is to be
//              displayed but acryonyms or proper nouns need to be preserved 
//    path: URL path where the handlers should be implemented
//    panel: Which panel the view link should appear in
//    priority: The priority within the panel, defaulting to "default"
//    ----------
//          history/view/edit have the concept of "allowing for roles at selectors"
//                  it is a list of these definition objects, which have properties:
//                      roles: ["researcher", ...] - list of roles to match on
//                      selector: {state:"state"} - Workflow selector to match on
//                      action: "allow"/"deny" - Default: allow. specify whether to eg: give permissions
//                              for a particular matched role/selector or whether to deny access
//    history: [{roles:[],selector:{}}, ...] - OPTIONAL, when the document history can be viewed, omitting this
//              property allows the history to be viewable by everyone
//    view: [{roles:[],selector:{}}, ...] - when the document can be viewed
//              (omit roles key to mean everyone)
//    edit: [{roles:[],selector:{},transitionsFiltered:[]},optional:true, ...] - when the document
//              can be edited, the (optional) transitionsFiltered property specifies
//              which transitions should only be avaialble if the form has been
//              edited & completed, the optional property overrides the default that,
//              when a user is allowed to edit a document, there must be a committed
//              version before they can transition
//    ----------
//    actionableUserMustReview: (selector) - a selector which specifies when the
//              current actionable user should be shown the completed document and
//              prompts the user to review/confirm before progressing use selector
//              like {pendingTransitions:[...]} to narrow down to individual transitions

// ----------------------------------------------------------------------------

var Delegate = function() { };
Delegate.prototype = {
    keyToKeyId: function(key) { return key.workUnit.id; }
};

var can = function(M, user, spec, action) {
    var list = spec[action];
    if(!list) { return false; }
    var allow = false, deny = false;
    for(var i = (list.length - 1); i >= 0; --i) {
        var t = list[i];
        if(t.roles && !(M.hasAnyRole(user, t.roles))) {
            continue;
        }
        if(t.selector && !(M.selected(t.selector))) {
            continue;
        }
        switch(t.action) {
            case "allow":
                allow = true;
                break;
            case "deny":
                deny = true;
                break;
            default:
                if(t.action !== undefined) {
                    throw new Error("Document store 'action' parameter must be either 'allow' or 'deny'.");
                } else { allow = true; }
                break;
        }
    }
    return allow && !deny;
};

var isOptional = function(M, user, list) {
    if(!list) { return false; }
    for(var i = (list.length - 1); i >= 0; --i) {
        var t = list[i];
        if(t.roles && !(M.hasAnyRole(user, t.roles))) {
            continue;
        }
        if(t.selector && !(M.selected(t.selector))) {
            continue;
        }
        if(t.optional) { return true; }
    }
    return false;
};

// ----------------------------------------------------------------------------

P.workflow.registerWorkflowFeature("std:document_store", function(workflow, spec) {

    var plugin = workflow.plugin;
    if(!("defineDocumentStore" in plugin)) {
        plugin.use("std:document_store");
    }

    var delegate = _.extend(new Delegate(), spec);
    var docstore = plugin.defineDocumentStore(delegate);
    if(!("documentStore" in workflow)) { workflow.documentStore = {}; }
    workflow.documentStore[spec.name] = docstore;

    // ------------------------------------------------------------------------

    // If a document has been edited when a transition occurs, commit that new version
    workflow.observeExit({}, function(M, transition) {
        var instance = docstore.instance(M);
        if(instance.currentDocumentIsEdited) {
            instance.commit(O.currentUser);
        }
    });

    // ----------------------------------------------------------------------

    // If the document is required, then don't allow a transition until it's complete
    _.each(spec.edit, function(t) {
        if(t.optional) { return; }
        workflow.filterTransition(t.selector || {}, function(M, name) {
            var instance = docstore.instance(M);
            if(!instance.currentDocumentIsComplete) {
                if(!t.transitionsFiltered || t.transitionsFiltered.indexOf(name) !== -1) {
                    return false;
                }
            }
        });
    });

    // ------------------------------------------------------------------------

    // If the user has to review the form before submission, redirect to a review page
    if(spec.actionableUserMustReview) {
        workflow.transitionUI(spec.actionableUserMustReview, function(M, E, ui) {
            // if we've reviewed the forms then don't redirect:
            //      clean session variable and return;
            if(E.request.parameters.reviewed) {
                delete O.session["std_document_store:review_list:"+M.workUnit.id];
                delete O.session["std_document_store:pending_transition:"+M.workUnit.id];
                return;
            }
            // collect links to things we need to review from other transitionUI calls
            var reviewList = O.session["std_document_store:review_list:"+M.workUnit.id] || [];
            reviewList.push(spec.path);
            O.session["std_document_store:review_list:"+M.workUnit.id] = reviewList;
            O.session["std_document_store:pending_transition:"+M.workUnit.id] =
                M.pendingTransition;
            ui.redirect(spec.path+"/submit/"+M.workUnit.id);
        });
    }

    // ------------------------------------------------------------------------

    // Display links in the action panel
    if("panel" in spec) {
        workflow.actionPanel({}, function(M, builder) {
            var instance = docstore.instance(M);
            var haveDocument = instance.hasCommittedDocument;
            if(haveDocument && can(M, O.currentUser, spec, 'view')) {
                var viewTitle = M.getTextMaybe("docstore-panel-view-link:"+spec.name) || spec.title;
                builder.panel(spec.panel).
                    link(spec.priority || "default", spec.path+'/view/'+M.workUnit.id, viewTitle);
            }

            if(can(M, O.currentUser, spec, 'viewDraft')) {
                if(!haveDocument && instance.currentDocumentIsEdited) {
                    var draftTitle = M.getTextMaybe("docstore-panel-draft-link:"+spec.name) || "Draft "+spec.title.toLowerCase();
                    builder.panel(spec.panel).
                        link(spec.priority || "default", spec.path+'/draft/'+M.workUnit.id, draftTitle);
                }
            }
        });
    }

    workflow.actionPanelTransitionUI({}, function(M, builder) {
        if(can(M, O.currentUser, spec, 'edit')) {
            var searchPath = "docstore-panel-edit-link:"+spec.name;
            var instance = docstore.instance(M);
            var label = M.getTextMaybe(searchPath+":"+M.state, searchPath) || "Edit "+spec.title.toLowerCase();
            var isDone = isOptional(M, O.currentUser, spec.edit) || instance.currentDocumentIsComplete;
            builder.
                link(spec.editPriority || "default",
                        spec.path+'/form/'+M.workUnit.id,
                        label,
                        isDone ? "standard" : "primary");
        }
    });

    // ------------------------------------------------------------------------

    var editor = {
        finishEditing: function(instance, E, complete) {
            if(complete && spec.onFinishPage) {
                return E.response.redirect(spec.onFinishPage(instance.key));
            }
            if(complete && !(instance.key.transitions.empty) && instance.key.workUnit.isActionableBy(O.currentUser)) {
                E.response.redirect("/do/workflow/transition/"+instance.key.workUnit.id);
            } else {
                E.response.redirect(instance.key.url);
            }
        },
        gotoPage: function(instance, E, formId) {
            E.response.redirect(spec.path+'/form/'+instance.key.workUnit.id+"/"+formId);
        },
        render: function(instance, E, deferredForm) {
            var M = workflow.instance(O.work.load(E.request.extraPathElements[0]));
            E.render({
                pageTitle: "Edit "+spec.title+": "+instance.key.title,
                backLink: instance.key.url,
                deferredForm: deferredForm,
                deferredPreForm: spec.deferredPreForm ? spec.deferredPreForm(M) : null
            }, "workflow/form");
        }
    };

    // ------------------------------------------------------------------------

    plugin.respond("GET,POST", spec.path+'/form', [
        {pathElement:0, as:"workUnit", workType:workflow.fullName, allUsers:true}
    ], function(E, workUnit) {
        E.setResponsiblePlugin(P); // take over as source of templates, etc
        var M = workflow.instance(workUnit);
        if(!can(M, O.currentUser, spec, 'edit')) {
            O.stop("Not permitted.");
        }
        var instance = docstore.instance(M);
        instance.handleEditDocument(E, editor);
    });

    // ------------------------------------------------------------------------

    var handleRedirect = function(E, reviewList, workUnit) {
        // redirect to next form to be reviewed or otherwise to transition page
        if(reviewList.length) {
            E.response.redirect(reviewList.pop()+"/submit/"+workUnit.id);
        } else {
            // appending ?reviewed=all to url to signal to transitionUI that we can progress
            E.response.redirect("/do/workflow/transition/"+workUnit.id+"?transition="+
                O.session["std_document_store:pending_transition:"+workUnit.id]+
                "&reviewed=all");
        }
    };

    plugin.respond("GET,POST", spec.path+'/submit', [
        {pathElement:0, as:"workUnit", workType:workflow.fullName}
    ], function(E, workUnit) {
        var M = workflow.instance(workUnit);
        var reviewList = false;
        if(O.session["std_document_store:review_list:"+M.workUnit.id]) {
            if(O.session["std_document_store:review_list:"+M.workUnit.id].length > 0) {
                reviewList = O.session["std_document_store:review_list:"+M.workUnit.id];
                if(reviewList.indexOf(spec.path) !== -1) {
                    reviewList.splice(reviewList.indexOf(spec.path), 1);
                }
                O.session["std_document_store:review_list:"+M.workUnit.id] = reviewList;
            }
        }
        if(!can(M, O.currentUser, spec, 'view')) {
            // if the user can't view this form, then skip it don't show it
            return handleRedirect(E, reviewList, workUnit);
        }
        if(E.request.method === "POST") {
            if(E.request.parameters.edit) {
                return E.response.redirect(spec.path+"/form/"+workUnit.id);
            }
            if(E.request.parameters.reviewed) {
                return handleRedirect(E, reviewList, workUnit);
            }
        }
        E.setResponsiblePlugin(P);  // take over as source of templates, etc
        var instance = docstore.instance(M);
        var ui = instance.makeViewerUI(E, {
            showCurrent: true
        });
        // std:ui:choose
        var text = M.getTextMaybe("docstore-review-prompt:"+spec.name) ||
            "Please review the form below.";
        var options = [
            {
                action: "",
                label: M.getTextMaybe("docstore-review-continue:"+spec.name) || "Continue",
                parameters:{reviewed:true}
            }
        ];
        if(can(M, O.currentUser, spec, 'edit')) {
            options.push({
                action: "",
                label: M.getTextMaybe("docstore-review-return-to-edit:"+spec.name) ||
                    "Return to edit", parameters:{edit:true}
            });
            text = text + "\n" + (M.getTextMaybe("docstore-review-editable:"+spec.name) ||
                "Once submitted, the form is no longer editable.");
        }
        E.render({
            pageTitle: M.title+': '+(spec.title || '????'),
            backLink: M.url,
            backLinkText: M.getTextMaybe("docstore-review-cancel:"+spec.name) || "Cancel",
            text: text,
            options: options,
            ui: ui
        }, "workflow/review_changes");
    });

    // ----------------------------------------------------------------------

    plugin.respond("GET", spec.path+"/draft", [
        {pathElement:0, as:"workUnit", workType:workflow.fullName, allUsers:true}
    ], function(E, workUnit) {
        E.setResponsiblePlugin(P);  // take over as source of templates, etc
        var M = workflow.instance(workUnit);
        if(!can(M, O.currentUser, spec, 'viewDraft')) {
            O.stop("Not permitted.");
        }
        var instance = docstore.instance(M);
        var ui = instance.makeViewerUI(E, {
            showVersions: spec.history ? can(M, O.currentUser, spec, 'history') : true,
            showCurrent: true,
            uncommittedChangesWarningText: M.getTextMaybe("docstore-draft-warning-text:"+
                spec.name) || "This is a draft version"
        });
        E.appendSidebarHTML(ui.sidebarHTML);
        E.render({
            pageTitle: M.title+': '+(spec.title || '????'),
            backLink: M.url,
            ui: ui
        }, "workflow/view");
    });

    // ----------------------------------------------------------------------

    plugin.respond("GET", spec.path+'/view', [
        {pathElement:0, as:"workUnit", workType:workflow.fullName, allUsers:true}
    ], function(E, workUnit) {
        E.setResponsiblePlugin(P);  // take over as source of templates, etc
        var M = workflow.instance(workUnit);
        if(!can(M, O.currentUser, spec, 'view')) {
            O.stop("Not permitted.");
        }
        var instance = docstore.instance(M);
        var canEdit = can(M, O.currentUser, spec, 'edit');
        if(!(canEdit || instance.hasCommittedDocument)) {
            O.stop("Form hasn't been completed yet.");
        }
        var ui = instance.makeViewerUI(E, {
            showVersions: spec.history ? can(M, O.currentUser, spec, 'history') : true,
            showCurrent: canEdit,
            uncommittedChangesWarningText: M.getTextMaybe("docstore-uncommitted-changes-warning-text:"+
                spec.name)
        });
        if(canEdit) {
            E.appendSidebarHTML(P.template("std:ui:panel").render({
                elements: [{href:spec.path+'/form/'+workUnit.id, label:"Edit",
                    indicator:"standard"}]
            }));
        }
        E.appendSidebarHTML(ui.sidebarHTML);
        E.render({
            pageTitle: M.title+': '+(spec.title || '????'),
            backLink: M.url,
            ui: ui
        }, "workflow/view");
    });

});
