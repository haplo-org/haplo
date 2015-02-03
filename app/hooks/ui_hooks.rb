# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KHooks

  [:hNavigationPosition, :hNavigationPositionAnonymous].each do |nav_hook_name|
    define_hook nav_hook_name do |h|
      h.argument    :name,        Symbol,   "Configured position name"
      h.result      :navigation,  "js:NavigationBuilder",   nil,  "NavigationBuilder object for adding entries to the navigation"
    end
  end

  define_hook :hTrayPage do |h|
    h.result      :buttons,     Hash,     "{}", "Hash of String (button name) to Array of [url_path,menu_text] for the menu"
  end

  define_hook :hHelpPage do |h|
    h.result      :redirectPath,String,   nil,  "If set, the user will be redirected to this path instead of viewing the built-in help pages"
  end

end
