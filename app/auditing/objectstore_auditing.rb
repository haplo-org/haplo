# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module KAuditing

  # Listen for object store change notifications, and write audit trail notifications.
  # Object 'reads' are handled differently, and are optional as most apps won't need it.

  OPERATION_TO_AUDIT_KIND = {
    :create => 'CREATE',
    :update => 'UPDATE',
    :relabel => 'RELABEL',
    :erase => 'ERASE'
  }

  AuditObjectChangeInfo = Struct.new(:previous, :modified, :data, :displayable)

  KNotificationCentre.when(:os_object_change) do |name, operation, previous_obj, modified_obj, is_schema|
    audit_kind = OPERATION_TO_AUDIT_KIND[operation]
    raise "Can't audit os_object_change / #{operation}" unless audit_kind

    data = {}
    if operation == :relabel
      data["old"] = previous_obj.labels._to_internal
      previous_is_deleted = previous_obj.labels.include?(KConstants::O_LABEL_DELETED)
      modified_is_deleted = modified_obj.labels.include?(KConstants::O_LABEL_DELETED)
      if previous_is_deleted != modified_is_deleted
        # It's a delete or undelete
        data["delete"] = modified_is_deleted
      end
    end

    # Only display non-schema, non-classification objects in the recent listing
    displayable = (!(is_schema) && !(modified_obj.labels.include?(KConstants::O_LABEL_STRUCTURE)))
    if displayable
      # Check it's not a classification object
      schema = KObjectStore.schema
      obj_type = modified_obj.first_attr(KConstants::A_TYPE)
      if obj_type
        type_desc = schema.type_descriptor(obj_type)
        if type_desc && type_desc.is_classification?
          displayable = false
        end
      end
    end

    # Allow other parts of the system to add info to the audit entry's data, and change the displayable flag
    info = AuditObjectChangeInfo.new(previous_obj, modified_obj, data, displayable)
    KNotificationCentre.notify(:auditing_object_change, operation, info)

    AuditEntry.write(
      :kind => audit_kind,
      :labels => modified_obj.labels,
      :objref => modified_obj.objref,
      :version => modified_obj.version,
      :data => info.data.empty? ? nil : info.data,
      :displayable => info.displayable
    )
  end

end
