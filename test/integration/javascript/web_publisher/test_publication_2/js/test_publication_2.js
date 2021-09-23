/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2021            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var Publication = P.webPublication.register(P.webPublication.DEFAULT).
    serviceUser("test:service-user:second-publisher").
    setHomePageUrlPath("/test-publication-2").
    permitFileDownloadsForServiceUser();

Publication.layout(function(E, context, blocks) {
    if(context.hint.useLayout) {
        return P.template('layout').render({
            context: context,
            blocks: blocks
        });
    }
});

Publication.respondToExactPath("/test-publication-2",
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

Publication.respondToExactPath("/duplicated",
    function(E, context, object) {
        E.render({});
    }
);

Publication.addRobotsTxtDisallow("/test-disallow/2");
