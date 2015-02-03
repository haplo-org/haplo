/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


T.test(function() {

    T.login("user1@example.com");

    T.get("/do/tested_plugin/handler1/2445");
    T.assert(T.last.body === "i=2445");
    T.assert(T.last.view === undefined);

    T.get("/do/tested_plugin/handler2", {z:"Ping"});
    T.assert(T.last.method === "GET");
    T.assert(T.last.body === "HANDLER2: Ping");
    T.assert(T.last.templateName === "handler2");
    T.assert(T.last.view.pageTitle === "Hello");
    T.assert(T.last.view.str === "Ping");

    var postLast = T.post("/do/tested_plugin/posting/ping/pong", {x:"yes", y:"hello"}, {headers:{h1:"value1"}});
    var requestAsSeenByPlugin = tested_plugin.requestAsSeenByPlugin;
    T.assert(requestAsSeenByPlugin.method === "POST");
    T.assert(requestAsSeenByPlugin.path === "/do/tested_plugin/posting/ping/pong");
    T.assert(requestAsSeenByPlugin.extraPathElements.join('!') === "ping!pong");
    T.assert(requestAsSeenByPlugin.headers.h1 === "value1");
    T.assert(requestAsSeenByPlugin.parameters.x === "yes");
    T.assert(requestAsSeenByPlugin.parameters.y === "hello");
    T.assert(requestAsSeenByPlugin.remote.protocol === "IPv4");
    T.assert(requestAsSeenByPlugin.remote.address === "10.1.2.3");
    T.assert(postLast.templateName === "posting_template");
    T.assert(postLast.body === "POSTED");
    T.assert(postLast.view.pageTitle === "Post");

});
