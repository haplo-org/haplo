/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * (c) Avalara, Inc 2021
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


t.test(function() {

    t.login("user1@example.com");

    t.get("/do/tested_plugin/handler1/2445");
    t.assertEqual(t.last.statusCode, 200);
    t.assertEqual(t.last.body, "i=2445 u=41");
    t.assertEqual(t.last.view, undefined);

    t.get("/do/tested_plugin/handler1/2446");
    t.assertEqual(t.last.statusCode, 200);
    t.assertEqual(t.last.body, "i=2446 u=41");

    t.get("/do/tested_plugin/handler2", {z:"Ping"});
    t.assertEqual(t.last.method, "GET");
    t.assertEqual(t.last.body, "HANDLER2: Ping");
    t.assertEqual(t.last.templateName, "handler2");
    t.assertEqual(t.last.view.pageTitle, "Hello");
    t.assertEqual(t.last.view.str, "Ping");

    var postLast = t.post("/do/tested_plugin/posting/ping/pong", {x:"yes", y:"hello"}, {headers:{h1:"value1"}});
    var requestAsSeenByPlugin = tested_plugin.requestAsSeenByPlugin;
    t.assertEqual(requestAsSeenByPlugin.method, "POST");
    t.assertEqual(requestAsSeenByPlugin.path, "/do/tested_plugin/posting/ping/pong");
    t.assertEqual(requestAsSeenByPlugin.extraPathElements.join('!'), "ping!pong");
    t.assertEqual(requestAsSeenByPlugin.headers.h1, "value1");
    t.assertEqual(requestAsSeenByPlugin.parameters.x, "yes");
    t.assertEqual(requestAsSeenByPlugin.parameters.y, "hello");
    t.assertEqual(requestAsSeenByPlugin.remote.protocol, "IPv4");
    t.assertEqual(requestAsSeenByPlugin.remote.address, "10.1.2.3");
    t.assertEqual(postLast.templateName, "posting_template");
    t.assertEqual(postLast.body, "POSTED");
    t.assertEqual(postLast.view.pageTitle, "Post");

    var postLast2 = t.post("/do/tested_plugin/posting2", {}, {body:{h1:"value1", h2:"value2"}, kind:"json"});
    var requestAsSeenByPlugin = tested_plugin.requestAsSeenByPlugin;
    t.assertEqual(postLast2.statusCode, 200);
    t.assertObject(JSON.parse(requestAsSeenByPlugin.body), {h1:"value1", h2:"value2"});
    t.assertObject(JSON.parse(requestAsSeenByPlugin.body), {h2:"value2", h1:"value1"});
    t.assertEqual(requestAsSeenByPlugin.kind, "json");
    t.assertJSONBody(postLast2, {h1:"value1", h2:"value2"});
});
