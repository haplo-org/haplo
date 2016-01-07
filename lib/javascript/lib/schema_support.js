/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


O.$private.preparePluginSchemaRequirements = function(pluginSchemaRequirements) {

    // pluginSchemaRequirements is a JSON compatible structure containing mappings for each plugin. For example:
    //     {
    //         "example_plugin": {
    //             "type": {
    //                 "Person": "std:type:person",
    //                 "Organisation": "std:type:organisation"
    //             },
    //             "attribute": {
    //                 "Speaker": "std:attribute:speaker"
    //             }
    //         }
    //     }

    // Lookup from schema kind to the schema lookup object in this runtime
    var baseSchemaObjects = {
        "type": TYPE,
        "attribute": ATTR,
        "aliased-attribute": ALIASED_ATTR,
        "qualifier": QUAL,
        "label": LABEL,
        "group": GROUP
    };

    // Constructor function for a new lookup object based on another schema object
    var make = function(basedOn) {
        var M = function() {};
        M.prototype = basedOn;
        return new M();
    };

    // Turn the pluginSchemaRequirements into a similar structure using schema lookup objects
    var pluginSchema = {};
    _.each(pluginSchemaRequirements, function(requirements, pluginName) {
        var s = pluginSchema[pluginName] = {};
        var optional = requirements["_optional"] || {};
        _.each(requirements, function(map, kind) {
            if(kind == "_optional") { return; }
            try {
                var schemaObject = s[kind] = make(baseSchemaObjects[kind]);
                _.each(map, function(code, name) {
                    schemaObject[name] = schemaObject[code];
                });
                // Some names are optional, and must be checked first
                if(kind in optional) {
                    _.each(optional[kind], function(code, name) {
                        if(code in schemaObject) {
                            schemaObject[name] = schemaObject[code];
                        }
                    });
                }
            } catch(e) {
                console.log("While creating runtime plugin specific schema object, exception thrown: "+e);
            }
        });
    });

    $registry.pluginSchema = pluginSchema;
};
