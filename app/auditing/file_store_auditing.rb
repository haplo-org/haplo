# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module KAuditing

  # Files are not labelled, because they're used as values in other data structures.
  # File versions are part of an object history, and visibility is controlled by object labels.

  # StoredFile creations and duplicate uploads
  KNotificationCentre.when(:file_store, :new_file) do |name, operation, stored_file, disposition|
    data = {
      "digest" => stored_file.digest,
      "size" => stored_file.size,
      "filename" => stored_file.upload_filename
    }
    data["duplicate"] = true if disposition == :duplicate
    AuditEntry.write(
      :kind => 'FILE-CREATE',
      :entity_id => stored_file.id,
      :data => data,
      :displayable => false
    )
  end

  # ----------------------------------------------------------------------------------------

  # Optionally audit downloads
  KNotificationCentre.when(:file_controller, :download) do |name, operation, stored_file, filespec|
    data = {'digest' => stored_file.digest, 'size' => stored_file.size}
    data['transform'] = filespec if filespec && filespec.length > 0
    AuditEntry.write(
      :kind => 'FILE-DOWNLOAD',
      :entity_id => stored_file.id,
      :displayable => false,
      :data => data
    ) do |e|
      e.ask_plugins_with_default(KApp.global_bool(:audit_file_downloads))
      e.cancel_if_repeats_previous
    end
  end

end
