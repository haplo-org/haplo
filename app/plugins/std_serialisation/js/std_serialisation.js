/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.implementService("std:serialisation:serialiser", function() {
    return new Serialiser();
});

// --------------------------------------------------------------------------

var descLookup, qualLookup, labelLookup, sources;

const UNKNOWN = "UNKNOWN";

// --------------------------------------------------------------------------

var formatDate = function(d) {
    return d ? (new XDate(d)).toISOString() : null;
};

// --------------------------------------------------------------------------

var Serialiser = function() {
    this.$useAllSources = false;
    this.$useSources = [];
    this.$expandValue = {};
    this.$listeners = {};
};

Serialiser.prototype = {  

    useAllSources() {
        this._checkNotSetup();
        this.$useAllSources = true;
        return this;
    },

    useSource(name) {
        this._checkNotSetup();
        this.$useSources.push(name);
        return this;
    },

    restrictObject() {
        this._checkNotSetup();
        this.$restrictObject = true;
        return this;
    },

    // Safe to use with untrusted data
    // Uses "sources" as comma separated list, or sources=ALL or sources=NONE
    // transform=restrict to call restrictedCopy() before serialisation
    configureFromParameters(parameters) {
        this._checkNotSetup();
        let sources = parameters.sources;
        if((typeof(sources) === "string") && (sources.length < 1024)) {
            if(sources === "ALL") {
                this.useAllSources();
            } else if(sources !== "NONE") {
                sources.split(',').forEach((s) => this.useSource(s));
            }
        }
        if("transform" in parameters) {
            if(parameters.transform === "restrict") {
                this.restrictObject();
            } else {
                throw new Error("Unknown transform specified: "+parameters.transform);
            }
        }
        return this;
    },

    expandValue(typecode, fn) {
        this._checkNotSetup();
        let existing = this.$expandValue[typecode];
        if(existing) {
            this.$expandValue[typecode] = function(value, valueSerialised) {
                existing(value, valueSerialised);
                fn(value, valueSerialised);
            };
        } else {
            this.$expandValue[typecode] = fn;
        }
    },

    listen(identifier, fn) {
        this._checkNotSetup();
        let existing = this.$listeners[identifier];
        if(existing) {
            // TODO: Is more than three args needed?
            this.$listeners[identifier] = function(a, b, c) {
                existing(a, b, c);
                fn(a, b, c);
            };
        } else {
            this.$listeners[identifier] = fn;
        }
    },

    notify(identifier, a, b, c) {
        let fn = this.$listeners[identifier];
        if(fn) { fn(a, b, c); }
    },

    _checkNotSetup() {
        if(this.$doneSetup) {
            throw new Error("Cannot change options after serialiser has been used.");
        }
    },

    _setup() {
        if(this.$doneSetup) { return; }

        if(!descLookup) {
            descLookup = {};
            for(let k in SCHEMA.ATTR) { descLookup[SCHEMA.ATTR[k]] = k; }
        }
        if(!qualLookup) {
            qualLookup = {};
            for(let k in SCHEMA.QUAL) { qualLookup[SCHEMA.QUAL[k]] = k; }
            delete qualLookup[SCHEMA.QUAL["std:qualifier:null"]];
        }
        if(!labelLookup) {
            labelLookup = O.refdict();
            for(let k in SCHEMA.LABEL) { labelLookup.set(SCHEMA.LABEL[k], k); }
        }
        if(!sources) {
            let s = [];
            O.serviceMaybe("std:serialiser:discover-sources", (source) => {
                s.push(source);
            });
            sources = _.sortBy(s, 'sort');
        }

        // NOTE: Source names may be untrusted data
        this.$sources = _.select(sources, (s) => {
            return this.$useAllSources || (-1 !== this.$useSources.indexOf(s.name));
        });
        this.$sources.forEach((s) => {
            if(s.depend) {
                if(!_.find(this.$sources, (source) => source.name === s.depend)) {
                    throw new Error("Source "+s.name+" depends on "+s.depend+" which has not been used.");
                }
            }
            s.setup(this);
        });

        this.$doneSetup = true;
    },

    formatDate: formatDate
};

// --------------------------------------------------------------------------

Serialiser.prototype.encode = function(object) {
    this._setup();

    let serialised = {
        kind: "haplo:object:0",
        sources: this.$sources.map((s) => s.name)
    };

    if(this.$restrictObject) {
        object = object.restrictedCopy(O.currentUser);
        serialised.transform = ["restrict"];
    }

    // Serialise basics about this object
    let ref = object.ref;
    if(ref) {
        serialised.ref = ref.toString();
        serialised.url = object.url(true);
        let b = ref.getBehaviourExactMaybe();
        if(b) { serialised.behaviour = b; }
    }
    serialised.recordVersion = object.version;  // named so the same one can be used for other data types, and clear it's not the format version
    serialised.title = object.title;
    serialised.labels = _.map(object.labels, (ref) => {
        let l = ref.load(),
            b = ref.getBehaviourExactMaybe(),
            s = {
                ref: ref.toString(),
                title: l.title
            };
        if(b) { s.behaviour = b; }
        let c = labelLookup.get(ref);
        if(c) { s.code = c; }
        return s;
    });
    serialised.deleted = !!object.deleted;
    serialised.creationDate = formatDate(object.creationDate);
    serialised.lastModificationDate = formatDate(object.lastModificationDate);

    // Provide type info
    let type = object.firstType();
    if(type) {
        let typeInfo = SCHEMA.getTypeInfo(type);
        if(typeInfo) {
            serialised.type = {
                code: typeInfo.code || UNKNOWN,
                name: typeInfo.name || UNKNOWN,
                rootCode: SCHEMA.getTypeInfo(typeInfo.rootType).code || UNKNOWN,
                annotations: typeInfo.annotations
            };
        }
    }
    if(!serialised.type) {
        // Provide some defaults, so consumer code can rely on the type property existing
        serialised.type = {
            code: UNKNOWN,
            name: UNKNOWN,
            rootCode: UNKNOWN,
            annotations: []
        };
    }

    // Serialise the attributes
    let attributes = serialised.attributes = {};
    let expandValue = this.$expandValue;
    object.each((v,d,q,x) => {
        let code = descLookup[d];
        if(code) {
            let values = attributes[code];
            if(!values) { values = attributes[code] = []; }
            let typecode = O.typecode(v),
                typecodeName = O.TYPECODE_TO_NAME[typecode];
            if(typecodeName) {
                let vs = {
                    type: typecodeName
                };
                if(q) {
                    let qualCode = qualLookup[q];
                    if(qualCode) { vs.qualifier = qualCode; }
                }
                if(x) {
                    vs.extension = {
                        desc: x.desc,
                        groupId: x.groupId
                    };
                }
                switch(typecode) {

                    case O.T_OBJREF:
                        vs.ref = v.toString();
                        let b = v.getBehaviourExactMaybe();
                        if(b) { vs.behaviour = b; }
                        if(d === ATTR.Type) {
                            let typeInfo = SCHEMA.getTypeInfo(v);
                            if(typeInfo) {
                                vs.code = typeInfo.code;
                                vs.title = typeInfo.name;
                            }
                        } else {
                            let o = v.load();
                            vs.title = o.title;
                        }
                        break;

                    case O.T_TEXT_PLUGIN_DEFINED:
                        vs.type = v._pluginDefinedTextType; // overrides the typecode's name for ease of use
                        vs.value = (v.toFields()||{}).value;
                        vs.readable = v.toString();
                        break;

                    case O.T_DATETIME:
                        vs.start = formatDate(v.start);
                        vs.end = formatDate(v.end);
                        vs.specifiedAsRange = !!v.specifiedAsRange;
                        vs.precision = v.precision;
                        vs.timezone = v.timezone;
                        vs.readable = v.toString();
                        break;

                    case O.T_IDENTIFIER_FILE:
                        vs.digest = v.digest;
                        vs.fileSize = v.fileSize;
                        vs.mimeType = v.mimeType;
                        vs.filename = v.filename;
                        vs.trackingId = v.trackingId;
                        vs.version = v.version;
                        vs.logMessage = v.logMessage;
                        let file = O.file(v);
                        if(file) {
                            vs.url = file.url({asFullURL:true});
                        }
                        break;

                    case O.T_IDENTIFIER_TELEPHONE_NUMBER:
                    case O.T_TEXT_PERSON_NAME:
                    case O.T_IDENTIFIER_POSTAL_ADDRESS:
                        let fields = v.toFields();
                        delete fields.typecode;
                        vs.value = fields;
                        vs.readable = v.toString();
                        break;

                    default:
                        vs.value = v.toString();
                        break;
                }

                // A source may wish to add additional information
                let expandFn = expandValue[typecode];
                if(expandFn) {
                    expandFn(v, vs);
                }

                values.push(vs);
            }
        }
    });

    this.$sources.forEach((s) => {
        s.apply(this, object, serialised);
    });

    return serialised;
};
