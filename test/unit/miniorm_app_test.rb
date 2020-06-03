# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class MiniORMAppTest < Test::Unit::TestCase

  class TestObjRef < MiniORM::Record
    table :miniorm_app_ref do |t|
      t.column :objref, :ref, nullable:true, db_name:"obj_id"
      t.where :ref_less_than, 'obj_id < ?', :objref
    end
  end

  def test_objref_column
    KApp.with_pg_database do |db|
      db.perform <<__E
        CREATE TABLE #{KApp.db_schema_name}.miniorm_app_ref (
          id SERIAL PRIMARY KEY,
          obj_id INT
        );
__E
    end
    ref0 = TestObjRef.new
    ref0.ref = nil
    ref0.save
    ref0_reload = TestObjRef.read(ref0.id)
    assert_equal nil, ref0_reload.ref

    objrefval = KObjRef.new(19989)
    ref1 = TestObjRef.new
    ref1.ref = objrefval
    ref1.save
    ref1_reload = TestObjRef.read(ref1.id)
    assert ref1_reload.ref.kind_of?(KObjRef)
    assert_equal 19989, ref1_reload.ref.obj_id
    assert !objrefval.equal?(ref1_reload.ref) # different object

    # use in conditions
    assert_equal ref0.id, TestObjRef.where(:ref => nil).first.id
    assert_equal ref1.id, TestObjRef.where(:ref => objrefval).first().id
    assert_equal 0, TestObjRef.where(:ref => KObjRef.new(76)).count()

    # where by SQL
    assert_equal 1, TestObjRef.where_ref_less_than(KObjRef.new(20000)).count()
    assert_equal 0, TestObjRef.where_ref_less_than(KObjRef.new(1)).count()
  ensure
    KApp.with_pg_database { |db| db.perform("DROP TABLE #{KApp.db_schema_name}.miniorm_app_ref") }
  end

end
