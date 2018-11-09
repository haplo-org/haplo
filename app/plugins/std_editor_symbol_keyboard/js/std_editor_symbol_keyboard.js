/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2018            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


const DEFAULT_KEYBOARDS = {"Greek":"ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩαβγδϵζηθικλμνξοπρστυϕχψω","Maths":"=≠≈><≥≤+−±×⋅÷/√"};

const CanEditKeyboards = O.action("std:editor-symbol-keyboard:can-edit-keyboards").
    title("Can configure object editor keyboards").
    allow("group", GROUP['std:group:administrators']);

const KeyboardsForm = P.form("keyboards", "form/keyboards.json");

// --------------------------------------------------------------------------

P.onInstall = function() {
    O.reloadUserSchema();
};

// --------------------------------------------------------------------------

var getKeyboards = function() {
    return P.data.keyboards || DEFAULT_KEYBOARDS;
};

var toKeyboardsDocument = function(keyboards) {
    var k = [];
    _.each(keyboards, function(characters, name) {
        k.push({name:name, characters:characters});
    });
    return {keyboards:k};
};

// --------------------------------------------------------------------------

P.hook('hEditorSymbolKeyboard', function(response) {
    response.keyboards = JSON.stringify(getKeyboards());
});

// --------------------------------------------------------------------------

P.hook('hGetReportsList', function(response) {
    if(O.currentUser.allowed(CanEditKeyboards)) {
        response.reports.push(["/do/std-editor-symbol-keyboard/keyboards", "Editor symbol keyboards"]);
    }
});

// --------------------------------------------------------------------------

P.respond("GET", "/do/std-editor-symbol-keyboard/keyboards", [
], function(E) {
    CanEditKeyboards.enforce();
    var keyboards = toKeyboardsDocument(getKeyboards());
    E.render({
        keyboards: KeyboardsForm.instance(keyboards)
    });
});

P.respond("GET,POST", "/do/std-editor-symbol-keyboard/edit", [
], function(E) {
    CanEditKeyboards.enforce();
    var document = toKeyboardsDocument(getKeyboards());
    var form = KeyboardsForm.handle(document, E.request);
    if(form.complete) {
        var d = {};
        document.keyboards.forEach(function(k) {
            d[k.name] = k.characters;
        });
        P.data.keyboards = d;
        O.reloadUserSchema(); // keyboards live in user schema JS file
        return E.response.redirect("/do/std-editor-symbol-keyboard/keyboards");
    }
    E.render({form:form});
});
