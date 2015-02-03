/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// -----------------------------------------------------------------------------------------------------------
//    $StoreObjectBase - base class for all store objects, proxying KObject
// -----------------------------------------------------------------------------------------------------------

var $StoreObjectBase = function() { };

_.extend($StoreObjectBase.prototype, {

    ref: null,  // null if object isn't saved, an objref otherwise

    isMutable: function() { return false; },

    isKindOf: function(typeRef) {
        return this.$kobject.isKindOf(typeRef);
    },

    render: function(style) {
        return $host.renderObject(this.$kobject, (style === null || style === undefined) ? "generic" : style.toString());
    },

    url: function(asFullURL) {
        return this.$kobject.generateObjectURL(!!asFullURL);
    },

    mutableCopy: function() {
        return this.$kobject.mutableCopy();
    },

    deleteObject: function() {
        this.$kobject = this.$kobject.deleteObject();
        return true;
    },

    first: function(desc, qual) {
        return this.$kobject.first(desc, (qual !== undefined && qual !== null), qual);
    },

    firstParent:function(qual) { return this.first(201, qual); },
    firstType:  function(qual) { return this.first(210, qual); },
    firstTitle: function(qual) { return this.first(211, qual); },

    has: function(value, desc, qual) {
        return this.$kobject.has(value, (desc !== undefined && desc !== null), desc, (qual !== undefined && qual !== null), qual);
    },

    valuesEqual: function(object, desc, qual) {
        return this.$kobject.valuesEqual(object, (desc !== undefined && desc !== null), desc, (qual !== undefined && qual !== null), qual);
    },

    relabel: function(labelChanges) {
        if(this.ref === null) {
            throw new Error("Cannot call relabel on a storeObject before it has been saved");
        }
        if(!(labelChanges instanceof $LabelChanges)) {
            throw new Error("relabel must be passed an O.labelChanges object");
        }
        if(this.isMutable()) {
            throw new Error("relabel() can only be used on immutable objects");
        }
        this.$kobject = this.$kobject.relabelObject(labelChanges);
    },

    $console: function() {
        var type = (this.isMutable()) ? "StoreObjectMutable" : "StoreObject";
        return "["+type+ " " + this.$kobject.descriptionForConsole() + "]";
    },

    /**
     * Convert to a JSON data structure which is easy to use for generating views.
     *
     * Note that only attributes defined in the schema will be returned.
     *
     * Options are:
     *   aliasing       - boolean, should the results be aliased? Default true.
     *   attributes     - optional array of attributes/aliased attributes to include.
     *                    If specified, the attributes will be output in this order.
     *
     * Root of returned data structure is an object containing:
     *   ref            - ref of this object
     *   title          - first title, as a string
     *   typeRef        - ref of type
     *   typeName       - name of type
     *   rootTypeRef    - ref of root type (might be == typeRef)
     *   rootTypeName   - name of root type
     *
     * For "lookup" kind views, the root is also a lookup from integer (value of SCHEMA.ATTR[] constants)
     * and api code lookup with : mapped to _ for easier use in views (eg "dc:attribute:title" maps to "dc_attribute_title") to value lists.
     *
     * For "display" kind views, the root contains:
     *   attributes     - array of value lists.
     *
     * Value lists are objects containing:
     *   values         - array of values
     *   first          - first value in "values"
     *   descriptor     - value of the relevant SCHEMA.ATTR[] constant
     *   descriptorName - user presentable name of the descriptor, eg "Title"
     *
     * Values are objects containing:
     *   typecode       - value of one of the SCHEMA.T_* constants
     *   T_*            - the string for that typecode constant, eg "T_REF" (for checking typecodes in views)
     *   string         - a string representation of the value (requires escaping)
     *   html           - an HTML representation of the value, which may include additional markup to the string representation
     *   ref            - ref of the linked object, for T_REF values
     *   qualifier      - Included only if the value is qualified. Value of a SCHEMA.QUAL[] constant.
     *   qualifierName  - user presentable name of the qualifier, eg "Alternative"
     *   isLastValue    - true if it's the last value - useful for creating separators
     *
     * NOTE: Public documentation should be careful to give options for an optimised implementation in the
     * future, for example, by returning objects which generate the data on demand.
     */
    toView: function(kind, options) {
        kind = kind || "lookup";
        options = options || {}; // TODO: validate options for store object toView()
        // Call into Ruby for the view JSON
        var view = JSON.parse(this.$kobject.toViewJSON(kind, JSON.stringify(options)));
        // Adjust the response
        // TODO: Do the 'first' value toView() alternative accessor in the JS to avoid duplicating data
        if(kind === "lookup") {
            // Add in the lookup based on numeric values as well as text names
            var altLookup = {};
            _.each(view, function(x,k) {
                if(k in SCHEMA) {
                    altLookup[SCHEMA[k]] = x;
                }
            });
            _.extend(view, altLookup);
        }
        return view;
    },

    /**
     * Different forms of calling:
     * A) Iteration with function(value, desc, qual)
     *   every(iterator) - all values
     *   every(desc, iterator) - all desc values
     *   every(desc, qual, iterator) - all desc+qual values
     * B) Returning an array of values
     *   every(desc)
     *   every(desc, qual)
     * null can be passed in place of desc, qual or iterator.
     */
    every: function(desc, qual, iterator) {
        var r_val;
        // Allow the iterator to be a function in the last position, shuffling the arguments if required
        if(qual === undefined && iterator === undefined && desc instanceof Function) {
            iterator = desc;
            desc = null;
        }
        else if(iterator === undefined && qual instanceof Function) {
            iterator = qual;
            qual = null;
        }
        // Make sure desc and qual are null if they're not being used to select attributes
        if(desc === undefined) { desc = null; }
        if(qual === undefined) { qual = null; }
        // If there's no iterator, generate one which generates the return result
        if(iterator === null || iterator === undefined) {
            r_val = [];
            iterator = function(value, desc, qual) { r_val.push(value); };
        }
        // Call the underlying object (use desc/qual != null because Rhino will convert null to 0s)
        this.$kobject.each(desc, desc !== null, qual, qual !== null, iterator);
        // Return undefined, or the array of collected values
        return r_val;
    },

    // Don't have an everyParent() function because objects shouldn't have more than one parent.
    everyType:  function(a,b) { return this.every(210, a, b); },
    everyTitle: function(a,b) { return this.every(211, a, b); }

});

// Define the getters for properties
$StoreObjectBase.prototype.__defineGetter__("title", function() {
    return this.firstTitle().toString();
});
$StoreObjectBase.prototype.__defineGetter__("descriptiveTitle", function() {
    return this.$kobject.descriptiveTitle();
});
$StoreObjectBase.prototype.__defineGetter__("labels", function() {
    return this.$kobject.getLabels();
});
$StoreObjectBase.prototype.__defineGetter__("deleted", function() {
    return this.$kobject.getIsDeleted();
});
$StoreObjectBase.prototype.__defineSetter__("labels", function(labels) {
    throw new Error("labels is a read only property");
});
$StoreObjectBase.prototype.__defineGetter__("version", function() {
    return this.$kobject.getVersion();
});
$StoreObjectBase.prototype.__defineGetter__("creationUid", function() {
    return this.$kobject.getCreatedByUid();
});
$StoreObjectBase.prototype.__defineGetter__("lastModificationUid", function() {
    return this.$kobject.getLastModificationUid();
});
$StoreObjectBase.prototype.__defineGetter__("creationDate", function() {
    return this.$kobject.getCreationDate();
});
$StoreObjectBase.prototype.__defineGetter__("lastModificationDate", function() {
    return this.$kobject.getLastModificationDate();
});
$StoreObjectBase.prototype.__defineGetter__("history", function() {
    return this.$history || (this.$history = $StoredObjectInterface.loadHistory(this.$kobject));
});

// alias every() function to each() for consistency
$StoreObjectBase.prototype.each = $StoreObjectBase.prototype.every;

// -----------------------------------------------------------------------------------------------------------
//    Methods for $StoreObjectMutable - added by js_schema.rb
// -----------------------------------------------------------------------------------------------------------

O.$private.$StoreObjectMutableMethods = {
    // $isNewObject is set by O.object() in framework, on new objects

    preallocateRef: function() {
        if(this.ref || this.$kobject.ref) {
            throw new Error("Object already has a ref allocated.");
        }
        $StoredObjectInterface._preallocateRef(this.$kobject);
        var ref = this.$kobject.ref;
        if(!ref) {
            throw new Error("Failed to preallocate ref for object.");
        }
        this.ref = ref;
        return ref;
    },

    isMutable: function() { return true; },

    append: function(value, desc, qual) {
        this.$kobject.append(value, desc, qual);
        return this;    // for chaining
    },

    appendParent:function(value, qual) { return this.append(value, 201, qual); },
    appendType:  function(value, qual) { return this.append(value, 210, qual); },
    appendTitle: function(value, qual) { return this.append(value, 211, qual); },

    remove: function(desc, qual, iterator) {
        // Allow the iterator to be a function in the qualifier position, shuffling the arguments if required
        if(iterator === undefined && qual instanceof Function) {
            iterator = qual;
            qual = null;
        }
        // Make sure desc is not null
        if(desc === undefined || desc === null) { throw new Error("desc must be specified remove()"); }
        // Make sure desc wasn't passed in as an interator
        if(desc instanceof Function) { throw new Error("desc must be specified remove() -- can't just use a single iterator argument"); }
        // Call underlying object
        if(iterator === null || iterator === undefined) {
            this.$kobject.remove(desc, qual, (qual !== null && qual !== undefined), null);
        }
        else {
            // Wrap the iterator function to make sure it returns true or false
            this.$kobject.remove(desc, qual, (qual !== null && qual !== undefined), function(v,d,q) { return iterator(v,d,q) ? true : false; });
        }
        return this;
    },

    save: function(labelChanges) {
        if(labelChanges !== null &&
           labelChanges !== undefined &&
           !(labelChanges instanceof $LabelChanges)) {
            throw new Error("labelChanges must be an O.labelChanges object");
        }
        this.$kobject = this.$kobject.saveObject(this.$isNewObject || false, labelChanges);
        this.$isNewObject = false;
        this.ref = this.$kobject.ref;
        return this;
    }
};

