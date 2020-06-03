# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Policy < MiniORM::Record
  table :policies do |t|
    t.column :int,      :user_id
    t.column :int,      :perms_allow
    t.column :int,      :perms_deny
  end

  # Send individual notifications after changes, which include the user ID
  def send_policy_modified_notification
    KNotificationCentre.notify(:user_policy_modified, nil, self.user_id)
  end
  def after_save;   send_policy_modified_notification; end
  def after_delete; send_policy_modified_notification; end

  # Use the notification centre system to count depth of transactions to batch multiple Policy changes into a single notification
  def self.delaying_update_notification
    @@change_notification_buffer.while_buffering do
      yield
    end
  end

  # Send global change notification outside transactions, just generic "something changed"
  @@change_notification_buffer = KNotificationCentre.when(:user_policy_modified, nil, {:deduplicate => true, :max_arguments => 0}) do
    # Also sent by PermissionRule
    KNotificationCentre.notify(:user_auth_change, nil)
  end
end
