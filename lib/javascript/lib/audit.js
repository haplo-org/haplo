/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function() {

    O.audit = {};

    O.audit.write = function(entry) {
        if(!entry || typeof(entry) !== 'object' || _.isArray(entry)) {
            throw new Error("Must pass an object to O.audit.write()");
        }
        var e = _.clone(entry);
        // Important not to allow objId propery, as it's internal
        if('objId' in e) {
            throw new Error("Can't pass objId property to O.audit.write()");
        }

        // Explicit check for retired secId attribute
        if('secId' in e) {
            throw new Error("Use of secId is no longer valid.");
        }

        // Can't pass a ref through JSON, so decompose it into obj_id, checking usage at same time.
        if('ref' in e) {
            if(!O.isRef(e.ref)) {
                throw new Error("The ref property for O.audit.write() must be a Ref");
            }
            e.objId = e.ref.objId;
            delete e['ref'];
        }
        // Default displayable to false
        if(!('displayable' in e)) {
            e.displayable = false;
        }
        // Check data property is a dictionary-like object, if it exists
        if('data' in e) {
            if(!(e.data) || typeof(e.data) !== 'object' || _.isArray(e.data)) {
                throw new Error("The data property must be an Object for O.audit.write()");
            }
        }
        return $AuditEntry._write(JSON.stringify(e));
    };

    // Querying
    O.audit.query = function() {
        return new $AuditEntryQuery();
    };

})();
