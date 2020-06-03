# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class MiniORM::QueryBase

  def initialize()
    @where_clauses = []
    @insert_values = []
  end

  def where(conditions = {})
    used_conditions = 0
    table = self.record_class.const_get(:TABLE)
    table.columns.each do |c|
      if conditions.has_key?(c.name)
        used_conditions += 1
        value = conditions[c.name]
        if value.nil?
          @where_clauses << "#{c.db_name_str} IS NULL"
        else
          @where_clauses << "#{c.db_name_str}=?"
          @insert_values << [c, value]
        end
      end
    end
    raise MiniORM::MiniORMException, "Conditions in where() clause contains unknown key" unless used_conditions == conditions.length
    self
  end

  def where_not_null(column)
    table = self.record_class.const_get(:TABLE)
    column = table.columns.find { |c| c.name == column }
    raise MiniORM::MiniORMException, "Unknown column #{column} for where_not_null()" unless column
    raise MiniORM::MiniORMException, "#{column} is not nullable" unless column.nullable
    @where_clauses << "#{column.db_name_str} IS NOT NULL"
    self
  end

  # Please avoid using this. By declaring all SQL where clauses up front, all sorts of SQL injection vunerabilities are avoided
  def unsafe_where_sql(sql)
    @where_clauses << sql
    self
  end

  def limit(limit)
    raise MiniORM::MiniORMException, "Limit already set" unless @limit.nil?
    @limit = limit
    self
  end

  def order(order)
    raise MiniORM::MiniORMException, "Order already set" unless @order.nil?
    valid_orders = self.class.const_get(:ORDERS)
    o = valid_orders[order]
    raise MiniORM::MiniORMException, "Order #{order} was not defined in table definition" unless o
    @order = o
    self
  end

  # Please avoid using this. By declaring all SQL where clauses up front, all sorts of SQL injection vunerabilities are avoided
  def unsafe_order(order_sql)
    @order = order_sql
    self
  end

  # -------------------------------------------------------------------------

  def count
    _with_query(self.record_class._sql_fragment(:COUNT_SQL)) do |results,table|
      results.next() ? results.getLong(1) : 0
    end
  end

  def select
    rows = []
    self.each { |row| rows << row }
    rows
  end

  def each
    _with_query(self.record_class._sql_fragment(:SELECT_SQL), "#{_order_sql()} #{_limit_sql()}") do |results,table|
      id_index = table.columns.length+1
      while results.next()
        yield self.record_class.new._assign_values_from_results(table, results.getInt(id_index), results)
      end
    end
    self
  end

  def first
    _with_query(self.record_class._sql_fragment(:SELECT_SQL), "#{_order_sql()} LIMIT 1") do |results,table|
      id_index = table.columns.length+1
      results.next() ? self.record_class.new._assign_values_from_results(table, results.getInt(id_index), results) : nil
    end
  end

  def delete
    row_count = _with_query(self.record_class._sql_fragment(:DELETE_SQL), _limit_sql(), false) do |results,table|
      results # is the row count
    end
    KApp.logger.info("DB #{self.record_class.name}: DELETE #{row_count} with query")
    row_count
  end

  # -------------------------------------------------------------------------

  # Please try to avoid writing SQL queries directly.
  def unsafe_get_where_clause_sql
    @where_clauses.join(' AND ')
  end
  def unsafe_insert_values_for_where_clause(statement)
    _insert_values(statement)
  end

  # -------------------------------------------------------------------------

  def _with_query(sql_begin, sql_end = nil, results_expected = true)
    table = self.record_class.const_get(:TABLE)
    sql = sql_begin
    unless @where_clauses.empty?
      sql = "#{sql} WHERE #{@where_clauses.join(' AND ')}"
    end
    sql = "#{sql} #{sql_end}" unless sql_end.nil? # not << to avoid corrupting sql_begin
    retval = nil
    KApp.with_jdbc_database do |db|
      statement = db.prepareStatement(sql)
      _insert_values(statement)
      begin
        results = results_expected ?
          statement.executeQuery() :
          statement.executeUpdate()
        retval = yield(results, table)
      ensure
        statement.close()
      end
    end
    retval
  end

  def _insert_values(statement)
    @insert_values.each_with_index do |v, index|
      c, value = v
      if value.nil?
        statement.setNull(index+1, c.sqltype)
      else
        c.set_value_in_statement(statement, index+1, value)
      end
    end
  end

  def _limit_sql
    @limit ? "LIMIT #{@limit.to_i}" : ''
  end

  def _order_sql
    @order ? "ORDER BY #{@order}" : ''
  end

end
