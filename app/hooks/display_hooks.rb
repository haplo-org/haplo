# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KHooks

  define_hook :hPreObjectDisplay do |h|
    h.argument    :object,      KObject,  "The object being displayed"
    h.result      :replacementObject, KObject, nil, "An object to display in place of the given object, or null for no replacement"
    h.result      :redirectPath,String,   nil,  "If set, the user will be redirected to this path instead of displaying the object"
  end

  define_hook :hPreObjectDisplayPublisher do |h|
    h.private_hook
    h.argument    :object,      KObject,  "The object being displayed"
    h.result      :replacementObject, KObject, nil, "An object to display in place of the given object, or null for no replacement"
  end

  define_hook :hObjectDisplay do |h|
    h.argument    :object,      KObject,        "The object being displayed"
    h.result      :hideModificationInfo,  "bool", "false", "Set to true to hide the modification info after the object"
    h.result      :buttons,     Hash,     "{}", "Hash of String (button name) to Array of [url_path,menu_text] for the menu"
    h.result      :backLink,    String,   nil,  "Link for the 'back' button for this object. Use with caution."
    h.result      :backLinkText,String,   nil,  "Label for the 'back' button for this object. Always use a noun describing the item you're linking to."
  end

  define_hook :hTempObjectAutocompleteTitle do |h|
    h.private_hook
    h.argument    :object,      KObject,    "The object for inclusion in the auto-complete list"
    h.result      :title,       String,     nil,  "The title to display in the list, or nil to remove it from the list."
  end

end
