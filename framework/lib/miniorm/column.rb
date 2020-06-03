# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

module MiniORM

  COLUMN_TYPES = {}

  class Column
    def initialize(name, db_name, nullable, modifiers)
      @name = name
      @name_str = name.to_s.freeze
      @db_name_str = (db_name||name).to_s.freeze
      @nullable = nullable
    end
    attr_accessor :name, :name_str, :db_name_str, :nullable

    def sqltype
      raise "Not implemented"
    end
    def set_value_in_statement(statement, index, value)
      raise "Not implemented"
    end
    def get_value_from_resultset(results, index)
      raise "Not implemented"
    end
    def generate_extra_setter_code
      ''
    end
    def generate_extra_record_code
      ''
    end

    def self._column(symbol, sqltype = nil)
      COLUMN_TYPES[symbol] = self
      self.class_eval "def sqltype; #{sqltype}; end" unless sqltype.nil?
      # QueryBase needs 'unassigned' columns to insert values in prepared statements
      QueryBase.const_set("TYPECOL__#{symbol.to_s.upcase}", self.new("query", "query", true, {}))
    end
  end

  # -------------------------------------------------------------------------

  class IntColumn < Column
    _column(:int, java.sql.Types::INTEGER)
    def set_value_in_statement(statement, index, value)
      statement.setInt(index, value)
    end
    def get_value_from_resultset(results, index)
      results.getInt(index)
    end
  end

  class SmallIntColumn < Column
    _column(:smallint, java.sql.Types::SMALLINT)
    def set_value_in_statement(statement, index, value)
      statement.setShort(index, value)
    end
    def get_value_from_resultset(results, index)
      results.getShort(index)
    end
  end

  class BigIntColumn < Column
    _column(:bigint, java.sql.Types::BIGINT)
    def set_value_in_statement(statement, index, value)
      statement.setLong(index, value)
    end
    def get_value_from_resultset(results, index)
      results.getLong(index)
    end
  end

  # -------------------------------------------------------------------------

  class IntArrayColumn < Column
    _column(:int_array, java.sql.Types::ARRAY)
    def set_value_in_statement(statement, index, value)
      Java::OrgHaploMiniorm::Values.setIntArray(statement, index, value.to_ary.to_java(Java::JavaLang::Integer))
    end
    def get_value_from_resultset(results, index)
      v = Java::OrgHaploMiniorm::Values.getIntArray(results, index)
      v ? v.map { |i| i.to_i } : nil
    end
  end

  class TextArrayColumn < Column
    _column(:text_array, java.sql.Types::ARRAY)
    def set_value_in_statement(statement, index, value)
      Java::OrgHaploMiniorm::Values.setTextArray(statement, index, value.to_ary.to_java(:string))
    end
    def get_value_from_resultset(results, index)
      v = Java::OrgHaploMiniorm::Values.getTextArray(results, index)
      v ? v.map { |i| i.to_s } : nil
    end
  end


  # -------------------------------------------------------------------------

  class BooleanColumn < Column
    _column(:boolean, java.sql.Types::BOOLEAN)
    def set_value_in_statement(statement, index, value)
      statement.setBoolean(index, value)
    end
    def get_value_from_resultset(results, index)
      results.getBoolean(index)
    end
  end

  # -------------------------------------------------------------------------

  class TextColumn < Column
    _column(:text, java.sql.Types::CHAR)
    def set_value_in_statement(statement, index, value)
      statement.setString(index, value)
    end
    def get_value_from_resultset(results, index)
      results.getString(index).freeze
    end
  end

  # -------------------------------------------------------------------------

  class TimestampColumn < Column
    _column(:timestamp, java.sql.Types::TIMESTAMP)
    def set_value_in_statement(statement, index, value)
      Java::OrgHaploMiniorm::Values.setSQLTimestampFromRubyTime(statement, index, value)
    end
    def get_value_from_resultset(results, index)
      time = Time.new
      Java::OrgHaploMiniorm::Values.setRubyTimeFromSQLTimestampValue(results, index, time) ? time : nil
    end
    def generate_extra_record_code
      <<__E
      def #{self.name_str}_milliseconds
        d = self.#{self.name_str}; d ? (d.to_f*1000).to_i : nil
      end
      def #{self.name_str}_milliseconds_set(ms)
        self.#{self.name_str} = ms.nil? ? nil : Time.at(Rational(ms,1000))
      end
__E
    end
  end

  # -------------------------------------------------------------------------

  class ByteaColumn < Column
    _column(:bytea, java.sql.Types::VARBINARY)
    def set_value_in_statement(statement, index, value)
      statement.setBytes(index, value.to_java_bytes)
    end
    def get_value_from_resultset(results, index)
      bytes = results.getBytes(index)
      bytes.nil? ? nil : String.from_java_bytes(bytes)
    end
  end

  # -------------------------------------------------------------------------

  class HstoreAsTextColumn < Column
    SQL_TYPE_HSTORE = 1111
    _column(:hstore_as_text, SQL_TYPE_HSTORE) # checked in miniorm_test.rb
    def set_value_in_statement(statement, index, value)
      statement.setObject(index, value, SQL_TYPE_HSTORE)
    end
    def get_value_from_resultset(results, index)
      results.getString(index)
    end
  end

  # -------------------------------------------------------------------------

  class JsonOnTextColumn < TextColumn
    _column(:json_on_text)
    def initialize(name, db_name, nullable, modifiers)
      super
      @deserialised_property = modifiers[:property]
      raise "No property modified set on column definition" unless @deserialised_property
    end
    def generate_extra_setter_code
      "@__deserialised_#{self.name_str} = nil"
    end
    def generate_extra_record_code
      <<__E
      def #{@deserialised_property}
        @__deserialised_#{self.name_str} ||= begin
          json = self.#{self.name_str}
          json.nil? ? nil : JSON.parse(json)
        end
      end
      def #{@deserialised_property}=(value)
        self.#{self.name_str} = if value.nil?
          nil
        elsif value.kind_of?(String)
          value
        else
          JSON.generate(value)
        end
        value
      end
__E
    end
  end

end
