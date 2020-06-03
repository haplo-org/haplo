# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KApp
  STATUS_INIT_IN_PROGRESS = 0
  STATUS_ACTIVE           = 1

  # NOTE: STATUS_TO_TEXT is used to validate status values
  STATUS_TO_TEXT = {
    STATUS_INIT_IN_PROGRESS => 'INIT',
    STATUS_ACTIVE => 'ACTIVE'
  }
end
