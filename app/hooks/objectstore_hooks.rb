# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
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

end
