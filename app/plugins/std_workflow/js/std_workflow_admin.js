/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var canAdminWorkflow = function(user) {
    return user.isMemberOf(Group.Administrators) || user.isMemberOf(Group.WorkflowOverride);
};

// --------------------------------------------------------------------------

P.WorkflowInstanceBase.prototype._addAdminActionPanelElements = function(builder) {
    if(!canAdminWorkflow(O.currentUser)) { return; }
    builder.panel(9999999).
        element(0, {title:"Workflow override"}).
        link(1, "/do/workflow/administration/full-info/"+this.workUnit.id, "Full info").
        link(2, "/do/workflow/administration/timeline/"+this.workUnit.id, "Timeline").
        link(3, "/do/workflow/administration/move-state/"+this.workUnit.id, "Move state");
};

// --------------------------------------------------------------------------

var getCheckedInstanceForAdmin = function(workUnit) {
    if(!canAdminWorkflow(O.currentUser)) { O.stop("Not authorised."); }
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
    E.render({
        M: M,
        workUnit: M.workUnit,
        calculatedActionableBy: calculatedActionableBy,
        actionableNotSameAsCalculated: actionableNotSameAsCalculated,
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

P.respond("GET,POST", "/do/workflow/administration/move-state", [
    {pathElement:0, as:"workUnit", allUsers:true}, // Security check below
    {parameter:"entry", as:"int", optional:true}
], function(E, workUnit, timelineId) {
    var M = getCheckedInstanceForAdmin(workUnit);
    if(E.request.method === "POST" && timelineId) {
        var entry = M.$timeline.load(timelineId);
        if(entry.workUnitId !== M.workUnit.id) { O.stop("Wrong workflow"); }
        M._forceMoveToStateFromTimelineEntry(entry);
        return E.response.redirect(M.url);
    }
    E.render({
        M: M,
        timeline: _.map(M.timelineSelect().where("previousState","!=",null), function(entry) {
            return {
                entry: entry,
                stateText: M._getText(['status'], [entry.state])
            };
        })
    }, "admin/move-state");
});
