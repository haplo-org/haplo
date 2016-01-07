/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.element("test", "Simple test element", function(L) {
    L.render({
        title: "Simple Test"
    });
});

P.element("opts", "Options display", function(L) {
    var opts = _.map(L.options, function(value, key) {
        return {key:key, value:value};
    });
    var title = "Options";
    if(L.options.title != undefined) { title = L.options.title; }
    L.render({
        title: title,
        opts: opts
    }, "option_display");   // don't use default
});

P.element("links", "Test Links", function(L) {
    L.renderLinks([
            ['/path1','Line 1'],
            ['/path2','Two']
        ],
        "Test Links"
    );
});

