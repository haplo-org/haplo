/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

P.onLoad = function() {
    if(!O.PLUGIN_DEBUGGING_ENABLED) {
        throw new Error("DEV PLUGIN std_document_store_dev LOADED ON NON-DEV SERVER");
    }
};

if(O.PLUGIN_DEBUGGING_ENABLED) {

    // UI for showing/hiding implemented by std_workflow_dev
    var showDebugTools = function() {
        return (O.PLUGIN_DEBUGGING_ENABLED &&
            O.currentAuthenticatedUser &&
            O.currentAuthenticatedUser.isSuperUser &&
            O.currentAuthenticatedUser.id === 3 && // SUPPORT only for now
            O.currentAuthenticatedUser.data["std:enable_debugging"]);
    };

    // ----------------------------------------------------------------------------

    P.workflow.registerOnLoadCallback(function(workflows) {
        workflows.forEach(function(workflow) {

            var plugin = workflow.plugin;

            _.each(workflow.documentStore, function(docstore, name) {
                var spec = docstore.delegate;

                workflow.actionPanel({}, function(M, builder) {
                    if(showDebugTools()) {
                        // We hide the docstore admin panel, and duplicate much of it
                        // so that permissions can be handled differently/less strictly
                        builder.panel(8888999).hidePanel();
                        if(!builder.panel(8889999).shouldBeRendered()) {
                            builder.panel(8889999).element(0, {title:"Docstore debug"});
                        }
                        builder.panel(8889999).
                            link("default", spec.path+'/debug/'+M.workUnit.id, spec.title);
                    }
                });

                // ----------------------------------------------------------------------

                plugin.respond("GET,POST", spec.path+'/debug', [
                    {pathElement:0, as:"workUnit", workType:workflow.fullName, allUsers:true}
                ], function(E, workUnit) {
                    if(!O.currentUser.isSuperUser && !showDebugTools()) { O.stop("Not permitted."); }
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
                    }, "workflow/debug/overview");
                });

                plugin.respond("GET,POST", spec.path+'/debug/view-document', [
                    {pathElement:0, as:"workUnit", workType:workflow.fullName, allUsers:true},
                    {pathElement:1, as:"int"}
                ], function(E, workUnit, requestedVersion) {
                    if(!O.currentUser.isSuperUser && !showDebugTools()) { O.stop("Not permitted."); }
                    E.setResponsiblePlugin(P);  // take over as source of templates, etc
                    var M = workflow.instance(workUnit);
                    var instance = docstore.instance(M);
                    var entry = _.find(instance.history, function(v) {
                        return v.version === requestedVersion;
                    });
                    E.render({
                        pageTitle: M.title+': '+(spec.title || '????'),
                        backLink: spec.path+'/debug/'+M.workUnit.id,
                        backLinkText: "debug",
                        M: M,
                        path: spec.path,
                        instance: instance,
                        entry: entry,
                        document: JSON.stringify(entry.document, undefined, 2)
                    }, "workflow/debug/view-document");
                });

                var debugEditor = {
                    finishEditing: function(instance, E, complete) {
                        E.response.redirect(spec.path+'/debug/'+instance.key.workUnit.id);
                    },
                    gotoPage: function(instance, E, formId) {
                        E.response.redirect(spec.path+'/debug/form/'+instance.key.workUnit.id+"/"+formId);
                    },
                    render: function(instance, E, deferredForm) {
                        var M = workflow.instance(O.work.load(E.request.extraPathElements[0]));
                        E.render({
                            pageTitle: "Debug Edit "+spec.title+": "+instance.key.title,
                            backLink: spec.path+'/debug/'+instance.key.workUnit.id,
                            deferredForm: deferredForm,
                            deferredPreForm: spec.deferredPreForm ? spec.deferredPreForm(M) : null
                        }, "workflow/form");
                    },
                    _showAllForms: true
                };

                plugin.respond("GET,POST", spec.path+'/debug/form', [
                    {pathElement:0, as:"workUnit", workType:workflow.fullName, allUsers:true}
                ], function(E, workUnit) {
                    if(!O.currentUser.isSuperUser && !showDebugTools()) { O.stop("Not permitted."); }
                    E.setResponsiblePlugin(P); // take over as source of templates, etc
                    var M = workflow.instance(workUnit);
                    var instance = docstore.instance(M);
                    instance.handleEditDocument(E, debugEditor);
                });
            });
        });
    });

}
