# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KHooks

  define_hook :hElementDiscover do |h|
    h.result      :elements,    Array,    "[]",   "Append an array of [name, description] for each Element."
  end

  define_hook :hElementRender do |h|
    h.argument    :name,        String,   "The name of the Element to render"
    h.argument    :path,        Symbol,   "Where the Element is being rendered"
    h.argument    :object,      KObject,  "The object the Element is being displayed with, or null"
    h.argument    :style,       Symbol,   "How the Element should be rendered"
    h.argument    :options,     String,   "Options for rendering the Element"
    h.result      :title,       String,   nil,    "The title to be displayed above this Element, or the empty string for no title"
    h.result      :html,        String,   nil,    "The HTML to output for this Element"
  end

end
