# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Implements efficient cross-process accounting for app usage (disc space, number of objects)

# Load the underlying primitives used to implement this. See kaccountingshm/kaccountingshm.c for documentation.
# require 'kaccountingshm/kaccountingshm'

class KAccounting

  COUNTER_NAMES = [:objects, :storage, :requests, :feed_reqs, :api_reqs, :_deprecated,  :logins]
  COUNTER_TYPES = [:usage,   :usage,   :event,    :event,     :event,    :event,        :event ]
  # :usage - tracks resource usage
  # :event - counts events

  # -----------------------------------------------------------------------------
  # Notification listeners

  # Object counts
  KNotificationCentre.when(:os_object_change) do |name, detail, previous_obj, modified_obj, is_schema_object|
    unless modified_obj.labels.include?(KConstants::O_LABEL_STRUCTURE)
      case detail
      when :create
        self.add(:objects, 1)
      when :erase
        self.add(:objects, -1)
      end
    end
  end

  # Logins
  KNotificationCentre.when(:authentication, :login) do
    self.add(:logins, 1)
  end

  # Storage
  KNotificationCentre.when(:file_store, :new_file) do |name, detail, file, disposition|
    unless disposition == :duplicate
      self.add(:storage, file.size)
    end
  end

  # Request counts
  KNotificationCentre.when(:http_request, :start) do |name, detail, request, user, api_key|
    self.add(:requests, 1)
    if api_key != nil
      self.add(:api_reqs, 1)
    end
  end

  # -----------------------------------------------------------------------------
  # Get/change counters during normal operations

  # Returns true if the set was successful. Generally it should be ignored.
  def self.add(counter, delta)
    c = COUNTER_NAMES.index(counter)
    raise "Bad counter name" if c == nil
    using_counters_for_current_app do |counters|
      counters[c] = counters[c] + delta
    end
    true
  end

  # May return nil if the accounting system is unavailable.
  def self.get(counter)
    c = COUNTER_NAMES.index(counter)
    raise "Bad counter name" if c == nil
    value = nil
    using_counters_for_current_app do |counters|
      value = counters[c]
    end
    value
  end

  # True if there's room for another app
  def self.room_for_another_app
    true
  end

  # -----------------------------------------------------------------------------
  # Setup

  # TODO: KAccounting.init_and_load will open a db connection for each application; rewrite to use a single connection.
  # Load all the basic data
  def self.init_and_load
    # Load the preserved data
    preserved_data = nil
    begin
      if File.exist?(KACCOUNTING_PRESERVED_DATA)
        loaded = nil
        File.open(KACCOUNTING_PRESERVED_DATA,"rb") do |f|
          loaded = Marshal.load(f.read)
        end
        if loaded != nil && loaded.class == Array && loaded.length == 2 && loaded.first == :accounting_v0 && loaded.last.class == Hash
          preserved_data = loaded.last
        else
          KApp.logger.error("Preserved accounting data is wrong format, ignoring")
        end
      end
    rescue => e
      # Any problems, just ignore the data loaded
      KApp.logger.error("Exception while loading preserved accounting data, ignoring. #{e.to_s}")
      preserved_data = nil
    end

    KApp.in_every_application do |app_id|
      set_counters_for_current_app((preserved_data == nil) ? nil : preserved_data[app_id])
    end

    KApp.logger.info "Initialised accounting counters (#{Time.now.to_iso8601_s})"
  end

  # -----------------------------------------------------------------------------
  # Infrastructure interface

  def self.setup_accounting
    true
  end

  # Set the counters all in one go, creating the app if it doesn't exist
  def self.set_counters(set_counters) # hash
    success = false
    using_counters_for_current_app(true) do |counters|
      # Set the counters given
      set_counters.each do |k,v|
        c = COUNTER_NAMES.index(k)
        counters[c] = v.to_i if c != nil
      end
      # Make sure that the other entries aren't nil
      0.upto(COUNTER_NAMES.length - 1) do |i|
        counters[i] = 0 if counters[i] == nil
      end
      success = true
    end
    # Whether it worked
    success
  end

  # Sets the counters for the app
  def self.set_counters_for_current_app(preserved_counters = nil)
    c = Hash.new
    if preserved_counters != nil
      COUNTER_NAMES.each_with_index do |name,i|
        c[name] = preserved_counters[i] if preserved_counters[i] != nil
      end
    end
    c[:objects] = KObjectStore.count_objects_stored([KConstants::O_LABEL_STRUCTURE])
    c[:storage] = StoredFile.storage_space_used()
    set_counters(c)
  end

  def self.dump_counters_for_current_app
    using_counters_for_current_app do |counters|
      0.upto(COUNTER_NAMES.length - 1) do |i|
        puts "  #{COUNTER_NAMES[i]}: #{counters[i]}"
      end
    end
  end

  def self.save_accounting_data
    data = Hash.new
    KApp.in_every_application do |app_id|
      using_counters_for_current_app do |counters|
        data[app_id] = counters.dup
      end
    end
    write_pathname = "#{KACCOUNTING_PRESERVED_DATA}.write"
    File.open(write_pathname,"wb") { |f| f.write Marshal.dump([:accounting_v0, data]) }
    File.rename(write_pathname, KACCOUNTING_PRESERVED_DATA)
  end

private
  def self.using_counters_for_current_app(yield_even_if_no_counters = false)
    KApp.current_app_info.using_counters do |counters|
      # Make sure the counters array is the right length - if it's too small the system hasn't been initialised
      if yield_even_if_no_counters || counters.length >= COUNTER_NAMES.length
        yield counters
      end
    end
  end

  # Background task to startup
  class AccountingBackgroundTask < KFramework::BackgroundTask
    def initialize
      @stop_flag = Java::ComOneisCommonUtils::WaitingFlag.new
      @do_background = true
    end
    def start
      # Make sure all the usage counts are correct on startup
      KAccounting.init_and_load
      KApp.logger.flush_buffered
      # Save the data every 15 minutes, or on shutdown of the application server
      while @do_background
        @stop_flag.waitForFlag(900000)  # 15 mins in ms
        KAccounting.save_accounting_data
        KApp.logger.info("Accounting data saved at #{Time.now.to_iso8601_s}")
        KApp.logger.flush_buffered
      end
    end
    def stop
      @do_background = false
      @stop_flag.setFlag()
    end
    def description
      "Accounting startup and data preservation"
    end
  end
  KFramework.register_background_task(AccountingBackgroundTask.new)

end


# Define a console command to dump accounting data for an app
class Console
  _Description "Show accounting data for an application"
  _Help <<-__E
    List the counters for a given application, specified by ID.
  __E
  def accounting(app_id)
    KApp.in_application(app_id) do
      KAccounting.dump_counters_for_current_app
    end
    nil
  end
end


