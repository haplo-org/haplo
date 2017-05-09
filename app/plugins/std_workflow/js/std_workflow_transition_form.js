/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Add a form at the top of the standard transition UI, which must be complete before the transition can take place.
// The form document is stored in the timeline entry.
P.registerWorkflowFeature("std:transition_form", function(workflow, spec) {

    var selector = spec.selector || {};
    var showForTransitions = spec.transitions;
    var form = spec.form;
    if(!form) { throw new Error("form must be specified."); }
    var onTransitionCallback = spec.onTransition;
    var prepareFormInstance = spec.prepareFormInstance;

    var doNotShowForm = function(ui) {
        if(showForTransitions && (-1 === showForTransitions.indexOf(ui.requestedTransition))) {
            return true;
        }
    };

    var getFormInstance = function(M, E, ui) {
        var instance = form.instance(ui.transitionData);
        if(prepareFormInstance) { prepareFormInstance(M, instance); }
        instance.update(E.request);
        return instance;
    };

    // Add the form to the top of the page, render error message if not complete.
    workflow.transitionUI(selector, function(M, E, ui) {
        if(doNotShowForm(ui)) { return; }
        var instance = getFormInstance(M, E, ui);
        var view = {form:instance};
        if(E.request.method === "POST" && !(instance.complete)) {
            view.incomplete = true;
            view.message = M._getTextMaybe(['transition-form-error'], [M.state]);
        }
        ui.addFormDeferred("top", P.template("transition-form").deferredRender(view));
    });

    // Prevent the transition from happening if the form is not complete.
    workflow.transitionFormSubmitted(selector, function(M, E, ui) {
        if(doNotShowForm(ui)) { return; }
        var instance = getFormInstance(M, E, ui);
        if(!instance.complete) {
            ui.preventTransition();
        }
    });

    // If an onTransition function is used, call it just before the transition is committed.
    if(onTransitionCallback) {
        workflow.transitionFormPreTransition(selector, function(M, E, ui) {
            if(doNotShowForm(ui)) { return; }
            onTransitionCallback(M, ui.transitionData);
        });
    }

});
