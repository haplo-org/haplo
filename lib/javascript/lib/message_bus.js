/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function() {

    var constructFromKeychain = {};

    // ----------------------------------------------------------------------
    //  Base class for Bus & Message
    // ----------------------------------------------------------------------

    var Bus = function() {};
    Bus.prototype._init = function() {
        this._receivers = [];
    };
    Bus.prototype._send = function(message) {
        throw new Error("_send not implemented for bus");
    };
    Bus.prototype._receive = function(message) {
        message._hasBeenReceived = true;
        this._receivers.forEach(function(fn) {
            fn(message);
        });
    };

    Bus.prototype.receive = function(fn) {
        this._receivers.push(fn);
        return this;
    };
    Bus.prototype.message = function() {
        return this._makeNewMessage();
    };

    // ----------------------------------------------------------------------

    var Message = function() { };
    Message.prototype._init = function(bus) {
        this._bus = bus;
    };
    Message.prototype._checkPreSend = function() {
        if(this._hasBeenReceived) { throw new Error("Message cannot be modified"); }
    };

    // Sending
    Message.prototype.body = function(messageBody) {
        this._checkPreSend();
        if(!_.isObject(messageBody) || (typeof(messageBody) === "function")) {
            throw new Error("Message body is not a JSON-compatible Object");
        }
        if(this._body) {
            throw new Error("Message body is already set");
        }
        this._body = messageBody;
        return this;
    };
    Message.prototype.send = function() {
        this._checkPreSend();
        if(!this._body) {
            throw new Error("Cannot send a message without a message body");
        }
        this._bus._send(this);
        return undefined;   // this shouldn't be chained
    };

    // Receiving
    Message.prototype.parsedBody = function() {
        return this._body;
    };

    // ----------------------------------------------------------------------
    //  Loopback implementation
    // ----------------------------------------------------------------------

    var LoopbackBus = function(name) {
        this._init();
        this._loopbackName = name;
    };
    LoopbackBus.prototype = new Bus();
    LoopbackBus.prototype._makeNewMessage = function() {
        return new LoopbackMessage(this);
    };
    LoopbackBus.prototype._send = function(message) {
        if(!(message instanceof LoopbackMessage)) { throw new Error("Bad type of message"); }
        if(O.PLUGIN_DEBUGGING_ENABLED) {
            // Check that the message can be JSON serialised
            JSON.stringify(message._body);
        }
        this._receive(message);
    };

    var LoopbackMessage = function(loopbackBus) {
        this._init(loopbackBus);
    };
    LoopbackMessage.prototype = new Message();

    // ----------------------------------------------------------------------

    var getLoopbackBus = function(name) {
        var loopbacks = $registry.$messageBusLoopback;
        if(!loopbacks) { $registry.$messageBusLoopback = loopbacks = {}; }
        if(name in loopbacks) { return loopbacks[name]; }
        var bus = new LoopbackBus(name);
        loopbacks[name] = bus;
        return bus;
    };

    constructFromKeychain['Loopback'] = function(info) {
        if(!info.name) {
            throw new Error("Loopback message bus credential does not have an API code");
        }
        return getLoopbackBus(info.name);
    };

    // ----------------------------------------------------------------------
    //  Inter-application implementation
    // ----------------------------------------------------------------------

    var InterApplicationBus = function(name, secret) {
        this._init();
        this._interappName = name;
        this._interappSecret = secret;
    };
    InterApplicationBus.prototype = new Bus();
    InterApplicationBus.prototype._makeNewMessage = function() {
        return new InterApplicationMessage(this);
    };
    InterApplicationBus.prototype._send = function(message) {
        if(!(message instanceof InterApplicationMessage)) { throw new Error("Bad type of message"); }
        $KMessageBusPlatformSupport.sendInterApplicationMessage(
            this._interappName,
            this._interappSecret,
            JSON.stringify(message._body)
        );
    };

    var InterApplicationMessage = function(interappBus) {
        this._init(interappBus);
    };
    InterApplicationMessage.prototype = new Message();

    // ----------------------------------------------------------------------

    O.$messageBusInterApplicationMessageDeliver = function(busName, busSecret, jsonMessage) {
        var interappBusses = $registry.$messageBusInterapp;
        if(!interappBusses) { return; }
        var bus = interappBusses[busName + "\t" + busSecret];
        if(!bus) {
            console.log("Unexpectedly dropping message for inter-application bus", busName);
            return;
        }
        var message = new InterApplicationMessage(bus);
        message.body(JSON.parse(jsonMessage));
        bus._receive(message);
    };

    constructFromKeychain['Inter-application'] = function(info) {
        if(!(info.name && info.secret)) {
            throw new Error("Inter-application message bus credential does not have a name and secret");
        }
        var interappBusses = $registry.$messageBusInterapp;
        if(!interappBusses) { $registry.$messageBusInterapp = interappBusses = {}; }
        var key = info.name + "\t" + info.secret;
        if(key in interappBusses) { return interappBusses[key]; }
        var bus = new InterApplicationBus(info.name, info.secret);
        interappBusses[key] = bus;
        return bus;
    };

    // ----------------------------------------------------------------------
    //  JS API for access by plugins
    // ----------------------------------------------------------------------

    O.messageBus = {

        loopback: getLoopbackBus,

        remote: function(name) {
            var infoStr = $KMessageBusPlatformSupport.queryKeychain(name);
            if(!infoStr) {
                // Fallback to loopback prevents horrid failures when loading plugins
                // TODO: Better approach to managing plugins which require message busses to be defined
                console.log('No configured message bus "'+name+'", falling back to loopback message bus');
                return getLoopbackBus("$fallbackNotInKeychain:"+name);
            }
            var info = JSON.parse(infoStr);
            var construct = constructFromKeychain[info.kind];
            if(!construct) { throw new Error("Unknown Message Bus kind in keychain"); }
            return construct(info);
        }
    };

})();
