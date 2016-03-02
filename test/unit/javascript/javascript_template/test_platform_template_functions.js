/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

// DEPLOYMENT TESTS: needs html quote minimisation

TEST(function() {
    var template;

    // std:form_csrf_token()
    template = new $HaploTemplate("<div> std:form:token() </div>");
    TEST.assert_equal(0, template.render({}).indexOf('<div><input type="hidden" name="__" value="'));
    TEST.assert_exceptions(function() {
        new $HaploTemplate('<div data-value=std:form:token()></div>').render({f:instance});
    }, "When rendering template 'undefined': std:form:token() can only be used in TEXT context");

    // std:form() + std:document()
    $registry.pluginLoadFinished = false;
    var plugin = new $Plugin();
    var form = plugin.form({
        "specificationVersion": 0, "formId": "test-form-id", "formTitle": "Test",
        "elements": [{type:"text", label:"Test text", path:"test"}]
    });
    var instance = form.instance({test:"HELLO"});
    template = new $HaploTemplate("<div> std:form(form) </div>");
    var formRendered = template.render({form:instance});
    TEST.assert(-1 != formRendered.indexOf('<div class="oform" id="test-form-id"')); // missing last > to avoid minimisation
    TEST.assert(-1 != formRendered.indexOf('Test text'));
    TEST.assert(-1 != formRendered.indexOf('HELLO'));
    template = new $HaploTemplate("<div> std:document(doc) </div>");
    var documentRendered = template.render({doc:instance});
    TEST.assert(-1 != documentRendered.indexOf('Test text'));
    TEST.assert(-1 != documentRendered.indexOf('HELLO'));
    TEST.assert_exceptions(function() {
        new $HaploTemplate('<div data-value=std:form(f)></div>').render({f:instance});
    }, "When rendering template 'undefined': std:form() can only be used in TEXT context");
    TEST.assert_exceptions(function() {
        new $HaploTemplate('<div data-value=std:document(f)></div>').render({f:instance});
    }, "When rendering template 'undefined': std:document() can only be used in TEXT context");

    // std:object()
    var objectRef = O.ref(TEST_BOOK);
    var object = objectRef.load();
    template = new $HaploTemplate('<div> std:object(o "linkedheading") </div>');
    var objectRendered = template.render({o:object});
    TEST.assert(objectRendered.match(/class="?z__linked_heading"?/)); // cope with minimisation
    TEST.assert(-1 != objectRendered.indexOf('class="z__icon z__icon_small"'));
    TEST.assert(-1 != objectRendered.indexOf('/test-book">Test book</a>'));
    TEST.assert_exceptions(function() {
        new $HaploTemplate('<div data-value=std:object(o)></div>').render({o:object});
    }, "When rendering template 'undefined': std:object() can only be used in TEXT context");
    var refRendered = template.render({o:objectRef});
    TEST.assert(refRendered.match(/class="?z__linked_heading"?/)); // cope with minimisation

    // std:object:link() & std:object:link:descriptive()
    template = new $HaploTemplate('<div> std:object:link(o) " ! " std:object:link:descriptive(o) </div>');
    var objectLinksRendered = template.render({o:object}).replace(/\/[0-9qvwxyz]+\//g,'/REF/');
    TEST.assert_equal(objectLinksRendered, '<div><a href="/REF/test-book">Test book</a> ! <a href="/REF/test-book">Test book</a></div>');
    // And with refs instead
    var refLinksRendered = template.render({o:objectRef}).replace(/\/[0-9qvwxyz]+\//g,'/REF/');
    TEST.assert_equal(refLinksRendered, '<div><a href="/REF/test-book">Test book</a> ! <a href="/REF/test-book">Test book</a></div>');

    // std:object:url*()
    template = new $HaploTemplate('<div> <a href=std:object:url(x)> "hello" </a> " / " <a href=std:object:url:full(x)> "world" </a> </div>');
    var objectUrlsRendered = template.render({x:object}).replace(/\/[0-9qvwxyz]+\//g,'/REF/').replace(/www\d\d+/g,'wwwAPP').replace(/\:\d+\b/,'');
    TEST.assert_equal(objectUrlsRendered, '<div><a href="/REF/test-book">hello</a> / <a href="http://wwwAPP.example.com/REF/test-book">world</a></div>');
    template = new $HaploTemplate('backLink(std:object:url(q))');
    // Check you can use it in backLink()
    var objectUrlBackLinkView = {q:object};
    template.render(objectUrlBackLinkView);
    TEST.assert_equal(objectUrlBackLinkView.backLink, object.url());

    // std:text:paragraph
    template = new $HaploTemplate('"START" std:text:paragraph(text) "END"');
    TEST.assert_equal(template.render({text:"a"}), "START<p>a</p>END");
    TEST.assert_equal(template.render({text:" \n\n\r a b \n\n\n b c d e \n\n\n\n"}), "START<p>a b</p><p>b c d e</p>END");
    TEST.assert_equal(template.render({text:"hello\n <a>\nthere & x \n"}), "START<p>hello</p><p>&lt;a&gt;</p><p>there &amp; x</p>END");

    // std:text:document
    template = new $HaploTemplate('"START" std:text:document(doc) "END"');
    TEST.assert_equal(template.render({doc:'<doc><p>a<b>b</b>c</p><h1>x</h1></doc>'}), 'START<div class="z__document"><p>a<b>b</b>c</p><h1>x</h1></div>END');

    // std:ui:notice
    template = new $HaploTemplate('<div> std:ui:notice(a b c) </div>');
    TEST.assert(-1 != template.render({a:"Test Message"}).indexOf("Test Message"));
    TEST.assert(-1 != template.render({a:"M", b:"/abc"}).indexOf("/abc"));
    TEST.assert(-1 != template.render({a:"M", b:"/abc", c:"D.Link"}).indexOf("D.Link"));

    // std:ui:navigation:arrow
    template = new $HaploTemplate('<div> std:ui:navigation:arrow(d l) </div>');
    TEST.assert_equal(template.render({d:"left",l:"/abc<"}), '<div><a class="z__plugin_ui_nav_arrow" href="/abc%3C">&#xE016;</a></div>');
    TEST.assert_equal(template.render({d:"right",l:"/ping"}), '<div><a class="z__plugin_ui_nav_arrow" href="/ping">&#xE005;</a></div>');
    TEST.assert_equal(template.render({d:"left"}), '<div><span class="z__plugin_ui_nav_arrow">&#xE016;</span></div>');

    // std:icon:*
    template = new $HaploTemplate('<div> std:icon:type(type "large") " ! " std:icon:object(ref "medium") " ! " std:icon:object(obj "small") " ! " std:icon:description(desc "medium") </div>');
    TEST.assert_equal(template.render({
        type: TYPE["std:type:book"],
        ref: objectRef,
        obj: object,
        desc: "E210,1,f E505,5,b"
    }), '<div><span class="z__icon z__icon_large"><span class="z__icon_colour1 z__icon_component_position_full">&#xE210;</span></span> ! <span class="z__icon z__icon_medium"><span class="z__icon_colour1 z__icon_component_position_full">&#xE210;</span></span> ! <span class="z__icon z__icon_small"><span class="z__icon_colour1 z__icon_component_position_full">&#xE210;</span></span> ! <span class="z__icon z__icon_medium"><span class="z__icon_colour1 z__icon_component_position_full">&#xE210;</span><span class="z__icon_colour5 z__icon_component_position_top_right">&#xE505;</span></span></div>');

    // std:date* and std:utc:date*
    var dateToFormat = new Date(2016, 6, 3, 23, 12);  // in the summer so default Europe/London time zone is in BST
    O.impersonating(O.user(41), function() { // to get a timezone
        [
            ["std:date",            "04 Jul 2016",          dateToFormat],
            ["std:date:long",       "04 July 2016",         dateToFormat],
            ["std:date:time",       "04 Jul 2016, 00:12",   dateToFormat],
            ["std:utc:date",        "03 Jul 2016",          dateToFormat],
            ["std:utc:date:long",   "03 July 2016",         dateToFormat],
            ["std:utc:date:time",   "03 Jul 2016, 23:12",   dateToFormat],
            ["std:utc:date:sort",   "201607032312",         dateToFormat],
            // Check bad values just result in empty strings
            ["std:date",            "",                     undefined],
            ["std:date",            "",                     true],
            ["std:date",            "",                     false],
            ["std:date",            "",                     "Pants"],
            ["std:date",            "",                     []],
            // Check library dates
            ["std:utc:date",        "06 Mar 2015",          new XDate(2015, 2, 6, 12, 34)],
            ["std:utc:date",        "05 Apr 2010",          moment([2010, 3, 5, 15, 10, 3])]
        ].forEach(function(t) {
            var fnname = t[0], expected = t[1], date = t[2];
            var datetemplate = new $HaploTemplate('<span> '+fnname+'(x) </span>');
            TEST.assert_equal(datetemplate.render({x:date}), '<span>'+expected+'</span>');
        });
    });
});
