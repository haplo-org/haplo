# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class ApiKey < ActiveRecord::Base
  after_commit :invalidate_apikey_cache
  after_create :send_create_notification
  after_destroy :send_destroy_notification
  belongs_to :user

  PART_A_LENGTH = 16

  def valid_for_request?(request, params)
    request.request_uri.start_with?(self.path)
  end

  def set_random_api_key
    self._set_api_key(KRandom.random_api_key)
  end

  def _set_api_key(secret)
    raise "Expected longer secret" unless secret.length > (PART_A_LENGTH*2)
    self.a = secret[0,PART_A_LENGTH]
    self.b = BCrypt::Password.create(secret[PART_A_LENGTH,secret.length]).to_s
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
      object = ApiKey.find(:first, :conditions => ['a = ?', a])
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

  # ----------------------------------------------------------------------------
  #  Callbacks to invalidate the cache appropriately
  # ----------------------------------------------------------------------------
  # after_commit
  def invalidate_apikey_cache
    ApiKey.invalidate_cached
  end

  # ----------------------------------------------------------------------------
  #  Notifications for auditing
  # ----------------------------------------------------------------------------

  # after_create
  def send_create_notification
    KNotificationCentre.notify(:user_api_key, :create, self)
  end

  # after_destroy
  def send_destroy_notification
    KNotificationCentre.notify(:user_api_key, :destroy, self)
  end

end
