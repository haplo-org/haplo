# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class PermissionRule < ActiveRecord::Base
  belongs_to :user

  DENY = 0 # Lower numbers here take precendence over higher numbers
  ALLOW = 1
  RESET = 2

  STATEMENT_SYMBOLS = {
    :allow => ALLOW,
    :deny => DENY,
    :reset => RESET,
  }

  def self.valid_statement?(statement)
    statement.kind_of?(Fixnum) && (STATEMENT_SYMBOLS.values.include? statement)
  end


  STATEMENT_NAMES_FOR_UI = [
      ["Can",         ALLOW],
      ["Cannot",      DENY],
      ["Reset rules", RESET]
    ]

  # Send individual notifications after changes, which include the user ID
  after_commit do
    KNotificationCentre.notify(:user_permission_rule_modified, nil, self.user_id)
  end

  def self.new_rule!(statement, user, label, *operations)
    statement = STATEMENT_SYMBOLS[statement] unless self.valid_statement? statement
    user = user.id if user.is_a? User
    label = label.to_i if label.is_a? KObjRef
    permissions = KPermissionRegistry.to_bitmask(*operations)
    new_rule = PermissionRule.new(:user_id => user, :label_id => label, :statement => statement, :permissions => permissions)
    new_rule.save!
    new_rule
  end

  # Use the notification centre system to count depth of transactions, as ActiveRecord automatically wraps saves with transactions
  def self.transaction
    @@change_notification_buffer.while_buffering do
      ActiveRecord::Base.transaction do
        yield
      end
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
      where_clause = "user_id IN (#{uid_to_distance.keys.join(',')})"
      # Get list of rules in format
      #   [distance, statement, plugin_name, user_id, label_id, permissions]
      KApp.get_pg_database.exec("SELECT statement, user_id, label_id, permissions FROM permission_rules WHERE #{where_clause}").each do |x|
        r = x.map { |n| n.to_i }
        statement, user_id, label_id, permissions = r
        @rules << [uid_to_distance[user_id] || 99999, statement, nil, user_id, label_id, permissions]
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
