# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module KAuditing

  # A note has been added to the audit trail by the administrator

  KNotificationCentre.when(:admin_ui, :add_note) do |name, operation, note|
    raise "Bad admin note" unless note.kind_of? String
    AuditEntry.write(
      :kind => 'NOTE',
      :displayable => false,
      :data => {"note" => note}
    )
  end

end
