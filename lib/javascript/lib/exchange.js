/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var $Exchange = function(plugin, handlerName, method, path, extraPathElements) {
    this.$plugin = plugin;
    this.$handlerName = handlerName;
    this.request = new $Exchange.$Request({method:method, path:path, extraPathElements:extraPathElements});
    this.response = new $Exchange.$Response();
};

$Exchange.$Request = function(details) {
    _.extend(this, details);
};

$Exchange.$Response = function() {
    this.$staticResourcesList = [];
};

(function() {

    _.extend($Exchange.prototype, {
        // templateName will be automatically choosen from the last component in the path name in the respond() statement, if not specified
        // Special keys in view:
        //   view.pageTitle - page title for layout rendering
        //   view.layout - name of HTML layout for main app (automatically set to "standard" if the view kind is "html")
        render: function(view, templateName, templateOptions) {
            var template, m;
            if(typeof(templateName) !== "string") {
                // Shuffle arguments, so templateName is optional
                templateOptions = templateName;
                templateName = undefined;
            }
            if(view === undefined || view === null) {
                view = {};  // use null view as caller didn't specify one
            }
            if(templateName === undefined || templateName === null) {
                // Automatically choose the template name from the last component of the path as the caller didn't specify one
                m = /\/([a-zA-Z0-9\-_]+)$/.exec(this.$handlerName);
                if(m === null) {
                    throw new Error("Can't automatically determine template name from path");
                } else {
                    templateName = m[1];
                }
            }
            // Call the callback function in the plugin - may modify the view
            this.$plugin.requestBeforeRender(this, view, templateName);
            // Testing integration
            var testingHook = $registry.$testingRenderHook;
            if(testingHook) {
                testingHook(view, templateName, templateOptions);
            }
            // Remove the name of a Ruby-implemented layout from any previous render
            delete this.response.layout;
            // Render template
            template = this.$plugin.template(templateName);
            this.response.body = template.render(view, templateOptions);
            this.response.kind = template.kind;
            if(template.kind == "html") {
                // HTML templates get special handling
                if(view.pageTitle != undefined) {
                    this.response.pageTitle = view.pageTitle;
                }
                if(view.layout == undefined) {
                    // Automatically add a layout for HTML pages if none is specified
                    this.response.layout = "std:standard";
                } else if(typeof view.layout === "string") {
                    // Render a layout
                    if(view.layout.indexOf("std:") === 0) {
                        // Standard layout, ask the Ruby layer to render it
                        this.response.layout = view.layout;
                    } else {
                        // Get the layout template, and render it, passing in the current content in the view.
                        var layoutTemplate = this.$plugin.template(view.layout);
                        view.content = this.response.body;
                        this.response.body = layoutTemplate.render(view);
                        this.response.kind = layoutTemplate.kind;
                    }
                }
                if(view.backLink != undefined) {
                    // Have to write it this clumsy way to avoid Rhino undefined property warnings
                    if(view.backLinkText != undefined) {
                        this.response.setBackLink(view.backLink, view.backLinkText);
                    } else {
                        this.response.setBackLink(view.backLink);
                    }
                }
            }
        },

        renderIntoSidebar: function(view, templateName, templateOptions) {
            if(!view) { view = {}; }
            if(!templateName) {
                throw new Error("Template name not specified to renderIntoSidebar() function call.");
            }
            var template = this.$plugin.template(templateName);
            if(template.kind !== "html") {
                throw new Error("Template "+templateName+" is not an HTML template");
            }
            $host.addRightContent(template.render(view, templateOptions));
        },

        appendSidebarHTML: function(html) {
            $host.addRightContent((html || "").toString());
        }
    });

    $Exchange.$Request.prototype.__defineGetter__("parameters", function() {
        if(this.$parameters == undefined) {
            this.$parameters = JSON.parse($host.fetchRequestInformation("parametersJSON"));
        }
        return this.$parameters;
    });

    $Exchange.$Request.prototype.__defineGetter__("headers", function() {
        if(this.$headers == undefined) {
            this.$headers = JSON.parse($host.fetchRequestInformation("headersJSON"));
        }
        return this.$headers;
    });

    $Exchange.$Request.prototype.__defineGetter__("remote", function() {
        return {address:$host.fetchRequestInformation("remoteIPv4"), protocol:"IPv4"};
    });

    $Exchange.$Request.prototype.__defineGetter__("body", function() {
        return $host.fetchRequestInformation("body");
    });

    $Exchange.$Response.prototype.__defineGetter__("headers", function() {
        // Only create the headers if they're used
        if(this.$headers == undefined) {
            this.$headers = {};
        }
        return this.$headers;
    });

    _.extend($Exchange.$Response.prototype, {
        redirect: function(url) {
            this.statusCode = HTTP.FOUND;
            this.headers["Location"] = url;
            // Framework sets Content-Type header as part of rendering
            this.body = $registry.standardTemplates['std:redirect_body'].render({url:url});
        },

        setBackLink: function(url, text) {
            // Use $ prefix on keys because we'd like every caller to use this function
            if(/[<>\s]/.test(url)) {
                throw new Error("backLink cannot contain < > or whitespace characters");
            }
            this.$backLink = url;
            this.$backLinkText = (typeof(text) == 'string') ? text : 'Back';
        },

        useStaticResource: function(resourceName) {
            if(!_.include(this.$staticResourcesList, resourceName)) {
                this.$staticResourcesList.push(resourceName);
            }
        },

        setExpiry: function(seconds) {
            seconds = Math.round(1*seconds);
            if(seconds <= 0) { seconds = 1; }
            var h = this.headers;
            h['Cache-Control'] = "private, max-age="+1*seconds;
            h['Expires'] = ((new XDate()).addSeconds(seconds)).toString("ddd, dd MMM yyyy HH:mm:ss +0000");    // depends on XDate library
        },

        // Called by the host object just before it uses a response object
        $finaliseResponse: function() {
            // Does the body need some special handling?
            if(this.body instanceof $GenerateTable) {
                if(!this.body.hasFinished) { this.body.finish(); }
            }
            // Headers need to be encoded as JSON for the moment.
            if(this.$headers != undefined) {
                this.$headersJSON = JSON.stringify(this.$headers);
            }
            // Static resources
            if(this.$staticResourcesList.length > 0) {
                this.$staticResources = JSON.stringify(this.$staticResourcesList);
            }
        }
    });

})();