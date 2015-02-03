# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KLabelsTest < Test::Unit::TestCase

  def test_label_list
    # Bad lists
    assert_raise(RuntimeError) { KLabelList.new([-1]) }
    assert_raise(RuntimeError) { KLabelList.new([0]) }
    assert_raise(RuntimeError) { KLabelList.new([nil]) }
    assert_raise(RuntimeError) { KLabelList.new([1,2,3,4,-1]) }
    assert_raise(RuntimeError) { KLabelList.new([2,4,0,23]) }
    assert_raise(RuntimeError) { KLabelList.new([238,12,nil,2398]) }

    # Construction
    assert_equal [], KLabelList.new([])._to_internal
    assert_equal [1,2,3,4], KLabelList.new([1,2,3,4])._to_internal
    assert_equal [1,2,3,4], KLabelList.new([2,4,3,1])._to_internal
    assert_equal [1,2,3,4], KLabelList.new([2,4,3,1,3])._to_internal
    assert KLabelList.new([2])._to_internal.frozen?
    assert_equal [5,6], KLabelList.new([KObjRef.new(6), KObjRef.new(5)])._to_internal

    # Equality etc
    assert KLabelList.new([]).empty?
    list0 = KLabelList.new([5,8])
    assert ! list0.empty?
    assert list0 == KLabelList.new([8,5])
    assert list0 != KLabelList.new([12])
    assert list0.eql?(KLabelList.new([5,8]))
    assert_equal [5,8].hash, list0.hash
    assert_equal [5,8] <=> [10,23], list0 <=> KLabelList.new([10,23])
    assert list0 != nil
    assert list0 != false

    # Inclusion
    list1 = KLabelList.new([9,5,2,10])
    assert list1.include?(9)
    assert list1.include?(2)
    assert list1.include?(10)
    assert ! list1.include?(9999)
    list2 = KLabelList.new([])
    assert ! list2.include?(2)

    assert list1.include_all?(KLabelList.new([5,2]))
    assert ! list1.include_all?(KLabelList.new([5,2,20]))
    assert ! list1.include_all?(KLabelList.new([20]))
    assert ! list1.include_all?(KLabelList.new([]))
    assert list1.include_all?(KLabelList.new([5,2,2,2,2,2,2,2]))

    # Enumeration etc
    assert_equal 4, list1.length
    assert_equal KObjRef.new(5), list1[1]
    assert_equal [KObjRef.new(2), KObjRef.new(5), KObjRef.new(9), KObjRef.new(10)], list1.map { |x| x }

    # SQL values
    list3 = KLabelList.new([23,9])
    assert_equal "{9,23}", list3._to_sql_value
    assert_equal [], KLabelList._from_sql_value("{}")._to_internal
    assert_equal [3,88], KLabelList._from_sql_value("{88,3}")._to_internal
    assert KLabelList._from_sql_value("{88,3}").frozen?
    assert_raise(RuntimeError) { KLabelList._from_sql_value("pants") }

    # Creating copies with changed values
    list4 = KLabelList.new([7,5])
    assert_equal [5,7], list4._to_internal
    list5 = list4.copy_adding([1,9,9]) # repeated 9
    assert_equal [5,7], list4._to_internal # didn't change
    assert_equal [1,5,7,9], list5._to_internal
    assert list5._to_internal.frozen?
    list6 = list4.copy_removing([1,7,7,7]) # includes a value not in it, repeated 7
    assert_equal [5,7], list4._to_internal # didn't change
    assert_equal [5], list6._to_internal
    assert list6._to_internal.frozen?
  end

  # ----------------------------------------------------------------------------------------------------

  def test_label_changes
    # Make sure that some list elements are specified as KObjRefs in the change lists

    list0 = KLabelList.new([2,3,KObjRef.new(4),5])

    c0 = KLabelChanges.new([KObjRef.new(2),1,2], [6,KObjRef.new(5)])
    assert_equal [1,2,3,4], c0.change(list0)._to_internal
    assert_equal "uniq(sort_asc(((((labels)+'{1,2}'::int[]))-'{5,6}'::int[])))", c0._sql_expression("labels")

    c1 = KLabelChanges.new()
    assert_equal c1.object_id, c1.add(1).object_id # returns itself
    c1.add([2])
    assert_equal c1.object_id, c1.remove(3).object_id # returns itself
    assert_equal [1,2,4,5], c1.change(list0)._to_internal
    assert_equal "uniq(sort_asc(((((ll)+'{1,2}'::int[]))-'{3}'::int[])))", c1._sql_expression("ll")
    assert_equal false, c1.empty?
    assert c1.will_add?(2)

    c2 = KLabelChanges.new()
    c2.add([10,KObjRef.new(11)])
    assert_equal [2,3,4,5,10,11], c2.change(list0)._to_internal
    assert_equal "uniq(sort_asc(((llx)+'{10,11}'::int[])))", c2._sql_expression("llx")
    assert_equal false, c2.empty?
    assert c2.will_add?(10)
    assert ! c2.will_remove?(10)
    assert c2.will_add?(11)
    assert ! c2.will_add?(2)

    c3 = KLabelChanges.new()
    c3.remove([5,KObjRef.new(4)])
    assert_equal [2,3], c3.change(list0)._to_internal
    assert_equal "uniq(sort_asc(((lly)-'{4,5}'::int[])))", c3._sql_expression("lly")
    assert_equal false, c3.empty?
    assert c3.will_remove?(5)
    assert ! c3.will_add?(5)

    c4 = KLabelChanges.new()
    assert_equal [2,3,4,5], c4.change(list0)._to_internal
    assert_equal "hello", c4._sql_expression("hello")
    assert_equal true, c4.empty?
    assert ! c4.will_add?(5)
    assert ! c4.will_remove?(5)

    # Generating changes between label lists
    [
      [[2,3,4,5,6], [4,5,6,7,8]],
      [[], []],
      [[], [3,5,6,7]],
      [[3,5,6,6], []]
    ].each do |from, to|
      ll1 = KLabelList.new(from)
      ll2 = KLabelList.new(to)
      c4 = KLabelChanges.changing(ll1, ll2)
      assert_equal ll2, c4.change(ll1)
    end
  end

  # ----------------------------------------------------------------------------------------------------

  def test_statements
    # Construction
    perms = KLabelStatementsOps.new
    perms.statement(:read, KLabelList.new([3,4,5]), KLabelList.new([9,10]))
    perms.statement(:create, KLabelList.new([5]), KLabelList.new([3,9,10]))
    perms.statement(:null, KLabelList.new([]), KLabelList.new([]))
    perms.statement(:no_deny, KLabelList.new([7,4,6]), KLabelList.new([]))
    perms.statement(:no_allow, KLabelList.new([]), KLabelList.new([3,6,6]))
    perms.statement(:overlapping, KLabelList.new([5,6]), KLabelList.new([5]))
    perms.freeze
    assert_raise(TypeError) { perms.statement(:pants, KLabelList.new([20]), KLabelList.new([])) }
    assert ! perms.is_superuser?

    # Operations allowed given label list?
    assert perms.allow?(:read, KLabelList.new([3,4,20]))
    assert ! perms.allow?(:read, KLabelList.new([]))
    assert ! perms.allow?(:read, KLabelList.new([4,5,20,10]))
    assert ! perms.allow?(:create, KLabelList.new([3,4,20]))
    assert ! perms.allow?(:read, KLabelList.new([1999,3993,2984,3498,1]))
    assert ! perms.allow?(:null, KLabelList.new([1999,3993,2984,3498,1]))
    assert ! perms.allow?(:null, KLabelList.new([]))
    assert perms.allow?(:no_deny, KLabelList.new([5,2,6]))
    assert ! perms.allow?(:no_allow, KLabelList.new([2]))

    # Tests on individual labels
    assert perms.label_is_allowed?(:read, 4)
    assert ! perms.label_is_allowed?(:read, 1)
    assert ! perms.label_is_allowed?(:read, 10)
    assert ! perms.label_is_allowed?(:overlapping, 5) # in allow and deny lists
    assert perms.label_is_denied?(:read, 10)
    assert ! perms.label_is_denied?(:read, 4)
    assert perms.label_is_denied?(:overlapping, 5)
    assert ! perms.label_is_denied?(:overlapping, 6)

    # Something allowed?
    assert perms.something_allowed?(:read)
    assert perms.something_allowed?(:create)
    assert ! perms.something_allowed?(:null)
    assert perms.something_allowed?(:no_deny)
    assert ! perms.something_allowed?(:no_allow)
    assert ! perms.something_allowed?(:made_this_one_up)

    # SQL statement generation
    assert_equal "FALSE", perms._sql_condition(:null, "labels")
    assert_equal "FALSE", perms._sql_condition(:no_allow, "labels")
    assert_equal "(labels && '{4,6,7}'::int[])", perms._sql_condition(:no_deny, "labels")
    assert_equal "((labels && '{3,4,5}'::int[]) AND NOT (labels && '{9,10}'::int[]))", perms._sql_condition(:read, "labels")
    # Check additiona excludes
    assert_equal "FALSE", perms._sql_condition(:null, "labels", nil)
    assert_equal "FALSE", perms._sql_condition(:no_allow, "labels", [])
    assert_equal "(labels && '{4,6,7}'::int[])", perms._sql_condition(:no_deny, "labels", nil)
    assert_equal "(labels && '{4,6,7}'::int[])", perms._sql_condition(:no_deny, "labels", [])
    assert_equal "((labels && '{4,6,7}'::int[]) AND NOT (labels && '{12}'::int[]))", perms._sql_condition(:no_deny, "labels", [12])
    assert_equal "((labels && '{4,6,7}'::int[]) AND NOT (labels && '{12,20}'::int[]))", perms._sql_condition(:no_deny, "labels", [20,12,20]) # test sort & uniq
    assert_equal "((labels && '{3,4,5}'::int[]) AND NOT (labels && '{9,10}'::int[]))", perms._sql_condition(:read, "labels", [10])
    assert_equal "((labels && '{3,4,5}'::int[]) AND NOT (labels && '{9,10,12,99}'::int[]))", perms._sql_condition(:read, "labels", [10,99,12])
  end

  # ----------------------------------------------------------------------------------------------------

  def test_combined_statements
    a = KLabelStatementsOps.new
    a.statement(:read, KLabelList.new([3,4,5]), KLabelList.new([9,10]))
    a.statement(:write, KLabelList.new([99]), KLabelList.new([101]))
    a.statement(:ping, KLabelList.new([200]), KLabelList.new([400]))
    b = KLabelStatementsOps.new
    b.statement(:read, KLabelList.new([5,6,7]), KLabelList.new([10,11]))
    b.statement(:write, KLabelList.new([100]), KLabelList.new([102]))

    # Basic checks on assumptions
    label_list_0 = KLabelList.new([3,4,20])
    assert a.allow?(:read, label_list_0)
    assert ! a.allow?(:write, label_list_0)
    assert ! b.allow?(:read, label_list_0)

    assert a.something_allowed?(:ping)
    assert ! b.something_allowed?(:ping)

    # Check types
    [[:and,KLabelStatementsAnd],["and",KLabelStatementsAnd],[:or,KLabelStatementsOr],["or",KLabelStatementsOr]].each do |op,klass|
      assert KLabelStatements.combine(a,b,op).kind_of? klass
    end
    assert_raises(RuntimeError) { KLabelStatements.combine(a,b,"pants") }

    # Basic checks for logic
    combined_and = KLabelStatements.combine(a,b,:and)
    combined_or = KLabelStatements.combine(a,b,:or)

    assert ! combined_and.label_is_allowed?(:read, 3)
    assert combined_or.label_is_allowed?(:read, 3)

    assert ! combined_and.label_is_denied?(:read, 9)
    assert combined_or.label_is_denied?(:read, 9)

    assert ! combined_and.allow?(:read, label_list_0)
    assert combined_or.allow?(:read, label_list_0)

    assert ! combined_and.something_allowed?(:ping)
    assert combined_or.something_allowed?(:ping)

    # Full checks for logic with mock classes to check methods called on underlying statements and full truth tables
    [
      [:label_is_allowed?, [:read, 3]],
      [:label_is_denied?, [:read, 9]],
      [:allow?, [:read, label_list_0]],
      [:something_allowed?, [:ping]]
    ].each do |symbol, valid_args|
      TRUTH_TABLES.each do |operation, a_value, b_value, combined_value|
        mock_a = MockLabelStatements.new(symbol, a_value)
        mock_b = MockLabelStatements.new(symbol, b_value)
        combined = KLabelStatements.combine(mock_a, mock_b, operation)
        assert_equal combined_value, combined.__send__(symbol, *valid_args)
      end
    end

    # Check SQL generation
    a_sql = a._sql_condition(:read, 'labels')
    assert_equal "((labels && '{3,4,5}'::int[]) AND NOT (labels && '{9,10}'::int[]))", a_sql
    b_sql = b._sql_condition(:read, 'labels')
    assert a_sql != b_sql
    assert_equal "(#{a_sql} AND #{b_sql})", combined_and._sql_condition(:read, 'labels')
    assert_equal "(#{a_sql} OR #{b_sql})", combined_or._sql_condition(:read, 'labels')
  end

  TRUTH_TABLES = [
    [:or,  false, false, false],
    [:or,  true,  false, true],
    [:or,  false, true,  true],
    [:or,  true,  true,  true],
    [:and, false, false, false],
    [:and, true,  false, false],
    [:and, false, true,  false],
    [:and, true,  true,  true],
  ]

  class MockLabelStatements
    def initialize(symbol, value)
      @symbol = symbol
      @value = value
    end
    def method_missing(symbol, *args)
      raise "Unexpected method call" if symbol != @symbol
      @value
    end
  end

  # ----------------------------------------------------------------------------------------------------

  def test_superuser_statements
    superuser = KLabelStatements.super_user
    assert superuser.frozen?
    assert superuser.is_superuser?
    assert superuser.allow?(:read, KLabelList.new([23,5,7]))
    assert superuser.allow?(:read, KLabelList.new([]))
    assert superuser.allow?(:anything, KLabelList.new([]))
    assert superuser.label_is_allowed?(:ping, 10)
    assert ! superuser.label_is_denied?(:ping, 1999)
    assert superuser.something_allowed?(:carrots)
    assert_equal "TRUE", superuser._sql_condition(:read, "labels")
    assert_equal "TRUE", superuser._sql_condition(:whatever, "labels")
    assert_equal "(NOT (labels && '{4,6,99}'::int[]))", superuser._sql_condition(:whatever, "labels", [4,"99",6])
  end

  # ----------------------------------------------------------------------------------------------------

  def test_bitmask_statement_construction
    operation_bits = [[:read, 1], [:update, 2], [:delete, 4], [:carrots, 8]]

    perms1 = KLabelStatements.from_bitmasks([
        [3, 7, 0],  # not sorted
        [1, 1, 4],
        [2, 2, 6],
        [4, 0, 2]
      ], operation_bits)
    assert perms1.frozen?
    assert_equal [
        {:read => [1,3], :update => [2,3], :delete => [3], :carrots => []},
        {:read => [], :update => [2,4], :delete => [1,2], :carrots => []}
      ], perms1._internal_states
  end

end
