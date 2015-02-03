# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KAuditing

  # See also: file_store_auditing for auditing of file downloads & transforms

  # Object has been displayed

  KNotificationCentre.when(:display, :object) do |name, operation, obj, source|
    AuditEntry.write(
      :kind => 'DISPLAY',
      :objref => obj.objref,
      :displayable => false,
      :data => source ? {"source" => source} : nil
    ) do |e|
      e.ask_plugins_with_default(KApp.global_bool(:audit_object_display))
      e.cancel_if_repeats_previous
    end
  end

  # ----------------------------------------------------------------------------------------

  # Search and demand loaded results

  KNotificationCentre.when(:display, :search) do |name, operation, spec|
    raise "Search spec has no audit data" unless spec[:audit]
    AuditEntry.write(
      :kind => 'SEARCH',
      :data => spec[:audit],
      :displayable => false
    ) do |e|
      e.ask_plugins_with_default(KApp.global_bool(:audit_search))
      e.cancel_if_repeats_previous
    end
  end

  # ----------------------------------------------------------------------------------------

  # Export results (always audited)

  KNotificationCentre.when(:display, :export) do |name, operation, spec|
    raise "Search spec for export has no audit data" unless spec[:audit]
    AuditEntry.write(
      :kind => 'EXPORT',
      :data => spec[:audit],
      :displayable => false
    )
  end

end
