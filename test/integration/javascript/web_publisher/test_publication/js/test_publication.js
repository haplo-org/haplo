/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var Publication = P.webPublication.register(P.webPublication.DEFAULT);

Publication.respondToExactPath("/test-publication",
    function(E) {
        E.render({
          parameter: E.request.parameters["test"]
        });
    }
);

Publication.respondToExactPath("/test-publication/all-exchange",
    function(E) {
        E.response.statusCode = HTTP.CREATED;
        E.response.kind = "html"; // only kind that's allowed
        E.response.body = "RESPONSE:"+E.request.parameters["t2"];
        E.response.headers["X-Test-Header"] = "Test Value";
    }
);

// For testing robots.txt
Publication.respondToDirectory("/testdir", function(E) {});
Publication.respondWithObject("/testobject", [], function(E) {});
