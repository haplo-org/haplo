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
    if(context.hint.useLayout) {
        return P.template('layout').render({blocks:blocks});
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

Publication.respondToExactPath("/publication/xml",
    function(E, context) {
        var xml = O.xml.document();
        xml.cursor().element("test");
        E.response.body = xml;
    }
);

// For testing robots.txt
Publication.respondToDirectory("/testdir", function(E, context) {});
Publication.respondWithObject("/testobject", [], function(E, context) {});
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
