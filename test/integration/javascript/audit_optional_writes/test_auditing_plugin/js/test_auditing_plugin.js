/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.hook('hAuditEntryOptionalWrite', function(response, entry, defaultWrite) {
    if(entry.remoteAddress !== '127.0.0.1' || !(entry.userId) || !(entry.authenticatedUserId) || !!(entry.apiKeyId)) {
        throw new Error("Audit entry not filled out");
    }
    if(entry.auditEntryType === 'DISPLAY') {
        var obj = entry.ref.load();
        if(obj.isKindOf(TYPE["std:type:book"])) {
            response.write = (obj.firstTitle().s() === 'Book Zero') ? !defaultWrite : defaultWrite;
        }
    } else if(entry.auditEntryType === 'SEARCH') {
        if(/audit/.test(entry.data.q)) {
            response.write = false;
        } else if(/ping/.test(entry.data.q)) {
            response.write = true;
        }
    } else if(entry.auditEntryType === 'FILE-DOWNLOAD') {
        if(entry.data.transform.indexOf("w53") !== -1) {
            response.write = false;
        } else if(entry.data.transform.indexOf("w54") !== -1) {
            response.write = true;
        }
    }
});

P.declareAuditEntryOptionalWritePolicy("Policy declared by string.");

P.MAGIC_AUDIT_POLICY_VALUE = 7263;   // check that 'this' is set correctly
P.declareAuditEntryOptionalWritePolicy(function() {
    return "Policy declared by function. "+this.MAGIC_AUDIT_POLICY_VALUE;
});
