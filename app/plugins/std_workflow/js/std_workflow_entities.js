/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var entityLoad = function(sourceEntity, desc, qual) {
    var sourceObject = this[sourceEntity+'_maybe'];
    return sourceObject ? sourceObject.first(desc, qual) : undefined;
};

var listLoad = function(sourceEntity, desc, qual) {
    var sourceList = this[sourceEntity+'_list'];
    var loadedList = [];
    _.each(sourceList, function(obj) {
        obj.every(desc, qual, function(o) {
            loadedList.push(o);
        });
    });
    return loadedList;
};

var loadRefs = function(ref) {
    if(!O.isRef(ref)) { throw new Error("Entities expected ref values when retrieving list property"); }
    return ref.load();
};

var getterBySuffix = {
    "refMaybe": function(name) {
        var defn = this.__entityDefinition(name);
        if(typeof(defn) === "function") { return defn.call(this, "first"); }
        return entityLoad.apply(this, defn);
    },
    "refList": function(name) {
        var defn = this.__entityDefinition(name);
        if(typeof(defn) === "function") { return defn.call(this, "list"); }
        return listLoad.apply(this, defn);
    },
    "ref": function(name) {
        return this.__required(name, this[name+"_refMaybe"]);
    },
    "maybe": function(name) {
        var refMaybe = this[name+"_refMaybe"];
        return refMaybe ? refMaybe.load() : undefined;
    },
    "list": function(name) {
        return this[name+"_refList"].map(loadRefs);
    }
};

var getterNoSuffix = function(name) {
    return this.__required(name, this[name+"_refMaybe"]).load();
};

var entityGetter = function(name, suffix) {
    var getter = suffix ? getterBySuffix[suffix] : getterNoSuffix;
    if(!getter) { throw new Error("Unknown entity suffix '"+suffix+"'"); }
    return getter.call(this, name);
};

// --------------------------------------------------------------------------

var EntitiesBase0 = function() { };
EntitiesBase0.prototype = new this.$GetterDictionaryBase(entityGetter, "_");
var EntitiesBase = function() { };
EntitiesBase.prototype = new EntitiesBase0();
EntitiesBase.prototype.__required = function(name, value) {
    return value || this.__lookupFailure(name);
};
EntitiesBase.prototype.__entityDefinition = function(name) {
    var defn = this.$entityDefinitions[name];
    return defn || this.__entityNotDefined(name);
};
EntitiesBase.prototype.__entityNotDefined = function(name) {
    throw new Error("Entity "+name+" not defined");
};
EntitiesBase.prototype.__lookupFailure = function(name) {
    // TODO: Better error reporting when entities aren't found?
    O.stop("Can't find "+name);
};

// --------------------------------------------------------------------------

var setupEntities = function(object, entityDefinitions, setupPrototype) {

    var Entities = function(ref, M) {
        if(!ref) { throw new Error("No ref for work unit"); }
        this.object_refMaybe = ref;
        this.object_refList = [ref];
        this.M = M;     // may be undefined
        this.$M = M;    // TODO: Remove this backwards compatibility property
    };
    Entities.prototype = object.$entitiesBase = new EntitiesBase();
    Entities.prototype.$entityDefinitions = _.clone(entityDefinitions); // may be modified by std:entities:add_entities
    if(setupPrototype) { setupPrototype(Entities.prototype); }

    object.constructEntitiesObject = function(o, M) {
        var ref;
        if("workUnit" in o) { ref = o.workUnit.ref; }
        else if(O.isRef(o)) { ref = o; }
        else                { ref = o.ref; }
        if(!ref) { throw new Error("Can't find ref when constructing Entities object"); }
        return new Entities(ref, M);
    };

    // Making the Entities object available for the std:entities:add_entities feature
    // allowing entity definitions to be supplied by workflow components
    object.constructEntitiesObject.$Entities = Entities;

    return object;
};

// --------------------------------------------------------------------------

P.registerWorkflowFeature("std:entities:add_entities", function(workflow, entityDefinitions) {
    var definitions = this.constructEntitiesObject.$Entities.prototype.$entityDefinitions;
    _.each(entityDefinitions, function(value, key) {
        if(key in definitions) {
            throw new Error('Entity "'+key+'" is already defined, should not be overwritten by feature');
        } else {
            definitions[key] = value;
        }
    });
});

// --------------------------------------------------------------------------

// Returns an entities object for the given ref.
// If a workflow has been started, it will be associated with that workflow.
// Otherwise it will not be associated with a particular workflow, and custom getter functions may not work.
P.implementService("std:workflow:entities:for_ref", function(name, ref) {
    var workflow = P.allWorkflows[name];
    if(!workflow) {
        throw new Error("No workflow defined for name "+name);
    }
    var M = workflow.instanceForRef(ref);
    if(M) {
        return M.entities;
    }
    return workflow.constructEntitiesObject(ref, undefined);
});

// --------------------------------------------------------------------------

// Allows standalone use of the entities system, returns an object which has
// a constructEntitiesObject function which takes a WorkUnit, Ref, or StoreObject
// and returns an entities object.
// Called as P.workflow.standaloneEntities(...) in a consuming plugin.
P.workflowFeatureFunctions.standaloneEntities = function(entityDefinitions, setupPrototype) {
    return setupEntities({}, entityDefinitions, setupPrototype);
};

// --------------------------------------------------------------------------

P.registerWorkflowFeature("std:entities", function(workflow, entityDefinitions, setupPrototype) {

    setupEntities(workflow, entityDefinitions, setupPrototype);

    workflow.$instanceClass.prototype.__defineGetter__("entities", function() {
        var entities = this.$entities;
        if(!entities) {
            entities = this.$entities = workflow.constructEntitiesObject(this.workUnit, this);
        }
        return entities;
    });

});

// --------------------------------------------------------------------------

P.registerWorkflowFeature("std:entities:roles", function(workflow) {
    if(!("constructEntitiesObject" in workflow)) {
        throw new Error('You must use("std:entities", {...}) before using the std:entities:roles workflow feature');
    }
    workflow.$stdEntitiesRolesInUse = true;

    workflow.getActionableBy(function(M, actionableBy) {
        if(!(actionableBy in workflow.$entitiesBase.$entityDefinitions)) { return; }
        var user, ref = M.entities[actionableBy+'_refMaybe'];
        if(ref && (user = O.user(ref))) {
            return user;
        }
    });

    workflow.hasRole(function(M, user, role) {
        if(!(role in workflow.$entitiesBase.$entityDefinitions)) { return; }
        var ref = user.ref;
        if(!ref) { return; }
        var refsForRole = M.entities[role+'_refList'];
        for(var i = (refsForRole.length - 1); i >= 0; --i) {
            if(ref == refsForRole[i]) {
                return true;
            }
        }
    });

    workflow.textInterpolate(function(M, text) {
        return text.replace(/\@([a-zA-Z0-9]+)\@/g, function(match, entityName) {
            var entity = M.entities[entityName+'_maybe'];
            // TODO: What should happen when entities aren't matched?
            return entity ? entity.title : '?';
        });
    });

});

// --------------------------------------------------------------------------

P.registerWorkflowFeature("std:entities:tags", function(workflow /* entity names */) {
    if(!("constructEntitiesObject" in workflow)) {
        throw new Error('You must use("entities", {...}) before using the std:entities:tags workflow feature');
    }

    // Can pass tags in separate arguments, or an array 
    var additionalEntityNames = _.flatten(Array.prototype.slice.call(arguments, 1));
    if(additionalEntityNames.length === 0) { return; }

    // List of entities is stored in workflow definition, but captured in a local variable here
    var workflowAlreadyHasEntityTags = ("$entityNamesTagList" in workflow);
    var entityNames = workflowAlreadyHasEntityTags ? workflow.$entityNamesTagList : (workflow.$entityNamesTagList = []);
    Array.prototype.push.apply(entityNames, additionalEntityNames);

    if(!workflowAlreadyHasEntityTags) {

        // Instance method to explicitly update tags (but not save work unit)
        workflow.$instanceClass.prototype.updateEntityTags = function() {
            var tags = this.workUnit.tags;
            var entities = this.entities;
            entityNames.forEach(function(entity) {
                var refMaybe = entities[entity+'_refMaybe'];
                if(refMaybe) {
                    tags[entity] = refMaybe.toString();
                } else {
                    delete tags[entity];
                }
            });
        };

        // Update tags whenever the work unit is saved
        workflow.preWorkUnitSave({}, function(M) {
            M.updateEntityTags();
        });

    }

});
