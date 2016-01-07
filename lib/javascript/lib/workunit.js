/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function() {

    // TODO: Is the naming of the unfunctions in the JS work unit API really that nice? Consistent? Should write up naming rules.

    O.work = {};

    // WorkUnit loader
    O.work.load = function(id) {
        var w = $WorkUnit.load(id);
        if(w === null) {
            throw new Error("Couldn't find work unit with id="+id);
        }
        return w;
    };

    var defaultUserForActionableBy = function() {
        var u = O.currentUser;
        // Don't allow the SYSTEM user to be used
        return (u && (u.id !== 0)) ? u : null;
    };

    // WorkUnit constructor
    // Argument: String of work type, or Object which contains at least workType property.
    // Tries to make reasonable defaults for the required values
    O.work.create = function(details) {
        var workUnit, workType, props = {};
        switch(typeof(details)) {
        case 'string':
            workType = details;
            break;
        case 'object':
            _.extend(props, details);
            workType = props.workType;
            delete props.workType;
            break;
        default:
            throw new Error("Bad argument for O.workUnit()");
        }
        if(workType === null || workType === undefined) {
            throw new Error("Work type must be specified when creating a work unit.");
        }
        if(workType.indexOf(":") < 1) {
            throw new Error("Work unit work type names must start with the plugin name followed by a : to avoid collisions.");
        }
        // Apply some defaults
        if(props.openedAt == undefined) { props.openedAt = new Date(); }
        if(props.createdBy == undefined) { props.createdBy = O.currentUser; }  // might be null
        if(props.actionableBy == undefined) { props.actionableBy = defaultUserForActionableBy(); }  // might be null
        // Convert dates from library dates
        if(props.openedAt) { props.openedAt = O.$convertIfLibraryDate(props.openedAt); }
        if(props.deadline) { props.deadline = O.$convertIfLibraryDate(props.deadline); }
        // Create the work unit, apply all the properties
        workUnit = $WorkUnit.constructNew(workType);
        _.extend(workUnit, props);
        return workUnit;
    };

    // Querying
    O.work.query = function(workType) {
        if(workType) {
            if(typeof(workType) !== "string") {
                throw new Error("Must pass work type as a string to O.work.query()");
            }
            if(workType.indexOf(":") < 1) {
                throw new Error("Work unit work type names must start with the plugin name followed by a : to avoid collisions.");
            }
        } else {
            workType = null;
        }
        return new $WorkUnitQuery(workType);
    };

})();
