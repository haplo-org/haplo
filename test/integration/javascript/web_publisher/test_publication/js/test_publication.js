/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var Publication = P.webPublication.register(P.webPublication.DEFAULT).
    serviceUser("test:service-user:publisher").
    setHomePageUrlPath("/test-publication").
    permitFileDownloadsForServiceUser();

Publication.layout(function(E, context, blocks) {
    if(context.hint.useLayout || -1 !== E.request.path.indexOf("testobject")) {
        return P.template('layout').render({
            context: context,
            blocks: blocks
        });
    }
});

Publication.respondToExactPath("/test-publication",
    function(E, context) {
        if(E.request.parameters.layout) {
            context.hint.useLayout = true;
        }
        if(E.request.parameters.sidebar) {
            E.renderIntoSidebar({}, "sidebar");
        }
        E.render({
            uid: O.currentUser.id,
            parameter: E.request.parameters["test"]
        });
    }
);

Publication.respondToExactPath("/test-publication/all-exchange",
    function(E, context) {
        E.response.statusCode = HTTP.CREATED;
        E.response.kind = "text";
        E.response.body = "RESPONSE:"+E.request.parameters["t2"];
        E.response.headers["X-Test-Header"] = "Test Value";
    }
);

Publication.respondToExactPathAllowingPOST("/post-test-exact",
    function(E, context) {
        if(E.request.method === "POST") {
            E.response.headers["Content-Type"] = "application/x-random-html";
        }
        E.response.kind = "html";
        E.response.body = "test exact "+E.request.method;
    }
);

Publication.respondToDirectoryAllowingPOST("/post-test-directory",
    function(E, context) {
        E.response.kind = "html";
        E.response.body = "test directory "+E.request.method;
    }
);

Publication.respondToDirectory("/publication/response-kinds", function(E, context) {
    var kind = E.request.extraPathElements[0];
    if(kind === "xml") {
        var xml = O.xml.document();
        xml.cursor().element("test");
        E.response.body = xml;
    } else if(kind === "binary-data-in-memory") {
        E.response.body = O.binaryData("ABC,DEF", {mimeType:"text/csv", filename:"hello.csv"})
    } else if(kind === "binary-data-on-disk") {
        E.response.setExpiry(200);
        E.response.headers["X-Test-1"] = "A";
        E.response.body = P.loadFile("bin.txt");
        E.response.headers["X-Test-2"] = "Z";
    } else if(kind === "zip") {
        var zip = O.zip.create("pub");
        zip.add(O.binaryData("DATA", {mimeType:"text/plain", filename:"test1.txt"}));
        E.response.body = zip;
    } else if(kind === "stored-file") {
        E.response.body = O.file("3442354441f857a2dd63ab43161fb5d4f9473927afbe39d5f9a8e1cb2ee4cc59"); // example3.pdf
    } else if(kind === "json") {
        E.response.kind = "json";
        E.response.body = JSON.stringify({"a":42});
    } else if(kind === "stop") {
        context.hint.useLayout = true;
        O.stop("Stop error message1", "Title for stop1");
    } else if(kind === "stop-no-layout") {
        O.stop("Stop error message2", "Title for stop2");
    } else if(kind === "exception") {
        context.hint.useLayout = true;
        throw new Error("ping");
    }
});

Publication.respondWithObject("/testobject", [T.Book],
    function(E, context, object) {
        E.render({
            object: P.webPublication.widget.object(object)
        });
    }
);

Publication.respondToExactPath("/duplicated",
    function(E, context, object) {
        E.render({});
    }
);

// For testing robots.txt
Publication.respondToDirectory("/testdir", function(E, context) {});
Publication.addRobotsTxtDisallow("/test-disallow/1");

// For testing downloads
P.hook('hUserPermissionRules', function(response, user) {
    if(user.isMemberOf(Group.ServiceGroup)) {
        response.rules.rule(T.Book, O.STATEMENT_ALLOW, O.PERM_READ);
    }
});

// --------------------------------------------------------------------------

// Mini-publication at the root of the second hostname of the test app

var RootPublication = P.webPublication.register('test'+O.application.id+'.host').
    serviceUser("test:service-user:publisher").
    setHomePageUrlPath("/");

RootPublication.respondToExactPath("/",
    function(E, context) {
        E.response.body = 'ROOT PUBLICATION';
        E.response.kind = 'text';
    }
);

RootPublication.addRobotsTxtDisallow("/test-disallow/2");
