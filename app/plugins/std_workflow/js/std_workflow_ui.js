/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


const NEW_TRANSITION_UI = !!O.application.config["std_workflow:new_transition_ui"];

_.extend(P.Workflow.prototype, {

    objectElementActionPanelName: function(name) {
        var workflow = this;
        workflow.plugin.implementService("std:action_panel:"+name, function(display, builder) {
            var M = workflow.instanceForRef(display.object.ref);
            if(M) {
                M.fillActionPanel(builder);
            }
        });
        return this;
    },

    panelHeading: function(priority, title) {
        var prototype = this.$instanceClass.prototype;
        if(!prototype.$panelHeadings) { prototype.$panelHeadings = []; }
        prototype.$panelHeadings.push({priority:priority, title:title});
    }

});

// --------------------------------------------------------------------------

_.extend(P.WorkflowInstanceBase.prototype.$fallbackImplementations, {

    $renderWork: {selector:{}, handler:function(M, W) {
        W.render({
            workUnit: M.workUnit,
            processName: M.getWorkflowProcessName(),
            status: M.getDisplayableStatus(),
            timeline: M.renderTimelineDeferred(true)
        }, P.template("default-work"));
        return true;
    }},

    $renderWorkList: {selector:{}, handler:function(M, W) {
        var view = {status:M._getText(['status-list', 'status'], [M.state])};
        M.setWorkListFullInfoInView(W, view);
        view.taskTitle = M._call('$taskTitle');
        W.render(view, P.template("default-work-list"));
        return true;
    }},

    $workListFullInfo: {selector:{}, handler:function(M, W, view) {
        if(!view.fullInfo) {
            view.fullInfo = M._call('$taskUrl');
        }
        return true;
    }},

    $actionPanelStatusUI: {selector:{}, handler:function(M, builder) {
        var state = this.state;
        let i = P.locale().text("template");
        builder.element("top", {
            title: i["Status"],
            label: this._getText(['status'], [state])
        });
        if(!this.workUnit.closed) {
            var displayedName = this._callHandler('$currentlyWithDisplayName');
            if(displayedName) {
                let i = P.locale().text("template");
                builder.element("top", {
                    title: this._getTextMaybe(['status-ui-currently-with'], [state]) || i['Currently with'],
                    label: displayedName
                });
            }
        }
    }},

    $currentlyWithDisplayName: {selector:{}, handler:function(M) {
        var state = this.state,
            user = M.workUnit.actionableBy;
        if(user && user.name) {
            var stateDefn = M.$states[state],
                displayedName = user.name;
            if(stateDefn && stateDefn.actionableBy) {
                var currentlyWithNameAnnotation = M._getTextMaybe(["status-ui-currently-with-annotation"], [stateDefn.actionableBy, state]);
                if(currentlyWithNameAnnotation) {
                    displayedName = displayedName+" ("+currentlyWithNameAnnotation+")";
                }
            }
            return displayedName;
        }
    }},

    $actionPanelTransitionUI: {selector:{}, handler:function(M, builder) {
        if(M.workUnit.isActionableBy(O.currentUser) && !M.transitions.empty) {
            builder.link("default",
                "/do/workflow/transition/"+M.workUnit.id,
                M._getText(['action-label'], [M.state]),
                "primary"
            );
        }
    }}

});

// --------------------------------------------------------------------------

_.extend(P.WorkflowInstanceBase.prototype, {

    // extraParameters may include "target" key to specify next target
    transitionUrl: function(transition, extraParameters) {
        // Use HSVT for safe generation of URL
        return P.template("transition-url").render({
            id: this.workUnit.id,
            transition: transition,
            extraParameters: extraParameters
        });
    },

    getWorkflowProcessName: function() {
        let i = P.locale().text("template");
        return this._getTextMaybe(["workflow-process-name"], [this.state]) || i['Workflow'];
    },

    getDisplayableStatus: function() {
        return this._getText(['status'], [this.state]);
    },

    getCurrentlyWithDisplayName: function() {
        return this._callHandler('$currentlyWithDisplayName');
    },

    fillActionPanel: function(builder) {
        this._callHandler('$actionPanelStatusUI', builder);
        this._callHandler('$actionPanelTransitionUI', builder);
        this._callHandler('$actionPanel', builder);
        this._addAdminActionPanelElements(builder);
        // Add any configured headings to the panels in the action panel, if they have something in them
        var headings = this.$panelHeadings;
        if(headings) {
            headings.forEach(function(heading) {
                var panel = builder.panel(heading.priority);
                if(!panel.empty) { panel.element(0, {title:heading.title}); }
            });
        }
        return builder;
    },

    setWorkListFullInfoInView: function(W, view) {
        this._callHandler('$workListFullInfo', W, view);
    },

    renderTimelineDeferred: function(renderingForWorkUnitDisplay) {
        var timeline = this.timelineSelect();
        var entries = this._renderTimelineEntries(timeline);
        return P.template("timeline").deferredRender({
            renderingForWorkUnitDisplay: renderingForWorkUnitDisplay,
            entries: entries
        });
    },

    timelineEntryDeferredRender: function(entry) {
        var textSearch = [entry.action];
        if(entry.previousState) { textSearch.push(entry.previousState); }
        var special, text = this._getTextMaybe(['timeline-entry'], textSearch);
        // If this can't be fulfilled by the text system, try the render handler instead
        if(!text) {
            special = this._call('$renderTimelineEntryDeferred', entry) ||
                this._renderTimelineEntryDeferredBuiltIn(entry);
        }
        if(text || special) {
            return P.template('timeline/entry-layout').deferredRender({
                entry: entry,
                text: text,
                special: special
            });
        }
    },

    _renderTimelineEntries: function(timeline) {
        var entries = [];
        for(var i = 0; i < timeline.length; ++i) {
            var entry = timeline[i];
            var deferred = this.timelineEntryDeferredRender(entry);
            if(deferred) {
                entries.push({
                    datetime: entry.datetime,
                    deferred: deferred
                });
            }
        }
        return entries;
    },

    // Render built-in timeline entries
    // This is a separate function which is hardcoded into the timeline rendering so it's
    // not easy to accidently remove, eg something else updates fallbackImplementation.
    _renderTimelineEntryDeferredBuiltIn: function(entry) {
        switch(entry.action) {
            // Can be overridden with timeline-entry:<NAME> text or renderTimelineEntryDeferred handler
            case "AUTOMOVE":
                return P.template("timeline/automove").deferredRender({});
            case "HIDE":
                return P.template("timeline/hide").deferredRender({entry:entry,hide:true});
            case "UNHIDE":
                return P.template("timeline/hide").deferredRender({entry:entry,hide:false});
        }
    },

    _workUnitRender: function(W) {
        this._callHandler(
            (W.context === "list") ? '$renderWorkList' : '$renderWork',
            W
        );
    }
});

// --------------------------------------------------------------------------

P.implementService("std:workflow:deferred_render_combined_timeline", function(instances) {
    var entries = [];
    _.each(instances, function(M) {
        var instanceProcessName = M.workflowServiceMaybe("std:workflow:combined_timeline:title_for_instance");
        var processName = instanceProcessName || M.getWorkflowProcessName();
        var renderedEntries = M._renderTimelineEntries(M.timelineSelect());
        renderedEntries.forEach(function(e) { e.processName = processName; });
        entries = entries.concat(renderedEntries);
    });
    entries = _.sortBy(entries, 'datetime');
    var currentProcessName;
    entries.forEach(function(e) {
        if(e.processName !== currentProcessName) {
            currentProcessName = e.processName;
            e.differentProcess = true;
        }
    });
    return P.template("timeline-combined").deferredRender({
        entries: entries
    });
});

// --------------------------------------------------------------------------

P.respond("GET,POST", "/do/workflow/transition", [
    {pathElement:0, as:"workUnit", allUsers:true},  // Security check below
    {parameter:"transition", as:"string", optional:true},
    {parameter:"target", as:"string", optional:true}
], function(E, workUnit, transition, requestedTarget) {
    if(!workUnit.isActionableBy(O.currentUser)) {
        return E.render({}, "transition-not-actionable");
    }

    var workflow = P.allWorkflows[workUnit.workType];
    if(!workflow) { O.stop("Workflow not implemented"); }
    var M = workflow.instance(workUnit);

    if(M.transitions.list.length === 1) {
        // If there is only one transition available, automatically select it to avoid
        // a confusing page with only one option.
        transition = M.transitions.list[0].name;
    }

    if(transition) {
        M._setPendingTransition(transition);
    }

    try {
        var ui = new TransitionUI(M, transition, requestedTarget);

        if(transition && M.transitions.has(transition)) {

            if(E.request.method === "POST") {
                M._callHandler('$transitionFormSubmitted', E, ui);
                if(ui._preventTransition) {
                    // Feature doesn't want the transition to happen right now, maybe redirect?
                    if(ui._redirect) {
                        return E.response.redirect(ui._redirect);
                    }
                } else {
                    // Workflow must validate any targets passed in to this UI, as otherwise
                    // user can pass in anything they want and mess things up.
                    var overrideTarget;
                    if(requestedTarget) {
                        if(M._callHandler('$transitionUIValidateTarget', requestedTarget) === true) {
                            overrideTarget = requestedTarget;
                        }
                    }

                    M._callHandler('$transitionFormPreTransition', E, ui);
                    M.transition(transition, ui._getTransitionDataMaybe(), overrideTarget);
                    var redirectTo = ui._redirect;
                    if(!redirectTo && M.workUnit.isActionableBy(O.currentUser)) {
                        redirectTo = M._callHandler('$transitionUIPostTransitionRedirectForActionableUser', M, ui);
                    }
                    return E.response.redirect(redirectTo || M._call('$taskUrl'));
                }
            }

            ui.transition = transition;
            ui.transitionProperties = M.transitions.properties(transition);
            M._callHandler('$transitionUI', E, ui);

        } else {

            M._callHandler('$transitionUIWithoutTransitionChoice', E, ui);

            // Generate std:ui:choose template options from the transition
            var urlExtraParameters = ui._urlExtraParameters;
            ui.options = _.map(M.transitions.list, function(transition) {
                return {
                    action: M.transitionUrl(transition.name, urlExtraParameters),
                    label: transition.label,
                    notes: transition.notes,
                    indicator: transition.indicator
                };
            });
        }

        if(ui._redirect) {
            return E.response.redirect(ui._redirect);
        }

        E.render(ui);

    } finally {
        // M.transition() may have already unset it by now
        M._setPendingTransition(undefined);
    }
});

// --------------------------------------------------------------------------

// Represents the built in UI, and act as the view for rendering.
var TransitionUI = function(M, transition, target) {
    this.M = M;
    this.requestedTransition = transition;
    if(target) {
        this.requestedTarget = target;
        this._urlExtraParameters = {target:target};
    }
};
TransitionUI.prototype = {
    NEW_TRANSITION_UI: NEW_TRANSITION_UI,
    addFormDeferred: function(position, deferred) {
        if(!this.$formDeferred) { this.$formDeferred = []; }
        this.$formDeferred.push({position:position, deferred:deferred});
    },
    addUrlExtraParameter: function(name, value) {
        if(!("_urlExtraParameters" in this)) { this._urlExtraParameters = {}; }
        this._urlExtraParameters[name] = value;
    },
    preventTransition: function() {
        this._preventTransition = true;
    },
    redirect: function(path) {
        this._redirect = path;
    },
    _getFormDeferreds: function(position) {
        return _.compact(_.map(this.$formDeferred || [], function(h) {
            return (h.position === position) ? h.deferred : undefined;
        }));
    },
    _getTransitionDataMaybe: function() {
        return this._transitionData;
    }
};
TransitionUI.prototype.__defineGetter__('backLinkText', function() {
    let i = P.locale().text("template");
    return i["Cancel"];
});
TransitionUI.prototype.__defineGetter__('pageTitle', function() {
    var taskTitle = this.M._call("$taskTitle");
    var pageTitle = this.M._getText(['transition-page-title', 'action-label'], [this.M.state]);
    if(taskTitle) { pageTitle = pageTitle + ': ' + taskTitle; }
    return pageTitle;
});
TransitionUI.prototype.__defineGetter__('transitionData', function() {
    var data = this._transitionData;
    if(!data) { data = this._transitionData = {}; }
    return data;
});
TransitionUI.prototype.__defineGetter__("backLink",             function() { return this.M._call('$taskUrl'); });
TransitionUI.prototype.__defineGetter__("aboveConfirmFormDeferreds", function() { return this._getFormDeferreds("aboveConfirm"); });
TransitionUI.prototype.__defineGetter__("bottomFormDeferreds",  function() { return this._getFormDeferreds("bottom"); });
TransitionUI.prototype.__defineGetter__("topFormDeferreds",     function() { return this._getFormDeferreds("top"); });
