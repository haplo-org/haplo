# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class PermissionRule < MiniORM::Record
  table :permission_rules do |t|
    t.column :int,      :user_id
    t.column :int,      :label_id
    t.column :smallint, :statement
    t.column :int,      :permissions

    t.order :label_id, 'label_id'
    t.order :id_desc, 'id DESC'

    t.where :user_id_in, 'user_id = ANY (?)', :int_array
  end

  # -------------------------------------------------------------------------

  DENY = 0 # Lower numbers here take precendence over higher numbers
  ALLOW = 1
  RESET = 2

  STATEMENT_SYMBOLS = {
    :allow => ALLOW,
    :deny => DENY,
    :reset => RESET,
  }

  def self.valid_statement?(statement)
    statement.kind_of?(Integer) && (STATEMENT_SYMBOLS.values.include? statement)
  end


  STATEMENT_NAMES_FOR_UI = [
      ["Can",         ALLOW],
      ["Cannot",      DENY],
      ["Reset rules", RESET]
    ]

  # Send individual notifications after changes, which include the user ID
  def send_rule_modified_notification
    KNotificationCentre.notify(:user_permission_rule_modified, nil, self.user_id)
  end
  def after_save;   send_rule_modified_notification; end
  def after_delete; send_rule_modified_notification; end

  def self.new_rule!(statement, user, label, *operations)
    statement = STATEMENT_SYMBOLS[statement] unless self.valid_statement? statement
    user = user.id if user.is_a? User
    label = label.to_i if label.is_a? KObjRef
    permissions = KPermissionRegistry.to_bitmask(*operations)
    new_rule = PermissionRule.new
    new_rule.user_id = user
    new_rule.label_id = label
    new_rule.statement = statement
    new_rule.permissions = permissions
    new_rule.save
  end

  def self.delaying_update_notification
    @@change_notification_buffer.while_buffering do
      yield
    end
  end

  # Send global change notification outside transactions, just generic "something changed"
  @@change_notification_buffer = KNotificationCentre.when(:user_permission_rule_modified, nil, {:deduplicate => true, :max_arguments => 0}) do
    # Also sent by Policy
    KNotificationCentre.notify(:user_auth_change, nil)
  end

  # Plugin install/uninstall count as a permission change, because they affect rules with the hUserPermissionRules hook
  KNotificationCentre.when(:plugin) { KNotificationCentre.notify(:user_auth_change, nil) }

  # ------------------------------------------------------------------------------------------

  class RuleList
    include KPlugin::HookSite

    DISTANCE_PLUGIN_RULES = 0
    DISTANCE_USER         = 1
    DISTANCE_FIRST_GROUP  = 2

    # For mapping between permission bitmasks in the database to label operations
    PERMISSIONS_BITS = KPermissionRegistry.entries.map { |e| [e.symbol, 1 << e.bitfield_index] }

    def initialize
      @rules = []
    end

    def load_permission_rules_for_user(user)
      uid_to_distance = {user.id => DISTANCE_USER}
      group_info = user.user_groups.calculated_group_info()
      group_info.each { |uid,distance| uid_to_distance[uid] = distance }
      # Get list of rules in format
      #   [distance, statement, plugin_name, user_id, label_id, permissions]
      PermissionRule.where_user_id_in(uid_to_distance.keys).each do |r|
        @rules << [uid_to_distance[r.user_id] || 99999, r.statement, nil, r.user_id, r.label_id, r.permissions]
      end
      # Get more rules from the plugins
      call_hook(:hUserPermissionRules) do |hooks|
        h = hooks.run(User.cache[user.id])
        load_untrusted_rules_from_javascript(h.rules)
      end
      self
    end

    # IMPORTANT: decoded_json is deserialized JSON from untrusted JavaScript code -- treat with caution
    def load_untrusted_rules_from_javascript(decoded_json)
      decoded_json["rules"].each do |plugin_name,label,statement,permissions|
        label = label.to_i
        permissions = permissions.to_i
        active_permission_bits = KPermissionRegistry.active_bits_bitmask
        permissions_valid = permissions & active_permission_bits > 0 && permissions & ~active_permission_bits == 0
        unless label > 0 and permissions_valid and PermissionRule.valid_statement?(statement)
          raise JavaScriptAPIError, "Bad permission rule statement"
        end
        @rules << [DISTANCE_PLUGIN_RULES, statement.to_i, plugin_name.to_s, -1, label, permissions]
      end
      self
    end

    def to_label_statements
      @rules.sort!  # by distance, THEN statement, then ...
      # Now transform into hash of label_id => [label_id, allow, deny]
      label_perms = Hash.new { |h,k| h[k] = [k,0,0] }
      # Use reverse each to start with most distant rule, so RESETs work usefully
      @rules.reverse_each do |distance,statement,plugin_name,user_id,label_id,permissions|
        bitmasks = label_perms[label_id]
        # Clear the stated permissions
        bitmasks[1] &= ~permissions
        bitmasks[2] &= ~permissions
        # Set the right permissions
        case statement
        when PermissionRule::ALLOW
          bitmasks[1] |= permissions
        when PermissionRule::DENY
          bitmasks[2] |= permissions
        when PermissionRule::RESET
          # RESET -- ignore
        else
          raise "Unknown permission rule statement #{statement}"
        end
      end
      # And use to build permissions
      KLabelStatements.from_bitmasks(label_perms.values, PERMISSIONS_BITS)
    end

    # Temporary method to get rules for displaying in UI
    def _temp__rules_for_display
      @rules.sort!
      @rules
    end

  end

end
