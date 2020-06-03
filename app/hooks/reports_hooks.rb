# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module KHooks

  define_hook :hGetReportsList do |h|
    h.result      :reports,     Array,    "[]",   "An array containing a list of reports. Append [url_path,report_name]"
  end

end
