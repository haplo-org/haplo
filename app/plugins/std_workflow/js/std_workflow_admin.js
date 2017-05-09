/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var CanAdminWorkflow = O.action("std:workflow:admin:can-administrate-workflow").
    title("Workflow: Make administrative changes and override workflow").
    allow("group", Group.Administrators).
    allow("group", Group.WorkflowOverride);

var CanChangeWorkflowVisibility = O.action("std:workflow:admin:change-workflow-visibility").
    title("Workflow: Change workflow visibility").
    allow("group", Group.Administrators).
    allow("group", Group.WorkflowVisibility);

// --------------------------------------------------------------------------

P.WorkflowInstanceBase.prototype._addAdminActionPanelElements = function(builder) {
    var admin = O.currentUser.allowed(CanAdminWorkflow),
        visibility = admin || O.currentUser.allowed(CanChangeWorkflowVisibility);
    if(!(visibility || admin)) { return; }

    var panel = builder.panel(8888888).
        spaceAbove().
        element(0, {title:"Workflow override"});

    if(admin) {
        panel.
            link(1, "/do/workflow/administration/full-info/"+this.workUnit.id, "Full info").
            link(2, "/do/workflow/administration/timeline/"+this.workUnit.id, "Timeline").
            link(3, "/do/workflow/administration/move-state/"+this.workUnit.id, "Move state");
    }
    if(visibility) {
        panel.
            link(9, "/do/workflow/administration/visibility/"+this.workUnit.id, "Task visibility");
    }
};

// --------------------------------------------------------------------------

var getCheckedInstanceForAdmin = function(workUnit, action) {
    (action || CanAdminWorkflow).enforce();
    var workflow = P.allWorkflows[workUnit.workType];
    if(!workflow) { O.stop("Workflow not implemented"); }
    return workflow.instance(workUnit);
};

// --------------------------------------------------------------------------

P.respond("GET,POST", "/do/workflow/administration/full-info", [
    {pathElement:0, as:"workUnit", allUsers:true},  // Security check below
    {parameter:"actionable", as:"string", optional:true},
    {parameter:"json", as:"string", optional:true}
], function(E, workUnit, updateActionableBy, newJSON) {
    var M = getCheckedInstanceForAdmin(workUnit);
    var calculatedActionableBy, actionableNotSameAsCalculated = false;
    var actionableByName = M._findCurrentActionableByNameFromStateDefinitions();
    if(actionableByName) {
        calculatedActionableBy = M._call('$getActionableBy', actionableByName, M.target);
        if(calculatedActionableBy && (calculatedActionableBy.id !== M.workUnit.actionableBy.id)) {
            actionableNotSameAsCalculated = true;
        }
    }
    if(E.request.method === "POST") {
        if(updateActionableBy && calculatedActionableBy) {
            M._updateWorkUnitActionableBy(actionableByName, M.target);
        } else {
            try { workUnit.data = JSON.parse(newJSON); } catch(e) { O.stop("Bad JSON"); }
        }
        workUnit.save();
        return E.response.redirect("/do/workflow/administration/full-info/"+workUnit.id);
    }
    if(M.entities) {
        E.renderIntoSidebar({
            elements: [{
                label: "Entities",
                href: "/do/workflow/administration/entities/"+workUnit.id
            }]
        }, "std:ui:panel");
    }
    E.render({
        M: M,
        workUnit: M.workUnit,
        calculatedActionableBy: calculatedActionableBy,
        actionableNotSameAsCalculated: actionableNotSameAsCalculated,
        flags: _.keys(M.flags).join(", "),
        tags: JSON.stringify(M.workUnit.tags || {}, undefined, 2),
        data: JSON.stringify(M.workUnit.data || {}, undefined, 2)
    }, "admin/full-info");
});

// --------------------------------------------------------------------------

P.respond("GET", "/do/workflow/administration/timeline", [
    {pathElement:0, as:"workUnit", allUsers:true}  // Security check below
], function(E, workUnit) {
    var M = getCheckedInstanceForAdmin(workUnit);
    E.render({
        M: M,
        timeline: M.timelineSelect()
    }, "admin/timeline");
});

// --------------------------------------------------------------------------

P.respond("GET", "/do/workflow/administration/entities", [
    {pathElement:0, as:"workUnit", allUsers:true}  // Security check below
], function(E, workUnit) {
    var M = getCheckedInstanceForAdmin(workUnit);
    var entities = M.entities;
    if(!entities) { O.stop("Workflow doesn't use entities"); }
    var usedAsActionableBy = {};
    _.each(M.$states, function(defn,name) {
        if(defn.actionableBy) {
            usedAsActionableBy[defn.actionableBy] = true;
        }
    });
    var display = [];
    _.each(entities.$entityDefinitions, function(v,name) {
        var i = {
            name: name,
            objects: entities[name+'_list'],
            usedAsActionableBy: usedAsActionableBy[name]
        };
        if(i.usedAsActionableBy) { display.unshift(i); } else { display.push(i); }
    });
    E.render({
        M: M,
        display: display
    }, "admin/entities");
});

// --------------------------------------------------------------------------

P.respond("GET,POST", "/do/workflow/administration/move-state", [
    {pathElement:0, as:"workUnit", allUsers:true}, // Security check below
    {parameter:"entry", as:"int", optional:true},
    {parameter:"target", as:"string", optional:true}
], function(E, workUnit, timelineId, calculatedTarget) {
    var M = getCheckedInstanceForAdmin(workUnit);
    if(E.request.method === "POST" && timelineId) {
        var entry = M.$timeline.load(timelineId);
        if(entry.workUnitId !== M.workUnit.id) { O.stop("Wrong workflow"); }
        M._forceMoveToStateFromTimelineEntry(entry, calculatedTarget || null);
        return E.response.redirect(M.url);
    }
    var timeline = _.map(M.timelineSelect().where("previousState","!=",null), function(entry) {
        return {
            entry: entry,
            stateText: M._getText(['status'], [entry.state])
        };
    });
    // Fix up targets - target in timeline entry is the target the transition went to
    var target = M.target;
    for(var l = timeline.length-1; l >= 0; --l) {
        var v = timeline[l];
        v.target = target;
        target = v.entry.target;
    }
    E.render({
        M: M,
        timeline: timeline
    }, "admin/move-state");
});

// --------------------------------------------------------------------------

P.respond("GET,POST", "/do/workflow/administration/visibility", [
    {pathElement:0, as:"workUnit", allUsers:true}
], function(E, workUnit) {
    var M = getCheckedInstanceForAdmin(workUnit, CanChangeWorkflowVisibility);
    var currentVisible = workUnit.visible;
    if(E.request.method === "POST") {
        workUnit.visible = !currentVisible;
        workUnit.autoVisible = !currentVisible;  // so visible auto changes, but hidden doesn't
        workUnit.save();
        M.addTimelineEntry(currentVisible ? 'HIDE' : 'UNHIDE');
        return E.response.redirect(M.url);
    }
    E.render({
        pageTitle: (currentVisible ? "Hide: " : "Unhide: ")+M.title,
        backLink: M.url,
        text: currentVisible ?
            "This task is visible. Do you want to hide it?" :
            "This task is currently hidden. Do you want to make it visible again?",
        options: [
            {
                label: currentVisible ? "Hide task" : "Unhide task"
            }
        ]
    }, "std:ui:confirm");
});

