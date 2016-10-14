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

var sharedEntitiesForWorkflow = {};

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

    // Database table to store the last selected entity
    workflow.plugin.db.table("stdworkflowSharedRoles", {
        workUnitId:     { type:"int",   indexed:true }, // which work unit (= instance of workflow)
        entityName:     { type:"text" },                // entity name
        ref:            { type:"ref" }                  // which ref was last used
    });
    var dbSharedRoles = workflow.plugin.db.stdworkflowSharedRoles;

    // Override std:entities:roles' getActionableBy() (the other handlers work
    // with shared roles and don't need to be overriden)
    workflow.getActionableBy(function(M, actionableBy) {
        if(!(actionableBy in workflow.$entitiesBase.$entityDefinitions)) { return; }
        if(-1 === sharedEntities.indexOf(actionableBy)) { return; }
        var q = dbSharedRoles.select().
            where("workUnitId","=",M.workUnit.id).
            where("entityName","=",actionableBy).
            limit(1).stableOrder();
        if(q.length) {
            var stickyRef = q[0].ref;
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

    // User interface for push/pull. Only displayed if the current user is
    // in the list of entities.
    workflow.actionPanelStatusUI({}, function(M, builder) {
        if(this.workUnit.closed) { return; }
        var stateDefinition = this.$states[M.state],
            actionableBy = stateDefinition ? stateDefinition.actionableBy : undefined;
        if(-1 === sharedEntities.indexOf(actionableBy)) { return; }
        var list = this.entities[actionableBy+"_refList"];
        if(list.length > 1) {
            var userRef = O.currentUser.ref;
            if(userRef && _.find(list, function(r) { return r == userRef; })) {
                if(this.workUnit.isActionableBy(O.currentUser)) {
                    builder.link(11, "/do/workflow/shared-role/delegate/"+this.workUnit.id,
                        this._getTextMaybe(['shared-role-delegate'], [this.state]) || "Delegate this task",
                        "standard");
                } else {
                    builder.link(11, "/do/workflow/shared-role/take-over/"+this.workUnit.id,
                        this._getTextMaybe(['shared-role-take-over'], [this.state]) || "Take over this task",
                        "standard");
                }
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
    if(workUnit.closed) { O.stop("Process has finished"); }

    var workflow = P.allWorkflows[workUnit.workType];
    if(!workflow) { O.stop("Workflow not implemented"); }
    var M = workflow.instance(workUnit);

    var stateDefinition = M.$states[M.state],
        sharedEntities = sharedEntitiesForWorkflow[workflow.fullName] || [],
        actionableBy = stateDefinition ? stateDefinition.actionableBy : undefined;
    if(-1 === sharedEntities.indexOf(actionableBy)) { return; }

    var currentUserRef = O.currentUser.ref;
    if(!currentUserRef) { O.stop("Not permitted"); }

    var list = M.entities[actionableBy+"_refList"],
        listWithoutCurrentUser = _.filter(list, function(e) { return e != currentUserRef; });
    if(list.length <= 1) { O.stop("There are no other users who can work with you on this process."); }
    // If the lists are the same length, then the current user isn't in the list
    if(list.length === listWithoutCurrentUser.length) { O.stop("You aren't a permitted user for this process."); }

    // User selected?
    if((E.request.method === "POST") && changeRefTo) {
        if(!_.find(list, function(r) { return r == changeRefTo; })) { O.stop("Selected user is not in the list"); }

        var user = O.user(changeRefTo);
        if(!user) { O.stop("User doesn't have an account."); }
        // Store changed ref so the role change is sticky
        var dbSharedRoles = workflow.plugin.db.stdworkflowSharedRoles;
        var row = dbSharedRoles.create({
            workUnitId: workUnit.id,
            entityName: actionableBy,
            ref: changeRefTo
        });
        row.save();
        dbSharedRoles.select().
            where("workUnitId","=",workUnit.id).
            where("entityName","=",actionableBy).
            where("id","!=",row.id).
            deleteAll();
        // Change actionable by of underlying work unit to user
        workUnit.actionableBy = user;
        workUnit.save();

        E.response.redirect(M.url);
    }

    // Confirm or user selection UI
    var view = {M:M};
    if(action === "delegate") {
        view.pageTitle = (M._getTextMaybe(['shared-role-delegate-title'], [M.state]) || "Delegate: ")+M.title;
        view.isDelegate = true;
        view.text = (M._getTextMaybe(['shared-role-delegate-message'], [M.state]) || "Delegate this process to:");
        view.options = _.map(listWithoutCurrentUser, function(ref) {
            return {
                label: ref.load().title,
                parameters: {ref:ref}
            };
        });
    } else {
        if(workUnit.isActionableBy(O.currentUser)) { O.stop("This process is already with you."); }
        view.pageTitle = (M._getTextMaybe(['shared-role-take-over-title'], [M.state]) || "Take over: ")+M.title;
        view.text = (M._getTextMaybe(['shared-role-take-over-message'], [M.state]) || "Would you like to take over this process?");
        view.options = [{
            label: "Take over",
            parameters: {ref:O.currentUser.ref}
        }];
    }
    E.render(view, "entity-shared-role/confirm-new-role");
});
