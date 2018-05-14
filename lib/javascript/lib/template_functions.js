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

    // ----------------------------------------------------------------------

    var FILE_ALLOWED_OPTIONS = [
        'asFullURL', 'authenticationSignature', 'forceDownload'
    ];

    var checkedFileFunction = function(object, optionIndexStart, args, renderer) {
        var options = {};
        for(var i = optionIndexStart; i < args.length; ++i) {
            var opt = args[i];
            if(-1 === FILE_ALLOWED_OPTIONS.indexOf(opt)) {
                throw new Error("Unknown option for file template function: "+opt);
            }
            options[opt] = true;
        }
        var file;
        if(object instanceof $StoredFile) {
            file = object;
        } else if((object instanceof $KText) && (object.typecode === O.T_IDENTIFIER_FILE)) {
            file = O.file(object);
        } else if(object) {
            throw new Error("Bad type of object passed to file template function");
        } else {
            return;     // don't render anything for falsey values
        }
        return renderer(object, file, options);
    };

    var renderFile = function(object, file, options, thumbnailOnly) {
        var url = file.url(options); // before options is modified to make thumbnail
        options.transform = 'thumbnail';
        var thumbnail = file.toHTML(options);
        return $registry.standardTemplates["std:_file"]({
            url: url,
            unsafeThumbnail: thumbnail,
            text: thumbnailOnly ? undefined : object.filename // use filename from identifier
        });
    };

    var renderFileWithLinkUrl = function(object, file, url, options, thumbnailOnly) {
        if(typeof(url) !== "string") {
            throw new Error("Bad url passed to file-with-link template function");
        }
        options.transform = 'thumbnail';
        var thumbnail = file.toHTML(options);
        return $registry.standardTemplates["std:_file"]({
            url: url,
            unsafeThumbnail: thumbnail,
            text: thumbnailOnly ? undefined : object.filename // use filename from identifier
        });
    };

    // ----------------------------------------------------------------------

    O.$templateFunction = {
        "std:file": function(object) {
            return checkedFileFunction(object, 1, arguments, renderFile); 
        },
        "std:file:thumbnail": function(object) {
            return checkedFileFunction(object, 1, arguments, function(o, file, options) {
                return renderFile(object, file, options, true);
            }); 
        },
        "std:file:transform": function(object, transform) {
            return checkedFileFunction(object, 2, arguments, function(o, file, options) {
                if(transform) { options.transform = transform; }
                return renderFile(object, file, options);
            });
        },
        "std:file:link": function(object) {
            return checkedFileFunction(object, 1, arguments, function(o, file, options) {
                return $registry.standardTemplates["std:_file_link"]({
                    url: file.url(options),
                    text: object.filename   // use filename from identifier
                });
            });
        },
        "std:file:with-link-url": function(object, url) {
            // Note only the "authenticationSignature" argument will have any effect
            // others are silently ignored
            return checkedFileFunction(object, 2, arguments, function(o, file, options) {
                return renderFileWithLinkUrl(object, file, url, options);
            });
        },
        "std:file:thumbnail:with-link-url": function(object, url) {
            // Note only the "authenticationSignature" argument will have any effect
            // others are silently ignored
            return checkedFileFunction(object, 2, arguments, function(o, file, options) {
                return renderFileWithLinkUrl(object, file, url, options, true);
            });
        },

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
