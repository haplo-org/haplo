/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.respond("POST", "/do/tested_plugin_failures/posting2", [
], function(E) {
    tested_plugin_failures.requestAsSeenByPlugin = E.request;
    E.response.kind = 'json';
    E.response.body = E.request.body;
});

P.willThrowException = function(msg) {
    throw new Error(msg || "Error message");
};

P.willNotThrowException = function() {
    return true;
};
