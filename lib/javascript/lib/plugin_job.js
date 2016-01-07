/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Implements standard handling for background processing (jobs) using the private platform hooks.

// TODO: Implement proper JS API for background processing / jobs

(function() {

    // Create a place within O for all the private elements, so they get sealed.
    O.$private.pluginJob = {};

    // ----------------------------------------------------------------------------------------------------------------------
    // Implementation of the job hook

    var hPlatformInternalJobRunImpl = O.$private.pluginJob.hpijri = function(response, name, data) {
        // Does this plugin implement this callback?
        var info = this.$backgroundCallbacks[name];
        if(undefined === info) { return; }
        // Deserialise the data
        var dataDeserialised = JSON.parse(data);
        // Call the callback function
        try {
            info.callback.apply(this, [dataDeserialised]);
        } catch(e) {
            // TODO: Handle exceptions in plugin background tasks
            console.log("Exception in background processing:", e);
        }
    };

    // ----------------------------------------------------------------------------------------------------------------------
    // Registration of job callback functions

    $Plugin.prototype.backgroundCallback = function(name, callbackFn) {
        if(undefined == this.$backgroundCallbacks) {
            // First background callback to be defined.
            if(undefined != this.hPlatformInternalJobRun) {
                throw new Error("When using backgroundCallback(), the hPlatformInternalJobRun hook must not be defined.");
            }
            // Setup plugin for handling the callbacks
            this.$backgroundCallbacks = {};
            this.hPlatformInternalJobRun = hPlatformInternalJobRunImpl;
        }
        // Ensure given name does not include the plugin yet, then generate the full name
        if(-1 !== name.indexOf(":")) {
            throw new Error("When using backgroundCallback(), the given name should not include a ':' character. The plugin name is automatically added as a prefix to the name.");
        }
        var fullName = this.$pluginName + ":" + name;
        // Store info about this background callback
        this.$backgroundCallbacks[fullName] = {unqualifiedName:name, fullName:fullName, callback:callbackFn};
    };

})();
