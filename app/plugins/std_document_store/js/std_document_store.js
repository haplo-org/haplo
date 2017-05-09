/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// DocumentStore - multi-page, versioned documents
// DocumentInstance - JS object representing the store
// key item - another JS object used as a key for this document
// keyId - a value derived from the key item to use as the key in the database (by default is just the key)
// current document - a "work in progress" which may become a new version of the document
// committed versions - current document is committed to become a timed version

// Delegate has properties:
//    name - of store (short string) - REQUIRED
//    keyIdType - type of keyId, if not "int"
// Delegate has methods:
//    formsForKey(key, instance, document) - return an array of forms - REQUIRED
//    keyToKeyId(key) - convert key to a keyId
//    blankDocumentForKey(key) - create a blank document for a key
//    formIdFromRequest(request) - given a request, return a form ID (default just takes the second extraPathElements)
//    prepareFormInstance(key, form, instance, context) - prepare a form instance for "form" or "document" (optional)
//    shouldDisplayForm(key, form, document) - return booleans about whether to display this form
//    shouldEditForm(key, form, document) - return booleans about whether to edit this form
//    alwaysShowNavigation(key, instance, document) - return true to always show navigation, regardless of whether the editor thinks it's useful
//    updateDocumentBeforeEdit(key, instance, document) - called when editing the form allowing for the document to be updated
//    onSetCurrentDocument(instance, document, isComplete) - called when current document is set
//    onCommit(instance, user) - called when a new version is committed
//    getAdditionalUIForViewer(key, instance, document) - called when a document is rendered, return object with
//          optional properties 'top' and 'bottom' of deferred renders to display
//    getAdditionalUIForEditor(key, instance, document, form) - called when a form for a document is edited, return object with
//          optional properties 'top', 'formTop', 'formBottom' and 'bottom' of deferred renders to display

P.provideFeature("std:document_store", function(plugin) {
    var DocumentStore = P.DocumentStore;
    plugin.defineDocumentStore = function(delegate) {
        return new DocumentStore(plugin, delegate);
    };
});
