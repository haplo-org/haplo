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
//    path: URL path where the handlers should be implemented
//    panel: Which panel the view link should appear in
//    priority: The priority within the panel, defaulting to "default"
//    showFormTitlesWhenEditing: show form titles in viewer (TODO consider making this the default)
//    sortDisplay: The priority for displaying in list of forms, defaulting to
//          priority if it's a number, or 100 otherwise.
//    mustCreateNewVersion: selector to specify where a user MUST create a new version before transitioning
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
//    viewDraft: [{roles:[],selector:{}}, ...] - when drafts of the document can be viewed
//    edit: [{roles:[],selector:{},transitionsFiltered:[]},optional:true, ...] - when the document
//              can be edited, the (optional) transitionsFiltered property specifies
//              which transitions should only be avaialble if the form has been
//              edited & completed, the optional property overrides the default that,
//              when a user is allowed to edit a document, there must be a committed
//              version before they can transition
//    addComment: [{roles:[],selector:{}}, ...] - OPTIONAL, when a user can comment on the forms
//    viewComments: [{roles:[],selector:{}}, ...] - OPTIONAL, when a user can view the comments
//    viewCommentsOtherUsers: [{roles:[],selector:{}}, ...] - OPTIONAL, when a user can view the 
//              comments of other users. Defaults to same value as viewComments.
//    hideCommentsWhen: selector - OPTIONAL, defaults to {closed:true}

// ----------------------------------------------------------------------------

var DEFAULT_HIDE_COMMENTS_WHEN = {closed:true};

var Delegate = function() { };
Delegate.prototype = {
    __formSubmissionDoesNotCompleteProcess: true,
    keyToKeyId: function(key) { return key.workUnit.id; }
};

P.implementService("std:document_store:workflow:sorted_store_names_action_allowed", function(M, user, action) {
    var workflow = O.service("std:workflow:definition_for_name", M.workUnit.workType);
    var stores = [];
    _.each(workflow.documentStore, function(store, name) {
        var spec = store.delegate;
        if(can(M, user, spec, action)) {
            var sort = spec.sortDisplay;
            if(!sort) { sort = spec.priority; }
            if(!sort) { sort = 100; }
            stores.push({name:name, sort:sort});
        }
    });
    return _.map(_.sortBy(stores,'sort'), function(s) { return s.name; });
});

P.implementService("std:document_store:workflow:form_action_allowed", function(M, form, user, action) {
    var workflow = O.service("std:workflow:definition_for_name", M.workUnit.workType);
    var spec = workflow.documentStore[form].delegate;
    return can(M, user, spec, action);
});

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
    // TODO: Reconsider this special integration between workflow and docstore. Perhaps it would be better to tweak the permissions model? See HAPLO-80
    if(allow && (action === 'edit')) {
        if(true === M._shouldPreferStrictActionableBy()) {
            if(!M.workUnit.isActionableBy(user)) {
                deny = true;
            }
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

// Serialiser source is only available if std_workflow is also installed
P.implementService("std:serialiser:discover-sources", function(source) {
    source({
        name: "std:workflow:documents",
        depend: "std:workflow",
        sort: 1200,
        setup(serialiser) {
            serialiser.listen("std:workflow:extend", function(workflowDefinition, M, work) {
                work.documents = {};
                _.each(workflowDefinition.documentStore, (store, name) => {
                    work.documents[name] = store.instance(M).lastCommittedDocument;
                });
            });
        },
        apply(serialiser, object, serialised) {
            // Implemented as listener
        }
    });
});

// ----------------------------------------------------------------------------

P.workflow.registerWorkflowFeature("std:document_store", function(workflow, spec) {

    var plugin = workflow.plugin;
    if(!("defineDocumentStore" in plugin)) {
        plugin.use("std:document_store");
    }

    var delegate = _.extend(new Delegate(), spec);

    // The 'addComment' permission implies that per element comments are needed
    if(spec.addComment) {
        delegate.enablePerElementComments = true;
    }

    var docstore = plugin.defineDocumentStore(delegate);
    if(!("documentStore" in workflow)) {
        workflow.documentStore = {};
        workflow.actionPanel({}, function(M, builder) {
            if(O.currentUser.isSuperUser) { builder.panel(8888999).element(0, {title:"Docstore admin"}); }
        });
    }
    workflow.documentStore[spec.name] = docstore;

    // ------------------------------------------------------------------------

    // Is there a version of the document which allows the transition to happen?
    var docstoreHasExpectedVersion = function(M, instance) {
        if(!instance.currentDocumentIsComplete) {
            return false;
        }
        if(spec.mustCreateNewVersion && M.selected(spec.mustCreateNewVersion)) {
            if(!instance.currentDocumentIsEdited) {
                return false;
            }
        }
        return true;
    };

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
            if(!docstoreHasExpectedVersion(M, instance)) {
                if(!t.transitionsFiltered || t.transitionsFiltered.indexOf(name) !== -1) {
                    return false;
                }
            }
        });
    });

    // ------------------------------------------------------------------------

    // DEPRECATED FEATURE -- DO NOT USE IN NEW CODE
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
    } // END DEPRECATED FEATURE -- DO NOT USE IN NEW CODE

    // ------------------------------------------------------------------------

    // Display links in the action panel
    if("panel" in spec) {
        workflow.actionPanel({}, function(M, builder) {
            var instance = docstore.instance(M);
            var haveDocument = instance.hasCommittedDocument;
            if(instance.currentDocumentIsEdited && can(M, O.currentUser, spec, 'viewDraft')) {
                let i = P.locale().text("template");
                var draftTitle = M.getTextMaybe("docstore-panel-draft-link:"+spec.name) || i["Draft"]+" "+spec.title.toLowerCase();
                builder.panel(spec.panel).
                    link(spec.priority || "default", spec.path+'/draft/'+M.workUnit.id, draftTitle);
            } else if(haveDocument && can(M, O.currentUser, spec, 'view')) {
                var viewTitle = M.getTextMaybe("docstore-panel-view-link:"+spec.name) || spec.title;
                builder.panel(spec.panel).
                    link(spec.priority || "default", spec.path+'/view/'+M.workUnit.id, viewTitle);
            }
        });
    }

    workflow.actionPanelTransitionUI({}, function(M, builder) {
        if(can(M, O.currentUser, spec, 'edit')) {
            let i = P.locale().text("template");
            var searchPath = "docstore-panel-edit-link:"+spec.name;
            var instance = docstore.instance(M);
            var label = M.getTextMaybe(searchPath+":"+M.state, searchPath) || i["Edit"]+" "+spec.title.toLowerCase();
            var isDone = isOptional(M, O.currentUser, spec.edit) || docstoreHasExpectedVersion(M, instance);
            var editUrl = spec.path+'/form/'+M.workUnit.id;
            // Allow other plugins to modify the URL needs to start the edit process
            editUrl = M.workflowServiceMaybe("std:workflow:modify-edit-url-for-transition-ui", editUrl, docstore, spec) || editUrl;
            builder.
                link(spec.editPriority || "default",
                        editUrl,
                        label,
                        isDone ? "standard" : "primary");
        }
    });

    workflow.actionPanel({}, function(M, builder) {
        if(O.currentUser.isSuperUser) {
            builder.panel(8888999).
                link("default", spec.path+'/admin/'+M.workUnit.id, spec.title);
        }
    });

    // ------------------------------------------------------------------------

    var editor = {
        finishEditing: function(instance, E, complete) {
            var M = instance.key;
            if(complete && spec.onFinishPage) {
                var redirectUrl = spec.onFinishPage(M);
                if(redirectUrl) { return E.response.redirect(redirectUrl); }
            }
            if(complete && !(M.transitions.empty) && M.workUnit.isActionableBy(O.currentUser)) {
                var transitionUrl = {
                    transition: spec.onFinishTransition,    // may be undefined
                    extraParameters: {}
                };
                // Allow other plugins to set a transition or add things to the URL
                M.workflowServiceMaybe("std:workflow:transition-url-properties-after-edit", transitionUrl, docstore, spec);
                E.response.redirect(M.transitionUrl(transitionUrl.transition, transitionUrl.extraParameters));
            } else {
                E.response.redirect(M.url);
            }
        },
        gotoPage: function(instance, E, formId) {
            E.response.redirect(spec.path+'/form/'+instance.key.workUnit.id+"/"+formId);
        },
        render: function(instance, E, deferredForm) {
            var M = workflow.instance(O.work.load(E.request.extraPathElements[0]));
            E.render({
                spec: spec,
                instance: instance,
                deferredForm: deferredForm,
                deferredPreForm: spec.deferredPreForm ? spec.deferredPreForm(M) : null
            }, "workflow/form");
        }
    };

    // TODO: Should this be done more elegantly?
    if(spec.showFormTitlesWhenEditing) {
        editor.showFormTitlesWhenEditing = true;
    }

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
        var configuredEditor = editor;
        if(delegate.enablePerElementComments) {
            configuredEditor = Object.create(editor);
            configuredEditor.viewComments = can(M, O.currentUser, spec, 'viewComments');
            configuredEditor.commentsUrl = spec.path+"/comments/"+M.workUnit.id;
        }
        instance.handleEditDocument(E, configuredEditor);
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
            showCurrent: true,
            viewComments: delegate.enablePerElementComments && can(M, O.currentUser, spec, 'viewComments'),
            commentsUrl: delegate.enablePerElementComments ? spec.path+"/comments/"+M.workUnit.id : undefined
        });
        // std:ui:choose
        let i = P.locale().text("template");
        var text = M.getTextMaybe("docstore-review-prompt:"+spec.name) ||
            i["Please review the form below."];
        var options = [
            {
                action: "",
                label: M.getTextMaybe("docstore-review-continue:"+spec.name) || i["Continue"],
                parameters:{reviewed:true}
            }
        ];
        if(can(M, O.currentUser, spec, 'edit')) {
            options.push({
                action: "",
                label: M.getTextMaybe("docstore-review-return-to-edit:"+spec.name) ||
                    i["Return to edit"], parameters:{edit:true}
            });
            text = text + "\n" + (M.getTextMaybe("docstore-review-editable:"+spec.name) ||
                i["Once submitted, the form is no longer editable."]);
        }
        E.render({
            pageTitle: M.title+': '+(spec.title || '????'),
            backLink: M.url,
            backLinkText: M.getTextMaybe("docstore-review-cancel:"+spec.name) || i["Cancel"],
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
        let i = P.locale().text("template");
        var ui = instance.makeViewerUI(E, {
            showVersions: spec.history ? can(M, O.currentUser, spec, 'history') : true,
            showCurrent: true,
            viewComments: delegate.enablePerElementComments && can(M, O.currentUser, spec, 'viewComments'),
            commentsUrl: delegate.enablePerElementComments ? spec.path+"/comments/"+M.workUnit.id : undefined,
            uncommittedChangesWarningText: M.getTextMaybe("docstore-draft-warning-text:"+
                spec.name) || i["This is a draft version"]
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
        let i = P.locale().text("template");
        var instance = docstore.instance(M);
        var canEdit = can(M, O.currentUser, spec, 'edit');
        if(!(canEdit || instance.hasCommittedDocument)) {
            O.stop(i["Form hasn't been completed yet."]);
        }
        var ui = instance.makeViewerUI(E, {
            showVersions: spec.history ? can(M, O.currentUser, spec, 'history') : true,
            showCurrent: canEdit,
            addComment: delegate.enablePerElementComments && can(M, O.currentUser, spec, 'addComment'),
            privateCommentsEnabled: !!spec.viewPrivateComments, // if someone can see private comments, others can leave private comments
            addPrivateCommentOnly: can(M, O.currentUser, spec, 'addPrivateCommentOnly'),
            privateCommentMessage: spec.privateCommentMessage || NAME("hres:document_store:private_comment_message", i["This comment is private."]),
            addPrivateCommentLabel: spec.addPrivateCommentLabel || NAME("hres:document_store:add_private_comment_label", i["Private comment"]),
            // TODO: review the inclusion of separate viewComments and viewCommentsOtherUsers. The below may need to be changed following this.
            viewComments: delegate.enablePerElementComments && (can(M, O.currentUser, spec, 'viewCommentsOtherUsers') || can(M, O.currentUser, spec, 'addComment')),
            commentsUrl: delegate.enablePerElementComments ? spec.path+"/comments/"+M.workUnit.id : undefined,
            hideCommentsByDefault: delegate.enablePerElementComments ? M.selected(spec.hideCommentsByDefault||DEFAULT_HIDE_COMMENTS_WHEN) : true,
            uncommittedChangesWarningText: M.getTextMaybe("docstore-uncommitted-changes-warning-text:"+
                spec.name),
            url: spec.path+'/view/'+workUnit.id
        });
        if(spec.enableSidebarPanel) {
            var builder = O.ui.panel();
            M.workflowServiceMaybe("std:document_store:sidebar_panel", builder);
            E.appendSidebarHTML(builder.render());
        }
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

    // ----------------------------------------------------------------------

    if(delegate.enablePerElementComments) {

        var checkPermissions = function(M, action) {
            if((action === "viewCommentsOtherUsers") && !spec.viewCommentsOtherUsers) {
                action = "viewComments";
            } else if(action === "viewPrivateComments") {
                if(spec.viewPrivateComments) {
                    return spec.viewPrivateComments(M, O.currentUser);
                } else {
                    return false;
                }
            } else if(action === "editComments") {
                return !!spec.enableCommentEditing;
            }
            return can(M, O.currentUser, spec, action);
        };

        plugin.respond("GET,POST", spec.path+'/comments', [
            {pathElement:0, as:"workUnit", workType:workflow.fullName, allUsers:true}
        ], function(E, workUnit) {
            var M = workflow.instance(workUnit);
            O.service("std:document_store:comments:respond", E, docstore, M, checkPermissions);
        });

    }

    // ----------------------------------------------------------------------

    plugin.respond("GET,POST", spec.path+'/admin', [
        {pathElement:0, as:"workUnit", workType:workflow.fullName, allUsers:true}
    ], function(E, workUnit) {
        if(!O.currentUser.isSuperUser) { O.stop("Not permitted."); }
        E.setResponsiblePlugin(P);  // take over as source of templates, etc
        var M = workflow.instance(workUnit);
        var instance = docstore.instance(M);
        var currentDocument = instance.currentDocument;
        var forms = _.map(docstore._formsForKey(M, instance), function(form) {
            return form;
        });
        if(E.request.method === "POST") {
            currentDocument = JSON.parse(E.request.parameters.currentDocument);
            if(E.request.parameters.set) {
                instance.setCurrentDocument(currentDocument, true);
            }
            if(E.request.parameters.setAndCommit) {
                instance.setCurrentDocument(currentDocument, true);
                instance.commit();
            }
        }
        E.render({
            pageTitle: M.title+': '+(spec.title || '????'),
            backLink: M.url,
            M: M,
            path: spec.path,
            forms: forms,
            instance: instance,
            currentDocument: JSON.stringify(currentDocument, undefined, 2)
        }, "workflow/admin/overview");
    });

    plugin.respond("GET,POST", spec.path+'/admin/view-document', [
        {pathElement:0, as:"workUnit", workType:workflow.fullName, allUsers:true},
        {pathElement:1, as:"int"}
    ], function(E, workUnit, requestedVersion) {
        if(!O.currentUser.isSuperUser) { O.stop("Not permitted."); }
        E.setResponsiblePlugin(P);  // take over as source of templates, etc
        var M = workflow.instance(workUnit);
        var instance = docstore.instance(M);
        var entry = _.find(instance.history, function(v) {
            return v.version === requestedVersion;
        });
        E.render({
            pageTitle: M.title+': '+(spec.title || '????'),
            backLink: spec.path+'/admin/'+M.workUnit.id,
            backLinkText: "Admin",
            M: M,
            path: spec.path,
            instance: instance,
            entry: entry,
            document: JSON.stringify(entry.document, undefined, 2)
        }, "workflow/admin/view-document");
    });

    var adminEditor = {
        finishEditing: function(instance, E, complete) {
            E.response.redirect(spec.path+'/admin/'+instance.key.workUnit.id);
        },
        gotoPage: function(instance, E, formId) {
            E.response.redirect(spec.path+'/admin/form/'+instance.key.workUnit.id+"/"+formId);
        },
        render: function(instance, E, deferredForm) {
            var M = workflow.instance(O.work.load(E.request.extraPathElements[0]));
            E.render({
                pageTitle: "Admin Edit "+spec.title+": "+instance.key.title,
                backLink: spec.path+'/admin/'+instance.key.workUnit.id,
                deferredForm: deferredForm,
                deferredPreForm: spec.deferredPreForm ? spec.deferredPreForm(M) : null
            }, "workflow/form");
        },
        _showAllForms: true
    };

    plugin.respond("GET,POST", spec.path+'/admin/form', [
        {pathElement:0, as:"workUnit", workType:workflow.fullName, allUsers:true}
    ], function(E, workUnit) {
        if(!O.currentUser.isSuperUser) { O.stop("Not permitted."); }
        E.setResponsiblePlugin(P); // take over as source of templates, etc
        var M = workflow.instance(workUnit);
        var instance = docstore.instance(M);
        instance.handleEditDocument(E, adminEditor);
    });

});
