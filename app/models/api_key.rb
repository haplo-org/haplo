# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class ApiKey < MiniORM::Record

  PART_A_LENGTH = 16
  PART_B_BCRYPT_ROUNDS = 5 # because the secret is good, and checking is performance sensitive (especially for plugin tool)

  # -------------------------------------------------------------------------

  table :api_keys do |t|
    t.column :int, :user_id
    t.column :text, :a
    t.column :text, :b
    t.column :text, :path
    t.column :text, :name

    t.order :name, 'name'
  end

  def after_create
    KNotificationCentre.notify(:user_api_key, :create, self)
  end
  def after_save
    ApiKey.invalidate_cached
  end
  def after_delete
    ApiKey.invalidate_cached
    KNotificationCentre.notify(:user_api_key, :destroy, self)
  end

  # -------------------------------------------------------------------------

  STRICT_EQUALITY_PATH = /\A\=(\/.+?)\z/

  def valid_for_request_path?(request_uri)
    if request_uri.start_with?(self.path)
      true
    elsif self.path =~ STRICT_EQUALITY_PATH
      request_uri == $1
    else
      false
    end
  end

  def set_random_api_key
    self._set_api_key(KRandom.random_api_key)
  end

  def _set_api_key(secret)
    raise "Expected longer secret" unless secret.length > (PART_A_LENGTH*2)
    self.a = secret[0,PART_A_LENGTH]
    self.b = BCrypt::Password.create(secret[PART_A_LENGTH,secret.length],PART_B_BCRYPT_ROUNDS).to_s
    secret
  end

  def b_matchs?(test_b)
    BCrypt::Password.new(self.b) == test_b
  end

  # ----------------------------------------------------------------------------
  #  API key cache, and access with ApiKey.cache
  # ----------------------------------------------------------------------------
  class ApiKeyCache
    def initialize
      @storage = Hash.new
    end
    def [](secret)
      a = secret[0,PART_A_LENGTH]
      b = secret[PART_A_LENGTH,secret.length]
      object = @storage[a]
      return object if object && object.b_matchs?(b)
      # Try and find it, caching it if it is
      object = ApiKey.where(:a => a).first()
      return nil unless object && object.b_matchs?(b)
      @storage[a] = object
    end
  end
  APIKEY_CACHE = KApp.cache_register(ApiKeyCache, "API key cache")

  def self.cache
    KApp.cache(APIKEY_CACHE)
  end
  def self.invalidate_cached
    KApp.cache_invalidate(APIKEY_CACHE)
  end

end
