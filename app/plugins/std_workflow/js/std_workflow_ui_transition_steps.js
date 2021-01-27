/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */



P.db.table("stepsUIData", {
    workUnitId: {type:"int"},
    userId:     {type:"int"},
    transition: {type:"text", nullable:true},
    data:       {type:"json"}
});

// --------------------------------------------------------------------------

var TransitionStepsUI = function(M) {
    var steps = [];
    M._callHandler('$transitionStepsUI', function(spec) {
        steps.push(spec);
    }, this);

    // If this workflow isn't using the steps UI, flag as unused
    // and don't do any further initialisation.
    if(steps.length === 0 || !M.workUnit.isActionableBy(O.currentUser)) {
        this._unused = true;
        return;
    }

    this.M = M;
    this._steps = _.sortBy(steps, 'sort');
    this._userId = O.currentUser.id;

    var q = P.db.stepsUIData.select().
        where("workUnitId", "=", M.workUnit.id).
        where("userId", "=", this._userId);
    this._data = q.length ? q[0] : P.db.stepsUIData.create({
        workUnitId: M.workUnit.id,
        userId: this._userId,
        data: {}
    });
};

TransitionStepsUI.prototype = {

    saveData: function() {
        this._data.data = this._data.data;  // ensure field is marked as dirty
        this._data.save();
    },

    nextRedirect: function() {
        var reqRdr = this.nextRequiredRedirect();
        return reqRdr ? reqRdr : this.M.transitionUrl(this.requestedTransition);
    },

    nextRequiredRedirect: function() {
        if(this._unused) { return; }
        var currentStep = this._currentStep();
        if(currentStep) {
            return this._callStepFn(currentStep, 'url');
        }
    },

    hideSteps: function() {
        this._unused = true;
    },

    _commit: function(transition) {
        if(this._unused) { return; }
        var ui = this;
        this._steps.forEach(function(step) {
            ui._callStepFn(step, 'commit', transition);
        });
        // Delete all the pending data for this workflow, including
        // for any other users who may have started the process.
        P.db.stepsUIData.select().
            where("workUnitId", "=", this.M.workUnit.id).
            deleteAll();
    },

    _currentStep: function() {
        var ui = this;
        return this._findStep(function(step) {
            return !ui._stepIsComplete(step);
        });
    },

    _stepIsComplete: function(step) {
        return this._callStepFn(step, 'complete');
    },

    _findStep: function(f) {
        var steps = this._steps,
            l = steps.length;
        for(var i = 0; i < l; ++i) {
            var s = steps[i];
            if(!this._callStepFn(s, 'skipped')) {
                if(f(s)) { return s; }
            }
        }
    },

    _callStepFn: function(step, fnname /*, ... */) {
        var fn = step[fnname];
        if(fn) {
            var functionArguments = Array.prototype.slice.call(arguments, 0);
            functionArguments[0] = this.M;
            functionArguments[1] = this;
            return fn.apply(step, functionArguments);
        }
    }
};

TransitionStepsUI.prototype.__defineGetter__('unused', function() {
    return this._unused;
});

TransitionStepsUI.prototype.__defineGetter__('data', function() {
    if(this._unused) { throw new Error("Not using transition steps UI"); }
    return this._data.data;
});

TransitionStepsUI.prototype.__defineGetter__('requestedTransition', function() {
    if(this._unused) { return; }
    return this._data.transition;
});

TransitionStepsUI.prototype.__defineSetter__('requestedTransition', function(transition) {
    if(this._unused) { throw new Error("Not using transition steps UI"); }
    this._data.transition = transition;
    this.saveData();
});

// --------------------------------------------------------------------------

P.WorkflowInstanceBase.prototype.__defineGetter__("transitionStepsUI", function() {
    var stepsUI = this._stepsUI;
    if(!stepsUI) {
        this._stepsUI = stepsUI = new TransitionStepsUI(this);
    }
    return stepsUI;
});

// --------------------------------------------------------------------------

P.globalTemplateFunction("std:workflow:transition-steps:navigation", function(M, currentId) {
    var stepsUI = M.transitionStepsUI;
    if(!stepsUI._unused && stepsUI._steps.length > 0) {
        var steps = [];
        stepsUI._steps.forEach(function(step) {
            if(!stepsUI._callStepFn(step, 'skipped')) {
                steps.push({
                    url: stepsUI._callStepFn(step, 'url'),
                    title: stepsUI._callStepFn(step, 'title') || 'Step',
                    incomplete: !stepsUI._callStepFn(step, 'complete'),
                    current: currentId === step.id
                });
            }
        });
        let i = P.locale().text("template");
        steps.push({
            url: M.transitionUrl(stepsUI.requestedTransition),
            title: i['Confirm'],
            incomplete: true,
            current: currentId === "std:workflow:final-confirm-step"
        });
        let seenIncomplete = false;
        steps.forEach(function(step) {
            if(seenIncomplete) {
                step.completeLater = true;
            } else if(step.incomplete) {
                step.firstIncomplete = true;
                seenIncomplete = true;
            }
        });
        this.render(P.template("steps/navigation").deferredRender({
            steps: steps
        }));
    }
});

// --------------------------------------------------------------------------

P.registerWorkflowFeature("std:transition-choice-step", function(workflow, spec) {

    var Step = {
        id: "std:workflow:transitions-choice",
        sort: spec.transitionStepsSort || 1001,
        title: function(M, stepsUI) {
            if("title" in spec) {
                return spec.title;
            } else {
                let i = P.locale().text("template");
                return i["Decision"];
            }
        },
        url: function(M, stepsUI) {
            return "/do/workflow/choose-transition/"+M.workUnit.id;
        },
        complete: function(M, stepsUI) {
            return !!stepsUI.requestedTransition;
        }
    };

    workflow.transitionStepsUI(spec.selector, function(M, step) {
        step(Step);
    });

});

P.respond("GET,POST", "/do/workflow/choose-transition", [
    {pathElement:0, as:"workUnit"},
    {parameter:"transition", as:"string", optional:true}
], function(E, workUnit, transition) {
    var workflow = P.allWorkflows[workUnit.workType];
    if(!workflow) { O.stop("Workflow not implemented"); }
    var M = workflow.instance(workUnit);
    var stepsUI = M.transitionStepsUI;
    if(transition && M.transitions.has(transition) && (E.request.method === "POST")) {
        stepsUI.requestedTransition = transition;
        return E.response.redirect(stepsUI.nextRedirect());
    }
    var ui = new P.TransitionUI(M, transition);
    ui.options = _.map(M.transitions.list, function(transition) {
        return {
            // static/steps.js relies on this exact form of the URL
            action: "/do/workflow/choose-transition/"+M.workUnit.id+"?transition="+transition.name,
            label: transition.label,
            notes: transition.notes,
            indicator: transition.indicator
        };
    });
    E.render(ui, "steps/choose-transition");
});
