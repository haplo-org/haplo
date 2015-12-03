/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function() {

    // Public interface

    O.fileTransformPipeline = function(name, data) {
        return new Pipeline(name, data);
    };

    $Plugin.prototype.fileTransformPipelineCallback = function(name, callbacks) {
        O.$registerFileTransformPipelineCallback(name, this, callbacks);
    };

    // ----------------------------------------------------------------------

    // Private registration of callbacks
    O.$registerFileTransformPipelineCallback = function(name, thisArg, callbacks) {
        if(!("fileTransformPipelineCallbacks" in $registry)) {
            $registry.fileTransformPipelineCallbacks = {};
        }
        var registeredCallbacks = $registry.fileTransformPipelineCallbacks;
        if(name in registeredCallbacks) {
            throw "Pipeline callback '"+name+"' is already registered.";
        }
        registeredCallbacks[name] = {thisArg:thisArg, callbacks:callbacks};
    };

    // Ruby code to call JS callbacks
    O.$fileTransformPipelineCallback = function(result) {
        var reg = ($registry.fileTransformPipelineCallbacks || {})[result.name];
        if(reg) {
            if(result.success) {
                if(reg.callbacks.success) { reg.callbacks.success.call(reg.thisArg, result); }
            } else {
                if(reg.callbacks.error) { reg.callbacks.error.call(reg.thisArg, result); }
            }
        }
    };

    // ----------------------------------------------------------------------

    var checkName = function(name) {
        if(!((typeof(name) === "string") && (name.length >= 1) && (name.length < 256))) {
            throw new Error("Invalid name used when building file transform pipeline.");
        }
    };

    // ----------------------------------------------------------------------

    var Pipeline = function(name, data) {
        this.name = name;
        this.data = data || {};
        this.files = [];
        this.transforms = [];
        this.waitUI = [];
    };
    _.extend(Pipeline.prototype, {

        _ensureNotExecuted: function() {
            if(this.$executed) {
                throw new Error("Transform pipeline has already been executed.");
            }
        },

        file: function(name, storedFile) {
            this._ensureNotExecuted();
            if(!(storedFile instanceof $StoredFile)) {
                throw new Error("Must pass a StoredFile instance to pipeline file()");
            }
            checkName(name);
            this.files.push([name, storedFile.digest, storedFile.fileSize]);
        },

        transform: function(transformName, transformSpecification) {
            this._ensureNotExecuted();
            checkName(transformName);
            $StoredFile._verifyFileTransformPipelineTransform(transformName, JSON.stringify(transformSpecification || {}));
            this.transforms.push([transformName, transformSpecification || {}]);
        },

        rename: function(fromName, toName) {
            checkName(fromName); checkName(toName);
            this.transform("std:file:rename", {rename:[[fromName,toName]]});
        },

        transformPreviousOutput: function(transformName, transformSpecification) {
            this.rename('output','input');
            this.transform(transformName, transformSpecification);
        },

        _identifierForWaitUI: function(name, filename, redirectTo, view) {
            this._ensureNotExecuted();
            if(!redirectTo) { checkName(name); }
            var identifier = O.security.random.identifier();
            this.waitUI.push([name, filename, redirectTo, identifier, (view || {})]);
            return identifier;
        },

        urlForOutput: function(name, filename) {
            return O.application.url +
                "/do/generated/file/" +
                this._identifierForWaitUI(name, filename, null) +
                "/"+filename.replace(/[^a-zA-Z0-9_\.-]+/,'_');
        },

        urlForOuputWaitThenDownload: function(name, filename, view) {
            return "/do/generated/download/" +
                this._identifierForWaitUI(name, filename, null, view) +
                "/"+filename.replace(/[^a-zA-Z0-9_\.-]+/,'_');
        },

        urlForWaitThenRedirect: function(redirectTo, view) {
            return "/do/generated/wait/" +
                this._identifierForWaitUI(null, null, redirectTo, view);
        },

        viewToWaitForOutput: function(name, filename) {
            return {
                identifier: this._identifierForWaitUI(name, filename, null),
                filename: filename
            };
        },

        execute: function() {
            this._ensureNotExecuted();
            if(this.transforms.length === 0) {
                throw new Error("No transforms specified in pipeline when calling execute()");
            }
            $StoredFile._executeFileTransformPipeline(JSON.stringify(this));
            this.$executed = true;
        }

    });

})();
