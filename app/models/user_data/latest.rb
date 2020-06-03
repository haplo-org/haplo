# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



# Constants for data in UserData for Latest updates system

module UserData::Latest

  FORMAT_PLAIN      = 0
  FORMAT_HTML       = 1

  SCHEDULE_NEVER    = 0 #SYNC_TO_JAVASCRIPT
  SCHEDULE_DAILY    = 1
  SCHEDULE_WEEKLY   = 2
  SCHEDULE_MONTHLY  = 3

  DEFAULT_FORMAT    = FORMAT_HTML
  DEFAULT_SCHEDULE  = "#{SCHEDULE_NEVER}:1:1:1"

end
