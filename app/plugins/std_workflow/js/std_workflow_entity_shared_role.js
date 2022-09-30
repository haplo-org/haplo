/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// specification has properties:
//      entities: array of entity names
// If one of those entities has multiple users, those used will be able to push and
// pull tasks between theselves. Any change of user will be 'sticky' when the workflow
// returns to that entity later on in the process.

var USE_TARGET_FOR_ENTITIES = O.application.config["std_workflow:entity_shared_roles:use_target_for_entities"];

var sharedEntitiesForWorkflow = {};

// Database table to store the last selected entity
P.db.table("sharedRoles", {
    workUnitId:     { type:"int",   indexed:true }, // which work unit (= instance of workflow)
    setByUser:      { type:"user",  nullable:true },// which user made this change, or null if automated
    entityName:     { type:"text" },                // entity name
    ref:            { type:"ref" }                  // which ref was last used
});

var tableSharedRolesSelect = function(M, entityName) {
    var q = P.db.sharedRoles.select().
        where("workUnitId","=",M.workUnit.id).
        where("entityName","=",entityName).
        limit(1).order("id");
    return q.length ? q[0] : null;
};

var replaceActionableByMaybe = function(M, actionableBy) {
    if(USE_TARGET_FOR_ENTITIES.length) {
        if(-1 !== USE_TARGET_FOR_ENTITIES.indexOf(actionableBy) && M.target) {
            let tt = M.target.split('.');
            if(tt.length === 2) {
                return tt[1];
            }
        }
    }
};

// --------------------------------------------------------------------------

P.registerWorkflowFeature("std:entities:entity_shared_roles", function(workflow, specification) {
    if(!(workflow.$stdEntitiesRolesInUse)) {
        throw new Error('You must use("std:entities:roles") before using the std:entities:entity_shared_roles workflow feature');
    }

    var sharedEntities = specification.entities || [],
        currentlyDeclaredSharedEntities = sharedEntitiesForWorkflow[workflow.fullName];
    if(currentlyDeclaredSharedEntities) {
        sharedEntitiesForWorkflow[workflow.fullName] = currentlyDeclaredSharedEntities.concat(sharedEntities);
        return;
    }
    sharedEntitiesForWorkflow[workflow.fullName] = sharedEntities;

    // ----------------------------------------------------------------------

    // When a user has been overridden by an action, this must be sticky so it
    // doesn't revert to the original user. But if the underlying entities change
    // it mustn't select user not in the list.

    // Override std:entities:roles' getActionableBy() (the other handlers work
    // with shared roles and don't need to be overriden)
    workflow.getActionableBy(function(M, actionableBy) {
        if(!(actionableBy in workflow.$entitiesBase.$entityDefinitions)) { return; }
        if(-1 === sharedEntitiesForWorkflow[workflow.fullName].indexOf(actionableBy)) { return; }
        if(!M.workUnit.isSaved) { return; } // doesn't have an ID until saved, but couldn't have been delegated either
        var row = tableSharedRolesSelect(M, actionableBy);
        if(row) {
            var stickyRef = row.ref;
            var list = M.entities[actionableBy+'_refList'];
            for(var l = list.length - 1; l >= 0; --l) {
                if(list[l] == stickyRef) {
                    var user = O.user(stickyRef);
                    if(user) { return user; }
                }
            }
        }
    });

    // ----------------------------------------------------------------------

    // If shared roles are active, we'd prefer that anything checking on roles
    // would use strict actionable by checks.
    workflow._preferStrictActionableBy({closed:false}, function(M) {
        var stateDefinition = M.$states[M.state];
        if(stateDefinition &&
                stateDefinition.actionableBy &&
                (-1 !== sharedEntitiesForWorkflow[workflow.fullName].
                    indexOf(stateDefinition.actionableBy))
                ) {
            return true;
        }
    });

    // ----------------------------------------------------------------------

    // User interface for push/pull. Only displayed if the current user is
    // in the list of entities.
    workflow.actionPanelStatusUI({}, function(M, builder) {
        if(M.workUnit.closed) { return; }
        var stateDefinition = M.$states[M.state],
            actionableBy = stateDefinition ? stateDefinition.actionableBy : undefined;
        if(USE_TARGET_FOR_ENTITIES) {
            actionableBy = replaceActionableByMaybe(M, actionableBy) || actionableBy;
        }
        if(-1 === sharedEntitiesForWorkflow[workflow.fullName].indexOf(actionableBy)) { return; }
        var list = M.entities[actionableBy+"_refList"];
        if(list.length > 1) {
            var userRef = O.currentUser.ref;
            if(userRef && _.find(list, function(r) { return r == userRef; })) {
                let i = P.locale().text("template");
                if(M.workUnit.isActionableBy(O.currentUser)) {
                    builder.link(11, "/do/workflow/shared-role/delegate/"+M.workUnit.id,
                        M._getTextMaybe(['shared-role-delegate'], [M.state]) || i["Delegate this task"],
                        "standard");
                } else {
                    builder.link(11, "/do/workflow/shared-role/take-over/"+M.workUnit.id,
                        M._getTextMaybe(['shared-role-take-over'], [M.state]) || i["Take over this task"],
                        "standard");
                }
            }
        }
    });

    // ----------------------------------------------------------------------

    // Make it clear in notification emails when proceses have been delegated.
    workflow.notification({}, function(M, notify) {
        var stateDefinition = M.$states[M.state],
            actionableBy = stateDefinition ? stateDefinition.actionableBy : undefined;
        if(USE_TARGET_FOR_ENTITIES) {
            actionableBy = replaceActionableByMaybe(M, actionableBy) || actionableBy;
        }
        if(-1 === sharedEntitiesForWorkflow[workflow.fullName].indexOf(actionableBy)) { return; }
        var row = tableSharedRolesSelect(M, actionableBy);
        if(row) {
            var delegatingUser = row.setByUser;
            if(delegatingUser) {
                notify.addHeaderDeferred(P.template("entity-shared-role/notify-header").deferredRender({
                    M:M, row:row,
                    wasTakeOver: (delegatingUser.ref == row.ref)
                }));
            }
        }
    });

});

// --------------------------------------------------------------------------

P.respond("GET,POST", "/do/workflow/shared-role", [
    {pathElement:0, as:"string"},
    {pathElement:1, as:"workUnit", allUsers:true},
    {parameter:"ref", as:"ref", optional:true}
], function(E, action, workUnit, changeRefTo) {
    let i = P.locale().text("template");

    if(workUnit.closed) {
        O.stop(i["Task has finished"]);
    }

    var workflow = P.allWorkflows[workUnit.workType];
    if(!workflow) { O.stop("Workflow not implemented"); }
    var M = workflow.instance(workUnit);

    var stateDefinition = M.$states[M.state],
        sharedEntities = sharedEntitiesForWorkflow[workflow.fullName] || [],
        actionableBy = stateDefinition ? stateDefinition.actionableBy : undefined;
    if(USE_TARGET_FOR_ENTITIES) {
        actionableBy = replaceActionableByMaybe(M, actionableBy) || actionableBy;
    }
    if(-1 === sharedEntities.indexOf(actionableBy)) { return; }

    var currentUserRef = O.currentUser.ref;
    if(!currentUserRef) { O.stop("Not permitted"); }

    var list = M.entities[actionableBy+"_refList"],
        listWithoutCurrentUser = _.filter(list, function(e) { return e != currentUserRef; });
    if(list.length <= 1) {
        O.stop(i["There are no other users who can work with you on this task."]);
    }
    // If the lists are the same length, then the current user isn't in the list
    if(list.length === listWithoutCurrentUser.length) { O.stop(i["You aren't a permitted user for this task."]); }

    // User selected?
    if((E.request.method === "POST") && changeRefTo) {
        if(!_.find(list, function(r) { return r == changeRefTo; })) { O.stop("Selected user is not in the list"); }

        var user = O.user(changeRefTo);
        if(!user) { O.stop(i["User doesn't have an account."]); }
        // Store changed ref so the role change is sticky
        var row = P.db.sharedRoles.create({
            workUnitId: workUnit.id,
            setByUser: O.currentUser,
            entityName: actionableBy,
            ref: changeRefTo
        });
        row.save();
        P.db.sharedRoles.select().
            where("workUnitId","=",workUnit.id).
            where("entityName","=",actionableBy).
            where("id","!=",row.id).
            deleteAll();
        var previousActionableBy = workUnit.actionableBy;
        // Change actionable by of underlying work unit to user
        workUnit.actionableBy = user;
        M._saveWorkUnit();
        M.addTimelineEntry("SHARED-ROLE-ACTION", {
            action: action,
            previousActionableUser: previousActionableBy.id,
            newActionableUser: user.id
        });

        E.response.redirect(M.url);
    }

    // Confirm or user selection UI
    var view = {M:M};
    if(action === "delegate") {
        view.pageTitle = (M._getTextMaybe(['shared-role-delegate-title'], [M.state]) || i["Delegate:"])+" "+M.title;
        view.isDelegate = true;
        view.text = (M._getTextMaybe(['shared-role-delegate-message'], [M.state]) || i["Delegate this task to:"]);
        view.options = _.map(listWithoutCurrentUser, function(ref) {
            return {
                label: ref.load().title,
                parameters: {ref:ref}
            };
        });
    } else {
        if(workUnit.isActionableBy(O.currentUser)) { O.stop(i["This task is already with you."]); }
        view.pageTitle = (M._getTextMaybe(['shared-role-take-over-title'], [M.state]) || i["Take over:"])+" "+M.title;
        view.text = (M._getTextMaybe(['shared-role-take-over-message'], [M.state]) || i["Would you like to take over this task?"]);
        view.options = [{
            label: i["Take over"],
            parameters: {ref:O.currentUser.ref}
        }];
    }
    E.render(view, "entity-shared-role/confirm-new-role");
});
