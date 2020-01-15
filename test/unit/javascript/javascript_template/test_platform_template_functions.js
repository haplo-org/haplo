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
    TEST.assert(-1 != objectRendered.indexOf('/test-book-">Test book&lt;</a>'));
    TEST.assert_exceptions(function() {
        new $HaploTemplate('<div data-value=std:object(o)></div>').render({o:object});
    }, "When rendering template 'undefined': std:object() can only be used in TEXT context");
    var refRendered = template.render({o:objectRef});
    TEST.assert(refRendered.match(/class="?z__linked_heading"?/)); // cope with minimisation

    // std:object:link() & std:object:link:descriptive()
    template = new $HaploTemplate('<div> std:object:link(o) " ! " std:object:link:descriptive(o) </div>');
    var objectLinksRendered = template.render({o:object}).replace(/\/[0-9qvwxyz]+\//g,'/REF/');
    TEST.assert_equal(objectLinksRendered, '<div><a href="/REF/test-book-">Test book&lt;</a> ! <a href="/REF/test-book-">Test book&lt;</a></div>');
    // And with refs instead
    var refLinksRendered = template.render({o:objectRef}).replace(/\/[0-9qvwxyz]+\//g,'/REF/');
    TEST.assert_equal(refLinksRendered, '<div><a href="/REF/test-book-">Test book&lt;</a> ! <a href="/REF/test-book-">Test book&lt;</a></div>');

    // std:object:title() & std:object:title:shortest() (can be used anywhere)
    template = new $HaploTemplate('<div> <p data-x=std:object:title(x)> std:object:title:shortest(x) </p> </div>');
    var objectTitlesRendered = template.render({x:object}).replace(/\/[0-9qvwxyz]+\//g,'/REF/').replace(/www\d\d+/g,'wwwAPP');
    TEST.assert_equal(objectTitlesRendered, '<div><p data-x="Test book&lt;">TB&amp;</p></div>');
    var objectTitlesRendered2 = template.render({x:objectRef}).replace(/\/[0-9qvwxyz]+\//g,'/REF/').replace(/www\d\d+/g,'wwwAPP');
    TEST.assert_equal(objectTitlesRendered2, '<div><p data-x="Test book&lt;">TB&amp;</p></div>');

    // std:object:url*()
    template = new $HaploTemplate('<div> <a href=std:object:url(x)> "hello" </a> " / " <a href=std:object:url:full(x)> "world" </a> </div>');
    var objectUrlsRendered = template.render({x:object}).replace(/\/[0-9qvwxyz]+\//g,'/REF/').replace(/www\d\d+/g,'wwwAPP').replace(/\:\d+\b/,'');
    TEST.assert_equal(objectUrlsRendered, '<div><a href="/REF/test-book-">hello</a> / <a href="http://wwwAPP.example.com/REF/test-book-">world</a></div>');
    template = new $HaploTemplate('backLink(std:object:url(q))');
    // Check you can use it in backLink()
    var objectUrlBackLinkView = {q:object};
    template.render(objectUrlBackLinkView);
    TEST.assert_equal(objectUrlBackLinkView.backLink, object.url());

    // std:file*()
    var file = O.file(PDF_DIGEST);
    template = new $HaploTemplate('<div> std:file(f) </div>');
    var fileRendered = template.render({f:file});
    TEST.assert_equal(fileRendered, '<div><table class="z__file_display"><tr class="z__file_display_r1"><td class="z__file_display_icon"><div class="z__thumbnail"><a href="/file/977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac/8457/example_3page.pdf"><img src="/_t/977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac/8457" width="45" height="64" alt=""></a></div></td><td class="z__file_display_name"><a href="/file/977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac/8457/example_3page.pdf">example_3page.pdf</a></td></tr></table></div>');
    var fileIdentifier = file.identifier().mutableCopy();
    fileIdentifier.filename = 'TEST_modified_name.pdf'
    fileRendered = template.render({f:fileIdentifier});
    TEST.assert_equal(fileRendered, '<div><table class="z__file_display"><tr class="z__file_display_r1"><td class="z__file_display_icon"><div class="z__thumbnail"><a href="/file/977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac/8457/example_3page.pdf"><img src="/_t/977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac/8457" width="45" height="64" alt=""></a></div></td><td class="z__file_display_name"><a href="/file/977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac/8457/example_3page.pdf">TEST_modified_name.pdf</a></td></tr></table></div>');
    template = new $HaploTemplate('<div> std:file:thumbnail(f) </div>');
    fileRendered = template.render({f:file});
    TEST.assert_equal(fileRendered, '<div><div class="z__thumbnail"><a href="/file/977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac/8457/example_3page.pdf"><img src="/_t/977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac/8457" width="45" height="64" alt=""></a></div></div>');
    fileRendered = template.render({f:fileIdentifier});
    TEST.assert_equal(fileRendered, '<div><div class="z__thumbnail"><a href="/file/977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac/8457/example_3page.pdf"><img src="/_t/977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac/8457" width="45" height="64" alt=""></a></div></div>');
    template = new $HaploTemplate('<div> std:file:link(f) </div>');
    fileRendered = template.render({f:file});
    TEST.assert_equal(fileRendered, '<div><a href="/file/977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac/8457/example_3page.pdf">example_3page.pdf</a></div>');
    fileRendered = template.render({f:fileIdentifier});
    TEST.assert_equal(fileRendered, '<div><a href="/file/977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac/8457/example_3page.pdf">TEST_modified_name.pdf</a></div>');
    template = new $HaploTemplate('<div> std:file:transform(f "w100/jpeg") </div>');
    fileRendered = template.render({f:file});
    TEST.assert_equal(fileRendered, '<div><table class="z__file_display"><tr class="z__file_display_r1"><td class="z__file_display_icon"><div class="z__thumbnail"><a href="/file/977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac/8457/w100/jpeg/example_3page.pdf"><img src="/_t/977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac/8457" width="45" height="64" alt=""></a></div></td><td class="z__file_display_name"><a href="/file/977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac/8457/w100/jpeg/example_3page.pdf">example_3page.pdf</a></td></tr></table></div>');
    // With all the options...
    template = new $HaploTemplate('<div> std:file(f "asFullURL" "authenticationSignature" "forceDownload") </div>');
    fileRendered = template.render({f:file});
    TEST.assert(/www\d+\.example\.com/.test(fileRendered));  // asFullURL
    TEST.assert(/\?s=[a-f0-9]+"/.test(fileRendered));  // authenticationSignature
    TEST.assert(/attachment=1/.test(fileRendered));  // forceDownload
    // With static signature
    template = new $HaploTemplate('<div> std:file(f "authenticationSignatureValidForSeconds") </div>');
    fileRendered = template.render({f:file});
    TEST.assert(/\?s=[a-f0-9]+,\d+,\d+"/.test(fileRendered));  // authenticationSignature
    // Unknown options exception
    template = new $HaploTemplate('<div> std:file(f "asFullURL" "UNKNOWN" "forceDownload") </div>');
    TEST.assert_exceptions(function() {
        template.render({f:file});
    }, "Unknown option for file template function: UNKNOWN");
    // Non-file objects exception
    template = new $HaploTemplate('<div> std:file(f) </div>');
    TEST.assert_exceptions(function() {
        template.render({f:"a nice string"});
    }, "Bad type of object passed to file template function");
    // But undefined and null just output nothing
    TEST.assert_equal(template.render({}), "<div></div>");
    TEST.assert_equal(template.render({f:null}), "<div></div>");

    // std:file*:with-link-url()
    var file = O.file(PDF_DIGEST);
    template = new $HaploTemplate('<div> std:file:with-link-url(f "/test") </div>');
    var fileRendered = template.render({f:file});
    TEST.assert_equal(fileRendered, '<div><table class="z__file_display"><tr class="z__file_display_r1"><td class="z__file_display_icon"><div class="z__thumbnail"><a href="/test"><img src="/_t/977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac/8457" width="45" height="64" alt=""></a></div></td><td class="z__file_display_name"><a href="/test">example_3page.pdf</a></td></tr></table></div>');
    var fileIdentifier = file.identifier().mutableCopy();
    fileIdentifier.filename = 'TEST_modified_name.pdf'
    fileRendered = template.render({f:fileIdentifier});
    TEST.assert_equal(fileRendered, '<div><table class="z__file_display"><tr class="z__file_display_r1"><td class="z__file_display_icon"><div class="z__thumbnail"><a href="/test"><img src="/_t/977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac/8457" width="45" height="64" alt=""></a></div></td><td class="z__file_display_name"><a href="/test">TEST_modified_name.pdf</a></td></tr></table></div>');
    template = new $HaploTemplate('<div> std:file:thumbnail:with-link-url(f "/test") </div>');
    fileRendered = template.render({f:file});
    TEST.assert_equal(fileRendered, '<div><div class="z__thumbnail"><a href="/test"><img src="/_t/977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac/8457" width="45" height="64" alt=""></a></div></div>');
    fileRendered = template.render({f:fileIdentifier});
    TEST.assert_equal(fileRendered, '<div><div class="z__thumbnail"><a href="/test"><img src="/_t/977ff9a79dfb38cbac1a3d5994962b9632a4589f021308f35f2c408aa796fdac/8457" width="45" height="64" alt=""></a></div></div>');
    // With valid options. "forceDownload" and "asFullURL" will be silently ignored
    template = new $HaploTemplate('<div> std:file:with-link-url(f "/test" "asFullURL" "authenticationSignature" "forceDownload") </div>');
    fileRendered = template.render({f:file});
    TEST.assert(/\?s=[a-f0-9]+/.test(fileRendered));  // authenticationSignature
    // Unknown options exception
    template = new $HaploTemplate('<div> std:file:with-link-url(f "asFullURL" "UNKNOWN" "forceDownload") </div>');
    TEST.assert_exceptions(function() {
        template.render({f:file});
    }, "Unknown option for file template function: UNKNOWN");
    // Non-file objects exception
    template = new $HaploTemplate('<div> std:file:with-link-url(f "/test") </div>');
    TEST.assert_exceptions(function() {
        template.render({f:"a nice string"});
    }, "Bad type of object passed to file template function");
    // Non-string links exception (including falsey urls)
    template = new $HaploTemplate('<div> std:file:with-link-url(f url) </div>');
    TEST.assert_exceptions(function() {
        template.render({
            f:file,
            url: { t: "This is an object:" }
        });
    }, "Bad url passed to file-with-link template function");
    TEST.assert_exceptions(function() {
        template.render({
            f:file,
            url: null
        });
    }, "Bad url passed to file-with-link template function");
    // But undefined and null files just output nothing
    TEST.assert_equal(template.render({}), "<div></div>");
    TEST.assert_equal(template.render({f:null, url: { t: "This is an object" }}), "<div></div>");

    // std:text:paragraph
    template = new $HaploTemplate('"START" std:text:paragraph(text) "END"');
    TEST.assert_equal(template.render({text:"a"}), "START<p>a</p>END");
    TEST.assert_equal(template.render({text:" \n\n\r a b \n\n\n b c d e \n\n\n\n"}), "START<p>a b</p><p>b c d e</p>END");
    TEST.assert_equal(template.render({text:"hello\n <a>\nthere & x \n"}), "START<p>hello</p><p>&lt;a&gt;</p><p>there &amp; x</p>END");

    // std:text:document / std:text:document:widgets
    template = new $HaploTemplate('"START" std:text:document(doc) "END"');
    TEST.assert_equal(template.render({doc:'<doc><p>a<b>b</b>c</p><h1>x</h1></doc>'}), 'START<p>a<b>b</b>c</p><h1>x</h1>END');
    TEST.assert_equal(template.render({doc:O.text(O.T_TEXT_DOCUMENT, '<doc><p>a<b>b</b>c</p><h1>x2</h1></doc>')}), 'START<p>a<b>b</b>c</p><h1>x2</h1>END');
    template = new $HaploTemplate('"START" std:text:document:widgets(doc) "END"');
    TEST.assert_equal(template.render({doc:'<doc><p>a<b>b</b>c</p><h1>x3</h1></doc>'}), 'START<div class="z__document"><p>a<b>b</b>c</p><h1>x3</h1></div>END');
    TEST.assert_equal(template.render({doc:O.text(O.T_TEXT_DOCUMENT, '<doc><p>a<b>b</b>c</p><h1>x4</h1></doc>')}), 'START<div class="z__document"><p>a<b>b</b>c</p><h1>x4</h1></div>END');

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
    // Test arrows and empty URLs, as it's a useful way of doing navigation with minimal templates
    template = new $HaploTemplate('<div> std:ui:navigation:arrow("left" url(?year=year)) </div>');
    TEST.assert_equal(template.render({}), '<div><span class="z__plugin_ui_nav_arrow">&#xE016;</span></div>');
    TEST.assert_equal(template.render({year:null}), '<div><span class="z__plugin_ui_nav_arrow">&#xE016;</span></div>');
    TEST.assert_equal(template.render({year:"2016"}), '<div><a class="z__plugin_ui_nav_arrow" href="?year=2016">&#xE016;</a></div>');

    // std:ui:button-link (with auto-urling)
    template = new $HaploTemplate('<div> std:ui:button-link("/abc" ? def="345" x=y) { "Hello " <span> "world" </span> } </div>');
    TEST.assert_equal(template.render({y:"ping"}), '<div><a role="button" class="z__button_link" href="/abc?def=345&x=ping">Hello <span>world</span></a></div>');
    template = new $HaploTemplate('<div> std:ui:button-link("/abc" ? def="345" x=y z="x") </div>');
    TEST.assert_equal(template.render({y:"ping"}), '<div><a role="button" class="z__button_link" href="/abc?def=345&x=ping&z=x"></a></div>');
    template = new $HaploTemplate('<div> std:ui:button-link:active("/abc" ? def="xyz" x=y z="x") { "Active" } </div>');
    TEST.assert_equal(template.render({y:"ping"}), '<div><a role="button" aria-pressed="true" class="z__button_link z__button_link_active" href="/abc?def=xyz&x=ping&z=x">Active</a></div>');
    template = new $HaploTemplate('<div> std:ui:button-link:disabled() { "Disabled text" } </div>');
    TEST.assert_equal(template.render({}), '<div><span role="button" aria-disabled="true" class="z__button_link_disabled">Disabled text</span></div>');

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

    // pageTitle
    template = new $HaploTemplate('pageTitle("test " value) <div> </div>');
    var pageTitleView = {value:"abc"};
    TEST.assert_equal(template.render(pageTitleView), "<div></div>");
    TEST.assert_equal("test abc", pageTitleView.pageTitle);

    // emailSubject
    template = new $HaploTemplate('emailSubject("subject " value) <div> </div>');
    var emailSubjectView = {value:"xyz"};
    TEST.assert_equal(template.render(emailSubjectView), "<div></div>");
    TEST.assert_equal("subject xyz", emailSubjectView.emailSubject);

    // backLink
    template = new $HaploTemplate('backLink("/abc" ? x=value) { "text " name } <div> </div>');
    var backLinkView = {value:"pqz", name:"T1"};
    TEST.assert_equal(template.render(backLinkView), "<div></div>");
    TEST.assert_equal("/abc?x=pqz", backLinkView.backLink);
    TEST.assert_equal("text T1", backLinkView.backLinkText);
});
