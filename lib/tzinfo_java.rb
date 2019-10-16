# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Provides a subset of the API of the TZInfo gem, implemented using Java.
# This ruby API and java capitalize "time zone" differently.

module TZInfo

  TIMEZONE_NAMES = Java::JavaUtil::TimeZone.getAvailableIDs().map {|n| n.to_s.freeze} .sort.uniq.freeze

  TIMEZONE_VALID = {}
  TIMEZONE_NAMES.each { |n| TIMEZONE_VALID[n] = true }
  TIMEZONE_VALID.freeze

  class Timezone

    @@cache = {}

    def self.valid?(identifier)
      TIMEZONE_VALID[identifier] || false
    end

    def self.get(identifier)
      tz = @@cache[identifier]
      unless tz
        raise "Bad timezone #{timezone}" unless TZInfo::TIMEZONE_VALID[identifier] # Java returns GMT for unknown
        tz = Timezone.new(identifier, Java::JavaUtil::TimeZone.getTimeZone(identifier))
        new_cache = @@cache.dup
        new_cache[identifier] = tz
        @@cache = new_cache
      end
      tz
    end

    def initialize(identifier, java_tz)
      @identifier = identifier
      @java_tz = java_tz
    end

    attr_reader :identifier

    def utc_to_local(time)
      _adjust(time, 1)
    end

    def local_to_utc(time)
      _adjust(time, -1)
    end

    def _adjust(time, direction)
      offset_ms = @java_tz.getOffset(time.to_i * 1000)
      adjust_s = direction * (offset_ms/1000)
      if time.kind_of?(Date)
        (time.to_time + adjust_s).to_datetime
      else
        time + adjust_s
      end
    end

  end

end
