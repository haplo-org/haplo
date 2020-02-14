/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.hook("hObjectDisplay", function(response, object) {
    if(O.currentUser.isSuperUser) {
        response.buttons["*SERIALISATIONOBJECTJSON"] = [["/do/std-serialisation-dev/object-json/"+object.ref, "JSON"]];
    }
});

P.respond("GET", "/do/std-serialisation-dev/object-json", [
    {pathElement:0, as:"object"}
], function(E, object) {
    if(!O.currentUser.isSuperUser) { O.stop("Not permitted"); }
    let serialiser = O.service("std:serialisation:serialiser").useAllSources();
    E.response.body = JSON.stringify(serialiser.encode(object), undefined, 2);
    E.response.kind = "json";
});
