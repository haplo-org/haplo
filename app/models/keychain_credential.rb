# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KeychainCredential < ActiveRecord::Base

  after_commit :send_modify_notification
  def send_modify_notification
    KNotificationCentre.notify(:keychain, :modified, self)
  end

  # -------------------------------------------------------------------------

  MODELS = [
      {
        :kind => 'Generic',
        :instance_kind => "Username and password",
        :account => {"Username" => ""},
        :secret => {"Password" => ""}
      },
      {
        :kind => 'Generic',
        :instance_kind => "Secret",
        :account => {},
        :secret => {"Secret" => ""}
      }
    ]

  USER_INTERFACE = {}

  def account
    JSON.parse(self.account_json)
  end
  def account=(info)
    self.account_json = info.to_json
  end

  def secret
    JSON.parse(self.secret_json)
  end
  def secret=(info)
    self.secret_json = info.to_json
  end

end
