/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var $DbObject = function() { };
_.extend($DbObject.prototype, {

    save: function() {
        if(this.id == undefined) {
            this.$table.createNewRow(this);
        }
        else {
            this.$table.saveChangesToRow(this.id, this);
        }
        return this;
    },

    deleteObject: function() {
        if(this.id == undefined) {
            return false;
        }
        return this.$table.deleteRow(this.id);
    }

});

// Generate setters for the fields in each per-table derived class
(function() {

    var numberSetter = function(fieldName, nullNotAllowed) {
        return function(value) {
            if(value === null) { if(nullNotAllowed) { throw new Error(fieldName+" cannot be null");} }
            else if(typeof value !== "number")      { throw new Error(fieldName+" must be a number"); }
            if(this.$changes == undefined) { this.$changes = {}; }
            this.$changes[fieldName] = value;
            this.$values[fieldName] = value;
        };
    };

    var dateSetter = function(fieldName, nullNotAllowed) {
        return function(value) {
            value = O.$convertIfLibraryDate(value); // support all the date libraries objects
            if(value === null) { if(nullNotAllowed) { throw new Error(fieldName+" cannot be null");} }
            else if(!(value instanceof Date)) { throw new Error(fieldName+" must be a Date"); }
            if(this.$changes == undefined) { this.$changes = {}; }
            this.$changes[fieldName] = value;
            this.$values[fieldName] = value;
        };
    };

    $DbObject.$defineSetter = {
        // ---- TEXT
        text: function(fieldName, nullNotAllowed) {
            return function(value) {
                if(value === null) { if(nullNotAllowed) { throw new Error(fieldName+" cannot be null");} }
                else if(typeof value !== "string") { throw new Error(fieldName+" must be a string"); }
                if(this.$changes == undefined) { this.$changes = {}; }
                this.$changes[fieldName] = value;
                this.$values[fieldName] = value;
            };
        },
        // ---- DATE
        date: dateSetter,
        datetime: dateSetter,
        time: function(fieldName, nullNotAllowed) {
            return function(value) {
                if(value === null) { if(nullNotAllowed) { throw new Error(fieldName+" cannot be null");} }
                else if(!(value instanceof DBTime))  { throw new Error(fieldName+" must be a DBTime"); }
                if(this.$changes == undefined) { this.$changes = {}; }
                this.$changes[fieldName] = value;
                this.$values[fieldName] = value;
            };
        },
        // ---- OBJECT REFERENCE
        ref: function(fieldName, nullNotAllowed) {
            return function(value) {
                if(value === null) { if(nullNotAllowed) { throw new Error(fieldName+" cannot be null");} }
                else {
                    if(value instanceof $StoreObject) { value = value.ref; } // Allow objects to be used as well as just refs
                    if(!(value instanceof $Ref))  { throw new Error(fieldName+" must be a Ref or StoreObject"); }
                }
                if(this.$changes == undefined) { this.$changes = {}; }
                this.$changes[fieldName] = value;
                this.$values[fieldName] = value;
            };
        },
        // ---- USER OBJECT
        user: function(fieldName, nullNotAllowed) {
            return function(value) {
                if(value === null) { if(nullNotAllowed) { throw new Error(fieldName+" cannot be null");} }
                else if(!(value instanceof $User))  { throw new Error(fieldName+" must be a User object"); }
                if(this.$changes == undefined) { this.$changes = {}; }
                this.$values[fieldName] = this.$changes[fieldName] = value ? value.id : null; // NOT JUST value!
            };
        },
        // ---- FILE OBJECT
        file: function(fieldName, nullNotAllowed) {
            return function(value) {
                if(value === null) { if(nullNotAllowed) { throw new Error(fieldName+" cannot be null");} }
                else {
                    value = O.file(value);  // Convert to StoredFile, allowing anything it'll take - will exception if there is no such file
                    if(!(value instanceof $StoredFile))  { throw new Error(fieldName+" must be a File object"); }
                }
                if(this.$changes == undefined) { this.$changes = {}; }
                this.$changes[fieldName] = value;
                this.$values[fieldName] = value;
            };
        },
        // ---- BOOLEAN
        "boolean": function(fieldName, nullNotAllowed) {
            return function(value) {
                if(value === null) { if(nullNotAllowed) { throw new Error(fieldName+" cannot be null");} }
                else if(value !== true && value !== false)  { throw new Error(fieldName+" must be true or false"); }
                if(this.$changes == undefined) { this.$changes = {}; }
                this.$changes[fieldName] = value;
                this.$values[fieldName] = value;
            };
        },
        // ---- LABELLIST
        "labelList": function(fieldName, nullNotAllowed) {
            return function(value) {
                if(value === null) { if(nullNotAllowed) { throw new Error(fieldName+" cannot be null");} }
                else if(!(value instanceof $LabelList))  { throw new Error(fieldName+" must be a LabelList object"); }
                if(this.$changes == undefined) { this.$changes = {}; }
                this.$changes[fieldName] = value;
                this.$values[fieldName] = value;
            };
        },
        // ---- LINK TO OTHER DATABASE TABLE
        link: function(fieldName, nullNotAllowed, otherTableName) {  // is special cased with extra parameter
            return function(value) {
                var objkey = fieldName+"_obj", idvalue = null;
                if(value === null) {
                    if(nullNotAllowed) { throw new Error(fieldName+" cannot be null"); }
                    idvalue = null;
                    this.$values[objkey] = undefined;
                } else if(typeof value === "number") {
                    idvalue = value;
                    this.$values[objkey] = undefined;
                } else if(value instanceof $DbObject) {
                    if(value.$table.name != otherTableName) {
                        throw new Error("Other database object must be in the "+otherTableName+" table");
                    }
                    idvalue = value.id;
                    this.$values[objkey] = value;
                } else {
                    throw new Error(fieldName+" must be a database object or a number");
                }
                if(this.$changes == undefined) { this.$changes = {}; }
                this.$changes[fieldName] = idvalue;
                this.$values[fieldName] = idvalue;
            };
        },
        // ---- SMALLINT, INT, BIGINT, FLOAT
        smallint: numberSetter,
        "int": numberSetter,
        bigint: numberSetter,
        "float": numberSetter
    };

})();

// Java code calls this to generate a factory function for each table
$DbObject.$makeFactoryFunction = function(tableDefinition, fields, initialiserOrMethods) {
    var DbObject, factory, nullableNulls = {};

    // Make a 'template' $values object which contains null for each nullable field. This is cloned for each new object.
    // This makes sure that nullable fields return null if they're not explicitly set.
    // Non-nullable fields will return undefined if they're not explicitly set.
    _.each(fields, function(defn, fieldName) {
        if(defn.nullable) {
            nullableNulls[fieldName] = null;
        }
    });

    // Make a subclass of $DbObject with a constructor and a reference to the table definition
    DbObject = function(initialValues) {
        this.$values = _.clone(nullableNulls);
        if(initialValues !== undefined) {
            _.extend(this /* not this.$values so that setters are called */, initialValues);
        }
    };
    DbObject.prototype = new $DbObject();
    _.extend(DbObject.prototype, {
        $table: tableDefinition
    });
    // Does the row prototype need additional initialisation?
    if(initialiserOrMethods) {
        if(typeof(initialiserOrMethods) === 'function') {
            initialiserOrMethods(DbObject.prototype);
        } else {
            _.extend(DbObject.prototype, initialiserOrMethods);
        }
    }

    // Add setters which check the type of the argument and use the $changes array
    _.each(fields, function(defn, fieldName) {
        var setterDefiner = $DbObject.$defineSetter[defn.type];
        if(setterDefiner === null) {
            throw new Error("When defining a database table, field type '"+defn.type+"' is unknown.");
        }
        // This nullNotAllowed construction is to avoid triggering a "Reference to undefined property" Rhino warning
        var nullNotAllowed = true;
        if(defn.nullable != undefined) { nullNotAllowed = (!defn.nullable); }
        if(defn.type === "link") {
            // Links to other objects may require loading the object from the other database table
            var otherTableName = fieldName;
            if(defn.linkedTable != undefined) { otherTableName = defn.linkedTable; }
            DbObject.prototype.__defineGetter__(fieldName, function() {
                var linkedObj, objkey = fieldName+"_obj";
                if(this.$values[objkey] !== undefined) {
                    // Already loaded
                    return this.$values[objkey];
                } else {
                    // Object isn't loaded yet - load it and store it in case it's requested again.
                    linkedObj = this.$table.namespace[otherTableName].load(this.$values[fieldName]);
                    this.$values[objkey] = linkedObj;
                    return linkedObj;
                }
            });
            DbObject.prototype.__defineSetter__(fieldName, setterDefiner(fieldName, nullNotAllowed, otherTableName));
        } else {
            // All other types of field
            // SETTER
            DbObject.prototype.__defineSetter__(fieldName, setterDefiner(fieldName, nullNotAllowed));
            // GETTER
            if(defn.type === "user") {
                // Links to user objects load the user with that ID via the O global
                DbObject.prototype.__defineGetter__(fieldName, function() {
                    var value = this.$values[fieldName];
                    return (value === null) ? null : O.user(value);
                });
            } else {
                // Otherwise create a very simple getter which just returns the value
                DbObject.prototype.__defineGetter__(fieldName, function() { return this.$values[fieldName]; });
            }
        }
    });

    // Make a factory function which returns a new object of this type, ready to be filled in by the Java code.
    factory = function(initialValues) {
        return new DbObject(initialValues);
    };

    return factory;
};

// Dummy 'database namespace' object which exceptions on attempted definition of a table.
(function() {
    O.$private.$DummyDb = function() { };
    _.extend(O.$private.$DummyDb.prototype, {
        table: function() {
            throw new Error("This plugin was not declared to use a database in plugin.json. Add the \"pDatabase\" privilege to the \"privilegesRequired\" array.");
        }
    });
})();
