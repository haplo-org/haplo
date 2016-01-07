# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KAuditing

  # Interactive log in

  KNotificationCentre.when(:authentication, :login) do |name, operation, user, details|
    AuditEntry.write(
      :kind => 'USER-LOGIN',
      :user_id => user.id,      # Need to override default, as user is still anonymous
      :auth_user_id => user.id,
      :displayable => false,
      :data => details
    )
  end

  # ----------------------------------------------------------------------------------------

  # Explicit log out

  KNotificationCentre.when(:authentication, :logout) do |name, operation, user, details|
    AuditEntry.write(
      :kind => 'USER-LOGOUT',
      :displayable => false
    )
  end

  # ----------------------------------------------------------------------------------------

  # Impersonate other user
  #   Note for consistency, the user_id is the user *being* impersonated, and auth_user_id
  #   is the user requesting the impersonation.

  KNotificationCentre.when(:authentication, :impersonate) do |name, operation, user, impersonate_uid|
    AuditEntry.write(
      :kind => 'USER-IMPERSONATE',
      :user_id => impersonate_uid,
      :auth_user_id => user.id,
      :displayable => false
    )
  end

  # ----------------------------------------------------------------------------------------

  # Interactive authentication failure

  KNotificationCentre.when(:authentication, :interactive_failure) do |name, operation, details|
    data = details.dup
    data["interactive"] = true
    AuditEntry.write(
      :kind => 'USER-AUTH-FAIL',
      :displayable => false,
      :data => data
    )
  end

  # ----------------------------------------------------------------------------------------

  # OAuth login failure

  KNotificationCentre.when(:authentication, :oauth_failure) do |name, operation, details|
    AuditEntry.write(
      :kind => 'USER-OAUTH-FAIL',
      :displayable => false,
      :data => details
    )
  end

  # ----------------------------------------------------------------------------------------

  # User creation and modification

  VISIBLE_USER_ATTRIBUTES = ["name_first", "name_last", "email"]
  VISIBLE_GROUP_ATTRIBUTES = ["name"]

  def self.write_user_modify_audit(user, kind, data = nil)
    AuditEntry.write(
      :kind => kind,
      :displayable => false,
      :entity_id => user.id,
      :data => data
    )
  end

  USER_KIND_TO_ENTRY_KIND = {
    User::KIND_USER => 'USER-ENABLE',
    User::KIND_GROUP => 'GROUP-ENABLE',
    User::KIND_USER_BLOCKED => 'USER-BLOCK',
    User::KIND_USER_DELETED => 'USER-DELETE',
    User::KIND_GROUP_DISABLED => 'GROUP-DISABLE'
  }

  KNotificationCentre.when(:user_modified) do |name, user_kind, user|
    changes = user.previous_changes
    if changes.has_key?('id') && (changes['id'].first == nil)
      # New user - audit basic details
      if user.kind == User::KIND_GROUP
        write_user_modify_audit(user, 'GROUP-NEW', {"name" => user.name})
      else
        data = {}
        VISIBLE_USER_ATTRIBUTES.each { |a| data[a] = user.read_attribute(a) }
        write_user_modify_audit(user, 'USER-NEW', data)
      end
    else
      # Modification - could be all sorts
      # Password change or set by recovery link/welcome
      if changes.has_key?('password')
        if changes.has_key?('recovery_token') && user.recovery_token == nil
          write_user_modify_audit(user, 'USER-SET-PASS')
        else
          write_user_modify_audit(user, 'USER-CHANGE-PASS')
        end
      end
      # Objref change
      if changes.has_key?('obj_id')
        write_user_modify_audit(user, 'USER-REF', {"ref" => user.objref ? user.objref.to_presentation : nil})
      end
      # OTP token change
      if changes.has_key?('otp_identifier')
        write_user_modify_audit(user, 'USER-OTP-TOKEN', {"identifier" => user.otp_identifier})
      end
      # Delete/block/disable etc
      if changes.has_key?('kind')
        change_kind = USER_KIND_TO_ENTRY_KIND[user.kind]
        write_user_modify_audit(user, change_kind)
      end
      # Attributes
      visible_attrs, attrs_audit_kind = (user.is_group ? [VISIBLE_GROUP_ATTRIBUTES, 'GROUP-MODIFY'] : [VISIBLE_USER_ATTRIBUTES, 'USER-MODIFY'])
      data = {}
      data_old = {}
      visible_attrs.each do |a|
        if changes.has_key?(a)
          data_old[a], data[a] = changes[a]
        end
      end
      unless data.length == 0
        data[:old] = data_old
        write_user_modify_audit(user, attrs_audit_kind, data)
      end
    end
  end

  KNotificationCentre.when_each([
    [:user_groups_modified, :set_groups],
    [:user_groups_modified, :set_members]
  ]) do |name, detail, user, ids|
    # For users and groups, set as either group memberships or group members
    AuditEntry.write(
      :kind => 'GROUP-MEMBERSHIP',
      :displayable => false,
      :entity_id => user.id,
      :data => {((detail == :set_groups) ? "groups" : "members") => ids}
    )
  end

  # ----------------------------------------------------------------------------------------

  # Policy changes

  # Buffer and deduplicate, so the audit entries are only written once per user id at the end of the request, job, etc
  KNotificationCentre.when(:user_policy_modified, nil,
    {:deduplicate => true, :start_buffering => true, :max_arguments => 3} # args = name,detail,user_id
  ) do |name, detail, user_id|
    # Make a compact summary of the policies
    policies = Policy.find(:all, :conditions => ['user_id = ?', user_id])
    data = case policies.length
    when 0
      {"allow" => 0, "deny" => 0}
    when 1
      {"allow" => policies[0].perms_allow, "deny" => policies[0].perms_deny}
    else
      raise "Internal logic error: Unexpected number of policies" if policies.length > 1
    end
    AuditEntry.write(
      :kind => 'POLICY-CHANGE',
      :displayable => false,
      :entity_id => user_id.to_i,
      :data => data
    )
  end

  # ----------------------------------------------------------------------------------------

  # Permission rule changes

  # Buffer and deduplicate, so the audit entries are only written once per user id at the end of the request, job, etc
  KNotificationCentre.when(:user_permission_rule_modified, nil,
    {:deduplicate => true, :start_buffering => true, :max_arguments => 3} # args = name,detail,user_id
  ) do |name, detail, user_id|
    # Make a compact summary of the permssions
    rules = PermissionRule.find(:all, :conditions => ['user_id = ?', user_id], :order => 'label_id') .map do |rule|
      [rule.label_id, rule.statement, rule.permissions]
    end
    AuditEntry.write(
      :kind => 'PERMISSION-RULE-CHANGE',
      :displayable => false,
      :entity_id => user_id.to_i,
      :data => {"rules" => rules}
    )
  end

  # ----------------------------------------------------------------------------------------

  # API key creation and destruction

  API_KEY_DETAIL_TO_KIND = {
    :create => 'USER-API-KEY-NEW',
    :view => 'USER-API-KEY-VIEW',
    :destroy => 'USER-API-KEY-DELETE'
  }

  KNotificationCentre.when_each([
    [:user_api_key, :create],
    [:user_api_key, :view],
    [:user_api_key, :destroy]
  ]) do |name, detail, api_key|
    AuditEntry.write({
      :kind => API_KEY_DETAIL_TO_KIND[detail],
      :displayable => false,
      :entity_id => api_key.user_id,    # the user, not the API key
      :data => {
        "key_id" => api_key.id,
        "path" => api_key.path,
        "name" => api_key.name
      }
    }) do |e|
      # Deduplicate views audit entries
      e.cancel_if_repeats_previous if detail == :view
    end
  end

end
