# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class MiniORM::Table

  def initialize(name)
    @name = name
    @name_str = name.to_s.freeze
    @columns = []
    @where_defns = []
    @orders = {}
  end
  attr_accessor :name, :name_str, :columns

  def column(type, name, modifiers = {})
    klass = MiniORM::COLUMN_TYPES[type]
    raise MiniORM::MiniORMException, "Unknown column type #{type}" unless klass
    @columns << klass.new(name, modifiers[:db_name], !!modifiers[:nullable], modifiers)
  end

  def order(name, sql)
    @orders[name] = sql
  end

  def where(name, sql, *insert_types)
    insert_types.each do |type|
      raise MiniORM::MiniORMException, "Unknown where insert type #{type}" unless MiniORM::COLUMN_TYPES[type]
    end
    @where_defns << [name, sql, insert_types]
  end

  def _setup_record_class(klass)
    # Use attr_reader as higher performance than a method
    klass.send(:attr_reader, :id, *@columns.map { |c| c.name})
    code = "# frozen_string_literal: true\n".dup
    assign_args = []
    assign_all_body = ''.dup
    @columns.each_with_index do |c,index|
      assign_args << "a#{index}"
      assign_all_body << "@#{c.name} = a#{index}\n"
      # Writers need extra logic, but used less frequently, so generate code
      # TODO: Validate type of argument, check for null, etc
      code << <<__E
        def #{c.name}=(value)
          _write_attribute(:#{c.name}, value, @#{c.name})
          #{c.generate_extra_setter_code()}
          @#{c.name} = value
        end
__E
      code << c.generate_extra_record_code()
    end
    all_column_names = @columns.map { |c| c.db_name_str } .join(',')
    orders = []
    @orders.each do |name, value|
      orders.push(":#{name.to_s}=>'#{value}'")
    end
    code << <<__E
      def _assign_all_values(#{assign_args.join(',')})
        #{assign_all_body}
      end
      SELECT_SQL = ['SELECT #{all_column_names},id FROM ','.#{@name_str}'].freeze
      COUNT_SQL = ['SELECT COUNT(*) FROM ','.#{@name_str}'].freeze
      DELETE_SQL = ['DELETE FROM ','.#{@name_str}'].freeze
      READ_SQL = ['SELECT #{all_column_names} FROM ','.#{@name_str} WHERE id=? LIMIT 1'].freeze
      DELETE_RECORD_SQL = ['DELETE FROM ','.#{@name_str} WHERE id=?'].freeze
      def self.where(conditions={})
        Query.new.where(conditions)
      end
__E
    query_code = <<__E .dup
      class Query < MiniORM::QueryBase
        def record_class
          #{klass.name}
        end
        ORDERS = {#{orders.join(', ')}}
        ORDERS.freeze
__E
    # Generate code for all the special SQL queries
    @where_defns.each do |name, sql, insert_types|
      args = (0..(insert_types.length-1)).map { |i| "arg#{i}" } .join(',')
      code << <<__E
      def self.where_#{name}(#{args})
        Query.new.where_#{name}(#{args})
      end
__E
      query_code << "        def where_#{name}(#{args})\n"
      # The SQL may contain markers where the current schema name needs to be inserted
      sql_parts = sql.split('%SCHEMA%')
      if sql_parts.length == 1
        # No inserts, just use constant
        query_code << "          @where_clauses << %q~(#{sql})~\n"
      else
        # Write code to interpolate the schema name between constant strings
        sql_last = sql_parts.pop
        query_code << "          c = '('.dup\n"
        sql_parts.each do |sql_fragment|
          query_code << "          c << %q~#{sql_fragment}~\n"
          query_code << "          c << self.record_class.db_schema_name\n"
        end
        query_code << "          c << %q~#{sql_last})~\n"
        query_code << "          @where_clauses << c\n"
      end
      insert_types.each_with_index do |type, index|
        query_code << "          @insert_values << [TYPECOL__#{type.to_s.upcase}, arg#{index}]\n"
      end
      query_code << "          self\n        end\n"
    end
    code << query_code
    code << "      end"
    klass.class_eval code
  end

end
