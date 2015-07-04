/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


    P.respond("GET", "/do/plugin_test", [], function(E) {
        E.response.kind = (E.request.extraPathElements.length > 1) ? "html" : "text";
        E.response.body = "TEST RESPONSE ("+E.request.extraPathElements.join(',')+")";
    });

    P.respond("POST", "/do/plugin_test/body", [], function(E) {
        E.response.body = "!"+E.request.body+"!";
        E.response.kind = "text";
    });
    P.respond("POST", "/do/plugin_test/body2", [
        {body:"body", as:"string"}
    ], function(E, body) {
        E.response.body = "_"+body+"_";
        E.response.kind = "text";
    });

    P.respond("GET", "/do/plugin_test/with_layout", [], function(E) {
        E.response.body = "TEST PLUGIN";
        E.response.kind = "html";
        E.response.layout = "std:standard";
        E.response.pageTitle = "From JS Plugin <&escaped?>";
        E.response.setBackLink("/hello/backlink", "<BackLink>");
    });

    P.respond("GET,POST", "/do/plugin_test/param_out", [], function(E) {
        E.response.body = E.request.parameters[E.request.extraPathElements[0]];
        E.response.kind = "text";
    });

    P.respond("GET", "/do/plugin_test/remote_addr", [], function(E) {
        E.response.body = E.request.remote.protocol + ' ' + E.request.remote.address;
        E.response.kind = "text";
    });

    P.respond("GET", "/do/plugin_test/header_out", [], function(E) {
        E.response.body = JSON.stringify(E.request.headers[E.request.extraPathElements[0]]);
        E.response.kind = "text";
    });

    P.respond("GET", "/do/plugin_test/invalid_response", [], function(E) {
        E.response.body = {not: "text"};
        E.response.kind = "json";
    });
    var no_response_at_all_was_called = false;
    P.respond("GET", "/do/plugin_test/no_response_at_all", [], function(E) {
        no_response_at_all_was_called = true;
    });
    P.respond("GET", "/do/plugin_test/no_response_at_all_was_called", [], function(E) {
        E.response.kind = 'text';
        E.response.body = no_response_at_all_was_called ? 'yes' : 'no';
    });

    P.respond("GET", "/do/plugin_test/stop", [
        {pathElement:0, as:"string"}
    ], function(E, type) {
        E.render({"message": "hello"});
        switch(type) {
            case "dont_stop":
                return;
                break;
            case "simple":
                O.stop("Stopping request early");
                break;
            case "text":
                O.stop({"message": "Stop called", layout: false});
                break;
        }
        throw new Error("This should not be seen");
    });

    var simpleArgValidationTester = function(path, args) {
        P.respond("GET", path, args, function(E, value) {
            E.response.body = JSON.stringify({"value":value});
            E.response.kind = 'text';
        });
    };
    simpleArgValidationTester("/do/plugin_test/arg_test0", [{pathElement:0, as:"string", validate:/HELLO/}]);
    simpleArgValidationTester("/do/plugin_test/arg_test1", [{pathElement:0, as:"string", validate:function(v) { return v == 'HELLO'; }}]);
    simpleArgValidationTester("/do/plugin_test/arg_test2", [{pathElement:0, as:"int"}]);
    simpleArgValidationTester("/do/plugin_test/arg_test3", [{pathElement:0, as:"int", validate:function(v) { return v > 10 && v < 20; }}]);
    simpleArgValidationTester("/do/plugin_test/arg_test4", [{pathElement:0, as:"string"}]);
    simpleArgValidationTester("/do/plugin_test/arg_test5", [{pathElement:0, as:"json"}]);

    P.respond("GET", "/do/plugin_test/arg_test", [
        {pathElement:1, as:"string", validate:/HELLO/},
        {parameter:"a1", as:"int", validate:function(v) { return v > 0; }},
        {pathElement:2, as:"ref", optional:true},
        {parameter:"load", as:"object"},
    ], function(E, ping, number, ref, obj) {
        var r = (ref == null) ? 'none' : ref.objId;
        E.response.body = "P["+ping+"] N["+number+"/"+typeof(number)+"] R["+r+"] OT["+obj.first(211).toString()+"]";
        E.response.kind = "text";
    });

    P.respond("GET", "/do/plugin_test/render", [
        {pathElement:0, as:"object"}
    ], function(E, object) {
        E.response.body = JSON.stringify({
            urlpath:object.url(),
            url:object.url(true),
            rendered:object.render("linkedheading")
        });
        E.response.kind = "json";
    });

    P.respond("POST", "/do/plugin_test/template1", [
        {parameter:"random", as:"string"}
    ], function(E, random) {
        E.render({randomStuff:random, pageTitle:"TEST TITLE"}, "test1");
        // Make sure the template went in the right place
        if(this.$templates['test1'] == undefined || $registry.standardTemplates['test1'] != undefined) {
            throw new Error("TEMPLATE WENT IN WRONG PLACE");
        }
        // Make sure the template is associated with this plugin
        if(this.$templates['test1'].$plugin != this) {
            throw new Error("PLUGIN TEMPLATE ISN'T ASSOCIATED WITH THE PLUGIN");
        }
    });

    P.respond("POST", "/do/plugin_test/template2", [
        {parameter:"name", as:"string"}
    ], function(E, name) {
        E.render({name:name}, "dir/indir");
    });

    P.respond("GET", "/do/plugin_test/template_partial", [
    ], function(E) {
        E.render({num:42, partial1:{ping:"pong"}, partial2:{hello:"there"}}, "test_partial");
    });

    P.respond("GET", "/do/plugin_test/template_partial2", [
    ], function(E) {
        // Same output as above, checks that the Mustache.js hacking hasn't broken partials
        E.render({num:42, ping:"pong", hello:"there"}, "test_partial");
    });

    P.respond("GET", "/do/plugin_test/template_partial_in_dir", [
    ], function(E) {
        // Make sure that partials in directories work: {{>dir/template}}
        E.render({name:"ABC123"}, "test_partial_in_dir");
    });

    P.respond("GET", "/do/plugin_test/auto_template", [
    ], function(E) {
        E.render();
    });

    P.respond("GET", "/do/plugin_test/auto_template2", [
    ], function(E) {
        E.render({x:64});
    });

    P.respond("GET", "/do/plugin_test/std_template1", [
    ], function(E) {
        E.render({test:"hello"}, "std:test");
        // Make sure the template went in the right place
        if(this.$templates['std:test'] != undefined || $registry.standardTemplates['std:test'] == undefined) {
            throw new Error("TEMPLATE WENT IN WRONG PLACE");
        }
        // Make sure the standard template doesn't have a plugin
        if($registry.standardTemplates['std:test'].$plugin != null) {
            throw new Error("STANDARD TEMPLATE HAS A PLUGIN");
        }
    });

    P.respond("GET", "/do/plugin_test/std_template2", [
        {pathElement:0, as:"object"}
    ], function(E, object) {
        E.render({value:49, "std:test":{test:"second"}, object:object});
    });

    P.respond("GET", "/do/plugin_test/ruby_template1", [
    ], function(E) {
        var template = O.object();
        template.appendType(TYPE["std:type:intranet-page"]);
        template.appendTitle("!Object title!");
        var renderobject = O.object();
        renderobject.appendType(TYPE["std:type:book"]);
        renderobject.appendTitle("Random-book");
        E.render({templateObject:template, note:"Hello there", object:renderobject});
    });

    P.respond("GET", "/do/plugin_test/ruby_hb_helpers", [
        {pathElement:0, as:"object"}
    ], function(E, object) {
        E.render({
            obj1: object,
            obj2: object
        });
    });

    P.respond("GET", "/do/plugin_test/current_user", [
    ], function(E) {
        var u = O.currentUser;
        E.response.body = "USER "+u.id+" '"+u.name+"' '"+u.nameFirst+"' '"+u.nameLast+"' '"+u.email+"'";
        E.response.kind = "text";
    });

    P.respond("GET", "/do/plugin_test/current_user_has_permission_to_create_intranet_page", [
    ], function(E) {
        E.response.body = O.currentUser.canCreateObjectOfType(TYPE["std:type:intranet-page"]) ? "YES" : "NO";
        E.response.kind = "text";
    });

    P.respond("POST", "/do/plugin_test/db_store", [
        {parameter:"name", as:"string"}
    ], function(E, name) {
        var row = this.db.names.create({name:name});
        row.save();
        E.response.body = ""+row.id;
        E.response.kind = "text";
    });

    P.respond("GET", "/do/plugin_test/db_get", [
        {pathElement:0, as:"db", table:"names"}
    ], function(E, row) {
        E.response.body = row.name;
        E.response.kind = "text";
    });

    P.respond("GET", "/do/plugin_test/user_membership", [
        {pathElement:0, as:"int"},
        {pathElement:1, as:"int"}
    ], function(E, userId, groupId) {
        E.response.body = O.user(userId).isMemberOf(groupId) ? "YES" : "NO";
        E.response.kind = "text";
    });

    P.respond("GET", "/do/plugin_test/redirect", [
    ], function(E) {
        E.response.redirect("/pants");
    });

    P.respond("GET", "/do/plugin_test/headers", [
    ], function(E) {
        E.response.headers["X-Ping"] = 'Carrots';
        E.response.headers["X-Pong"] = 'Hello';
        E.response.body = "Something";
    });

    P.respond("GET", "/do/plugin_test/client_side_resources", [
    ], function(E) {
        E.response.useStaticResource("teststyle.css");
        E.response.useStaticResource("testscript.js");
        E.response.useStaticResource("testscript.js");  // check deduplication
        E.render({randomStuff:"ping", pageTitle:"TEST TITLE"}, "test1");
    });

    P.respond("GET", "/do/plugin_test/client_side_resources_templates", [
        {parameter:"testResourceHTML", as:"string", optional:true}
    ], function(E, testResourceHTML) {
        var view = {
            pageTitle:"Testing resources",
            "std:resources": {
                css: "/random/css/file",
                javascript: ["/random/javascript1.js", "/random/javascript2.js"]
            }
        };
        if(testResourceHTML) { view.layout = false; }
        E.render(view, "client_side_resources_templates" + (testResourceHTML ? '_html' : ''));
    });

    P.respond("GET", "/do/plugin_test/work_unit_defaults", [
        {pathElement:0, as:"int"}
    ], function(E, userId) {
        var w = O.work.create("plugin_test:Hello");
        if(w.workType == "plugin_test:Hello" && (w.createdBy.id == userId) && (w.actionableBy.id == userId) && (w.openedAt instanceof Date)) {
            E.response.body = "WORK UNIT HAS RIGHT DEFAULTS";
        } else {
            E.response.body = "FAILED";
        }
        E.response.kind = "text";
    });

    P.respond("GET", "/do/plugin_test/work_unit_simple", [
        {pathElement:0, as:"workUnit"}
    ], function(E, workUnit) {
        E.response.body = workUnit.id.toString();
    });

    P.respond("GET", "/do/plugin_test/work_unit_parameters", [
        {parameter: 'o', as:"workUnit"},
        {parameter: 'all', as:"workUnit", allUsers: true, optional: true},
        {parameter: 'type', as:"workUnit", workType: "plugin_test:unit", optional: true},
        {parameter: 'different', as:"workUnit", allUsers: true, workType: "plugin_test:different", optional: true}
    ], function(E, unit1, unit2, unit3, unit4) {
        function id(unit) {
            return (unit) ? unit.id : null;
        }
        E.response.body = JSON.stringify([id(unit1), id(unit2), id(unit3), id(unit4)]);
    });

    P.respond("GET", "/do/plugin_test/xls", [
        {pathElement:0, as:"string"}
    ], function(E, with_finish) {
        var xls = O.generate.table.xls("Excel Test"); // has character which will be filtered out
        xls.newSheet("Randomness");
        xls.cell("Hello").cell("There");
        // Add a cell with a ref to something which does't exist in a section which does
        //  - checks that it doesn't go bang when the obj can't be loaded
        xls.cell(O.ref(39854));
        if(with_finish == 'finish') {
            // Try with and without xls.finish() to make sure it's called automatically
            xls.finish();
        }
        E.response.body = xls;
        // Make sure a custom header appears
        E.response.headers["X-MadeStuff"] = 'yes';
    });

    P.respond("GET", "/do/plugin_test/css_rewrite", [
    ], function(E) {
        E.response.kind = 'text';
        E.response.headers['X-staticDirectoryUrl'] = this.staticDirectoryUrl;
        E.response.body = this.rewriteCSS("div {background: url(PLUGIN_STATIC_PATH/ping.png)} p {color:APPLICATION_COLOUR_MAIN}");
    });

    P.respond("GET", "/do/plugin_test/audit_table", [
        { parameter: "all", as: "string", optional: true }
    ], function(E, all) {
        var query = O.audit.query().displayable(null);
        var data;
        function getData() {
            data = query.table.apply(query, E.request.extraPathElements);
        }
        if(all) {
            O.impersonating(O.SYSTEM, getData);
        } else {
            getData();
        }
        E.response.body = data;
    });

    P.respond("GET", "/do/plugin_test/special_arguments_to_templates", [
        {pathElement:"0", as:"string"}
    ], function(E, specialType) {
        var testObject = null;
        if(specialType == 'undefined') {
            var emptyObject = {};
            testObject = emptyObject.missing;
        }
        E.response.kind = 'text';
        var t1 = this.template('std:link_to_object');
        var t2 = this.template('std:link_to_object_descriptive');
        E.response.body = t1.render({object:testObject})+' '+t2.render({});
    });

    P.respond("GET", "/do/plugin_test/compare_link_to_object", [
        {pathElement:"0", as:"ref"}
    ], function(E, ref) {
        E.response.kind = 'text';
        for(var templateName in {"std:link_to_object": 1, "std:link_to_object_descriptive": 1, "std:object": 1}) {
            var template = this.template(templateName);
            var ref_body = template.render({object: ref});
            var object_body = template.render({object: ref.load()});
            if(ref_body != object_body) {
                E.response.statusCode = 500;
                E.response.body = templateName + ": '" + ref_body + "' != '" + object_body + "'";
                return;
            }
        }
        E.response.body = "OK";
    });

    P.respond("GET", "/do/plugin_test/expiry", [
        {pathElement:0, as:"int"}
    ], function(E, seconds) {
        E.response.kind = 'text';
        E.response.setExpiry(seconds);
        E.response.body = "s="+seconds;
    });

    P.respond("POST", "/do/plugin_test/optional_file_upload", [
        {parameter:"testfile", as:"file", optional:true}
    ], function(E, file) {
        E.response.kind = 'text';
        E.response.body = (file === null) ? 'no file' : ((file instanceof $UploadedFile) ? 'have file' : 'other type found');
    });

    P.respond("POST", "/do/plugin_test/file_upload", [
        {parameter:"testfile", as:"file"}
    ], function(E, file) {
        // Create a new store file from it
        var storedFile = O.file(file);
        if(storedFile !== O.file(file)) { throw new Error("Doesn't return same file twice."); }
        // Make object
        var o = O.object();
        o.appendType(TYPE["std:type:file"]);
        o.appendTitle("Test file");
        o.append(storedFile.identifier(), ATTR["std:attribute:file"]);
        o.save();
        // Return info from request
        E.response.kind = 'json';
        E.response.body = JSON.stringify({filename:file.filename, mimeType:file.mimeType, digest:file.digest, fileSize:file.fileSize, ref:o.ref.toString()});
    });

    P.respond("GET", "/do/plugin_test/get_stored_file_by_digest", [
        {parameter:"digest", as:"string"}
    ], function(E, digest) {
        E.response.body = O.file(digest);
    });

    P.respond("POST", "/do/plugin_test/file_upload_readasstring", [
        {parameter:"file", as:"file"}
    ], function(E, file) {
        E.response.kind = 'text';
        E.response.body = file.readAsString('UTF-8');
    });

    P.respond("POST", "/do/plugin_test/file_identifier_text", [
        {parameter:"r", as:"object"},
        {parameter:"f", as:"string"},
        {parameter:"i", as:"string"}
    ], function(E, object, functionName, json) {
        var id = object.first(ATTR["std:attribute:file"]);
        var apiObject = O.file(id);
        var r = '-';
        if(json == "null") {
            r = apiObject[functionName]();
        } else {
            r = apiObject[functionName](JSON.parse(json));
        }
        E.response.kind = 'text';
        E.response.body = r;
    });

    P.respond("GET", "/do/plugin_test/test_string_encoding", [
        {parameter:"output", as:"string", optional: true},
    ], function(E, out_type) {
        var output = [];
        // Based on: http://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt
        var badStrings = [
            "Hello World", "κόσμε", "£10/€20", "\u0080", "\u8000", "\u0800",
            "\u0001\u0000", "\u0100\u0000", "\u0020\u0000", "\u2000\u0000",
            "\u0400\u0000", "\u0004\u0000", "\u007F", "\u7F00", "\u07FF",
            "\uFF07", "\uFFFF", "\u001F\uFFFF", "\u1F00\uFFFF", "\u00FF", "\u00FF",
            "\uFFFF\uFFFF", "Before\u0000After"
        ];
        var objects = [];

        O.impersonating(O.SYSTEM, function() {
            _.each(badStrings, function(bad) {
                // Create an object..
                var object = O.object();
                object.append(TYPE["std:type:book"], ATTR.Type);
                object.append(bad, ATTR.Title);
                object.save();
                objects.push(object.ref);
                // Write an audit entry
                var badData = {};
                badData[bad] = bad;
                O.audit.write({
                    auditEntryType: "example:bad_string",
                    data: badData
                });
            });

            _.each(_.zip(objects, badStrings), function(pair) {
                var new_object = O.ref(pair[0]).load();
                var expected_title = pair[1];
                if (expected_title != new_object.firstTitle().toString()) {
                    output.push("Object title of '" + new_object.firstTitle() + "' doesn't match expected '" + expected_title + "'");
                }
            });

            var query = O.audit.query().displayable(null).auditEntryType("example:bad_string").sortBy("creationDate_asc");
            if(query.length !== badStrings.length) {
                output.push("Audit entry count doesn't match bad string length: " + query.length);
            }
            _.each(_.zip(query, badStrings), function(pair) {
                    var entry = pair[0];
                    var expected_string = pair[1];
                    if(entry.data[expected_string] !== expected_string){
                        output.push("Audit entry data " + entry.data + " doesn't match '" + expected_string + "'");
                    }
                }
            );
            if(out_type == "table") {
                E.response.body = query.table("auditEntryType", "data");
            }
        });

        if(out_type != "table") {
            _.each(badStrings, function(string) { output.push(string); });
            E.response.body = output.join("\n");
        }
    });

    P.respond("GET", "/do/plugin_test/object_title_encoding", [
        {pathElement: 0, as: "string"}
    ], function(E, ob_ref) {
        var expected = "£45/€55 - κόσμε ಮಣ್ಣಾಗಿ";
        O.impersonating(O.SYSTEM, function() {
            var object = O.ref(ob_ref).load();
            var title = object.firstTitle().toString();
            E.response.body = ((title == expected) ? "PASS"  : "FAIL") + " " + title;
        });
    });

    P.respond("GET", "/do/plugin_test/layouts", [
        {parameter:"layout", as:"string"},
        {parameter:"value", as:"string"}
    ], function(E, layout, value) {
        if(layout == "false") { layout = false; }
        if(layout == "undefined") { layout = undefined; }
        E.render({layout:layout, value:value});
    });

    P.respond("GET", "/do/plugin_test/session_set", [
        {pathElement:0, as:"string"},
        {pathElement:1, as:"string"}
    ], function(E, key, value) {
        O.session[key] = value;
        E.response.body = 'SET'; E.response.kind = 'text';
    });
    P.respond("GET", "/do/plugin_test/session_get", [
        {pathElement:0, as:"string"}
    ], function(E, key) {
        E.response.body = JSON.stringify(O.session[key]) || 'undefined'; E.response.kind = 'text';
    });

    P.respond("GET", "/do/plugin_test/tray_get", [
    ], function(E) {
        E.response.body = _.map(O.tray, function(r) {
            return O.isRef(r) ? r.toString() : 'NOT_REF';
        }).join(',');
        E.response.kind = 'text';
    });

    P.respond("GET", "/do/plugin_test/hbhelper1", [
    ], function(E) {
        // Template uses plugin global helper function
        E.render({layout:false});
    });

    P.respond("GET", "/do/plugin_test/hbhelper2", [
    ], function(E) {
        // Template uses plugin global helper function & request local helper function
        var helpers = {viewhelper: function(v) { return 'X-'+v; }};
        E.render({layout:false}, {helpers:helpers}); // implicit template name
    });

    P.respond("GET", "/do/plugin_test/hbhelper3", [
    ], function(E) {
        // Template uses plugin global helper function & request local helper function
        var helpers = {viewhelper: function(v) { return 'Y-'+v; }};
        E.render({layout:false}, "hbhelper2", {helpers:helpers}); // explicit template name
    });

    P.respond("GET", "/do/plugin_test/render_into_sidebar", [
    ], function(E) {
        // Do two renders to make sure they both get output, one of which uses a helper to do the outputting
        E.renderIntoSidebar({text:"Sidebar One"}, "sidebar");
        E.renderIntoSidebar(undefined, "sidebar", {helpers:{text:function() { return 'Second Sidebar'; }}});
        E.appendSidebarHTML('<div class="test_sidebar">AS HTML</div>');
        // Render the normal way
        E.render({}, "test1");
    });

    // This checks a bug has been fixed
    P.respond("GET", "/do/plugin_test/test_std_template_with_hook_during_request", [
    ], function(E) {
        var o = O.object(4);
        o.appendType(TYPE["std:type:book"]);
        o.appendTitle("TEST BOOK");
        o.save();   // calls hPostObjectChange
        var body = this.template('std:object').render({object:o,style:"linkedheading"});    // exception!
        body += O.isHandlingRequest ? ' IN_REQUEST' : ' NO_REQUEST';
        E.response.body = body; E.response.kind = 'text';
    });
    P.hook('hPostObjectChange', function() {});   // make sure there's a hook function for the hook we want to be called

    P.respond("GET", "/do/plugin_test/std_ui_confirm", [
    ], function(E) {
        E.render({
            pageTitle: "Example UI confirmation",
            backLink: "/do/cancelled",
            backLinkText: "Cancel button>",
            text: "P1\nP2",
            options: [
                {
                    action: "/do/option1",
                    label: "First option",
                    parameters: {"a<>": "<b>", c: "d"}
                },
                {
                    action: "/do/option-two",
                    label: "<Option two>"
                }
            ]
        }, "std:ui:confirm");
    });

    P.respond("GET", "/do/plugin_test/std_ui_choose", [
    ], function(E) {
        E.render({
            pageTitle: "Example UI choice",
            options: [
                {
                    action: "/do/option1",
                    label: "First option",
                    notes: "Hello notes"
                },
                {
                    action: "/do/option-two",
                    label: "<Option two>",
                    highlight: true
                }
            ]
        }, "std:ui:choose");
    });

    P.respond("GET", "/do/plugin_test/std_search_results", [
    ], function(E) {
        E.render({
            pageTitle: "Test search results",
            query: "type:book"
        }, "std:search_results");
    });
