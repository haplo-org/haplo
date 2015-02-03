# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KHooks

  define_hook :hPreObjectDisplay do |h|
    h.argument    :object,      KObject,  "The object being displayed"
    h.result      :replacementObject, KObject, nil, "An object to display in place of the given object, or null for no replacement"
    h.result      :redirectPath,String,   nil,  "If set, the user will be redirected to this path instead of displaying the object"
  end

  define_hook :hObjectDisplay do |h|
    h.argument    :object,      KObject,        "The object being displayed"
    h.result      :hideModificationInfo,  "bool", "false", "Set to true to hide the modification info after the object"
    h.result      :buttons,     Hash,     "{}", "Hash of String (button name) to Array of [url_path,menu_text] for the menu"
  end

end
