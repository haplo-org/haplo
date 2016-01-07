/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function() {

    // Template functions defined here all return HTML

    var oFormTemplateFn = function(helperName, functionName) {
        return function(formInstance) {
            if(!O.$private.$isFormInstance(formInstance)) {
                throw new Error("You must pass a FormInstance object to the "+helperName+"() template function");
            }
            return (formInstance[functionName])();
        };
    };

    O.$templateFunction = {
        "std:ui:notice": function(message, dismissLink, dismissText) {
            return $registry.standardTemplates["std:ui:notice"]({
                message: message,
                dismissLink: (typeof(dismissLink) === "string") ? dismissLink : undefined,  // need type checks for optional arguments
                dismissText: (typeof(dismissText) === "string") ? dismissText : undefined
            });
        },

        "std:ui:navigation:arrow": function(direction, link) {
            return O.$private.hsvtStandardTemplates["std:_fn_nav_arrow"]({
                direction: direction,
                link: link
            });
        },

        "std:form": oFormTemplateFn('std:form', 'renderForm'),
        "std:document": oFormTemplateFn('std:document', 'renderDocument')
    };

})();
