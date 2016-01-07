# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KHooks

  define_hook :hMainApplicationCSS do |h|
    h.result :css, String, "''", "CSS to add to the main CSS file"
  end

  define_hook :hStandardChrome do |h|
    h.result :layoutOptions, Hash, "{}", "Layout options"
    h.result :headerHTML, String, nil, "HTML for the page header"
  end

end

