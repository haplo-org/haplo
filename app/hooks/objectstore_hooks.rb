# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KHooks

  define_hook :hPostObjectChange do |h|
    h.argument    :object,      KObject,  "The object which has been changed"
    h.argument    :operation,   Symbol,   "What operation was performed: 'create', 'update', 'relabel' or 'erase'"
    h.argument    :previous,    KObject,  "The previous version of the object, or null"
  end

  define_hook :hLabelObject do |h|
    h.argument    :object,      KObject,  "The object which is about to be created"
    h.result      :changes,     KLabelChanges,  nil,  "Changes to apply to the label list"
  end

  define_hook :hLabelUpdatedObject do |h|
    h.argument    :object,      KObject,  "The object which is about to be updated"
    h.result      :changes,     KLabelChanges,  nil,  "Changes to apply to the label list"
  end

  define_hook :hPreIndexObject do |h|
    h.argument    :object,      KObject,  "The object which is being updated"
    h.result      :replacementObject, KObject, nil, "An object which will be indexed in place of the given object, or null for no effect"
  end

  define_hook :hObjectTextValueDiscover do |h|
    h.private_hook
    h.result      :types,       Array,    "[]",   "Append an array of [type, description] for each defined text type."
  end

  define_hook :hObjectTextValueTransform do |h|
    h.private_hook
    h.argument    :type,        String,   "Type of value"
    h.argument    :value,       String,   "Value encoded as a string"
    h.argument    :transform,   Symbol,   "Requested transform"
    h.result      :output,      String,   nil,  "Output of transform"
  end

  define_hook :hOperationAllowOnObject do |h|
    h.private_hook
    h.argument    :user,        User,     "SecurityPrincipal attempting to perform the operation"
    h.argument    :object,      KObject,  "The object to check"
    h.argument    :operation,   Symbol,   "Which operation to check: 'create', 'update', 'relabel', 'delete', 'erase'"
    h.result      :allow,       "bool",   "false",  "Whether to allow this operation"
  end

end
