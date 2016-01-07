/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.hook('hTestNullOperation1', function(response) {
    $host._testCallback("hTestNullOperation1");
});

P.onInstallCallCount = 0;
P.onInstall = function() {
    test_plugin.data.currentUserOnInstall = O.currentUser.id;
    this.onInstallCallCount = this.onInstallCallCount + 1;
};
P.onLoadCallCount = 0;
P.onLoad = function() {
    test_plugin.data.currentUserOnLoad = O.currentUser.id;
    this.onLoadCallCount = this.onLoadCallCount + 1;
};
P.hook('hTestOnLoadAndOnInstall', function(response) {
    response.onInstallCallCount = this.onInstallCallCount;
    response.onLoadCallCount = this.onLoadCallCount;
});

P.hook('hTestHook', function(response, inputValue1, object) {
    var x, o;
    if(inputValue1 == "test-1") {
        x = "null:";
        if(response.testString == null) { x += " string"; }
        if(response.testSymbol == null) { x += " symbol"; }
        if(response.testBool == null) { x += " bool"; }
        if(response.testObject == null) { x += " object"; }
        if(response.testArray == null) { x += " array"; }
        if(response.testHash == null) { x += " hash"; }
        if(object == null) { x += " object-arg"; }
        response.testString = x;
    } else if(inputValue1 == "test-2") {
        x = "has-correct-value:";
        if(response.testString == "Carrots") { x += " string"; }
        if(response.testSymbol == "parsnips") { x += " symbol"; }
        if(response.testBool == false) { x += " bool"; }
        o = response.testObject;
        if(o.first(76).toString() == "Ping2") { x += " object"; }
        if(_.isEqual([1, 4, 6, 7], response.testArray)) { x += " array"; }
        if(_.isEqual({a:"b",c:4}, response.testHash)) { x += " hash"; }
        response.testArray = null;
        response.testHash = null;
        response.testString = x;
    } else if(inputValue1 == "test-3") {
        response.doesNotExist = 45;
    } else if(inputValue1 == "test-4") {
        response.testSymbol = 23;
    } else if(inputValue1 == "test-5") {
        response.testObject = "Hello";
    } else if(inputValue1 == "test-6") {
        response.testArray = {a:3};
    } else if(inputValue1 == "test-7") {
        response.testHash = [1,3];
    } else {
        $host._debug_string = "hTestHook called with "+inputValue1+"/"+object.first(5).toString();
        response.testString = "Hello!";
        response.testSymbol = "something";
        response.testBool = true;
        o = O.object();
        o.append("Randomness", 42);
        response.testObject = o;
        response.testArray = [349,3982,27584,null];
        response.testHash = {c:"pong", d:56};
    }
});

P.hook('hChainTest1', function(response) {
    $host._debug_string = "1 - test_plugin";
    response.stopChain();
});

P.hook('hChainTest2', function(response) {
    $host._debug_string = "2 - test_plugin";
});

P.hook('hAppGlobalWrite', function(response, key, value) {
    this.data[key] = value;
});

P.hook('hAppGlobalDelete', function(response, key) {
    delete this.data[key];
});

P.hook('hAppGlobalRead', function(response, key) {
    if(this.data[key] === undefined) {
        response.value = "UNDEFINED VALUE";
    } else {
        response.value = this.data[key];
    }
});

P.hook('hTestInterPluginService', function(response) {
    response.value = O.service("test_service", "Hello");
});

P.hook('hTestSessionOutsideRequest', function(response) {
    response.called = "yes";
    O.session["hello"] = "carrots";
});

P.hook('hTestScheduleBackgroundTask', function(response, value) {
    O.background.run("test_plugin:hello", {helloValue:value});
});

test_plugin.hook("hTestMultipleHookDefinitionsInOnePlugin", function(response) {
    response.passedThrough += "1";
});
test_plugin.hook("hTestMultipleHookDefinitionsInOnePlugin", function(response) {
    response.passedThrough += " two";
});
test_plugin.hook("hTestMultipleHookDefinitionsInOnePlugin", function(response) {
    response.passedThrough += " three";
});

P.hook("hLabelObject", function(response, object) {
    var title = object.firstTitle();
    if(title === null) return;
    switch(title.toString()) {
        case "add_common_label":
            // LABEL_COMMON should already be there, but just check
            response.changes.add(LABEL["std:label:common"]);
        case "remove_common_label":
            response.changes.remove(LABEL["std:label:common"]);
            break;
        case "self_label":
            response.changes.add(object.ref);
            break;
        case "add_remove_self_label":
            response.changes.add(object.ref);
            response.changes.remove(object.ref);
            break;
        case "add_many":
            response.changes.add(object.ref);
            response.changes.add(4);
            break;
        case "remove_not_existing":
            response.changes.remove(99999);
            break;
        case "invalid_labels":
            _.each([function(){}, "A", 1.1, -1], function(value) {
                var assertRaised = false;
                try {
                    response.changes.add(value);
                } catch(e) {
                    assertRaised = true;
                    if(!/Bad label value/.test(e.message)) {
                        throw e;
                    }
                }
                if(!assertRaised) throw new Error("Exception not raised adding " + value + " to object labels.");
            });
            response.changes.add(9999);  // Add a random label to ensure that the exceptions didn't break anything
            break;
        case "add_9999":
            response.changes.add(9999);
            break;
        case "update_object":
            // Should never be called
            response.changes.add(888899);
            break;
    }
});

P.hook("hLabelUpdatedObject", function(response, object) {
    switch(object.firstTitle().toString()) {
        case "update_object":
            response.changes.add(1234);
            break;
    }
});

// --------------------------------------------------------------------

// Store which user is active when plugin code is evaluated
P.data.currentUserCodeEvaluate = O.currentUser.id;

// --------------------------------------------------------------------

// Legacy declaration
P.workUnit("wu_one", "Test 1", function(W) {
    W.render({type:W.workUnit.workType, context:W.context});
});

P.workUnit({workType:"wu_two", description:"Test 2", render:function(W) {
    W.render({fullInfo:'/ping'});
}});

P.workUnit({workType:"wu_three", description:"Test 3", render:function(W) {
    W.render({fullInfo:'/ping', fullInfoText:"Carrots"});
}});

P.workUnit({workType:"wu_four", description:"Test 4", render:function(W) {
    W.render({hello:"World"}, "wu_four_template");
}});

P.workUnit({workType:"wu_five", description:"Test 5", render:function(W) {
    W.render({something:"Else"}, test_plugin.template("wu_five_template"));
}});

P.backgroundCallback("hello", function(data) {
    test_plugin.data.hello = data.helloValue;
});

// --------------------------------------------------------------------

P.constructTestTextType1 = test_plugin.implementTextType("test:testtype", "First test type", {
    string: function(value) {
        return value.text;
    },
    indexable: function(value) {
        return "XTEXTTYPEX "+value.text;
    },
    render: function(value) {
        return test_plugin.template("test_text_type").render(value);
    }
});
P.implementTextType("test_plugin:testtype2", "Test type Two", {
    validate: function(value) {
        if(!("v" in value)) {
            throw new Error("Bad value");
        }
    },
    string: function(value) {
        return 'X'+value.v;
    },
    identifier: function(value) {
        return 'ID-'+value.v;
    }
});
