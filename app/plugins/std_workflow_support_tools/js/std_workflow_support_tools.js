/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// To prevent this support tool from being used in states where it would
// do unhelpful things, set the __preventSupportMoveBack__ flag.

// To allow groups of users to use these tools, based on the labels of objects,
// implement the std:workflow:support-tools:discover-allow-by-label
// service.

// If labels on underlying objects aren't sufficient, implement the
// std:workflow:support-tools:user-can-use-tools workflow service and return
// true if the specified user can use the tools.

// --------------------------------------------------------------------------

var CanUseSupportToolsForAllWorkflows = O.action("std:workflow:support-tools:allow-for-all-workflows").
    title("Workflow: Use support tools for all workflows").
    allow("group", Group.Administrators).
    allow("group", Group.WorkflowOverride);

var canUseWhenLabelled; // array of {groupId:..., label:...}

var canUseSupportToolsFor = function(user, M) {
    if(user.allowed(CanUseSupportToolsForAllWorkflows)) {
        return true;
    }
    // Discover additional permissions
    if(undefined === canUseWhenLabelled) {
        let l = [];
        O.serviceMaybe("std:workflow:support-tools:discover-allow-by-label", (action, label) => {
            l.push({action:action, label:label});
        });
        canUseWhenLabelled = l;
    }
    // Check for per-label permissions
    let num = canUseWhenLabelled.length;
    if(num && M.workUnit.ref) {
        let labels = M.workUnit.ref.load().labels;
        for(let i = 0; i < num; ++i) {
            let c = canUseWhenLabelled[i];
            // Check label first, as it's much quicker than checking an action
            if(labels.includes(c.label) && O.currentUser.allowed(c.action)) {
                return true;
            }
        }
    }
    // Check for per-workflow custom permissions
    if(true === M.workflowServiceMaybe("std:workflow:support-tools:user-can-use-tools", user)) {
        return true;
    }
    return false;
};

// --------------------------------------------------------------------------

// Use private service to extend all workflow UI
P.implementService("__std:workflow:add-support-actions-to-panel__", function(M, builder) {
    if(canUseSupportToolsFor(O.currentUser, M)) {
        let i = P.locale().text("template");
        builder.panel(8888887).
            spaceAbove().
            element(0, {title:i["Support tools"]}).
            link(1, "/do/workflow-support-tools/move-back/"+M.workUnit.id, i["Move back..."]);
    }
});

// --------------------------------------------------------------------------

const MOVE_BACK_ACTION = "SUPPORT-MOVE-BACK";

var MoveBack = P.form("move-back", "form/move-back.json");

P.respond("GET,POST", "/do/workflow-support-tools/move-back", [
    {pathElement:0, as:"workUnit", allUsers:true}
], function(E, workUnit) {
    let workflow = O.service("std:workflow:definition_for_name", workUnit.workType);
    let M = workflow.instance(workUnit);
    if(!canUseSupportToolsFor(O.currentUser, M)) { O.stop("Not permitted"); }

    let entries = M.timelineSelect().or((sq) => {
            sq.where("previousState", "!=", null).
               where("action", "=", MOVE_BACK_ACTION);
        }).order("datetime","DESC").limit(2);

    // Check that moving back is allowed
    let notPossible = (why) => E.render({M:M,why:why}, "move-back-not-possible");
    if(entries.length < 2) {
        return notPossible("no-previous");
    }
    if(_.find(entries, (e) => e.action === MOVE_BACK_ACTION)) {
        return notPossible("already");
    }
    if(M.flags.__preventSupportMoveBack__) {
        return notPossible("prevented");
    }

    let previousEntry = entries[1],
        currentEntry = entries[0],
        actionableUserBeforeMove = workUnit.actionableBy;

    let document = {};
    let form = MoveBack.handle(document, E.request);
    if(form.complete) {
        M.addTimelineEntry(MOVE_BACK_ACTION, {reason:document.reason});
        // Target for state is saved into the next entry
        M._forceMoveToStateFromTimelineEntry(previousEntry, currentEntry.target);

        // Email affected users
        M.sendEmail({
            template: P.template("email/move-back-notification"),
            to: [
                actionableUserBeforeMove,
                M.workUnit.actionableBy // will be de-duplicated
            ],
            view: {
                fullUrl: O.application.url + M.url,
                reason: document.reason,
                movedBy: O.currentUser
            }
        });

        return E.response.redirect(M.url);
    }
    E.render({
        M: M,
        form: form,
        currentStateText: M._getText(['status'], [M.state]),
        previousStateText: M._getText(['status'], [previousEntry.state]),
        previousUser: currentEntry.user,
        isError: E.request.method === "POST"
    });
});

P.implementService("__std:workflow:fallback-timeline-entry-deferrred__", function(M, entry) {
    if(entry.action === MOVE_BACK_ACTION) {
        return P.template("timeline/support-move-back").deferredRender({entry:entry});
    }
});

// When this is installed, override the admin tools to use this
P.implementService("__std:workflow:alternative-move-state-interface__", function(M) {
    return "/do/workflow-support-tools/move-back/"+M.workUnit.id;
});
