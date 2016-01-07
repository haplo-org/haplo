# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KApp

  # ----------------------------------------------------------------------------------------------------
  # Cached data

  # TODO: Monitor how many copies of the KApp.caches there are, and perhaps clear unnecessary objects to save memory?

  # Create a reporter for cache checkin exceptions
  CACHE_CHECKIN_EXCEPTION_HEALTH_EVENTS = KFramework::HealthEventReporter.new('CACHE_CHECKIN')

  # Info about each cache
  CacheInfo = Struct.new(:cache_class, :description, :cache_kind)
  # Holds the caches in the AppInfo object. Serial is a monotonically increasing int to know whether or not to return caches after a clear
  CacheList = Struct.new(:caches, :serial)
  # Looks after checked out caches, stored in Thread local storage
  CacheCheckout = Struct.new(:cache, :serial_when_checked_out)

  # Stored array
  CACHE_INFO = Array.new

  # Returns an integer with the cache number. Example:
  #    FOO_CACHE = KApp.cache_register(Hash, "Cache for foo")
  # where Hash is the class used for creating new empty cache objects.
  # Optional cache_kind argument, which defaults to :per_thread, creating as many cache objects as there are
  # concurent threads requesting a cache. Set to :shared to just use a single cache object.
  # If :shared, then cache_invalidate does nothing, and objects stored within it must behave as immutable.
  def self.cache_register(klass, description, cache_kind = :per_thread)
    info = CacheInfo.new(klass, description, cache_kind)
    # In development mode, check to see if a cache has already been registered with that description
    if KFRAMEWORK_ENV == 'development'
      c = nil
      CACHE_INFO.each_with_index { |i,n| c = n if i.description == description }
      if c != nil
        # Update with new info
        CACHE_INFO[c] = info
        return c
      end
    end
    CACHE_INFO << info
    CACHE_INFO.length - 1
  end

  # Returns a cache object. If two threads request a cache at the same time, they'll get their own private copies.
  def self.cache(cache_number)
    raise "Bad cache_number" if cache_number < 0 || cache_number >= CACHE_INFO.length
    # Is something checked out?
    thread_context = self._thread_context
    checkouts = (thread_context.cache_checkouts ||= Array.new)
    cache_checkout = checkouts[cache_number]
    if cache_checkout != nil
      # Return the previously checked out cache
      cache_checkout.cache
    else
      # Need to checkout the cache, or create one if it's not there
      # Get the current AppInfo object
      app_info = thread_context.current_app_info
      raise "No app selected" if app_info == nil
      # See is there's something which can be checked out
      cache_info = CACHE_INFO[cache_number]
      cache = nil
      serial = 0
      app_info.lock.synchronize do
        cache_list = app_info.caches[cache_number]
        if cache_info.cache_kind == :shared
          # Shortcut processing for shared caches - no checkout
          cache_list.caches << cache_info.cache_class.new if cache_list.caches.empty?
          return cache_list.caches.first
        else
          serial = cache_list.serial
          if cache_list.caches.empty?
            # Create a new cache
            cache = cache_info.cache_class.new
          else
            # Checkout a cache
            cache = cache_list.caches.pop
          end
        end
      end
      # Store the checkout in case it's requested again
      checkouts[cache_number] = CacheCheckout.new(cache, serial)
      begin
        # Inform the cache that it's being checked out (outside the lock)
        cache.kapp_cache_checkout if cache.respond_to?(:kapp_cache_checkout, false)
      rescue => e
        # Failure in the cache object checkout method: give up on this cache object which is probably in a bad state
        checkouts[cache_number] = nil
        # Log then send the exception on its way
        KApp.logger.error("kapp_cache_checkout failed when checking out cache")
        KApp.logger.log_exception(e)
        raise
      end
      cache
    end
  end

  # Returns a cache object, if one has already been checked out in this thread
  def self.cache_if_already_checked_out(cache_number)
    checkouts = self._thread_context.cache_checkouts
    return nil if checkouts == nil
    cache_checkout = checkouts[cache_number]
    (cache_checkout != nil) ? cache_checkout.cache : nil
  end

  # Invalidates all cache objects. Requests in progress will keep their cache copies.
  def self.cache_invalidate(cache_number)
    raise "Bad cache_number" if cache_number < 0 || cache_number >= CACHE_INFO.length
    KApp.logger.info("Invalidating cache '#{CACHE_INFO[cache_number].description}'")
    # Get the current AppInfo object
    thread_context = self._thread_context
    app_info = thread_context.current_app_info
    raise "No app selected" if app_info == nil
    app_info.lock.synchronize do
      cache_list = app_info.caches[cache_number]
      cache_list.caches = Array.new
      # Increment serial number so old caches don't get checked in
      cache_list.serial = cache_list.serial + 1
    end
    # Clear cache in this thread
    checkouts = thread_context.cache_checkouts
    if checkouts != nil
      if checkouts[cache_number] != nil
        cache = checkouts[cache_number].cache
        # Tell the cache object for the current thread
        cache.kapp_cache_invalidated if cache.respond_to?(:kapp_cache_invalidated, false)
        checkouts[cache_number] = nil
      end
    end
  end

  def self.cache_checkin_all_caches
    thread_context = self._thread_context
    checkouts = thread_context.cache_checkouts
    if checkouts != nil
      # First, clear the checkouts on this thread, so if anything goes wrong, the caches will have been thrown away
      thread_context.cache_checkouts = nil
      # Notify caches, outside the lock, but before they're checked in and may be reused
      failure = false
      checkouts.each do |cache_checkout|
        if cache_checkout != nil && cache_checkout.cache.respond_to?(:kapp_cache_checkin)
          begin
            cache_checkout.cache.kapp_cache_checkin
          rescue => e
            failure = true
            CACHE_CHECKIN_EXCEPTION_HEALTH_EVENTS.log_and_report_exception(e)
          end
        end
      end
      # If any of the caches threw an exception, stop now which throws everything away
      return if failure
      # Finally check in the caches, inside the lock
      app_info = thread_context.current_app_info
      app_info.lock.synchronize do
        checkouts.each_with_index do |cache_checkout, cache_number|
          if cache_checkout != nil
            cache = cache_checkout.cache
            # Only put it back in the list if the serial number matches the serial number when it was checked out
            cache_list = app_info.caches[cache_number]
            if cache_list.serial == cache_checkout.serial_when_checked_out
              cache_list.caches << cache
            end
          end
        end
      end
    end
  end

  def self.clear_all_cached_data_for_app(app_id)
    app_info = get_app_info_for(app_id)
    if app_info != nil
      app_info.lock.synchronize do
        app_info.caches.each do |cache_list|
          cache_list.caches = Array.new
          cache_list.serial = cache_list.serial + 1
        end
      end
    end
  end

  # For the console command to call to dump out cache information
  def self.dump_cache_info_for(app_id)
    app_info = get_app_info_for(app_id)
    if app_info == nil
      puts "Couldn't get app info object for #{app_id}"
      return
    end
    app_info.lock.synchronize do
      if app_info.caches == nil
        puts "No caches for app #{app_id}"
        return
      end
      CACHE_INFO.each_with_index do |info, index|
        puts info.description
        cache = app_info.caches[index]
        if cache == nil
          puts "  * nothing cached"
        else
          internal_count = ""
          cache.caches.each do |obj|
            internal_count << if obj.kind_of?(Array) || obj.kind_of?(Hash)
              "#{obj.length} "
            else
              "? "
            end
          end
          puts "  n=#{cache.caches.length}, serial=#{cache.serial}, obj_lengths=#{internal_count}"
        end
      end
      puts "NOTE: Counts will not include any caches which are currently checked out."
    end
  end

end


