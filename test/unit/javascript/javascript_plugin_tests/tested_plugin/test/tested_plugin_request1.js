/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


t.test(function() {

    t.login("user1@example.com");

    t.get("/do/tested_plugin/handler1/2445");
    t.assert(t.last.body === "i=2445");
    t.assert(t.last.view === undefined);

    t.get("/do/tested_plugin/handler2", {z:"Ping"});
    t.assert(t.last.method === "GET");
    t.assert(t.last.body === "HANDLER2: Ping");
    t.assert(t.last.templateName === "handler2");
    t.assert(t.last.view.pageTitle === "Hello");
    t.assert(t.last.view.str === "Ping");

    var postLast = t.post("/do/tested_plugin/posting/ping/pong", {x:"yes", y:"hello"}, {headers:{h1:"value1"}});
    var requestAsSeenByPlugin = tested_plugin.requestAsSeenByPlugin;
    t.assert(requestAsSeenByPlugin.method === "POST");
    t.assert(requestAsSeenByPlugin.path === "/do/tested_plugin/posting/ping/pong");
    t.assert(requestAsSeenByPlugin.extraPathElements.join('!') === "ping!pong");
    t.assert(requestAsSeenByPlugin.headers.h1 === "value1");
    t.assert(requestAsSeenByPlugin.parameters.x === "yes");
    t.assert(requestAsSeenByPlugin.parameters.y === "hello");
    t.assert(requestAsSeenByPlugin.remote.protocol === "IPv4");
    t.assert(requestAsSeenByPlugin.remote.address === "10.1.2.3");
    t.assert(postLast.templateName === "posting_template");
    t.assert(postLast.body === "POSTED");
    t.assert(postLast.view.pageTitle === "Post");

});
