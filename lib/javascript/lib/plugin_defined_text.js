/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Implements standard handling for plugin defined text values using the private platform hooks.

(function() {

    // Create a place within O for all the private elements, so they get sealed.
    O.$private.pluginText = {};

    // ----------------------------------------------------------------------------------------------------------------------

    var hObjectTextValueTransformImpl = O.$private.pluginText.hotvti = function(response, type, value, transform) {
        // Does this plugin implement this callback?
        var info = this.$textTypes[type];
        if(undefined === info) { return; }
        var implementation = info.implementation;
        // Parse the value as JSON
        value = JSON.parse(value);
        var output;
        if(transform === "html") {
            if("render" in implementation) {
                output = implementation.render(value);
            }
            if(!output && "string" in implementation) {
                var plain = implementation.string(value);
                if(plain) {
                    output = _.escape(plain);
                }
            }
        } else {
            if(transform in implementation) {
                output = implementation[transform].call(this, value);
            }
        }
        if(output !== undefined && output !== null) {
            response.output = output;
        }
    };

    var hObjectTextValueDiscoverImpl = O.$private.pluginText.hotvdi = function(response) {
        _.each(this.$textTypes, function(info) {
            response.types.push([info.type, info.description]);
        });
    };

    // ----------------------------------------------------------------------------------------------------------------------
    // Registration of plugin defined text implementations

    $Plugin.prototype.implementTextType = function(type, description, implementation) {
        if(undefined == this.$textTypes) {
            // First text type to be defined.
            if(this.hObjectTextValueTransform || this.hObjectTextValueDiscover) {
                throw new Error("When using implementTextType(), the hObjectTextValueTransform and hObjectTextValueDiscover hooks must not be defined.");
            }
            // Setup plugin for handling text types
            this.$textTypes = {};
            this.hObjectTextValueDiscover = hObjectTextValueDiscoverImpl;
            this.hObjectTextValueTransform = hObjectTextValueTransformImpl;
        }
        // Ensure given name looks like it includes some sort of namespacing
        if(!(/^[a-z0-9_]+:[a-z0-9_:]+$/.test(type))) {
            throw new Error("Type names passed to implementTextType() must include a : character");
        }
        this.$textTypes[type] = {type:type, description:description, implementation:implementation};
        // Return a function which constructs new text objects
        return function(value) {
            if(!(_.isObject(value)) || _.isFunction(value)) {
                throw new Error("A JSON compatible JavaScript object must be passed to plugin text type constructor functions.");
            }
            return O.text(O.T_TEXT_PLUGIN_DEFINED, {
                type: type,
                value: value || {}
            });
        };
    };

})();
