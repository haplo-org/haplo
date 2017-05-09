/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var allNoteSpec = {};

var MAX_NOTIFICATION_NOTE_AGE_IN_HOURS = 48;

// --------------------------------------------------------------------------

P.registerWorkflowFeature("std:notes", function(workflow, spec) {

    var canSeePrivateNotes = (typeof(spec.canSeePrivateNotes) === 'function') ? spec.canSeePrivateNotes : function() { return false; };
    var canAddNonTransitionNote = (typeof(spec.canAddNonTransitionNote) === 'function') ? spec.canAddNonTransitionNote : function() { return true; };

    allNoteSpec[workflow.fullName] = {
        canSeePrivateNotes: canSeePrivateNotes,
        canAddNonTransitionNote: canAddNonTransitionNote
    };

    workflow.renderTimelineEntryDeferred(function(M, entry) {
        if(entry.action !== 'NOTE') { return; }
        if(entry.data['private'] && !canSeePrivateNotes(M, O.currentUser)) { return; }
        return P.template("timeline/note").deferredRender({
            M: M,
            showEditLink: !(M.workUnit.closed) && entry.user.id === O.currentUser.id,
            entry: entry
        });
    });

    // Display link to add note, but only if workflow is in progress
    workflow.actionPanel({closed:false}, function(M, builder) {
        if(canAddNonTransitionNote(M, O.currentUser)) {
            builder.panel(1500).link("default", "/do/workflow/note/"+M.workUnit.id, "Add note", "standard");
        }
    });

    // Provide access to notification note rendering to workflows
    workflow.$instanceClass.prototype.notesDeferredRenderForNotificationEmail = notesDeferredRenderForNotificationEmail;

    // Include the latest notes in the notification emails
    workflow.notification({}, function(M, notify) {
        var notes = M.notesDeferredRenderForNotificationEmail(M.workUnit.actionableBy);
        if(notes) { notify.addEndDeferred(notes); }
    });

    // Display the notes forms on the transition page
    workflow.transitionUI({}, function(M, E, ui) {
        var userCanSeePrivateNotes = canSeePrivateNotes(M, O.currentUser);
        var parameters = E.request.parameters;
        ui.addFormDeferred("bottom", P.template("notes/transition-notes-form").deferredRender({
            canSeePrivateNotes: userCanSeePrivateNotes,
            everyoneNoteExplaination: M._getTextMaybe(['notes-explanation-everyone'], ['transition-ui']) ||
                NAME("std:workflow:notes-explanation-everyone", "Notes can be seen by the applicant and all staff reviewing this application."),
            privateNoteExplaination: M._getTextMaybe(['notes-explanation-private'], ['transition-ui']) ||
                NAME("std:workflow:notes-explanation-private", "Seen only by staff reviewing this application, not seen by the applicant."),
            notes: parameters['notes'],
            privateNotes: parameters['privateNotes']
        }));
    });

    // Save the notes when the transition form is submitted
    // Use transitionFormPreTransition rather than transitionFormSubmitted, so that if other
    // parts of the workflow prevent the transition, the notes won't be added.
    workflow.transitionFormPreTransition({}, function(M, E, ui) {
        var saveNote = function(isPrivate, name) {
            var text = _.trim(E.request.parameters[name] || '');
            if(text.length > 0) {
                var data = {text:text};
                if(isPrivate) { data['private'] = true; }
                M.addTimelineEntry('NOTE', data);
            }
        };
        saveNote(false, "notes");
        if(canSeePrivateNotes(M, O.currentUser)) { saveNote(true, "privateNotes"); }
    });

});

// --------------------------------------------------------------------------

var notesDeferredRenderForNotificationEmail = function(toUser) {
    var noteSpec = allNoteSpec[this.workUnit.workType];
    if(!noteSpec) { return; }
    var userCanSeePrivateNotes = noteSpec.canSeePrivateNotes(this, toUser);

    var notes = this.timelineSelect().
        where("action","=","NOTE").
        where("datetime",">",(new XDate()).addHours(0 - MAX_NOTIFICATION_NOTE_AGE_IN_HOURS)).order("datetime",true);
    var notesForEmail = [];
    _.each(notes, function(entry) {
        var isPrivate = entry.data["private"];
        if(userCanSeePrivateNotes || !isPrivate) {
            notesForEmail.push({
                text: entry.data.text,
                dateAndTime: (new XDate(entry.datetime)).toString("dd MMM yyyy HH:mm"),
                isPrivate: isPrivate,
                author: entry.user.name
            });
        }
    });

    if(notesForEmail.length === 0) { return; }
    return P.template("email/notes").deferredRender({
        maxAge: MAX_NOTIFICATION_NOTE_AGE_IN_HOURS,
        notes: notesForEmail
    });
};

// --------------------------------------------------------------------------

P.respond("GET,POST", "/do/workflow/note", [
    {pathElement:0, as:"workUnit", allUsers:true},
    {parameter:"e", as:"int", optional:true},
    {parameter:"note", as:"string", optional:true},
    {parameter:"private", as:"string", optional:true}
], function(E, workUnit, entryId, note, privateNote) {
    if(workUnit.closed) { O.stop("Workflow is complete"); }
    var workflow = P.allWorkflows[workUnit.workType];
    if(!workflow) { O.stop("No workflow"); }
    var noteSpec = allNoteSpec[workUnit.workType];
    if(!noteSpec) { O.stop("No notes on this workflow"); }
    var M = workflow.instance(workUnit);
    var taskUrl = M._call('$taskUrl');

    var userCanSeePrivateNotes = noteSpec.canSeePrivateNotes(M, O.currentUser);
    var entry;
    if(entryId) {
        entry = M.$timeline.load(entryId);
        if(!entry || (entry.workUnitId !== M.workUnit.id)) { O.stop("Wrong task"); }
        if(O.currentUser.id !== entry.user.id) { O.stop("Unauthorised"); }
    }

    var view = {
        taskTitle: M._call('$taskTitle'),
        taskUrl: taskUrl,
        privateNoteExplaination: M._getTextMaybe(['notes-explanation-private'], ['add-note']),
        userCanSeePrivateNotes: userCanSeePrivateNotes,
        isPrivate: entry ? !!(entry.data['private']) : userCanSeePrivateNotes,
        entry: entry,
        note: entry ? entry.data.text : ""
    };

    if(E.request.method === "POST") {
        note = _.trim(note);
        if(!note) {
            if(!entry) {
                return E.response.redirect(taskUrl);
            } else {
                note = '(REMOVED)';
            }
        }
        var timelineData = {
            "text": note,
            "private": ((privateNote === "yes") && userCanSeePrivateNotes)
        };
        if(entry) {
            entry.json = JSON.stringify(timelineData);
            entry.save();
        } else {
            M.addTimelineEntry('NOTE', timelineData);
        }
        return E.response.redirect(taskUrl);
    }

    E.render(view, "notes/add-note");
});
