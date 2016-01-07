# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KHooks

  define_hook :hAuditEntryOptionalWrite do |h|
    h.argument    :entry,         AuditEntry,   "The proposed audit entry"
    h.argument    :defaultWrite,  "bool",       "Whether the audit entry is configured to be written by default"
    h.result      :write,         "bool",       "nil",    "Whether the proposed audit entry should be written"
  end

  define_hook :hAuditEntryOptionalWritePolicy do |h|
    h.private_hook
    h.result      :policies,      Array,        "[]",     "Array of strings defining policy."
  end

end
