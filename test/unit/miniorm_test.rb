# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class MiniORMTest < Test::Unit::TestCase

  def create_miniorm_test_table
    KApp.with_pg_database do |db| 
      db.perform <<__E
        CREATE TABLE a#{KApp.current_application}.miniorm_test (
          id SERIAL PRIMARY KEY,
          number INT NOT NULL,
          numberdef INT NOT NULL DEFAULT(3),
          bignumber BIGINT,
          smallnumber SMALLINT,
          dbbool BOOLEAN,
          string TEXT NOT NULL,
          maybestring TEXT
        );
__E
    end
  end

  def drop_miniorm_test_table
    KApp.with_pg_database do |db|
      db.perform("DROP TABLE a#{KApp.current_application}.miniorm_test")
    end
  end

  class TestRecord < MiniORM::Record
    table :miniorm_test do |t|
      t.column :int, :number
      t.column :int, :numberdef
      t.column :bigint, :bignumber
      t.column :smallint, :smallnumber
      t.column :boolean, :boolean, db_name:"dbbool", nullable:true
      t.column :text, :string
      t.column :text, :maybestring, nullable:true
      t.where :less_than_number, "number < ?", :int
      t.where :number_and_bool, "number = ? AND dbbool = ?", :int, :boolean
      t.where :with_other_table, "number IN (SELECT id FROM %SCHEMA%.users WHERE id > ?)", :int
      t.order :number_desc, 'number DESC'
    end
    # Callbacks
    def before_save; tc(:before_save); end
    def after_save; tc(:after_save); end
    def after_create; tc(:after_create); end
    def after_update; tc(:after_update); end
    def before_delete; tc(:before_delete); end
    def after_delete
      tc(:after_delete)
      # Check this callback is called before values are wiped
      raise "No id" unless self.id > 0
      raise "No value" unless self.string != nil && self.string.length > 0
    end
    def tc(callback_name)
      l = Thread.current[:test_record_callbacks_made]
      l.push([callback_name, self.id, self.number]) if l
    end
  end

  # -------------------------------------------------------------------------

  def test_create_read
    create_miniorm_test_table()
    r0 = TestRecord.new
    assert_equal true, r0.changed?
    assert_equal false, r0.attribute_changed?(:number)
    r0.number = 5
    assert_equal true, r0.changed?
    assert_equal true, r0.attribute_changed?(:number)
    r0.string = "Hello"
    assert_equal nil, r0.id
    r0.smallnumber = -400
    r0.bignumber = 2826152738326
    r0.boolean = true
    r0.save
    assert_equal false, r0.changed?
    r0.smallnumber = -400
    assert_equal false, r0.attribute_changed?(:smallnumber) # because actual value didn't change, even though it was assigned
    assert_equal false, r0.changed?

    assert_equal 5, r0.number
    assert_equal nil, r0.numberdef # because not set explictly
    assert_equal "Hello", r0.string
    assert_equal nil, r0.maybestring
    assert r0.id > 0

    r0_reload = TestRecord.read(r0.id)
    assert_equal false, r0_reload.changed?
    assert r0_reload.kind_of?(TestRecord)
    assert_equal r0.id, r0_reload.id
    assert_equal 5, r0_reload.number
    assert_equal 3, r0_reload.numberdef # default set by database
    assert_equal "Hello", r0_reload.string
    assert_equal true, r0_reload.string.frozen?
    assert_equal nil, r0_reload.maybestring
    assert_equal -400, r0_reload.smallnumber
    assert_equal true, r0_reload.boolean
    assert_equal 2826152738326, r0_reload.bignumber

    r0_reload.save # noop, as no changes
    assert_equal false, r0_reload.changed?
    r0_reload.maybestring = "World"
    assert_equal true, r0_reload.changed?
    r0_reload.numberdef = 23
    r0_reload.boolean = false # renamed column
    r0_reload.save
    assert_equal false, r0_reload.changed?

    r0_reload2 = TestRecord.read(r0.id)
    assert_equal r0.id, r0_reload2.id
    assert_equal 5, r0_reload2.number
    assert_equal 23, r0_reload2.numberdef
    assert_equal "Hello", r0_reload2.string
    assert_equal "World", r0_reload2.maybestring

    r1 = TestRecord.new
    r1.number = 5
    r1.string = "Ping"
    r1.save

    assert_equal 2, TestRecord.where().count
    assert_equal 1, TestRecord.where(:string => 'Ping').count
    assert_equal 1, TestRecord.where(:string => 'Ping', :number => 5).count
    assert_equal 0, TestRecord.where(:string => 'Ping', :number => 50).count

    s0 = TestRecord.where().select
    assert_equal 2, s0.length

    first0 = TestRecord.where().first
    assert_equal s0[0].id, first0.id

    first1 = TestRecord.where(:string => 'NOT IN TABLE').first
    assert_equal nil, first1

    s1 = TestRecord.where(:string => 'Ping').select
    assert_equal 1, s1.length
    assert_equal r1.id, s1[0].id
    assert_equal 5, s1[0].number
    assert_equal "Ping", s1[0].string

    s2 = TestRecord.where(:maybestring => nil).select
    assert_equal 1, s2.length
    assert_equal r1.id, s2[0].id

    s3 = TestRecord.where(:maybestring => nil).where(:string => 'Ping').select
    assert_equal 1, s3.length
    assert_equal r1.id, s3[0].id

    s4_rows = []
    q4 = TestRecord.where(:maybestring => nil).where(:string => 'Ping')
    rval = q4.each do |row|
      s4_rows << row
    end
    assert_equal 1, s4_rows.length
    assert_equal r1.id, s4_rows[0].id
    assert rval.equal?(q4)

    s5 = TestRecord.where(:boolean => false).select # query on renamed column
    assert_equal 1, s5.length
    assert_equal r0.id, s5[0].id 

    # Generated special queries
    s6 = TestRecord.where_less_than_number(7).select
    assert_equal 2, s6.length
    s6.each do |r|
      assert_equal 5, r.number # all have number = 5
    end
    assert_equal 0, TestRecord.where_less_than_number(3).count

    s7 = TestRecord.where_number_and_bool(5, false).select
    assert_equal 1, s7.length
    assert_equal r0.id, s7[0].id

    # Can combine special cases and normal where() clauses
    s8 = TestRecord.where(:boolean => false).where_less_than_number(8).select
    assert_equal 1, s8.length
    assert_equal r0.id, s8[0].id

    # Error when trying to use column name that doesn't exist
    assert_raises(MiniORM::MiniORMException, "Conditions in where() clause contains unknown key") do
      TestRecord.where(:does_not_exist => 6)
    end

    # IS NOT NULL
    s10 = TestRecord.where().where_not_null(:boolean).select
    assert_equal 1, s10.length
    assert_equal r0.id, s10[0].id

    assert_raises(MiniORM::MiniORMException, "Unknown column does_not_exist for where_not_null()") do
      TestRecord.where().where_not_null(:does_not_exist)
    end
    assert_raises(MiniORM::MiniORMException, "text is not nullable") do
      TestRecord.where().where_not_null(:text)
    end

    # Interleaved writes on object, checking only dirty values are written to database
    r1b = TestRecord.read(r1.id)
    r1b.number = 6
    r1b.save
    r1.string = 'Pong'
    r1.save
    r1_reload = TestRecord.read(r1.id)
    assert_equal 6, r1_reload.number
    assert_equal 'Pong', r1_reload.string

    r1_id = r1.id
    r1.delete
    assert_equal 1, TestRecord.where().count
    assert_equal nil, r1.id
    assert_equal nil, r1.number
    assert_equal nil, r1.string
    assert_equal nil, r1.numberdef
    assert_equal nil, r1.maybestring
    assert_equal true, r1.changed? # as no longer something in database
    assert_raises MiniORM::MiniORMRecordNotFoundException, "MiniORMTest::TestRecord id #{r1_id} does not exist" do
      TestRecord.read(r1_id)
    end
    r1b.number = 7
    assert_raises MiniORM::MiniORMRecordNotFoundException, "MiniORMTest::TestRecord id #{r1_id} does not exist in database for update" do
      r1b.save
    end
    # first record still exists
    r0_still_exists = TestRecord.read(r0.id)
    assert_equal "Hello", r0_still_exists.string

    # Can reference current schema in WHERE clause (just checks valid SQL is generated; other tests should check query)
    s20 = TestRecord.where_with_other_table(7).select()
  ensure
    drop_miniorm_test_table
  end

  # -------------------------------------------------------------------------

  def test_order_and_limit
    create_miniorm_test_table()
    [9, 0, 42, -92, 6, 11, -12, 45].each do |n|
      r = TestRecord.new
      r.number = n
      r.string = "Number #{n}"
      r.save
    end
    assert_equal [45, 42, 11, 9, 6, 0, -12, -92], TestRecord.where().order(:number_desc).select().map { |r| r.number }
    assert 3, TestRecord.where().limit(3).select().map { |r| r.number }
    assert_equal [45, 42, 11, 9, 6], TestRecord.where().order(:number_desc).limit(5).select().map { |r| r.number }
    assert_equal [45, 42, 11, 9, 6, 0, -12, -92], TestRecord.where().order(:number_desc).limit(1000).select().map { |r| r.number }

    assert_equal 45, TestRecord.where().order(:number_desc).first.number
    assert_equal 45, TestRecord.where().order(:number_desc).limit(100).first.number
    assert_equal 45, TestRecord.where().order(:number_desc).limit(0).first.number # ignores limit

    assert_equal 8, TestRecord.where().limit(5).count() # SQL doesn't do limits on COUNT(*) queries, so limit is ignored

    # Can't do accidental SQL injection with limit
    assert_equal [], TestRecord.where().limit("; DROP TABLE a#{KApp.current_application}.users;").select
    assert_equal "LIMIT 0", TestRecord.where().limit("; DROP TABLE a#{KApp.current_application}.users;")._limit_sql()
    assert_equal "LIMIT 5", TestRecord.where().limit("5")._limit_sql()

    assert_raises MiniORM::MiniORMException, "Order does_not_exist was not defined in table definition" do
      TestRecord.where().order(:does_not_exist)
    end
    assert_raises MiniORM::MiniORMException, "Order already set" do
      TestRecord.where().order(:number_desc).order(:number_desc)
    end
    assert_raises MiniORM::MiniORMException, "Limit already set" do
      TestRecord.where().limit(10).limit(10)
    end
  ensure
    drop_miniorm_test_table
  end

  # -------------------------------------------------------------------------

  def test_delete_conditionals
    create_miniorm_test_table()
    0.upto(10) do |i|
      r = TestRecord.new
      r.number = i
      r.string = "Record #{i}"
      r.numberdef = i % 2
      r.save
    end
    assert_equal 11, TestRecord.where().count
    assert_equal 6, TestRecord.where(:numberdef => 0).count
    deleted_count = TestRecord.where(:numberdef => 0).delete
    assert_equal 6, deleted_count
    assert_equal 0, TestRecord.where(:numberdef => 0).delete # repeat 
    assert_equal 0, TestRecord.where(:numberdef => 10000).delete # different value
    assert_equal 5, TestRecord.where().count
    numbers = TestRecord.where().select.map { |r| r.number } .sort
    assert_equal [1,3,5,7,9], numbers
    TestRecord.read(4).delete # number==3
    numbers = TestRecord.where().select.map { |r| r.number } .sort
    assert_equal [1,5,7,9], numbers
    TestRecord.where(:number => 7).delete
    numbers = TestRecord.where().select.map { |r| r.number } .sort
    assert_equal [1,5,9], numbers
  ensure
    drop_miniorm_test_table
  end

  # -------------------------------------------------------------------------

  def test_record_callbacks
    create_miniorm_test_table()
    Thread.current[:test_record_callbacks_made] = callbacks = []
    r1 = TestRecord.new
    r1.number = 19
    r1.string = "Record"
    r1.save
    assert_equal 1, r1.id
    assert_equal callbacks, [[:before_save, nil, 19], [:after_create, 1, 19], [:after_save, 1, 19]]
    callbacks.clear
    r1 = TestRecord.read(r1.id)
    r1.number = 28
    r1.save
    assert_equal callbacks, [[:before_save, 1, 28], [:after_update, 1, 28], [:after_save, 1, 28]]
    callbacks.clear
    r1.delete
    assert_equal callbacks, [[:before_delete, 1, 28], [:after_delete, 1, 28]]
  ensure
    Thread.current[:test_record_callbacks_made] = nil
    drop_miniorm_test_table
  end

  # -------------------------------------------------------------------------

  def test_transaction
    create_miniorm_test_table()
    assert_raises(RuntimeError) do
      MiniORM.transaction do
        r = TestRecord.new
        r.number = 16
        r.string = 'hello'
        r.save
        raise "Abort transaction"
      end
    end
    assert_equal 0, TestRecord.where().count()
    MiniORM.transaction do
      r = TestRecord.new
      r.number = 16
      r.string = 'hello'
      r.save
    end
    assert_equal 1, TestRecord.where().count()
  ensure
    drop_miniorm_test_table
  end

  # -------------------------------------------------------------------------

  class TestTimestamp < MiniORM::Record
    table :miniorm_timestamp do |t|
      t.column :timestamp, :value, nullable:true
    end
  end

  def test_timestamp
    KApp.with_pg_database do |db|
      db.perform <<__E
        CREATE TABLE a#{KApp.current_application}.miniorm_timestamp (
          id SERIAL PRIMARY KEY,
          value TIMESTAMP
        );
__E
    end
    time0 = TestTimestamp.new
    time0.value = nil
    time0.save
    time0_reload = TestTimestamp.read(time0.id)
    assert_equal nil, time0_reload.value

    timeval = Time.new(2014, 3, 21, 12, 0, 60.00005) # needs greated than ms precision
    time1 = TestTimestamp.new
    time1.value = timeval
    time1.save
    time1_reload = TestTimestamp.read(time1.id)
    assert time1_reload.value.kind_of?(Time)
    assert_equal timeval, time1_reload.value
    assert !timeval.equal?(time1_reload.value) # different object
  ensure
    KApp.with_pg_database { |db| db.perform("DROP TABLE a#{KApp.current_application}.miniorm_timestamp") }
  end

  # -------------------------------------------------------------------------

  class TestBytes < MiniORM::Record
    table :miniorm_bytes do |t|
      t.column :bytea, :data, nullable:true
    end
  end

  def test_bytea
    KApp.with_pg_database do |db|
      db.perform <<__E
        CREATE TABLE a#{KApp.current_application}.miniorm_bytes (
          id SERIAL PRIMARY KEY,
          data BYTEA
        );
__E
    end
    data = File.open("test/fixtures/files/example5.png","rb") { |f| f.read }
    assert_equal Encoding::BINARY, data.encoding
    bytes0 = TestBytes.new
    bytes0.data = data
    bytes0.save
    bytes0_reload = TestBytes.read(bytes0.id)
    assert_equal Encoding::BINARY, bytes0_reload.data.encoding
    assert_equal data, bytes0_reload.data

    bytes1 = TestBytes.new
    bytes1.data = nil
    bytes1.save
    bytes1_reload = TestBytes.read(bytes1.id)
    assert_equal nil, bytes1_reload.data
  ensure
    KApp.with_pg_database { |db| db.perform("DROP TABLE a#{KApp.current_application}.miniorm_bytes") }
  end

  # -------------------------------------------------------------------------

  class TestIntArray < MiniORM::Record
    table :miniorm_intarray do |t|
      t.column :int_array, :iarray, nullable:true
    end
  end

  def test_int_array
    KApp.with_pg_database do |db|
      db.perform <<__E
        CREATE TABLE a#{KApp.current_application}.miniorm_intarray (
          id SERIAL PRIMARY KEY,
          iarray INT[]
        );
__E
    end
    ia0 = TestIntArray.new
    ia0.iarray = nil
    ia0.save
    ia0_reload = TestIntArray.read(ia0.id)
    assert_equal nil, ia0_reload.iarray

    iavalue = [1,6,89,10,-42]
    ia1 = TestIntArray.new
    ia1.iarray = iavalue
    ia1.save
    ia1_reload = TestIntArray.read(ia1.id)
    assert ia1_reload.iarray.kind_of?(Array)
    assert_equal iavalue, ia1_reload.iarray
    assert !iavalue.equal?(ia1_reload.iarray) # different object
  ensure
    KApp.with_pg_database { |db| db.perform("DROP TABLE a#{KApp.current_application}.miniorm_intarray") }
  end

  # -------------------------------------------------------------------------

  def test_pg_hstore_sql_type
    KApp.with_jdbc_database do |db|
      sql_type = db.createArrayOf("hstore", [''].to_java(:string)).getBaseType()
      assert_equal sql_type, MiniORM::HstoreAsTextColumn.new("t",nil,nil,{}).sqltype
    end
  end

  # -------------------------------------------------------------------------

  def test_definitions_use_frozen_strings
    assert TestRecord::SELECT_SQL.frozen?
    assert TestRecord::SELECT_SQL.first.frozen?
    assert TestRecord::SELECT_SQL.last.frozen?
    assert TestRecord::Query::ORDERS.frozen?
    assert TestRecord::Query::ORDERS[:number_desc].frozen?
    assert TestRecord::Query::ORDERS[:number_desc].kind_of?(String) # not nil
  end

  # -------------------------------------------------------------------------

  def test_array_to_java_assumptions
    # Types which cannot be converted raise an error
    assert_raises(TypeError) do
      ["string"].to_java(Java::JavaLang::Integer)
    end
    assert_raises(TypeError) do
      [2].to_java(:string)
    end

    int_array = [1, 2.1, nil].to_java(Java::JavaLang::Integer)
    assert int_array.inspect.start_with?('java.lang.Integer[1, 2, null]@')
    assert_equal 3, int_array.length
    0.upto(1) { |i| assert int_array[i].kind_of?(Integer) } # JRuby converts back
    assert_equal nil, int_array[2]

    string_array = ["2", "string", nil].to_java(:string)
    assert string_array.inspect.start_with?('java.lang.String[2, string, null]@')
    assert_equal 3, string_array.length
    0.upto(1) { |i| assert string_array[i].kind_of?(String) } # JRuby converts back
    assert_equal nil, string_array[2]
  end

end

