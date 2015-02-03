# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class AuditEntry < ActiveRecord::Base
  include KPlugin::HookSite
  before_update :prevent_modification_of_audit_entries
  composed_of :objref, :allow_nil => true, :class_name => 'KObjRef', :mapping => [[:obj_id,:obj_id]]
  KLabelsActiveRecord.implement_labels_attribute self

  # ----------------------------------------------------------------------------------------------------------------

  # A limit on how old an audit entry can be to count as a duplicate
  REPEAT_PREVIOUS_WITHIN  = 5 # minutes

  # ----------------------------------------------------------------------------------------------------------------
  # Write a new audit trail entry. Optionally yields entry for extra functionality.
  #
  # AuditEntry.write(...) do |e|
  #   e.ask_plugins_with_default(false)
  #   e.cancel_if_repeats_previous
  #   e.cancel_write!("Cancelled")
  # end

  # Write an entry into the audit trail, optionally using a block to modify behaviour
  def self.write(info)
    entry = AuditEntry.new(info)
    raise "No kind passed to new AuditEntry" unless entry.kind
    # Fill in details from the controller, if a request is in progress
    if (rc = KFramework.request_context)
      entry.remote_addr = rc.controller.request.remote_ip
      api_key = rc.controller.current_api_key
      entry.api_key_id = (api_key ? api_key.id : nil)
    end
    # Fill in the user IDs, if not set
    if entry.user_id == nil
      state = AuthContext.state
      raise "Can't determine user IDs for audit when no AuthContext set" unless state
      entry.user_id = state.user.id
      entry.auth_user_id = state.auth_user.id
    end
    # Allow behaviour to be modified
    if block_given?
      yield entry
      if entry.cancelled?
        KApp.logger.info("Cancelled write of audit entry kind #{entry.kind} because #{entry.cancel_reason}")
        return nil
      end
    end
    entry.save!
    entry
  end

  # ----------------------------------------------------------------------------------------------------------------

  # Send notification when new entries are written
  after_commit :send_write_notification
  def send_write_notification
    KNotificationCentre.notify(:audit_trail, :write, self)
  end

  # ----------------------------------------------------------------------------------------------------------------

  # Ask plugins if the audit entry should be written
  def ask_plugins_with_default(default_write)
    should_write = default_write
    call_hook(:hAuditEntryOptionalWrite) do |hooks|
      h = hooks.run(self, default_write)
      should_write = h.write if h.write != nil
    end
    cancel_write!("optional and not required") unless should_write
  end

  # Cancel this new entry if there's an identical one within a few minutes
  def cancel_if_repeats_previous
    return if cancelled? # to avoid unnecessary database lookup
    # Attempt to find a previous entry matching this one
    relevant_attrs = self.attributes.dup
    relevant_attrs.delete('created_at')
    relevant_attrs.delete('labels')
    klabels_check_labelling() # to make sure unlabelled is set if necessary
    previous_count = AuditEntry.
      where(['created_at > ?', REPEAT_PREVIOUS_WITHIN.minutes.ago]).
      where(['labels = ?', self.labels._to_sql_value]).
      where(relevant_attrs).
      count(:all)
    # Cancel the write if such an entry exists
    cancel_write!("repeats previous") unless previous_count == 0
  end

  # Stop this entry from being written, giving a reason for the logs
  def cancel_write!(reason)
    raise "bad reason" unless reason.kind_of?(String)
    @_cancel_reason = reason
  end

  # Info for self.write()
  def cancelled?    ; !!(@_cancel_reason) ; end
  def cancel_reason ; @_cancel_reason     ; end

  # ----------------------------------------------------------------------------------------------------------------

  # Not foolproof as you can modify the table underneath, but prevents accident updates
  # before_update
  def prevent_modification_of_audit_entries
    raise "AuditEntry should not be updated."
  end

  # ----------------------------------------------------------------------------------------------------------------

  # Data field
  # arbitary data field
  def data
    d = read_attribute('data')
    (d == nil) ? nil : (@_decoded_data ||= JSON.parse(d))
  end

  def data=(new_data)
    if new_data == nil
      write_attribute('data', nil)
    else
      write_attribute('data', new_data.kind_of?(String) ? new_data : new_data.to_json)
    end
    @_decoded_data = nil
    new_data
  end

  # =============================================================================================================
  #   JavaScript interface
  # =============================================================================================================

  def jsGetCreationDate
    self.created_at.to_i * 1000
  end
  def jsGetData
    self.read_attribute('data')
  end

end
