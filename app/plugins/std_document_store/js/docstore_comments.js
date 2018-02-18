/* Haplo Platform                                    https://haplo.org
 * (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// checkPermissions called with key & action, where action is 'addComment', 'viewComments' or 'viewCommentsOtherUsers'
P.implementService("std:document_store:comments:respond", function(E, docstore, key, checkPermissions) {
    E.response.kind = 'json';

    // Check permission
    if(!checkPermissions(key, (E.request.method === "POST") ? 'addComment' : 'viewComments')) {
        E.response.body = JSON.stringify({result:"error",message:"Permission denied"});
        E.response.statusCode = HTTP.UNAUTHORIZED;
        return;
    }

    var instance = docstore.instance(key);
    var response = {result:"success"};

    if(E.request.method === "POST") {
        // Add a comment for this user
        var version = parseInt(E.request.parameters.version,10),
            formId = E.request.parameters.form,
            elementUName = E.request.parameters.uname,
            comment = E.request.parameters.comment;
        if(!(version && formId && elementUName && comment && (formId.length < 200) && (elementUName.length < 200) && (comment.length < 131072))) {
            response.result = "error";
            response.method = "Bad parameters";
        } else {
            var row = docstore.commentsTable.create({
                keyId: instance.keyId,
                version: version,
                userId: O.currentUser.id,
                datetime: new Date(),
                formId: formId,
                elementUName: elementUName,
                comment: comment
            });
            row.save();
            response.comment = rowForClient(row);
            response.commentUserName = O.currentUser.name;
        }

    } else {
        // Return all comments for this document
        var users = {}, forms = {};
        var allComments = docstore.commentsTable.select().
            where("keyId","=",instance.keyId).
            order("datetime", true);    // latest comments first
        if(!checkPermissions(key, 'viewCommentsOtherUsers')) {
            allComments.where("userId","=",O.currentUser.id);
        }
        var onlyCommentsForForm = E.request.parameters.onlyform;
        if(onlyCommentsForForm) { allComments.where("formId","=",onlyCommentsForForm); }
        _.each(allComments, function(row) {
            var form = forms[row.formId];
            if(!form) { form = forms[row.formId] = {}; }
            var comments = form[row.elementUName];
            if(!comments) { comments = form[row.elementUName] = []; }
            comments.push(rowForClient(row));
            var uid = row.userId;
            if(!users[uid]) {
                users[uid] = O.user(uid).name;
            }
        });
        response.users = users;
        response.forms = forms;
    }

    E.response.body = JSON.stringify(response);
});

// --------------------------------------------------------------------------

var rowForClient = function(row) {
    return {
        id: row.id,
        uid: row.userId,
        version: row.version,
        datetime: (new XDate(row.datetime)).toString("dd MMM yyyy HH:mm"),
        comment: row.comment
    };
};
