/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    // TODO: Check exceptions on bad use of the client side editor support JS API

    // Encoded objects from browser are back-tick encoded.
    var encoded = "A`211`V`0`16`Test news title`A`400`A`213`A`2501`V`0`24`Here are some notes.\nMore notes.";

    var news = O.object();
    news.appendType(TYPE["std:type:news"]);
    TEST.assert(!!(O.editor.decode(encoded, news)));

    TEST.assert(TYPE["std:type:news"] == news.firstType());
    TEST.assert_equal("Test news title", news.firstTitle().s());
    TEST.assert_equal("Here are some notes.\nMore notes.", news.first(ATTR["std:attribute:notes"]).s());

    // Encoded objects from the server are JSON encoded, but in a private format
    var encoded2 = O.editor.encode(news);
    var ejson = JSON.parse(encoded2);
    TEST.assert("v2" in ejson);
    var attrs = ejson.v2;
    var findAttr = function(desc) {
        var a = _.detect(attrs, function(a) { return a[0] == desc; });
        TEST.assert(!!a);
        var list = a[1];
        TEST.assert_equal(1, list.length);
        return list[0];
    };
    TEST.assert(_.isEqual([O.T_TEXT, QUAL["std:qualifier:null"], "Test news title"], findAttr(ATTR.Title)));
    TEST.assert(_.isEqual([O.T_TEXT_PARAGRAPH, QUAL["std:qualifier:null"], "Here are some notes.\nMore notes."], findAttr(ATTR["std:attribute:notes"])));

});
