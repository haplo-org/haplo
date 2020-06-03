# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KeychainCredential < MiniORM::Record

  table :keychain_credentials do |t|
    t.column :timestamp,    :created_at
    t.column :timestamp,    :updated_at
    t.column :text,         :name
    t.column :text,         :kind
    t.column :text,         :instance_kind
    t.column :json_on_text, :account_json,  property:'account'
    t.column :json_on_text, :secret_json,   property:'secret'

    t.where :id_maybe, 'id=?', :int
    t.order :id, 'id'
    t.order :name, 'name'
  end

  def before_save
    now = Time.now
    self.created_at = now if self.created_at.nil?
    self.updated_at = now
  end

  def after_save
    KNotificationCentre.notify(:keychain, :modified, self)
  end
  def after_delete
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

end
