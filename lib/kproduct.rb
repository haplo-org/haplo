# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Info about product limitations, etc
module KProduct

  # How many bytes an object 'costs'
  OBJECT_COST     = (64*1024)

  PRICE_PLANS = {
    'haplo' => {
      :limit_users        => 500,
      :limit_objects      => 200000,
      :limit_storage      => 1024*16
    }
  }
  PRICE_PLANS['oneis'] = PRICE_PLANS['haplo']

  # ----------------------------------------------------------------------------------------------------------------------

  # Set limits for product by product name
  def self.set_to_product(product_name, inform_management_server = true)
    product_info = PRICE_PLANS[product_name]
    raise "Bad product name" if product_info == nil
    self.set_limits(product_info, inform_management_server)
  end

  # Set limits, given a hash of limits
  def self.set_limits(limits, inform_management_server = true)
    limits = self.check_and_symbolize_limits(limits)
    raise "Bad product limits" unless limits
    limits.each do |key,value|
      if DEFN_KEYS.include?(key)
        KApp.set_global(key, value)
      end
    end
    # Inform the management server
    if KFRAMEWORK_IS_MANAGED_SERVER && inform_management_server
      KMessageQueuing.spool_message(KManagementServer.hostname, :app_update, [[KApp.current_application, :update, {'limits' => limits}]])
    end
  end

  # Check a product exists, by name
  def self.product_exists?(product_name)
    PRICE_PLANS.has_key?(product_name)
  end

  # Check a limit definition contains everything is should
  # Make sure all the keys are symbols, not the strings from JSON decoding
  def self.check_and_symbolize_limits(defn)
    return nil unless defn.class == Hash
    r = Hash.new
    DEFN_KEYS.each do |key|
      value = defn[key] || defn[key.to_s]
      return nil unless value != nil
      r[key] = value
    end
    r
  end

  # Counting logic
  def self.count_users
    User.count(:conditions => "kind=#{User::KIND_USER} AND id<>#{User::USER_ANONYMOUS}")
  end

  # Logic for determining whether limits are met
  def self.limit_users_exceeded?
    max_users = KApp.global(:limit_users)
    # If max_users == 0 then any number of users are allowed
    (max_users > 0) && (self.count_users >= KApp.global(:limit_users))
  end

  def self.limit_objects_exceeded?
    max_objects = KApp.global(:limit_objects)
    # If max_objects == 0 any number of objects are allowed
    return false if max_objects == 0
    # Get the objects counter from KAccounting
    objects_counter = KAccounting.get(:objects)
    # It may be nil if unavailable, in which case, let the creation happen
    return false if objects_counter == nil
    # Otherwise check against the limit (adjusted by the number of objects created at init time)
    (objects_counter - KApp.global(:limit_init_objects)) >= max_objects
  end

  def self.limit_storage_exceeded?
    max_storage = KApp.global(:limit_storage)
    # If max_storage == 0 any amount of storage is allowed
    return false if max_storage == 0
    # Storage is in MB
    max_storage *= (1024*1024)
    # Then similar to limit_objects_exceeded?
    storage_counter = KAccounting.get(:storage) # in bytes
    return false if storage_counter == nil # unavailable
    costing_objects = (KAccounting.get(:objects) || 0) - KApp.global(:limit_init_objects)  # safe assumption that :objects is available too
    storage_counter += costing_objects * KProduct::OBJECT_COST # object cost
    storage_counter >= max_storage
  end

  DEFN_KEYS = [:limit_users, :limit_objects, :limit_storage]

end
