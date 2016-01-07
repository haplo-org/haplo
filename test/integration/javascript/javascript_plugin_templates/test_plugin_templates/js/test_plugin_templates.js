/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var CHOOSE = {
    options: [{
        indicator: "primary",
        action: "/url/one",
        label: "Label One"
    }]
};

P.respond("GET", "/do/plugin-templates/new", [
], function(E) {
    E.render({
        what: "New",
        deferredHandlebars: P.template("deferred-handlebars").deferredRender({deferredValue:"DEFVAL"}),
        choose: CHOOSE
    });
});

P.respond("GET", "/do/plugin-templates/legacy", [
], function(E) {
    E.render({
        pageTitle: "Legacy templates",
        choose: CHOOSE
    });
});

P.respond("GET", "/do/plugin-templates/page-title-and-back-link", [
], function(E) {
    E.render({
        a: {
            b: {
                c: { },
                titleText: "abc &><",
                blPrefix: "/page/one/two",
                y: "YYY <&>",
                backPrefix: "<>&"
            }
        }
    });
});

P.respond("GET", "/do/plugin-templates/layout", [
    {pathElement:0, as:"string"}
], function(E, layout) {
    E.render({layoutChoice:layout});
});

P.respond("GET", "/do/plugin-templates/resources", [], function(E) { E.render({}); });
