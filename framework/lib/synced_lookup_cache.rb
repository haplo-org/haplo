# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# A very simple Hash-like class for caching simple data shared across processes, with the key difference
# that it'll use a given proc to generate values which aren't in the cache.
class SyncedLookupCache

  # Create a new factory object, for use with KApp.register_cache
  def self.factory(not_found_proc)
    Factory.new(not_found_proc)
  end

  # Create with a proc object which will generate
  def initialize(not_found_proc)
    @not_found_proc = not_found_proc
    @storage = Hash.new
    @lock = Mutex.new
  end

  # Clear the cache
  def clear
    KApp.logger.info("Clearing SyncedLookupCache 0x#{self.object_id.to_s(16)}")
    @lock.synchronize { @storage.clear }
  end

  # Lookup values, potentially using the proc to create it.
  def [](key)
    @lock.synchronize do
      @storage[key] ||= @not_found_proc.call(key)
    end
  end

  # Set a value
  def []=(key, value)
    @lock.synchronize do
      @storage[key] = value
    end
  end

  # Helper class for KApp caches.
  class Factory
    def initialize(not_found_proc)
      @not_found_proc = not_found_proc
    end
    def new
      SyncedLookupCache.new(@not_found_proc)
    end
  end

end
