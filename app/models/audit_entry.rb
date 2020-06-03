# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class AuditEntry < MiniORM::Record
  include KPlugin::HookSite

  table :audit_entries do |t|
    t.column :timestamp,  :created_at
    t.column :text,       :remote_addr,       nullable:true
    t.column :int,        :user_id
    t.column :int,        :auth_user_id
    t.column :int,        :api_key_id,        nullable:true
    t.column :text,       :kind
    t.column :labellist,  :labels
    t.column :objref,     :objref,            nullable:true, db_name:'obj_id'
    t.column :int,        :entity_id,         nullable:true
    t.column :int,        :version,           nullable:true
    t.column :boolean,    :displayable
    t.column :json_on_text, :data_json,       nullable:true, db_name:'data', property:'data'

    t.order :id_desc, 'id DESC'
    t.order :recent_first, 'created_at DESC'

    t.where :created_after, 'created_at > ?', :timestamp
    t.where :created_at_or_after, 'created_at >= ?', :timestamp
    t.where :created_at_or_before, 'created_at <= ?', :timestamp
    t.where :kind_is_one_of, 'kind = ANY (?)', :text_array
    t.where :user_id_is_not, 'user_id <> ?', :int
    t.where :user_id_or_auth_user_id, '(user_id = ? OR auth_user_id = ?)', :int, :int
    t.where :id_less_than, 'id < ?', :int
    t.where :id_less_than_or_equal, 'id <= ?', :int
  end

  def before_save
    if self.persisted?
      # Not foolproof as you can modify the table underneath, but prevents accident updates
      # before_update
      raise "AuditEntry should not be updated."
    end
    self.created_at = Time.now unless self.created_at
    _check_labels()
  end

  def after_save
    KNotificationCentre.notify(:audit_trail, :write, self)
  end

  # ----------------------------------------------------------------------------------------------------------------

  WRITE_ATTRS = {
    :remote_addr => :remote_addr=,
    :user_id => :user_id=,
    :auth_user_id => :auth_user_id=,
    :api_key_id => :api_key_id=,
    :kind => :kind=,
    :labels => :labels=,
    :objref => :objref=,
    :entity_id => :entity_id=,
    :version => :version=,
    :displayable => :displayable=,
    :data => :data=
  }

  COMPARE_ATTRS = WRITE_ATTRS.keys - [:data] + [:data_json]

  # ----------------------------------------------------------------------------------------------------------------

  def _check_labels
    current_labels = self.labels
    if current_labels.nil? || current_labels.empty?
      # If nil or empty, give it the unlabelled label instead
      self.labels = KLabelList.new([KConstants::O_LABEL_UNLABELLED])
    end
  end

  # ----------------------------------------------------------------------------------------------------------------

  def self.where_labels_permit(operation, label_statements)
    raise "where_labels_permit requires a KLabelStatements" unless label_statements.kind_of? KLabelStatements
    self.where().unsafe_where_sql(label_statements._sql_condition(operation, "labels"))
  end

  # ----------------------------------------------------------------------------------------------------------------

  # A limit on how old an audit entry can be to count as a duplicate
  REPEAT_PREVIOUS_WITHIN  = 5*60 # seconds

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
    entry = AuditEntry.new
    info.each do |key,value|
      method = WRITE_ATTRS[key]
      raise "Unknown key for AuditEntry.write: #{key}" unless method
      entry.__send__(method, value)
    end
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
    entry.save
    entry
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
    _check_labels() # to make sure unlabelled is set if necessary
    relevant_attrs = {}
    COMPARE_ATTRS.each do |name|
      relevant_attrs[name] = self.__send__(name)
    end
    previous_count = AuditEntry.
      where_created_after(Time.now - REPEAT_PREVIOUS_WITHIN).
      where(relevant_attrs).
      count()
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

end
