/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

(function() {

    O.action = function(code) {
        if(typeof(code) !== 'string') {
            throw new Error("Invalid argument to O.action()");
        }
        var action = $registry.$actions[code];
        if(!action) {
            checkSetupAllowed();
            action = $registry.$actions[code] = new Action(code);
        }
        return action;
    };

    // ----------------------------------------------------------------------

    var checkSetupAllowed = function() {
        if($registry.pluginLoadFinished) {
            // While O.action() can be used to retrieve an action object at any time,
            // it can't create new ones after plugins have been loaded, nor can those
            // actions be reconfigured. In future, we'll need to have a definitive list
            // of actions for the UI, lock it down.
            throw new Error("Cannot create or configure Actions after plugins have been loaded.");
        }
    };

    // ----------------------------------------------------------------------

    var Action = O.$private.$Action = function(code) {
        this.code = code;
        this.$allow = [];
        this.$deny = [];
    };
    // Setup functions
    Action.prototype.title = function(title) {
        checkSetupAllowed();
        this.$title = title;
        return this;
    };
    Action.prototype.$add = function(kind, thing, list) {
        checkSetupAllowed();
        if(!((kind === 'group') || (kind === 'all') || ('std:action:check:'+kind in $registry.servicesReg))) {
            throw new Error("Unimplemented kind for allow() or deny(), service std:action:check:"+kind+" must be implemented.");
        }
        list.push([kind, thing]);
        return this;
    };
    Action.prototype.allow = function(kind, thing) {
        return this.$add(kind, thing, this.$allow);
    };
    Action.prototype.deny = function(kind, thing) {
        return this.$add(kind, thing, this.$deny);
    };
    // Utility functions
    Action.prototype.enforce = function(message) {
        if(!O.currentUser.allowed(this)) {
            O.stop(message || "You are not permitted to perform this action.");
        }
    };

    // ----------------------------------------------------------------------

    // Implements SecurityPrincipal's allowed() method.
    O.$actionAllowed = function(user, action) {
        if(!(action instanceof Action)) {
            throw new Error("Bad action passed to user.allowed(). You must pass in the Action object returned by O.action()");
        }
        // The special administrator override action may allow the user to perform this action
        var adminOverride = $registry.$actions['std:action:administrator_override'];
        if(adminOverride) {
            if(!check(user, adminOverride.$deny) && check(user, adminOverride.$allow)) {
                return true;
            }
        }
        // Allowed if no denies and at least one allow.
        // Check deny first to short circuit allow checks if denied.
        return !(check(user, action.$deny)) && check(user, action.$allow);
    };

    var check = function(user, list) {
        for(var l = list.length - 1; l >= 0; --l) {
            var e = list[l];
            var kind = e[0], thing = e[1];
            if(kind === 'group') {
                if(user.isMemberOf(thing)) {
                    return true;
                }
            } else if(kind === 'all') {
                return true;
            } else {
                // The service is known to be implemented at this point
                if(O.service('std:action:check:'+kind, user, thing)) {
                    return true;
                }
            }
        }
        return false;
    };

})();
