# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class Policy < ActiveRecord::Base
  belongs_to :user

  def self.blank_for_user(user_id)
    self.new(:user_id => user_id, :perms_allow => 0, :perms_deny => 0)
  end

  # Send individual notifications after changes, which include the user ID
  after_commit do
    KNotificationCentre.notify(:user_policy_modified, nil, self.user_id)
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
  @@change_notification_buffer = KNotificationCentre.when(:user_policy_modified, nil, {:deduplicate => true, :max_arguments => 0}) do
    # Also sent by PermissionRule
    KNotificationCentre.notify(:user_auth_change, nil)
  end
end
