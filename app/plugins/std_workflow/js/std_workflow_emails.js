/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Generic email sending mechanism for workflows, also used for generic notifications
// on transitions when prompted by the platform.


// Set a template for sending emails
P.Workflow.prototype.emailTemplate = function(template) {
    this.$instanceClass.prototype.$emailTemplate = template;
};

// Default to the email template defined in requirements.schema
P.WorkflowInstanceBase.prototype.$emailTemplate = "std:email-template:workflow-notification";

// --------------------------------------------------------------------------

// USE OF M.sendEmail()
//
// specification has keys:
//      template - Template object, or name of template within consuming plugin
//          When used as a notification, template need not be specified and defaults
//          to "notification/NAME" where NAME is the name of the notification.
//      view - view for rendering template
//          If view is a function, the function is called to generate the view
//          with M as the single argument.
//      to - list of recipients
//      cc - CC list, only sent if the to list includes at least one entry
//      except - list of recipients to *not* send stuff to
//      toExternal - list of external recipients, as objects with at least
//          email, nameFirst & name properties. Note that external recipients don't
//          get de-duplicated or respect the 'except' property.
//          If a list entry if a function, that function will be called with
//          a M argument, and should return an object or a list of objects
//          as above.
//      ccExternal - external CC list, objects as toExternal
//
// Object is created with view as a prototype. This new view is passed to the
// template with additional properties:
//      M - workflow instance
//      toUser - the user the email is being sent to
//
// Recipients lists can be specified directly, or as a function which is called
// with M as a single argument. The function version of the specification is
// useful when passing sendEmail() specifications as configuration to workflow
// components.
//
// Recipients lists can contains:
//      Strings,
//          when ending _refMaybe, _refList, _ref, _maybe, _list: recipients from
//              M.entities (which will be adjusted to use 'ref'/'maybe' variants
//              for efficiency)
//          otherwise: as actionableBy names resolved by M.getActionableBy(),
//              which for entity names, will give as result as using entities.
//              When used standalone, will use entity lookup for this case too.
//      SecurityPrincipal objects (users or groups)
//      numeric user/group IDs (eg from the Group schema dictionary)
//      Ref of a user, looked up with O.user()
//      Anything with a ref property which is a Ref (eg StoreObject), then treated as Ref
//      An array of any of the above (nesting allowed)
//      The above allows you to use entities with code like M.entities.supervisor_list
// Note that if there's a single recipient, it can be specified without enclosing it in an array.
//
// Email subject should be set in view as emailSubject, or preferably use the emailSubject() template function
//
//
// NOTIFICATIONS
//
// Notifications are pre-defined 'notification' emails, as a lookup of name to
// sendEmail() specification. The template name can be left out of these
// specifications, as it will default to templates in the notification/
// directory with the same name as the notification.
//
// Use Workflow.notifications() to create one or more notifications, then 
// M.sendNotification() to send one.
//
// When the workflow enters a state (or passes through a dispatch state),
// the notification with the same name as the state is automatically sent.
//
// Remember that the sendEmail() spec is created when the plugin is loaded,
// so view will have to be a function, so ideally use strings to specific
// recipients. If necessary use a function for recipients.
//
// devtools has a feature to send test emails from all defined notifications.

// --------------------------------------------------------------------------

const IS_ENTITY_NAME = /_(refMaybe|refList|ref|maybe|list)$/;
const MATCH_ENTITY_SUFFIX = /(|_[a-zA-Z]+)$/;
const ENTITY_SUFFIX_REPLACEMENTS = {
    "": "_refMaybe",
    "_ref": "_refMaybe",
    "_maybe": "_refMaybe",
    "_list": "_refList"
};

var toId = function(u) { return u.id; };

var sendEmail = function(specification, entities, M) {
    if(M) {
        // Allow global changes (which have to be quite carefully written)
        var modify = {specification:specification};
        M._call('$modifySendEmail', modify);
        specification = modify.specification;   
    }

    var except = _generateEmailRecipientList(specification.except, [], entities, M).map(toId);
    var to = _generateEmailRecipientList(specification.to, except, entities, M);
    var cc = _generateEmailRecipientList(specification.cc, except.concat(to.map(toId)), entities, M);

    // Add in any external recipients
    if("toExternal" in specification) { to = to.concat(_externalEmailRecipients(specification.toExternal, M)); }
    if("ccExternal" in specification) { cc = cc.concat(_externalEmailRecipients(specification.ccExternal, M)); }

    // NOTE: If any additional properties are added, initialise them to something easy
    // to use in std_workflow_notifications.js

    // Obtain the message template
    var template = specification.template;
    if(!template) { throw new Error("No template specified to sendEmail()"); }
    if(typeof(template) === "string") {
        if(M) {
            template = M.$plugin.template(template);
        } else {
            throw new Error("template property for sendEmail can only be a string when called on a workflow object. Use P.template() to obtain a Template object.");
        }
    }

    // Set up the initial template
    var view = Object.create(
        // view property is a template view, or a function which generates the view
        ((typeof(specification.view) === "function") ? specification.view(M) : specification.view) || {}
    );
    if(M) {
        view.M = M;
    }
    // Get the email template
    var emailTemplate;
    if(M) {
        emailTemplate = O.email.template(M.$emailTemplate);
    } else {
        emailTemplate = O.email.template("std:email-template:workflow-notification");
    }    

    // Send emails to the main recipients
    var firstBody, firstSubject, firstUser;
    to.forEach(function(user) {
        view.toUser = user;
        var body = template.render(view);
        var subject = view.emailSubject || 'Notification';
        if(!firstBody) { firstBody = body; firstSubject = subject; }    // store for CC later
        emailTemplate.deliver(user.email, user.name, subject, body);
    });

    // CCed emails have a header added
    if(cc && firstBody) {
        var ccTemplate = P.template("email/cc-header");
        view.$std_workflow = {
            unsafeOriginalEmailBody: firstBody,
            sentUser: to[0]
        };
        cc.forEach(function(user) {
            view.toUser = user;
            var body = ccTemplate.render(view);
            emailTemplate.deliver(user.email, user.name, "(CC) "+firstSubject, body);
        });
    }
};

var _generateEmailRecipientList = function(givenList, except, entities, M) {
    if(typeof(givenList) === "function") {
        givenList = givenList(M);
    }
    var outputList = [];
    var pushRecipient = function(r) {
        if(r && (-1 === except.indexOf(r.id)) && r.email && r.isActive) {
            for(var l = 0; l < outputList.length; ++l) {
                if(outputList[l].id === r.id) { return; }
            }
            outputList.push(r);
        }
    };
    _.flatten([givenList || []]).forEach(function(recipient) {
        if(recipient) {
            switch(typeof(recipient)) {
                case "string":
                    if(!M || IS_ENTITY_NAME.test(recipient)) {
                        // Adjust given entity name to 1) use maybe variants, so missing entities don't exception
                        // and 2) use ref variants, to avoid loading objects from the store unnecessarily.
                        var recipientEntityName = recipient.replace(MATCH_ENTITY_SUFFIX, function(_, suffix) {
                            return ENTITY_SUFFIX_REPLACEMENTS[suffix] || suffix;
                        });
                        _.each(_.flatten([entities[recipientEntityName]]), function(ref) {
                            if(ref) { pushRecipient(O.user(ref)); }
                        });
                    } else {
                        pushRecipient(M.getActionableBy(recipient));
                    }
                    break;
                case "number":
                    pushRecipient(O.securityPrincipal(recipient));
                    break;
                default:
                    if(O.isRef(recipient)) {
                        pushRecipient(O.user(recipient));
                    } else if(recipient instanceof $User) {
                        pushRecipient(recipient);
                    } else if(("ref" in recipient) && recipient.ref) {
                        pushRecipient(O.user(recipient.ref));
                    } else {
                        throw new Error("Unknown recipient kind " + recipient);
                    }
                    break;
            }
        }
    });
    return outputList;
};

var _externalEmailRecipients = function(givenList, M) {
    var outputList = [];
    _.flatten([givenList || []]).forEach(function(recipient) {
        if(typeof(recipient) === "function") {
            recipient = recipient(M);   // may return a list of recipients
        }
        if(recipient) {
            outputList.push(recipient);
        }
    });
    return _.flatten(outputList);
};

P.WorkflowInstanceBase.prototype.sendEmail = function(specification) {
    sendEmail(specification, this.entities, this);
};

P.implementService("std:workflow_emails:send_email", function(specification, entities) {
    sendEmail(specification, entities);
});

// --------------------------------------------------------------------------

// $notifications = {} in WorkflowInstanceBase constructor function

// Define notifications
P.Workflow.prototype.notifications = function(notifications) {
    _.extend(this.$instanceClass.prototype.$notifications, notifications);
    return this;
};

// Explicitly send a notification email
P.WorkflowInstanceBase.prototype.sendNotification = function(name) {
    var specification = this.$notifications[name];
    if(!specification) { throw new Error("Notification "+name+" is not defined"); }
    // Notification template names can be implicit
    if(!specification.template) {
        specification = Object.create(specification);
        specification.template = "notification/"+name;
    }
    this.sendEmail(specification);
};

// Automatically send a notification when entering state
P.WorkflowInstanceBase.prototype._maybeSendNotificationOnEnterState = function(state) {
    if(state in this.$notifications) {
        this.sendNotification(state);
    }
};

// --------------------------------------------------------------------------

// Template functions to make writing notifications easier

P.globalTemplateFunction("M:text", function(text) {
    var M = this.view.M;
    var t = M._applyFunctionListToValue('$textInterpolate', text) || text;
    this.render(P.template("n/text").deferredRender({
        // don't use std:text:paragraph as we assume there'll be lots of extra whitespace for indents
        paragraphs: _.strip(t).split(/\s*\n\s*/)
    }));
});

P.globalTemplateFunction("M:if-entity", function(entityName) {
    var ref = this.view.M.entities[entityName+"_refMaybe"];
    if(ref) {
        if(this.hasBlock(null)) { this.writeBlock(null); }
    } else {
        if(this.hasBlock("else")) { this.writeBlock("else"); }
    }
});

P.globalTemplateFunction("M:button", function(title, url) {
    var M = this.view.M;
    if(title) { title = M._applyFunctionListToValue('$textInterpolate', title) || title; }
    this.render(P.template("n/button").deferredRender({
        title: title || M.title,
        url:   url   || M.url
    }));
});

P.globalTemplateFunction("M:list", function(/* args */) {
    templateFunctionRenderList(this, _.flatten(Array.prototype.slice.call(arguments)));
});

P.globalTemplateFunction("M:entity-list", function(entityName) {
    var M = this.view.M;
    templateFunctionRenderList(this, M.entities[entityName+"_list"]);
});

var templateFunctionRenderList = function(t, items) {
    var strings = _.map(_.compact(items), function(item) {
        if(typeof(item) === "string") {
            return item;
        } else if(O.isRef(item)) {
            return item.load().title;
        } else if(item instanceof $StoreObject) {
            return item.title;
        } else {
            return ""+item;
        }
    });
    var first = strings.shift();
    var last = strings.pop();
    t.render(P.template("n/list").deferredRender({
        first: first,
        middle: strings,
        last: last
    }));
};


P.globalTemplateFunction("M:first-name", function(object) {
    return templateFunctionNamePart(this, "first", object);
});

P.globalTemplateFunction("M:last-name", function(object) {
    return templateFunctionNamePart(this, "last", object);
});

var templateFunctionNamePart = function(t, part, object) {
    if(!object) { return ""; }
    if(typeof(object) === "string") { object = t.view.M.entities[object]; }
    var title = object.firstTitle();
    if(O.typecode(title) === O.T_TEXT_PERSON_NAME) {
        var f = title.toFields();
        return f[part];
    }
    return title.toString();
};

P.globalTemplateFunction("M:switch-role", function(user) {
    var M = this.view.M;
    var haveRenderedBlock = false;
    this.getAllNamedBlockNames().forEach(function(name) {
        // If user is a Group, hasRole() won't match as groups are not members of themselves.
        // In this case compare against the group API code, so group roles work usefully.
        if(M.hasRole(user, name) || (user.isGroup && user.code === name)) {
            this.writeBlock(name);
            haveRenderedBlock = true;
        }
    }, this);
    if(!haveRenderedBlock) { this.writeBlock(null); }
});
