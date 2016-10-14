/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.allWorkflows = {}; // workType -> workflow object

P.workflowFeatures = {}; // name -> function(workflow)

// --------------------------------------------------------------------------

P.workflowNameToDatabaseTableFragment = function(name) {
    // Encode the database name using a stable transform which only uses a-zA-X0-9
    return name.replace(/([^a-zA-Y])/g, function(match, p1) { return 'Z'+p1.charCodeAt(0); });
};

var timelineRowDataGetter = function() {
    var data = this.$data;
    if(!data) {
        var json = this.json;
        data = this.$data = (json ? JSON.parse(json) : {});
    }
    return data;
};

var defineTimelineDatabase = function(plugin, workflowName) {
    var dbName = 'stdworkflowTl'+P.workflowNameToDatabaseTableFragment(workflowName);
    plugin.db.table(dbName, {
        workUnitId:     { type:"int",   indexed:true }, // which work unit (= instance of workflow)
        datetime:       { type:"datetime" },            // when this event happened
        user:           { type:"user" },                // which user was active when this entry was created
        action:         { type:"text" },                // what action was performed, ALL CAPS reserved for system
        previousState:  { type:"text", nullable:true }, // previous state the workflow was in (transitions only)
        target:         { type:"text", nullable:true }, // value of the target tag when this entry was created
        state:          { type:"text" },                // which state the workflow is in
        json:           { type:"text",  nullable:true } // json encoded data (use data property to read)
    }, function(prototype) {
        prototype.__defineGetter__('data', timelineRowDataGetter);
    });
    return dbName;
};

// --------------------------------------------------------------------------

var Transition = P.Transition = function(M, name, destination, destinationTarget) {
    this.M = M;
    this.name = name;
    this.destination = destination;
    this.destinationTarget = destinationTarget;
};
Transition.prototype.__defineGetter__('label', function() {
    return this.M._getText(['transition'], [this.name, this.M.state]);
});
Transition.prototype.__defineGetter__('notes', function() {
    return this.M._getTextMaybe(['transition-notes'], [this.name, this.M.state]);
});
Transition.prototype.__defineGetter__('indicator', function() {
    return this.M._getTextMaybe(['transition-indicator'], [this.name, this.M.state]) || 'standard';
});
Transition.prototype.__defineGetter__('confirmText', function() {
    return this.M._getTextMaybe(['transition-confirm', 'transition-notes'], [this.name, this.M.state]);
});

// --------------------------------------------------------------------------

var Transitions = P.Transitions = function(M) {
    this.list = [];
    var state = M.state;
    var stateDefinition = M.$states[state];
    var definitions = stateDefinition.transitions || [];

    for(var i = 0; i < definitions.length; ++i) {
        var d = definitions[i];
        var name = d[0];
        var destination = M._callHandler("$resolveTransitionDestination", name, d.slice(1), M.target) || d[1];
        var destinationTarget = M.target;
        if(typeof(destination) !== "string") {
            // resolveTransitionDestination is specifying the target as well as the state
            destinationTarget = destination.target;
            destination = destination.state;
        }
        // Don't allow workflows to resolve the destination to a state which wasn't in the list
        if(-1 === d.indexOf(destination, 1)) {
            throw new Error("Bad workflow destination resolution");
        }
        var filterResult = M._callHandler('$filterTransition', name);
        if((filterResult === undefined) || (filterResult === true)) {
            this.list.push(new Transition(M, name, destination, destinationTarget));
        }
    }
};
Transitions.prototype = {
    properties: function(name) {
        for(var i = (this.list.length - 1); i >= 0; --i) {
            if(this.list[i].name === name) {
                return this.list[i];
            }
        }
    },
    has: function(name) {
        return !!(this.properties(name));
    }
};
Transitions.prototype.__defineGetter__("empty", function() {
    return (this.list.length === 0);
});

// --------------------------------------------------------------------------

var WorkflowInstanceBase = P.WorkflowInstanceBase = function() {
    this.$states = {};
    var instance = this;
    _.each(this.$fallbackImplementations, function(impl, list) {
        instance[list] = [impl];
    });
    this.$textLookup = {};
};

WorkflowInstanceBase.prototype = {
    // Is this work unit selected by the selector?
    selected: function(selector) {
        var state = selector.state;
        if((state !== undefined) && (this.state !== state)) {
            return false;
        }
        var requiredFlags = selector.flags;
        if(requiredFlags !== undefined) {
            var currentFlags = this.flags;
            for(var f = 0; f < requiredFlags.length; ++f) {
                if(!(currentFlags[requiredFlags[f]])) {
                    return false;
                }
            }
        }
        var closed = selector.closed;
        if(closed !== undefined && (this.workUnit.closed !== closed)) {
            return false;
        }
        var pendingTransitions = selector.pendingTransitions;
        if(pendingTransitions !== undefined) {
            // If selector uses pendingTransitions, a transition must be pending and in the given list
            if(!(this.pendingTransition &&
                    -1 !== pendingTransitions.indexOf(this.pendingTransition))) {
                return false;
            }
        }
        return true;
    },

    hasRole: function(user, role) {
        return !!(this._call('$hasRole', user, role));
    },

    hasAnyRole: function(user, roles) {
        for(var i = (roles.length - 1); i >= 0; --i) {
            if(this.hasRole(user, roles[i])) {
                return true;
            }
        }
        return false;
    },

    getActionableBy: function(actionableBy, target) {
        return this._call('$getActionableBy', actionableBy, target);
    },

    // Move state
    transition: function(transition, data, overrideTarget) {
        var previousState = this.state,
            previousTarget = this.target,
            destination, destinationTarget, stateDefinition;
        this._setPendingTransition(transition);
        // Select the handlers for transitionComplete based on the initial state of transition.
        // (if it were done on the post transition state, it'd be quite hard to use)
        var transitionComplete = this._callHandlerDeferred('$transitionComplete', transition, previousState);
        try {
            var props = this.transitions.properties(transition);
            if(!props) {
                // TODO: How to make it easy for workflows to be tolerant of duplicate form submissions? transitionMaybe() function as well as this one?
                throw new Error("Not a valid transition for this state: "+transition);
            }
            destination = props.destination;
            destinationTarget = props.destinationTarget;
            if(overrideTarget) { destinationTarget = overrideTarget; }
            stateDefinition = this.$states[destination];
            if(!stateDefinition) {
                throw new Error("Workflow does not have destination state: "+destination);
            }
            this._callHandler('$observeExit', transition);
            this.workUnit.tags.state = destination;
            this.workUnit.tags.target = destinationTarget;

            // Dispatch states are used to make decisions which skip other states
            var safety = 256;
            while((--safety > 0) && ("dispatch" in stateDefinition)) {
                if("transitions" in stateDefinition) {
                    throw new Error("State definition with 'dispatch' property may not also have 'transitions' property.");
                }
                var possibleDestinations = stateDefinition.dispatch;
                var dispatchedDestination = this._callHandler("$resolveDispatchDestination", transition, destination, destinationTarget, possibleDestinations) || possibleDestinations[0];
                if(!dispatchedDestination) { throw new Error("Can't resolve dispatch destination for "+destination); }
                if(-1 === possibleDestinations.indexOf(dispatchedDestination)) { throw new Error("Not a valid dispatch destination for state: "+destination); }
                destination = dispatchedDestination;
                stateDefinition = this.$states[destination];
                if(!stateDefinition) { throw new Error("Workflow does not have destination state after dispatch: "+destination); }
                this.workUnit.tags.state = destination;
            }
            if(safety <= 0) { throw new Error("Went through too many dispatch states when attempting transition (possible loop)"); }

            this._callHandler('$setWorkUnitProperties', transition);
            if(stateDefinition.finish === true) {
                this.workUnit.close(O.currentUser);
                this._removeEntityDependencyTags(this.workUnit.tags);
            }
        } finally {
            this._setPendingTransition(undefined);
        }
        if("actionableBy" in stateDefinition) {
            this._updateWorkUnitActionableBy(stateDefinition.actionableBy, destinationTarget);
        }
        this._callHandler('$observeEnter', transition, previousState);
        if(stateDefinition.finish === true) {
            this._callHandler('$observeFinish');
        }
        this._saveWorkUnit();
        // Add timeline entry
        var timelineRow = {
            workUnitId: this.workUnit.id,
            datetime: new Date(),
            user: O.currentUser,
            action: transition,
            previousState: previousState,
            target: previousTarget || null,
            state: destination
        };
        if(data) { timelineRow.json = JSON.stringify(data); }
        this.$timeline.create(timelineRow).save();
        transitionComplete(); // Handlers selected before anything changed
        if(O.serviceImplemented("std:workflow:notify:transition")) {
            O.service("std:workflow:notify:transition", this, transition, previousState);
        }
        return this;
    },

    _forceMoveToStateFromTimelineEntry: function(entry, forceTarget) {
        this._setPendingTransition(entry.action);
        try {
            this.workUnit.tags.state = entry.state;
            if(forceTarget === null) { delete this.workUnit.tags.target; } else { this.workUnit.tags.target = forceTarget; }
            var stateDefinition = this.$states[entry.state];
            if("actionableBy" in stateDefinition) {
                this._updateWorkUnitActionableBy(stateDefinition.actionableBy, forceTarget);
            }
            if(this.workUnit.closed) { this.workUnit.reopen(O.currentUser); }
        } finally {
            this._setPendingTransition(undefined);
        }
        this._callHandler('$observeEnter', entry.action, entry.previousState);
        this._saveWorkUnit();
        this.$timeline.create({
            workUnitId: this.workUnit.id,
            datetime: new Date(),
            user: O.currentUser,
            action: "MOVE",
            previousState: entry.previousState,
            target: forceTarget || null,
            state: entry.state,
            json: entry.json
        }).save();
    },

    addTimelineEntry: function(action, data) {
        var timelineRow = {
            workUnitId: this.workUnit.id,
            datetime: new Date(),
            user: O.currentUser,
            action: action,
            target: this.workUnit.tags.target || null,
            state: this.state
        };
        if(data) { timelineRow.json = JSON.stringify(data); }
        this.$timeline.create(timelineRow).save();
        return this;
    },

    // Call function list in reverse order, stopping when a function returns
    // something other than undefined
    _call: function(list /* arguments */) {
        // Copy arguments, replace first with this
        var functionArguments = Array.prototype.slice.call(arguments, 0);
        functionArguments[0] = this;
        // Call functions in list in reverse order
        var returnValue;
        var functions = this[list];
        if(!functions) { return; }
        for(var i = (functions.length - 1); i >= 0; --i) {
            returnValue = functions[i].apply(this, functionArguments);
            if(returnValue !== undefined) { break; }
        }
        return returnValue;
    },

    // Call function list in reverse order with single argument, with the
    // return value the argument to the next function
    _applyFunctionListToValue: function(list, value) {
        var functions = this[list];
        if(!functions) { return value; }
        for(var i = (functions.length - 1); i >= 0; --i) {
            value = functions[i].call(this, this, value);
        }
        return value;
    },

    // Call handlers in the given list in reverse order
    _callHandler: function(list /* arguments */) {
        // Copy arguments, replace first with this
        var handlerArguments = Array.prototype.slice.call(arguments, 0);
        handlerArguments[0] = this;
        // Call handlers where their selector selects this work unit
        var handlers = this[list];
        if(!handlers) { return; }
        for(var i = (handlers.length - 1); i >= 0; --i) {
            var h = handlers[i];
            if(this.selected(h.selector)) {
                var r = h.handler.apply(this, handlerArguments);
                if(r !== undefined) {
                    return r;
                }
            }
        }
    },

    // Create a function which will call handlers with the arguments.
    // The handlers to call are selected using the current state of the
    // workflow, but called with M in the state after the transition.
    _callHandlerDeferred: function(list /* arguments */) {
        // Copy arguments, replace first with this
        var handlerArguments = Array.prototype.slice.call(arguments, 0);
        handlerArguments[0] = this;
        // Choose handlers
        var handlers = this[list];
        if(!handlers) { return function() {}; }
        var selectedHandlers = [];
        for(var i = (handlers.length - 1); i >= 0; --i) {
            var h = handlers[i];
            if(this.selected(h.selector)) {
                selectedHandlers.push(h);
            }
        }
        // Return function which will call the selected handler later
        var M = this; // for scope
        return function() {
            // selectedHandlers is in reverse order to the list, so called in order
            selectedHandlers.forEach(function(h) {
                var r = h.handler.apply(M, handlerArguments);
                if(r !== undefined) {
                    return r;
                }
            });
        };
    },

    // Called to start a new workflow
    _initialise: function(properties) {
        var initial = {state:"START"};
        this._call("$start", initial, properties);
        var stateDefinition = this.$states[initial.state];
        if(!stateDefinition) { throw new Error("Start state does not exist"); }
        if(stateDefinition.actionableBy) {
            this._updateWorkUnitActionableBy(stateDefinition.actionableBy, this.workUnit.tags.target);
        }
        this.workUnit.tags.state = initial.state;
        if(initial.target) { this.workUnit.tags.target = initial.target; }
        this._saveWorkUnit();
        this.$timeline.create({
            workUnitId: this.workUnit.id,
            datetime: new Date(),
            user: O.currentUser,
            action: 'START',
            previousState: "START",     // Need something in initialState so the initial state recorded as a state transition for flag calculation
            target: initial.target || null,
            state: initial.state
        }).save();
        return this;
    },

    _setPendingTransition: function(transition) {
        if(transition !== undefined) {
            this.pendingTransition = transition;
        } else {
            delete this.pendingTransition;
        }
        // Transitions may need to be recalculated as different selectors will match
        delete this.$transitions;
        delete this.$flags;
    },

    _saveWorkUnit: function() {
        this._callHandler('$preWorkUnitSave');
        this.workUnit.save();
    },

    // Given a kind of text, using the text system
    _getTextMaybe: function(names, path) {
        var search = [undefined].concat(path);
        while(search.length) {
            for(var n = 0; n < names.length; ++n) {
                search[0] = names[n];
                var text = this._call('$text', search.join(':'));
                if(typeof(text) === "string") {
                    return this._applyFunctionListToValue('$textInterpolate', text) || text;
                }
            }
            search.pop();
        }
    },

    _getText: function(names, path) {
        return this._getTextMaybe(names, path) || '????';
    },

    getTextMaybe: function(/* arguments */) {
        return this._getTextMaybe(arguments, []);
    },

    timelineSelect: function() {
        // order by ID rather than datetime to make sure always in sequence -- datetime could be equal
        // TODO: Change platform so order("id") works, then use instead of stableOrder().
        return this.$timeline.select().where("workUnitId","=",this.workUnit.id).stableOrder();
    },

    _findCurrentActionableByNameFromStateDefinitions: function() {
        var states = this.$states;
        var stateDefinition = states[this.state] || {};
        var actionableByName = stateDefinition.actionableBy;
        // Quick case - use the actionableBy in the current state
        if(actionableByName) { return actionableByName; }
        // Otherwise the timeline has to be searched
        var entry, timeline = this.timelineSelect();
        for(var i = timeline.length - 1; i >= 0; --i) {
            entry = timeline[i];
            stateDefinition = states[entry.state];
            if(stateDefinition && (actionableByName = stateDefinition.actionableBy)) {
                return actionableByName;
            }
        }
        // Didn't find an actionableBy name
        return undefined;
    },

    _calculateFlags: function() {
        // Flags are defined in the state definition rather than being recorded in the work unit data
        // so that they're easy to change in the code.
        var flags = {};
        var M = this;   // scoping
        // Change flags value
        var stateDefinition; // captured by change()
        var change = function(name, set) {
            var list = stateDefinition[name];
            if(list) {
                for(var i = 0; i < list.length; ++i) {
                    if(set) { flags[list[i]] = true; }
                    else { delete flags[list[i]]; }
                }
            }
        };
        // Get state changes from timeline, which all have non-null previousState.
        var timeline = this.timelineSelect().where("previousState", "!=", null);
        var states = _.map(timeline, function(row) { return row.state; });
        // Make sure the current state is the last entry (eg if in the middle of a transition)
        if((states.length === 0) || (states[states.length-1] !== this.state)) {
            states.push(this.state);
        }
        // Iterate through states
        var statesLength = states.length;
        var state;
        for(var i = 0; i < statesLength; ++ i) {
            state = states[i];
            stateDefinition = this.$states[state];
            if(stateDefinition) { // to be tolerant of code changing and states no longer existing
                // Enter flags
                change('flagsSetOnEnter', true);
                change('flagsUnsetOnEnter', false);
                // Exit flags, if entry doesn't refer to the current state
                if(i < (statesLength - 1)) {
                    change('flagsSetOnExit', true);
                    change('flagsUnsetOnExit', false);
                }
            }
        }
        // Flags from current state (stateDefinition is left set from loop unless there are no flags at all)
        if(stateDefinition) { change('flags', true); }
        // For setting flags calculated from workflow data, not state
        this._call('$modifyFlags', flags);
        return flags;
    },

    recalculateFlags: function() {
        var f = this.$flags = this._calculateFlags();
        return f;
    },

    getStateDefinition: function(state) {
        return this.$states[state];
    }
};

WorkflowInstanceBase.prototype.__defineGetter__("title", function() {
    return this._call('$taskTitle');
});

WorkflowInstanceBase.prototype.__defineGetter__("url", function() {
    return this._call('$taskUrl');
});

WorkflowInstanceBase.prototype.__defineGetter__("state", function() {
    return this.workUnit.tags.state;
});

WorkflowInstanceBase.prototype.__defineGetter__("target", function() {
    return this.workUnit.tags.target;
});

// pendingTransition property is set when workflow may transition (ie in UI) or is in the process of transitioning

WorkflowInstanceBase.prototype.__defineGetter__("transitions", function() {
    if(this.$transitions) { return this.$transitions; }
    var t = this.$transitions = new Transitions(this);
    return t;
});

WorkflowInstanceBase.prototype.__defineGetter__('flags', function() {
    if(this.$flags) { return this.$flags; }
    var f = this.$flags = this._calculateFlags();
    return f;
});

WorkflowInstanceBase.prototype.__defineGetter__("$timeline", function() {
    return this.$plugin.db[this.$timelineDbName];
});

// --------------------------------------------------------------------------

var interpolateNAMEmatch = function(_, name) { return NAME(name); };
P.interpolateNAME = function(_, text) { // must ignore first argument
    return text.replace(/\bNAME\(([^\)]+?)\)/g, interpolateNAMEmatch);
};

// --------------------------------------------------------------------------

// Other files add more fallback implementations of functions and handlers
WorkflowInstanceBase.prototype.$fallbackImplementations = {

    $taskUrl: function(M) {
        if(M.workUnit.ref) {
            return M.workUnit.ref.load().url();
        }
    },

    $taskTitle: function(M) {
        if(M.workUnit.ref) {
            return M.workUnit.ref.load().title;
        }
    },

    $text: function(M, key) {
        return M.$textLookup[key];
    },

    $textInterpolate: P.interpolateNAME,

    $getActionableBy: function(M, actionableBy, target) {
        if(actionableBy in GROUP) {
            return O.group(GROUP[actionableBy]);
        }
        if(actionableBy === "object:creator") {
            if(M.workUnit.ref) {
                return O.user(M.workUnit.ref.load().creationUid);
            }
        }
        return O.group(Group.WorkflowFallback);
    },

    $hasRole: function(M, user, role) {
        if((role in GROUP) && user.isMemberOf(GROUP[role])) {
            return true;
        }
        if(role === "object:creator") {
            if(M.workUnit.ref) {
                return (user.id === M.workUnit.ref.load().creationUid);
            }
        }
    }

};

// --------------------------------------------------------------------------

var Workflow = P.Workflow = function(plugin, name, description) {
    this.plugin = plugin;
    this.name = name;
    this.fullName = plugin.pluginName + ':' + this.name;
    this.description = description;

    this.$instanceClass = function(workUnit) {
        this.workUnit = workUnit;
    };
    this.$instanceClass.prototype = new WorkflowInstanceBase();
    this.$instanceClass.prototype.$plugin = plugin;
    this.$instanceClass.prototype.$timelineDbName = defineTimelineDatabase(plugin, name);

    var workflow = this;
    plugin.workUnit({
        workType: name,
        description: description,
        render: function(W) {
            (new workflow.$instanceClass(W.workUnit))._workUnitRender(W);
        },
        notify: function(workUnit) {
            return (new workflow.$instanceClass(workUnit))._workUnitNotify(workUnit);
        }
    });
};

var implementFunctionList = function(name) {
    var listInternalName = '$'+name;
    Workflow.prototype[name] = function(fn) {
        var prototype = this.$instanceClass.prototype;
        if(!(listInternalName in prototype)) { prototype[listInternalName] = []; }
        prototype[listInternalName].push(fn);
    };
};

var implementHandlerList = function(name) {
    var listInternalName = '$'+name;
    Workflow.prototype[name] = function(selector, handler) {
        var prototype = this.$instanceClass.prototype;
        if(!(listInternalName in prototype)) { prototype[listInternalName] = []; }
        prototype[listInternalName].push({
            selector: selector,
            handler: handler
        });
    };
};

Workflow.prototype = {

    use: function(name /* arguments */) {
        var feature = P.workflowFeatures[name];
        if(!feature) { throw new Error("No workflow feature: "+name); }
        // Copy arguments, replace name with this workflow definition, call feature function to let it set up the feature
        var featureArguments = Array.prototype.slice.call(arguments, 0);
        featureArguments[0] = this;
        feature.apply(this, featureArguments);
        return this;
    },

    // ----------------------------------------------------------------------

    states: function(states) {
        _.extend(this.$instanceClass.prototype.$states, states);
        return this;
    },

    // ----------------------------------------------------------------------

    text: function(text) {
        if(typeof(text) === 'function') {
            this.$instanceClass.prototype.$text.push(text);
        } else {
            _.extend(this.$instanceClass.prototype.$textLookup, text);
        }
        return this;
    },

    // ----------------------------------------------------------------------

    instance: function(workUnit) {
        if(workUnit.workType !== this.fullName) {
            throw new Error("Unexpected work unit type, got "+
                workUnit.workType+" expected "+this.fullName);
        }
        return new (this.$instanceClass)(workUnit);
    },

    instanceForRef: function(ref) {
        var q = O.work.query(this.fullName).ref(ref).isEitherOpenOrClosed().anyVisibility();
        return (q.length === 0) ? null : (new (this.$instanceClass)(q[0]));
    },

    create: function(properties) {
        var workUnit = O.work.create(this.fullName);
        if(properties && properties.object) {
            workUnit.ref = properties.object.ref;
        }
        var instance = new (this.$instanceClass)(workUnit);
        return instance._initialise(properties);
    }
};
implementFunctionList('start');
implementFunctionList('taskUrl');
implementFunctionList('taskTitle');
implementFunctionList('getActionableBy');
implementFunctionList('hasRole');
implementFunctionList('textInterpolate');
implementFunctionList('renderTimelineEntryDeferred');
implementFunctionList('modifyFlags');
// text() function list implemented above with exception for text dictionary
implementHandlerList('preWorkUnitSave');
implementHandlerList('setWorkUnitProperties');
implementHandlerList('observeEnter');
implementHandlerList('observeExit');
implementHandlerList('observeFinish');
implementHandlerList('transitionComplete');
implementHandlerList('renderWork');
implementHandlerList('renderWorkList');
implementHandlerList('workListFullInfo');
implementHandlerList('notification');
implementHandlerList('actionPanel');
implementHandlerList('actionPanelStatusUI');
implementHandlerList('actionPanelTransitionUI');
implementHandlerList('resolveDispatchDestination');
implementHandlerList('resolveTransitionDestination');
implementHandlerList('filterTransition');
implementHandlerList('transitionUI');
implementHandlerList('transitionFormSubmitted');
implementHandlerList('transitionFormPreTransition');
implementHandlerList('transitionUIValidateTarget');
implementHandlerList('transitionUIPostTransitionRedirectForActionableUser');

// --------------------------------------------------------------------------

P.registerWorkflowFeature = function(name, feature) {
    if(name in P.workflowFeatures) { throw new Error("Feature '"+name+"' already registered"); }
    P.workflowFeatures[name] = feature;
};

P.workflowFeatureFunctions = {
    registerWorkflowFeature: P.registerWorkflowFeature
    // More functions added in other files.
};

var implementWorkflow = function(plugin) {
    return function(name, description) {
        var workflow = new Workflow(plugin, name, description);
        P.allWorkflows[workflow.fullName] = workflow;
        return workflow;
    };
};

P.provideFeature("std:workflow", function(plugin) {
    plugin.workflow = _.extend({

        implement: implementWorkflow(plugin)

    }, P.workflowFeatureFunctions);
});

// --------------------------------------------------------------------------

P.implementService("std:workflow:for_ref", function(fullName, ref) {
    var workflow = P.allWorkflows[fullName];
    if(!workflow) {
        throw new Error("No workflow defined for name "+fullName);
    }
    return workflow.instanceForRef(ref);
});

