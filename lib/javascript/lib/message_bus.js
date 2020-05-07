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
        this._deliveryReportNotifiers = [];
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
    // For delivery reports,
    //    status: "success", "delayed", "failure" plus bus specific reports
    //    information: bus specific information about delivery
    //    message: message as sent  
    Bus.prototype._deliveryReport = function(status, information, message) {
        this._deliveryReportNotifiers.forEach(function(fn) {
            fn(status, information, message);
        });
    };
    Bus.prototype._getPlatformConfig = function() {
        return [
            this._receivers.length > 0,
            this._deliveryReportNotifiers.length > 0
        ];
    };

    Bus.prototype.receive = function(fn) {
        this._receivers.push(fn);
        return this;
    };
    Bus.prototype.deliveryReport = function(fn) {
        this._deliveryReportNotifiers.push(fn);
        return this;
    };
    Bus.prototype.message = function() {
        return this._makeNewMessage();
    };

    // ----------------------------------------------------------------------

    var Message = function() { };
    Message.prototype._init = function(bus) {
        this._bus = bus;
        this._reliability = 0;      // lowest guarantees of reliability
    };
    Message.prototype._checkPreSend = function() {
        if(this._hasBeenReceived) { throw new Error("Message cannot be modified"); }
    };

    // Sending
    Message.prototype.bestReliability = function() {
        this._reliability = 255;    // highest guarantees to reliability
        return this;
    };
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
        // For consistency with other message bus types, impersonate SYSTEM during delivery
        var bus = this;
        O.impersonating(O.SYSTEM, function() {
            try {
                bus._receive(message);
                bus._deliveryReport("success", {}, message);
            } catch(e) {
                bus._deliveryReport("failure", {exception:e}, message);
            }
        });
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
        try {
            $KMessageBusPlatformSupport.sendMessageToBus(
                "$InterApplication",
                this._platformBusId,
                this._interappName,
                this._interappSecret,
                message._reliability,
                JSON.stringify(message._body)
            );
            // Send delivery report because it was successfully delivered to the bus
            // TODO: Additional inter-application bus reports back from other apps with a different status code?
            this._deliveryReport("success", {}, message);
        } catch(e) {
            // If there's ever an exception, there are bigger problems.
            this._deliveryReport("failure", {exception:e}, message);
        }
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
    //  Amazon kinesis implementation
    // ----------------------------------------------------------------------

    var AmazonKinesisBus = function(streamName) {
        this._init();
        this._streamName = streamName;
    };
    AmazonKinesisBus.prototype = new Bus();
    AmazonKinesisBus.prototype._makeNewMessage = function() {
        return new AmazonKinesisMessage(this);
    };
    AmazonKinesisBus.prototype._send = function(message) {
        if(!(message instanceof AmazonKinesisMessage)) { throw new Error("Bad type of message"); }
        $KMessageBusPlatformSupport.sendMessageToBus(
            "$AmazonKinesis",
            this._platformBusId,
            this._streamName,
            undefined,
            message._reliability,
            JSON.stringify(message._body)
        );
    };

    var AmazonKinesisMessage = function(amazonKinesisBus) {
        this._init(amazonKinesisBus);
    };
    AmazonKinesisMessage.prototype = new Message();

    O.$messageBusKinesisMessageAction = function(busName, jsonMessage, action, reportStatus, reportInformation) {
        var kinesisBusses = $registry.$messageBusKinesis;
        if(!kinesisBusses) { return; }
        var bus = kinesisBusses[busName];
        if(!bus) {
            console.log("Unexpectedly dropping message for Kinesis bus", busName);
            return;
        }
        var message = new AmazonKinesisMessage(bus);
        message.body(JSON.parse(jsonMessage));
        if(action === "deliver") {
            bus._receive(message);
        } else if(action === "report") {
            bus._deliveryReport(reportStatus, JSON.parse(reportInformation), message);
        } else {
            throw new Error("logic error for action "+action);
        }
    };

    constructFromKeychain['Amazon Kinesis Stream'] = function(info) {
        if(!info.name) {
            throw new Error("Amazon Kinesis message bus credential error");
        }
        var kinesisBusses = $registry.$messageBusKinesis;
        if(!kinesisBusses) { $registry.$messageBusKinesis = kinesisBusses = {}; }
        var bus = kinesisBusses[info.name];
        if(!bus) { kinesisBusses[info.name] = bus = new AmazonKinesisBus(info.name); }
        return bus;
    };

    // ----------------------------------------------------------------------
    //  Amazon SQS implementation
    // ----------------------------------------------------------------------

    var AmazonSQSBus = function(queueName) {
        this._init();
        this._queueName = queueName;
    };
    AmazonSQSBus.prototype = new Bus();
    AmazonSQSBus.prototype._makeNewMessage = function() {
        return new AmazonSQSMessage(this);
    };
    AmazonSQSBus.prototype._send = function(message) {
        if(!(message instanceof AmazonSQSMessage)) { throw new Error("Bad type of message"); }
        $KMessageBusPlatformSupport.sendMessageToBus(
            "$AmazonSQS",
            this._platformBusId,
            this._queueName,
            undefined,
            message._reliability,
            JSON.stringify(message._body)
        );
    };

    var AmazonSQSMessage = function(amazonSQSBus) {
        this._init(amazonSQSBus);
    };
    AmazonSQSMessage.prototype = new Message();

    O.$messageBusSQSMessageAction = function(busName, jsonMessage, action, reportStatus, reportInformation) {
        var SQSBusses = $registry.$messageBusSQS;
        if(!SQSBusses) { return; }
        var bus = SQSBusses[busName];
        if(!bus) {
            console.log("Unexpectedly dropping message for SQS bus", busName);
            return;
        }
        var message = new AmazonSQSMessage(bus);
        message.body(JSON.parse(jsonMessage));
        if(action === "deliver") {
            bus._receive(message);
        } else if(action === "report") {
            bus._deliveryReport(reportStatus, JSON.parse(reportInformation), message);
        } else {
            throw new Error("logic error for action "+action);
        }
    };

    constructFromKeychain['Amazon SQS Queue'] = function(info) {
        if(!info.name) {
            throw new Error("Amazon SQS message bus credential error");
        }
        var SQSBusses = $registry.$messageBusSQS;
        if(!SQSBusses) { $registry.$messageBusSQS = SQSBusses = {}; }
        var bus = SQSBusses[info.name];
        if(!bus) { SQSBusses[info.name] = bus = new AmazonSQSBus(info.name); }
        return bus;
    };

    // ----------------------------------------------------------------------
    //  Amazon SNS implementation
    // ----------------------------------------------------------------------

    var AmazonSNSBus = function(queueName) {
        this._init();
        this._queueName = queueName;
    };
    AmazonSNSBus.prototype = new Bus();
    AmazonSNSBus.prototype._makeNewMessage = function() {
        return new AmazonSNSMessage(this);
    };
    AmazonSNSBus.prototype._send = function(message) {
        if(!(message instanceof AmazonSNSMessage)) { throw new Error("Bad type of message"); }
        $KMessageBusPlatformSupport.sendMessageToBus(
            "$AmazonSNS",
            this._platformBusId,
            this._queueName,
            undefined,
            message._reliability,
            JSON.stringify(message._body)
        );
    };

    var AmazonSNSMessage = function(amazonSNSBus) {
        this._init(amazonSNSBus);
    };
    AmazonSNSMessage.prototype = new Message();

    O.$messageBusSNSMessageAction = function(busName, jsonMessage, action, reportStatus, reportInformation) {
        var SNSBusses = $registry.$messageBusSNS;
        if(!SNSBusses) { return; }
        var bus = SNSBusses[busName];
        if(!bus) {
            console.log("Unexpectedly dropping message for SNS bus", busName);
            return;
        }
        var message = new AmazonSNSMessage(bus);
        message.body(JSON.parse(jsonMessage));
        if(action === "deliver") {
            bus._receive(message);
        } else if(action === "report") {
            bus._deliveryReport(reportStatus, JSON.parse(reportInformation), message);
        } else {
            throw new Error("logic error for action "+action);
        }
    };

    constructFromKeychain['Amazon SNS Topic'] = function(info) {
        if(!info.name) {
            throw new Error("Amazon SNS message bus credential error");
        }
        var SNSBusses = $registry.$messageBusSNS;
        if(!SNSBusses) { $registry.$messageBusSNS = SNSBusses = {}; }
        var bus = SNSBusses[info.name];
        if(!bus) { SNSBusses[info.name] = bus = new AmazonSNSBus(info.name); }
        return bus;
    };

    // ----------------------------------------------------------------------
    //  Report back config for each bus to set platform delivery
    // ----------------------------------------------------------------------

    O.$private.$callBeforePluginOnLoad.push(function() {
        var config = {};
        _.each($registry.$messageBusByPlatformId || {}, function(bus, id) {
            config[id] = bus._getPlatformConfig();
        });
        $KMessageBusPlatformSupport.setBusPlatformConfig(JSON.stringify(config));
    });

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
            if(!construct) { throw new Error("Unknown Message Bus kind in keychain: "+info.kind); }
            var bus = construct(info);
            bus._platformBusId = info._platformBusId;
            var byId = $registry.$messageBusByPlatformId;
            if(!byId) { $registry.$messageBusByPlatformId = byId = {}; }
            byId[info._platformBusId] = bus;
            return bus;
        }
    };

})();
