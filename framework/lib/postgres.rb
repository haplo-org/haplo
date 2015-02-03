# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Make pg utilities available to java in a way matching the old interface
module PGconn
  PS = Java::ComOneisUtils::PostgresSupport
  def self.escape_string(s); s == nil ? nil : String.from_java_bytes(PS.escape_string(s.to_java_bytes, false)).force_encoding(Encoding::UTF_8); end
  def self.quote(s); %Q!'#{PGconn.escape_string(s)}'!; end

  BYTEA_HEX_PACKING = 'H*'

  def self.escape_bytea(s)
    return nil if s == nil
    escaped = '\\\\x'
    escaped << s.unpack(BYTEA_HEX_PACKING).first
  end

  def self.unescape_bytea(s)
    return nil if s == nil
    raise "Trying to use unescape_bytea on a string which isn't using the hex encoding" unless s =~ /\A\\x/
    [s[2,s.length-2]].pack(BYTEA_HEX_PACKING)
  end
end

# Turn a JDBC raw connection into something approaching the old interface
class PostgresConnWrapper

  def initialize(jdbc_conn)
    @jdbc_conn = jdbc_conn
  end

  def close
    @jdbc_conn.close()
    @jdbc_conn = nil
  end

  def jdbc_connection
    @jdbc_conn
  end

  def exec(sql, *inserts)
    sql = do_inserts(sql, inserts)
    statement = @jdbc_conn.createStatement()
    statement.setEscapeProcessing(false)
    haveResults = statement.execute(sql)
    results = nil
    while true
      if haveResults
        results = Results.new(statement.getResultSet())
      elsif (update_count = statement.getUpdateCount()) != -1
        results = ResultsNoQuery.new(update_count)
      else
        break
      end
      haveResults = statement.getMoreResults()
    end
    statement.close()
    results
  end
  alias perform exec
  alias update exec

  ResultsNoQuery = Struct.new(:cmdtuples)

  class Results
    include Enumerable
    attr_reader :num_fields

    def initialize(result_set)
      @results = Array.new
      # Collect all the results into an array now, because it's impossible to tell how many rows
      # there are using the JDBC result_set
      @num_fields = result_set.getMetaData().getColumnCount()
      colrange = (1 .. @num_fields)
      while(result_set.next())
        @results << colrange.map { |i| result_set.getString(i) }
      end
      result_set.close()
    end

    # For compatibility with the existing interface
    def result
      self
    end

    # Release resources
    def clear
      @results = nil
    end

    def each
      @results.each do |row|
        yield row
      end
      nil
    end

    def first
      @results.first
    end

    def length
      @results.length
    end
  end

private
  def do_inserts(sql, inserts)
    if inserts.empty?
      sql
    else
      sql.gsub(/\$(\d)/) do |m|
        i = $1.to_i
        raise "Bad insert in PostgresConnWrapper#exec" if i <= 0 || i > inserts.length  # > because will - 1 from the insert
        value = inserts[i - 1]
        if value == nil
          'NULL'
        elsif value.kind_of? Integer
          value.to_s
        elsif value.kind_of? Float
          value.to_s
        else
          %Q!E'#{PGconn.escape_string(value.to_s)}'!
        end
      end
    end
  end

end

