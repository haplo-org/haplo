/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * (c) Avalara, Inc 2021
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.respond("GET", "/do/tested_plugin/handler1", [
    {pathElement:0, as:"int"}
], function(E, number) {
    E.response.kind = 'text';
    E.response.statusCode = 200;
    E.response.body = "i="+number+" u="+O.currentUser.id;
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

P.respond("POST", "/do/tested_plugin/posting2", [
], function(E) {
    tested_plugin.requestAsSeenByPlugin = E.request;
    E.response.kind = 'json';
    E.response.statusCode = 200;
    E.response.body = E.request.body;
});

P.willThrowException = function(msg) {
    throw new Error(msg || "Error message");
};
