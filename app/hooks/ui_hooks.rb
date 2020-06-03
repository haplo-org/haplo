# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
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

  define_hook :hPreSearchUI do |h|
    h.argument    :query,       String,   "Search query"
    h.argument    :subset,      KObjRef,  "Selected search subset"
    h.result      :redirectPath,String,   nil,  "If set, the user will be redirected to this path instead of viewing the search results"
  end

end
