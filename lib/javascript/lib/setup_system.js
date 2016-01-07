/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Set up schema, access permissions, etc.
// Not a complete interface to everything, but just the minimal interface for
// common plugin setup requirements.

(function() {

    // Container for the API
    O.setup = {};

    // Create new user, returning user object
    O.setup.createUser = function(details) {
        if(!_.isObject(details)) {
            throw new Error("Must pass an object containing details to O.setup.createUser()");
        }
        if(("ref" in details) && details.ref) {
            if(!(details.ref instanceof $Ref)) {
                throw new Error("The optional ref property passed to O.setup.createUser() must be a Ref.");
            }
            details = _.clone(details);
            details.ref = details.ref.objId;    // Convert to number for JSON serialisation
        }
        return $User.setup_createUser(JSON.stringify(details));
    };

    // Create new group, returning group object
    O.setup.createGroup = function(groupName) {
        if((typeof groupName !== 'string') || !(/\S/.test(groupName))) {
            throw new Error("Invalid group name for O.setup.createGroup()");
        }
        return $User.setup_createGroup(_.strip(groupName));
    };

})();
