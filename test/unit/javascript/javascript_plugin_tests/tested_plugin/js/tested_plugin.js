/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.respond("GET", "/do/tested_plugin/handler1", [
    {pathElement:0, as:"int"}
], function(E, number) {
    E.response.kind = 'text';
    E.response.body = "i="+number;
});

P.respond("GET", "/do/tested_plugin/handler2", [
    {parameter:"z", as:"string"}
], function(E, str) {
    E.render({
        pageTitle: "Hello",
        str: str
    });
});

P.respond("POST", "/do/tested_plugin/posting", [
], function(E) {
    tested_plugin.requestAsSeenByPlugin = E.request;
    E.render({pageTitle: "Post"}, "posting_template");
});


