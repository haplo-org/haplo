# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KHooks

  define_hook :hNewObjectPage do |h|
    h.result      :htmlAfter,   String,   "''", "Append to this string to add extra HTML after the object display"
  end

  define_hook :hPreObjectEdit do |h|
    h.argument    :object,      KObject,  "The object being edited"
    h.argument    :isTemplate,  "bool",   "Whether this object is a proposed template for a new object"
    h.argument    :isNew,       "bool",   "Whether this object is a new object"
    h.result      :replacementObject, KObject, nil, "An object to edit in place of the given object, or null for no effect"
    h.result      :readOnlyAttributes, Array, "[]", "An array containing a list attributes which are read only for this object"
    h.result      :restrictionLiftedAttributes, Array, [], "DEPRECATED (will be removed in later version, use hObjectAttributeRestrictionLabelsForUser instead): An array containing a list of attributes for which read-only and hidden attribute restrictions should not be applied for this object"
    h.result      :redirectPath,String,   nil,  "If set, the user will be redirected to this path instead of editing the object"
  end

  define_hook :hObjectEditor do |h|
    h.private_hook  # until the interface is complete
    h.argument    :object,      KObject,  "The object being edited"
    h.result      :plugins,     Hash,     "{}", "Hash of String (delegate name) to JSON-serialisable data for plugin"
  end

  define_hook :hLabellingUserInterface do |h|
    h.argument    :object,      KObject,  "Object which is about to be edited"
    h.argument    :user,        User,     "SecurityPrincipal representing the user who is editing the object"
    h.argument    :operation,   Symbol,   "What operation is being performed: 'create' or 'update'"
    h.result      :ui,          "js:LabellingUserInterface",   nil,  "LabellingUserInterface object representing extra labelling UI"
  end

  define_hook :hPostObjectEdit do |h|
    h.argument    :object,      KObject,  "The object being edited"
    h.argument    :previous,    KObject,  "The previous version of the object, or null"
    h.result      :replacementObject, KObject, nil, "An object to store in place of the edited object, or null for no effect"
    h.result      :redirectPath,String,   nil,  "If set, the user will be redirected to this path instead of the newly edited object"
  end

  define_hook :hObjectDeleteUserInterface do |h|
    h.argument    :object,      KObject,  "The object the user would like to delete"
    h.result      :redirectPath,String,   nil,  "If set, the user will be redirected to this path instead of the built-in object deletion user interface"
  end

end
