/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// This function runs in the context of the per-runtime scope, so must be careful not to bind to the shared scope.
function $haplo_framework_initialiser() {
    // For storing private information
    this.$registry = {};
    // List of plugins registered, in order of registration
    this.$registry.plugins = [];
    // Which plugins provide which features to other plugins
    this.$registry.featureProviders = {};
    // Services registered by plugins
    this.$registry.services = {};
    this.$registry.servicesReg = {};    // services which are registered, but not callable yet
    // Callbacks to plugins
    this.$registry.callbacks = {}; // Maps from "plugin:callback" to function
    // Work units
    this.$registry.workUnits = {};
    // Support for console
    this.$registry.console = {times:{}};
    // Support sprintf for underscore.string.js
    this.$underscore_string_sprintf_cache = {};
    // Support moment.js per-runtime caches
    this.$moment_js_globals = {};
    // Actions
    this.$registry.$actions = {};
    // Main interface with the application
    this.$host = new $Host();
    // Set up templates in this instance
    this.O.$private.$setupRuntimeInstanceTemplates.apply(this);
    // oForms
    this.$registry.$oFormsCustomValidationFunctions = {};
    // HSVT template functions
    this.$registry.$templateFunctions = {};
    // NAME implementation
    this.NAME = O.$private.$makeNAME();
    // Return the host object to the caller
    return this.$host;
}


// Mix in non-conflict functions from Underscore.string.js to Underscore namespace
_.mixin(_.str.exports());


(function() {

    var root = this;

    // Make the root O object
    var O = function() { return null; };
    root.O = O;

    // Server classification
    O.SERVER_CLASSIFICATION_TAGS = this.$server_classification_tags;
    delete this.$server_classification_tags;

    // Some special constants
    O.Q_NULL = 0;

    // Console logging representation
    O.$console = function() {
        return "[Haplo Global Interface]";
    };

    // Integration for date libraries
    O.$isAcceptedDate = function(value) {
        return !!value && (
            (value instanceof Date) ||
            moment.isMoment(value) ||
            (value instanceof XDate)
        );
    };
    O.$convertIfLibraryDate = function(value) {
        // Pass through null and undefined etc
        if(!value) { return value; }
        // Conversion from included date libraries
        if(moment.isMoment(value) || value instanceof XDate) { value = value.toDate(); }
        return value;
    };

    // Application information
    O.application = {};
    O.application.__defineGetter__("id", function() { return parseInt($host.getApplicationInformation("id"),10); });
    O.application.__defineGetter__("name", function() { return $host.getApplicationInformation("name"); });
    O.application.__defineGetter__("hostname", function() { return $host.getApplicationInformation("hostname"); });
    O.application.__defineGetter__("url", function() { return $host.getApplicationInformation("url"); });
    O.application.__defineGetter__("config", function() {
        var c = $registry.applicationConfigurationData;
        if(c) { return c; }
        c = $registry.applicationConfigurationData = Object.seal(JSON.parse($host.getApplicationConfigurationDataJSON()));
        return c;
    });
    O.application.__defineGetter__("plugins", function() {
        return $host.getApplicationInformationPlugins().split(",");
    });

    // Constructors
    O.ref = function(objId, second) {
        if(objId === null || objId === undefined) {
            return null;
        }
        if(second !== undefined) {
            throw new Error("Bad arguments to O.ref(). O.ref no longer takes a section.");
        }
        var t = typeof(objId);
        if(t == 'string') {
            return $host.objrefFromString(objId);
        } else if(t == 'number') {
            return new $Ref(objId);
        } else if(objId instanceof $Ref) {
            return objId;
        } else {
            throw new Error("Bad arguments to O.ref()");
        }
    };
    O.behaviourRef = function(behaviour) {
        if(typeof(behaviour) !== "string") { throw new Error("Must pass String to O.behaviourRef()"); }
        var ref = $Ref.behaviourRef(behaviour);
        if(!ref) {
            throw new Error("Unknown behaviour: "+behaviour);
        }
        return ref;
    };
    O.behaviourRefMaybe = function(behaviour) {
        if(typeof(behaviour) !== "string") { throw new Error("Must pass String to O.behaviourRefMaybe()"); }
        return $Ref.behaviourRef(behaviour);
    };

    // IMPORTANT: See guaranteed properties in the documentation when modifying
    O.deduplicateArrayOfRefs = function(array) {
        var input = array || [],
            output = [],
            check = new $RefSet(),
            inlen = input.length;
        for(var i = 0; i < inlen; ++i) {
            var r = check.addForDedup(input[i]);
            if(r) { output.push(r); }
        }
        return output;
    };

    var constructRefdict = function(klass, valueConstructorFn, sizeHint) {
        var fn = null;
        if(valueConstructorFn !== null && valueConstructorFn !== undefined) {
            if(typeof(valueConstructorFn) == 'function') {
                fn = valueConstructorFn;
            } else {
                throw new Error("O.refdict() argument must be omitted or be a function.");
            }
        }
        return new klass(fn, sizeHint);
    };
    O.refdict = function(fn, sizeHint) { return constructRefdict($RefKeyDictionary, fn, sizeHint); };
    O.refdictHierarchical = function(fn, sizeHint) { return constructRefdict($RefKeyDictionaryHierarchical, fn, sizeHint); };
    O.object = function(/* label list */) {
        return $StoreObject.constructBlankObject(O.labelList(_.toArray(arguments)));
    };
    O.query = function(queryString) {
        return (queryString === undefined) ? $KQueryClause.constructQuery() : $KQueryClause.queryFromQueryString(queryString);
    };
    // Text constructor has translation code for some special types
    var ALLOWED_PERSON_NAME_KEYS = {"first":true, "middle":true, "last":true, "suffix":true, "title":true};
    var POSTAL_ADDRESS_KEY_TO_INDEX = {"street1":0, "street2":1, "city":2, "county":3, "postcode":4, "country":5};
    var ALLOWED_TELEPHONE_NUMBER_KEYS = {"guess_number":true, "guess_country":true, "country":true, "number":true, "extension":true};
    O.text = function(typecode, text) {
        var isJSON = false;
        // Specific constructors for some text types
        switch(typecode) {
            case O.T_TEXT_PERSON_NAME:
                // Check object passed in
                if(typeof text !== "object") {
                    throw new Error("O.text(O.T_TEXT_PERSON_NAME,...) must be passed an Object (used as a dictionary).");
                }
                for(var k1 in text) {
                    if(typeof text[k1] !== "string") {
                        throw new Error("Values in the dictionary passed to O.text(O.T_TEXT_PERSON_NAME,...) must be strings.");
                    }
                    if(undefined === ALLOWED_PERSON_NAME_KEYS[k1]) {
                        throw new Error("Invalid key '"+k1+"' in dictionary passed to O.text(O.T_TEXT_PERSON_NAME,...)");
                    }
                }
                isJSON = true;
                break;
            case O.T_IDENTIFIER_POSTAL_ADDRESS:
                if(typeof text !== "object") {
                    throw new Error("O.text(O.T_IDENTIFIER_POSTAL_ADDRESS,...) must be passed an Object (used as a dictionary).");
                }
                var a = []; // Convert to array form for Ruby code
                for(var k2 in text) {
                    if(typeof text[k2] !== "string") {
                        throw new Error("Values in the dictionary passed to O.text(O.T_IDENTIFIER_POSTAL_ADDRESS,...) must be strings.");
                    }
                    var index = POSTAL_ADDRESS_KEY_TO_INDEX[k2];
                    if(undefined === index) {
                        throw new Error("Invalid key '"+k2+"' in dictionary passed to O.text(O.T_IDENTIFIER_POSTAL_ADDRESS,...)");
                    }
                    a[index] = text[k2];
                }
                if(undefined === text["country"] || text["country"].length !== 2) {
                    throw new Error("The dictionary passed to O.text(O.T_IDENTIFIER_POSTAL_ADDRESS,...) must have a two letter string for the 'country' key.");
                }
                text = a;
                isJSON = true;
                break;
            case O.T_IDENTIFIER_TELEPHONE_NUMBER:
                if(typeof text !== "object") {
                    throw new Error("O.text(O.T_IDENTIFIER_TELEPHONE_NUMBER,...) must be passed an Object (used as a dictionary).");
                }
                for(var k3 in text) {
                    if(typeof text[k3] !== "string") {
                        throw new Error("Values in the dictionary passed to O.text(O.T_IDENTIFIER_TELEPHONE_NUMBER,...) must be strings.");
                    }
                    if(undefined === ALLOWED_TELEPHONE_NUMBER_KEYS[k3]) {
                        throw new Error("Invalid key '"+k3+"' in dictionary passed to O.text(O.T_IDENTIFIER_TELEPHONE_NUMBER,...)");
                    }
                }
                isJSON = true;
                break;
            case O.T_IDENTIFIER_CONFIGURATION_NAME:
                if(typeof text !== "string") {
                    throw new Error("O.text(O.T_IDENTIFIER_CONFIGURATION_NAME,...) must be passed a String.");
                }
                if(!(/^[a-zA-Z0-9_-]+\:[:a-zA-Z0-9_-]+$/.test(text))) {
                    throw new Error("O.text(O.T_IDENTIFIER_CONFIGURATION_NAME,...) must be formed of a-zA-Z0-9_ and contain at least one : separator.");
                }
                break;
            case O.T_TEXT_PLUGIN_DEFINED:
                if(typeof text !== "object" || !("type" in text) || !("value" in text)) {
                    throw new Error("O.text(O.T_TEXT_PLUGIN_DEFINED,...) must be passed an Object with properties 'type' and 'value'.");
                }
                text = {
                    type: text.type,
                    value: (typeof text.value === "string") ? text.value : JSON.stringify(text.value)
                };
                isJSON = true;
                break;
        }
        return $KText.constructKText(typecode, isJSON ? JSON.stringify(text) : text, isJSON);
    };

    O.interRuntimeSignal = function(name, signalFunction) {
        if(!(typeof(name) === "string" && (name.length > 0) && typeof(signalFunction) === "function")) {
            throw new Error("Must pass non-empty name and signal function to O.interRuntimeSignal()");
        }
        return new $InterRuntimeSignal(name, signalFunction);
    };

    // Files
    O.file = function(value, fileSize) {
        var file;
        if(value instanceof $StoredFile) {
            file = value;
        } else if((value instanceof $KText) && (value.typecode === O.T_IDENTIFIER_FILE)) {
            file = $StoredFile._tryLoadFile(value);
        } else if(value instanceof $BinaryData) {
            file = value._createStoredFileFromData();
        } else if(typeof(value) === "string" && value.startsWith("https://")) {
            file = $StoredFile._getFileBySignedURL(value);
        } else if(typeof(value) === "string" && value.length < 128) {
            var haveFileSize = (typeof(fileSize) === "number");
            file = $StoredFile._tryFindFile(value, haveFileSize, haveFileSize ? fileSize : -1);
        } else if(value && value.digest) {
            var haveFileSizeFromValue = (typeof(value.fileSize) === "number");
            file = $StoredFile._tryFindFile(value.digest, haveFileSizeFromValue, haveFileSizeFromValue ? value.fileSize : -1);
        }
        if(!file) {
            throw new Error("Cannot find or create a file from the value passed to O.file()");
        }
        return file;
    };

    O.binaryData = function(source, properties) {
        if(!properties) { properties = {}; }
        if(typeof(source) !== 'string') {
            throw new Error("O.binaryData expects a string as the first argument");
        }
        return new $BinaryDataInMemory(true,
            source,
            properties.charset || 'UTF-8',
            properties.filename || 'data.bin',
            properties.mimeType || 'application/octet-stream');
    };

    // Constructors for generators
    O.generate = {};
    O.generate.table = {};
    O.generate.table.xls = function(filename) { return new $GenerateXLS(filename, false); };
    O.generate.table.xlsx = function(filename) { return new $GenerateXLS(filename, true); };
    O.generate.table.FORMATS = ['xls', 'xlsx'];

    // User lookup by various kinds of values
    var makeSecurityPrincipalFetchFn = function(shouldCheckKind, isGroup, errorMsg) {
        return function(value) {
            var user;
            if(typeof(value) === 'string') {
                user = $User.getUserByEmail(value, shouldCheckKind, isGroup);
            } else if(value instanceof $Ref) {
                user = $User.getUserByRef(value);
            } else {
                user = $User.getUserById(value);
                if(!user) {
                    throw new Error(errorMsg);
                }
            }
            if(shouldCheckKind) {
                if((user !== null) && (isGroup !== user.isGroup)) {
                    throw new Error(errorMsg);
                }
            }
            return user;
        };
    };
    O.securityPrincipal = makeSecurityPrincipalFetchFn(false, null,  "The security principal requested does not exist.");
    O.user =              makeSecurityPrincipalFetchFn(true,  false, "The user requested does not exist.");
    O.group =             makeSecurityPrincipalFetchFn(true,  true,  "The group requested does not exist.");
    O.serviceUser = function(code) {
        if(typeof(code) !== 'string') { throw new Error("Must pass API code as string to O.serviceUser()"); }
        return $User.getServiceUserByCode(code);
    };
    // There can be multiple users for a given email address, so a function is provided to find them all
    O.allUsersWithEmailAddress = function(email) {
        return $User.getAllUsersByEmail(email);
    };
    O.usersByTags = function(tags) {
        return $User.getAllUsersByTags(JSON.stringify(tags));
    };

    // Current user
    O.__defineGetter__("currentUser", function() { return $User.getCurrentUser(); });

    // User behind currently authenticated/active session (useful when impersonating other user)
    O.__defineGetter__("currentAuthenticatedUser", function() { return $User.getCurrentAuthenticatedUser(); });

    // Sessions
    O.__defineGetter__("session", function() { return $host.getSessionStore(); });

    // Tray
    O.__defineGetter__("tray", function() { return $host.getSessionTray(); });

    // Locale
    O.__defineGetter__("currentLocaleId", function() { return $host.i18n_getCurrentLocaleId(); });
    O.setSessionLocaleId = function(localeId) { return $host.i18n_setSessionLocaleId(localeId); };

    // Background processing
    O.background = {};
    O.background.run = function(name, data) { $Job.runJob(name, JSON.stringify(data)); };

    // Email templates
    O.email = {};
    O.email.template = function(code) { return $EmailTemplate.loadTemplate(code, !!(code)); };

    // Handling request?
    O.__defineGetter__("isHandlingRequest", function() { return $host.isHandlingRequest(); });

    // Impersonation
    var SYSTEM_SINGLETON = O.SYSTEM = {};  // singleton object
    O.impersonating = function(user, action) {
        var userObject = user;
        if(user === SYSTEM_SINGLETON) {
            userObject = null;
        } else if(!(user instanceof $User) || user.isGroup) {
            throw new Error("O.impersonating() must be passed O.SYSTEM or a SecurityPrincipal object presenting a user.");
        }
        if(typeof(action) !== 'function') {
            throw new Error("O.impersonating() must be passed a function to call while impersonation is in effect.");
        }
        return $host.impersonating(userObject, action);
    };

    // Temporary suspension of object store permissions
    O.withoutPermissionEnforcement = function(action) {
        if(typeof(action) !== 'function') {
            throw new Error("O.withoutPermissionEnforcement() must be passed a function to call while permission suspension is in effect.");
        }
        return $host.withoutPermissionEnforcement(action);
    };

    // Typecode query functions
    O.typecode = function(value) {
        if(value instanceof $Ref) { return O.T_REF; }
        if(value instanceof $KText) { return value.typecode; }
        if(value instanceof $DateTime || value instanceof Date) { return O.T_DATETIME; }
        if(value === true || value === false) { return O.T_BOOLEAN; }
        if(typeof(value) === "number") {
            return (Math.round(value) === value) ? O.T_INTEGER : O.T_NUMBER;
        }
        if(typeof(value) === "string") { return O.T_TEXT; }
        return null;
    };
    O.isText = function(value) {
        return (value instanceof $KText);
    };
    O.isRef = function(value) {
        return (value instanceof $Ref);
    };

    // Health events
    O.reportHealthEvent = function(eventTitle, eventText, exception) {
        var exceptionText = null;
        if((exception instanceof Error) && exception.stack) {
            // Pure JS errors need their message & stack extracted here
            exceptionText = ""+exception.message+"\n\n"+exception.stack;
        }
        $host.reportHealthEvent(eventTitle, eventText, exception || null, exceptionText);
    };

    // Cache invalidation
    O.reloadUserPermissions = function() {
        return $host.reloadUserPermissions();
    };
    O.reloadJavaScriptRuntimes = function() {
        console.log("O.reloadJavaScriptRuntimes() called to request delayed reload. (Frequent calls to this method will severely impact performance.)");
        return $host.reloadJavaScriptRuntimes();
    };
    O.reloadNavigation = function() {
        return $host.reloadNavigation();
    };
    O.reloadUserSchema = function() {
        return $host.reloadUserSchema();
    };
    O.reloadPlatformDynamicFiles = function() {
        console.log("O.reloadPlatformDynamicFiles() called to invalidate platform dynamic files. (Frequent calls to this method will severely impact performance.)");
        return $host.reloadPlatformDynamicFiles();
    };

    // Security utility functions
    O.security = {};
    // The $Security* classes aren't available until later, so something like {random: $SecurityRandom} doesn't work here.
    // Use a getter function instead. Not as efficient, but gives a nice API.
    O.security.__defineGetter__("random", function() {
        return $SecurityRandom;
    });
    O.security.__defineGetter__("bcrypt", function() {
        return $SecurityBCrypt;
    });
    O.security.__defineGetter__("digest", function() {
        return $SecurityDigest;
    });
    O.security.__defineGetter__("hmac", function() {
        return $SecurityHMAC;
    });

    // Base64
    O.__defineGetter__("base64", function() {
        return $Base64;
    });

    // Container for private functions and classes
    O.$private = {};

    // Functions to call just before plugin onLoad functions
    O.$private.$callBeforePluginOnLoad = [];

    // Test for sealing
    var hiddenInsideFunction = {number:1, string:"str", array:[{property:"here"}]};
    O.$private.$getHiddenInsideFunction = function() { return hiddenInsideFunction; };

    // Can be called at any time within a request handler, processing will be aborted, and a message
    // displayed to the user
    O.stop = function(message, title) {
        var view, template = 'std:stop_body';
        if(typeof message === 'object') {
            // Dictionary passed, so call was O.stop(view, templateName)
            var templateName = title;
            view = message;
            template = (templateName) ? templateName : 'std:stop_body';
        } else {
            view = {
                message: message,
                pageTitle: (title) ? title : 'Error'
            };
        }
        var e = new Error("O.stop() called - "+(view.message || "(no message)"));
        e.$haploStopError = {view:view, template:template};
        if(O.PLUGIN_DEBUGGING_ENABLED) { Error.captureStackTrace(e); }
        throw e;
    };

    // Service support
    // Registration by plugin. Returns number of services registered.
    O.$private.$registerService = function(name, serviceFunction, serviceThis) {
        var serviceRegistration = $registry.servicesReg[name];
        if(serviceRegistration) {
            serviceRegistration.push([serviceFunction, serviceThis]);
        } else {
            $registry.servicesReg[name] = serviceRegistration = [[serviceFunction, serviceThis]];
        }
        return serviceRegistration.length;
    };
    // After loading plugins, this is called to make the services available. This prevents services being called
    // during plugin loading, which is not encouraged. There's an onLoad() function for that kind of thing.
    O.$private.$callBeforePluginOnLoad.push(function() {
        $registry.services = $registry.servicesReg;
    });
    var serviceCall = O.$private.$serviceCall = function(serviceRegistration, args) {
        // Call each service function, returning the value of the first one which
        // returns a value which isn't undefined.
        for(var i = 0; i < serviceRegistration.length; i++) {
            var s = serviceRegistration[i];
            // Call the function
            var r = s[0].apply(s[1], args);
            if(undefined !== r) { return r; }
        }
    };
    // Public interface for calling services
    O.service = function(name /* , arg1, arg2, ... */) {
        // Get registered functions for the service, throw exception if nothing registered
        var serviceRegistration = $registry.services[name];
        if(!serviceRegistration) {
            throw new Error("No provider registered for service '"+name+"' (or attempt to use service during plugin loading)");
        }
        return serviceCall(serviceRegistration, _.tail(arguments));
    };
    O.serviceMaybe = function(name /* , arg1, arg2, ... */) {
        return serviceCall($registry.services[name] || [], _.tail(arguments));
    };
    // Query for service registered
    O.serviceImplemented = function(name) {
        return (name in $registry.services);
    };

    // Features
    O.featureImplemented = function(name) {
        return (name in $registry.featureProviders);
    };

    // Generic name translation service for plugins
    O.$private.$makeNAME = function() {
        var cache = {}, notTranslated = {};
        return function(name, defaultName) {
            if(undefined !== defaultName) {
                // If default is provided, and translation failed before, return the default text now
                if(notTranslated[name]) { return defaultName; }
            }
            var translated = cache[(name || '').toString()];
            if(undefined === translated) {
                translated = serviceCall(
                        $registry.servicesReg["std:NAME"] || [], // use Reg version so service can be called during plugin load
                        [name]);
                // default to untranslated name, unless there's a default name provided as second argument
                if(undefined === translated) {
                    notTranslated[name] = true;
                    if(undefined !== defaultName) { return defaultName; }
                    translated = name;
                }
                cache[name] = translated;
            }
            return translated;
        };
    };
    // Function for NAME interpolations in strings, for use by platform and std_* plugins.
    var interpolateNAMEmatch = function(_, name, __, defaultText) {
        if(undefined !== defaultText) {
            return NAME(name, defaultText);
        } else {
            return NAME(name);
        }
    };
    O.interpolateNAMEinString = function(text) {
        return text ? text.replace(/\bNAME\(([^\)]+?)(\|([^\)]+?))?\)/g, interpolateNAMEmatch) : text;
    };
    // Private name, which allows other parts of the platform to use the "raw" function.
    O.$private.$interpolateNAMEinString = O.interpolateNAMEinString;

    // Generic string interpolation
    O.interpolateString = function(text, inserts) {
        if(!inserts) { inserts = {}; }
        return (text||'').replace(/\{(.+?)\}/g, function(m, prop) {
            return inserts[prop] || '';
        });
    };

    // Create schema information functions in SCHEMA objects.
    var convertSchemaIdsToRefs = function(t) { return new $Ref(t); };
    O.$private.prepareSCHEMA = function(s) {
        var typeInfo = new $RefKeyDictionary(function(t) {
            var json = $host.getSchemaInfo(0,t.objId);
            if(!json) { return null; }
            var i = JSON.parse(json);
            i.rootType = new $Ref(i.rootType);
            if(i.parentType) { i.parentType = new $Ref(i.parentType); }
            i.childTypes = _.map(i.childTypes, convertSchemaIdsToRefs);
            return i;
        });
        s.getTypeInfo = function(type) { return typeInfo.get(type); };

        var m = function(type) {
            var info = {};
            return function(desc) {
                var i = info[desc];
                if(i) { return i; }
                i = null;
                var json = $host.getSchemaInfo(type,desc);
                if(json) {
                    i = JSON.parse(json);
                    if("types" in i) {
                        i.types = _.map(i.types, convertSchemaIdsToRefs);
                    }
                }
                info[desc] = i;
                return i;
            };
        };
        s.getAttributeInfo = m(1);
        s.getQualifierInfo = m(2);
        s.getAliasedAttributeInfo = m(3);

        s.$console = function() { return '[SCHEMA]'; };

        s.getTypesWithAnnotation = function(annotation) {
            return _.map(JSON.parse($host.getSchemaInfoTypesWithAnnotation(annotation)), convertSchemaIdsToRefs);
        };
    };

    // Access to remote services
    var useRemoteService = function(serviceClass, name, fn) {
        var returnValue;
        if(typeof(name) === 'function' && fn === undefined) {
            fn = name; name = undefined; // name argument is optional
        }
        if(typeof(fn) !== 'function') {
            throw new Error("Callback function not passed to connect().");
        }
        var service = serviceClass.findService((typeof(name) === "string"), name);
        if(!service) {
            throw new Error("Couldn't find service");
        }
        service._connect();
        try {
            // Caller does something with the connected service
            returnValue = fn(service);
        } finally {
            service._disconnect();
        }
        return returnValue; // whatever the callback function returned
    };
    O.remote = {
        collaboration: {
            connect: function(name, fn) {
                return useRemoteService($CollaborationService, name, fn);
            }
        },
        authentication: {
            connect: function(name, fn) {
                return useRemoteService($AuthenticationService, name, fn);
            },
            urlToStartOAuth: function(data, name, extraConfiguration) {
                return $AuthenticationService.urlToStartOAuth((typeof(data) === 'string'), data, (typeof(name) === 'string'), name, (typeof(extraConfiguration) === 'object'), extraConfiguration);
            }
        }
    };

    // Keychain access
    O.keychain = {
        query: function(kind) {
            return JSON.parse($KeychainCredential.query(kind));
        },
        credential: function(nameOrId) {
            return $KeychainCredential.load(nameOrId);
        }
    };

    // BigDecimal
    O.bigDecimal = function(number) {
        return new $BigDecimal(number || 0);
    };

    // Number formatter (works with BigDecimal & other numbers), returns any function that's passed in.
    O.numberFormatter = function(format) {
        if(typeof(format) ==="function") {
            return format;  // so you can use O.numberFormatter() to wrap formats and/or functions
        }
        var formatter = new $DecimalFormat(format);
        return function(number) {
            return formatter.format(number);
        };
    };

    // Date parser (uses Java's SimpleDateFormat parser)
    O.dateParser = function(format) {
        var parser = new $DateParser(format);
        return function(string) {
            return parser.parse(string);
        };
    };

    // Zip files
    O.zip = {
        create: function(filename) {
            return new $ZipFile(filename || null);
        }
    };

    // Redirect URL path checking
    O.checkedSafeRedirectURLPath = function(rdr) {
        if((typeof(rdr) === "string") && SAFE_REDIRECT_URL_PATH.test(rdr)) {
            return rdr;
        }
        return null;
    };
    // Ensures scheme relative URLs like //example.org/ and /\example.org/ are not accepted
    var SAFE_REDIRECT_URL_PATH = /^\/[a-zA-Z0-9]\S*$/; // match regexp in lib/ksafe_redirect.rb

    // Root for user interface widgets
    O.ui = {};

    // Callback infrastructure: invoke a callback, given its name
    O.$private.$callbackConstructors = {};

    O.$private.invokeCallback = function(name /* ... */) {
        if(!(name in $registry.callbacks)) {
            throw new Error("An attempt was made to invoke a callback with name ["+name+"], which has not been declared by the plugin");
        }

        var args = arguments, idx = 1; // Skip name in arguments[0]
        var nextArg = function() { return args[idx++]; };
        var callbackArgs = [];
        while(idx < arguments.length) {
            var constructorName = nextArg();
            switch(constructorName) {
            case "raw":
                callbackArgs.push(nextArg());
                break;
            case "parseJSON":
                callbackArgs.push(JSON.parse(nextArg()));
                break;
            default:
                var constructor = O.$private.$callbackConstructors[constructorName];
                if(!constructor) {
                    throw new Error("An invalid argument declaration was used in a callback invocation: " + constructorName);
                }
                callbackArgs.push(constructor(nextArg));
            }
        }

        var callback = $registry.callbacks[name];
        return callback.apply(callbackArgs);
    };

})();
