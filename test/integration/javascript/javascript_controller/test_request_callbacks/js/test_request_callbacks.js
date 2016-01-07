/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.requestBeforeHandle = function(E) {
    this.__requestBeforeHandle_called_for = E.request.path;
    if(E.request.path == "/do/test_request_callbacks/req2") {
        return false; // abort request
    }
    if(E.request.path == "/do/test_request_callbacks/req3") {
        // Render something else
        E.render({value:"Request3"});   // uses the template named after the request path
        return undefined;
    }
    if(E.request.path == "/do/test_request_callbacks/req4") {
        E.response.body = "Request Four";
        E.response.kind = "text";
        return false;   // return false, to check that the forbidden response isn't returned when there is output
    }
};

P.requestBeforeRender = function(E, view, templateName) {
    view.requestBeforeHandle_called_for = this.__requestBeforeHandle_called_for;
    view.beforeRenderCalled = "yes";
    view.templateName = templateName;
};

P.requestAfterHandle = function(E) {
    E.response.body += "-after";
};

P.respond("GET", "/do/test_request_callbacks/req1", [
], function(E) {
    E.render({value:"x", exampleLocal:exampleLocal});
});

P.respond("GET", "/do/test_request_callbacks/req2", [
], function(E) {
    // Shouldn't be called
    E.response.body = "Called handler";
    E.response.kind = "text";
});

P.respond("GET", "/do/test_request_callbacks/req3", [
], function(E) {
    // Shouldn't be called, as something else is rendered in it's place
    E.render({value:"HANDLER_CALLED"});
});

P.respond("GET", "/do/test_request_callbacks/req4", [
], function(E) {
    // Shouldn't be called, as something else is output in it's place
    E.render({value:"HANDLER_CALLED"});
});
