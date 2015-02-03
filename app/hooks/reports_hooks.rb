# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KHooks

  define_hook :hGetReportsList do |h|
    h.result      :reports,     Array,    "[]",   "An array containing a list of reports. Append [url_path,report_name]"
  end

end
