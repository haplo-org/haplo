/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// std_workflow takes over notifications and uses the M.sendEmail() function
// to use workflow infrastructure to add features to the built in platform
// notifications. The platform still controls when notifications are sent.

// --------------------------------------------------------------------------

// Use platform private API
var GenericDeferredRender = $GenericDeferredRender;

// --------------------------------------------------------------------------

P.WorkflowInstanceBase.prototype._workUnitNotify = function(workUnit) {
    var notify = new NotificationView();
    // Returning false from the notification handler cancels the notification.
    if(false !== this._callHandler('$notification', notify)) {
        // Build a specification for M.sendEmail()
        notify._finalise(this);
        var specification = {
            template: P.template("email/generic-notification"),
            view: notify,
            // to matches platform's implementation
            to: [this.workUnit.actionableBy],
            // empty array for all the other properties, so it's easier to use.
            cc: [],
            except: [],
            toExternal: [],
            ccExternal: []
        };
        // Let workflows modify the email that's about to be sent
        this._callHandler('$notificationModifySendEmail', specification);
        this.sendEmail(specification);
    }
    // std_workflow has implemented everything itself, so the platform shouldn't do anything
    return null;
};

// --------------------------------------------------------------------------

var NotificationView = function() {
    this.$headerDeferreds = [];
    this.$notesDeferreds = [];
    this.$endDeferreds = [];
};
NotificationView.prototype = {
    addHeaderDeferred: function(deferred) {
        this.$headerDeferreds.push(deferred);
    },
    addNoteDeferred: function(deferred) {
        this.$notesDeferreds.push(deferred);
        return this;
    },
    addNoteText: function(notes) {
        this.$notesDeferreds.push(P.template('email/status-notes-text').deferredRender({notes:notes}));
        return this;
    },
    addNoteHTML: function(html) { // TODO: Remove addNoteHTML() when possible
        console.log("In workflow notification handler, addNoteHTML() is deprecated, use addNoteDeferrred() instead");
        this.addNoteDeferred(new GenericDeferredRender(function() { return html; }));
        return this;
    },
    addEndDeferred: function(deferred) {
        this.$endDeferreds.push(deferred);
        return this;
    },
    addEndHTML: function(html) { // TODO: Remove addEndHTML() when possible
        console.log("In workflow notification handler, addEndHTML() is deprecated, use addEndDeferred() instead");
        this.addEndDeferred(new GenericDeferredRender(function() { return html; }));
        return this;
    },
    _finalise: function(M) {
        // Basic defaults have slightly different logic to platform
        if(!this.title)        { this.title = M._call('$taskTitle'); }
        if(!this.emailSubject) { this.emailSubject = this.title; }
        if(!this.action)       { this.action = M._call('$taskUrl'); }
        this.$actionFullUrl = O.application.url + this.action;
        if(!this.status) {
            var statusText = M._getTextMaybe(['notification-status', 'status'], [M.state]);
            if(statusText) { this.status = statusText; }
        }
        if(!this.button) {
            var buttonLabel = M._getTextMaybe(['notification-action-label', 'action-label'], [M.state]);
            if(buttonLabel) { this.button = buttonLabel; }
        }
        if(0 === this.$notesDeferreds.length) {
            // If there aren't any notes, use the workflow text system to find some 
            var notesText = M._getTextMaybe(['notification-notes'], [M.state]);
            if(notesText) { this.addNoteText(notesText); }
        }
        return this;
    }
};
