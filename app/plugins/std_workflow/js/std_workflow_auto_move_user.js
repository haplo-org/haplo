/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Workflows need to move actionableBy to the right person when the underlying data changes.
//
// Assuming that:
//   * only data in the object store is relevant
//   * actionableBy is set through the entities system, or by logic which uses it
// then a list of objects on which this depends can be determined simply by seeing which
// objects and refs have been loaded into the entities object.
//
// So if the entities object is reset before the getActionableBy handlers are called, and any
// refs founds afterwards are added as tags, it's easy to find the work units which need
// updating when an object is updated.
//
// Use a suffix of '.ABD' (actionablyBy dependency) for the tags as it's short, and uppercase
// is generally reserved by the platform.

// --------------------------------------------------------------------------

// actionableBy must always be set by this function to update the dependency information.
P.WorkflowInstanceBase.prototype._updateWorkUnitActionableBy = function(actionableBy, target) {
    delete this.$entities;
    var user = this._call('$getActionableBy', actionableBy, target);
    if(!user) {
        // If getActionableBy function returns null, function chain will terminate immediately.
        console.log("WARNING: Workflow getActionableBy() returned null or undefined, using fallback group");
        user = O.group(Group.WorkflowFallback);
    }
    this.workUnit.actionableBy = user;
    // Remove old dependency tags, then add in new ones from the objects in entities
    var tags = this.workUnit.tags;
    this._removeEntityDependencyTags(tags);
    var thisRef = this.workUnit.ref;
    var entities = this.$entities;
    if(thisRef && entities) { // object+entities might not be in use by this workflow
        tags[thisRef.toString()+'.ABD'] = "t"; // object is a dependency to simplify querying later
        var saveDep = function(value) {
            if(O.isRef(value)) {
                tags[value.toString()+'.ABD'] = "t";
            } else if(value.ref) {
                saveDep(value.ref);
            }
        };
        for(var name in entities) {
            if(entities.hasOwnProperty(name)) {
                var value = entities[name];
                if(_.isArray(value)) {
                    _.each(value, saveDep);
                } else {
                    saveDep(value);
                }
            }
        }
    }
    return user;
};

// --------------------------------------------------------------------------

P.WorkflowInstanceBase.prototype._removeEntityDependencyTags = function(tags) {
    var existingDependsTags = [];
    _.each(tags, function(value, key) {
        if(/\.ABD$/.test(key)) {
            existingDependsTags.push(key);
        }
    });
    existingDependsTags.forEach(function(key) { delete tags[key]; });
};

// --------------------------------------------------------------------------

// When objects are changed, iterate over work units which are tagged as dependent on that
// object and check the actionable by doesn't need to be updated.
P.hook("hPostObjectChange", function(response, object, operation, previous) {
    O.background.run("std_workflow:update_actionableby", {ref: object.ref.toString()});
});

// TODO: remove pBackgroundProcessing from plugin.json when the new background change notification is implemented
P.backgroundCallback("update_actionableby", function(data) {
    var ref = O.ref(data.ref);
    O.impersonating(O.SYSTEM, function() {
        _.each(O.work.query().isOpen().tag(ref.toString()+'.ABD',"t"), function(workUnit) {
            var workflow = P.allWorkflows[workUnit.workType];
            if(workflow) {
                var M = workflow.instanceForRef(workUnit.ref);
                var currentActionableById = workUnit.actionableBy.id;
                var actionableByName = M._findCurrentActionableByNameFromStateDefinitions();
                if(actionableByName) {
                    M._callHandler('$setWorkUnitProperties', "AUTOMOVE");
                    var user = M._updateWorkUnitActionableBy(actionableByName, M.target);
                    if(user.id !== currentActionableById) {
                        M._saveWorkUnit();
                        M.addTimelineEntry("AUTOMOVE", {from:currentActionableById, to:user.id});
                    }
                }
            }
        });
    });
});

