# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# This patch fixes a thread safety issue with the postgresql adaptor

unless Gem.loaded_specs['activerecord-jdbcpostgresql-adapter'].version.version == '1.2.9'
  raise "Unexpected version of activerecord-jdbcpostgresql-adapter gem, shouldn't monkey patch it"
end
unless ActiveRecord::ConnectionAdapters.const_defined? :PostgreSQLAdapter
  raise "Can't monkey patch original, hasn't been loaded yet"
end

module ActiveRecord::ConnectionAdapters

  class PostgreSQLAdapter < JdbcAdapter

    @@quoted_table_names = {}

    def quote_table_name(name)
      cache = @@quoted_table_names
      unless quoted = cache[name]
        quoted = super
        cache = cache.dup
        cache[name] = quoted.freeze
        @@quoted_table_names = cache
      end
      quoted
    end

    @@quoted_column_names = {}

    def quote_column_name(name)
      cache = @@quoted_column_names
      unless quoted = cache[name]
        quoted = super
        cache = cache.dup
        cache[name] = quoted.freeze
        @@quoted_column_names = cache
      end
      quoted
    end

  end
end
