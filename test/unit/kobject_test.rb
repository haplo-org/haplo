# coding: utf-8

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KObjectTest < Test::Unit::TestCase
  include KConstants

  def test_object_freeze_dup_and_clone
    obj = KObject.new()
    obj.add_attr('Pants', 1);
    obj.add_attr("a", 3)
    obj.freeze
    assert_raises(RuntimeError) { obj.add_attr("b", 4) }
    assert_raises(RuntimeError) { obj.delete_attrs!(4) }
    assert_raises(RuntimeError) { obj.delete_attr_if { true } }
    assert_raises(RuntimeError) { obj.replace_values! {"x"} }
    obj_dup = obj.dup
    obj_dup.add_attr("b", 4)
    obj_dup.delete_attrs!(4)
    obj_dup.delete_attr_if { true }
    assert_equal "Pants", obj.first_attr(1).to_s
    assert_equal nil, obj_dup.first_attr(1)
    # Check modification of attributes of duped objects doesn't affect the original
    copy = obj.dup
    assert copy == obj
    copy.add_attr('Ping', 1)
    assert copy != obj
    copy2 = obj.dup
    assert copy2 == obj
    copy2.delete_attrs!(1)
    assert copy2 != obj
    copy2.add_attr('Pong', 1)
    assert copy2 != obj
    # A clone of a frozen object is also frozen
    obj_clone = obj.clone
    assert_raises(RuntimeError) { obj_clone.delete_attrs!(4) }
  end

  def test_object_restrictions
    restore_store_snapshot("basic")
    # Attribute 1 is hidden apart from holders of label 100
    # Attribute 3 is read-only apart from holders of labels 100 or 200, and hidden apart from holders of label 200
    restriction1 = KObject.new([O_LABEL_STRUCTURE])
    restriction1.add_attr(O_TYPE_RESTRICTION, A_TYPE)
    restriction1.add_attr(O_TYPE_BOOK, A_RESTRICTION_TYPE)
    restriction1.add_attr(KObjRef.new(100), A_RESTRICTION_UNRESTRICT_LABEL)
    restriction1.add_attr(KObjRef.new(1), A_RESTRICTION_ATTR_RESTRICTED)
    KObjectStore.create(restriction1)

    restriction2 = KObject.new([O_LABEL_STRUCTURE])
    restriction2.add_attr(O_TYPE_RESTRICTION, A_TYPE)
    restriction2.add_attr(O_TYPE_BOOK, A_RESTRICTION_TYPE)
    restriction2.add_attr(KObjRef.new(100), A_RESTRICTION_UNRESTRICT_LABEL)
    restriction2.add_attr(KObjRef.new(200), A_RESTRICTION_UNRESTRICT_LABEL)
    restriction2.add_attr(KObjRef.new(3), A_RESTRICTION_ATTR_READ_ONLY)
    KObjectStore.create(restriction2)

    restriction3 = KObject.new([O_LABEL_STRUCTURE])
    restriction3.add_attr(O_TYPE_RESTRICTION, A_TYPE)
    restriction3.add_attr(O_TYPE_BOOK, A_RESTRICTION_TYPE)
    restriction3.add_attr(KObjRef.new(200), A_RESTRICTION_UNRESTRICT_LABEL)
    restriction3.add_attr(KObjRef.new(3), A_RESTRICTION_ATTR_RESTRICTED)
    KObjectStore.create(restriction3)

    obj = KObject.new()
    obj.add_attr(O_TYPE_BOOK, A_TYPE)
    obj.add_attr('Pants', 1);
    obj.add_attr("a", 3)
    obj.add_attr("c", 4)

    ra_none = KObject::RestrictedAttributes.new(obj, [])
    ra_100 = KObject::RestrictedAttributes.new(obj, [100])
    ra_200 = KObject::RestrictedAttributes.new(obj, [200])
    ra_300 = KObject::RestrictedAttributes.new(obj, [300])
    ra_100_200 = KObject::RestrictedAttributes.new(obj, [100,200])

    assert ra_100.can_read_attribute?(1)
    assert ra_200.can_read_attribute?(3)
    assert ra_100_200.can_read_attribute?(1)
    assert ra_100_200.can_read_attribute?(3)
    assert (not ra_200.can_read_attribute?(1))
    assert (not ra_100.can_read_attribute?(3))

    assert ra_100.can_read_attribute?(4)
    assert ra_200.can_read_attribute?(4)
    assert ra_100_200.can_read_attribute?(4)
    assert ra_none.can_read_attribute?(4)

    assert (not ra_none.can_read_attribute?(1))
    assert (not ra_300.can_read_attribute?(1))

    assert ra_100.can_modify_attribute?(3)
    assert ra_200.can_modify_attribute?(3)
    assert ra_100_200.can_modify_attribute?(3)
    assert (not ra_300.can_modify_attribute?(3))
    assert (not ra_none.can_modify_attribute?(3))

    assert ra_100.can_modify_attribute?(4)
    assert ra_200.can_modify_attribute?(4)
    assert ra_100_200.can_modify_attribute?(4)
    assert ra_none.can_modify_attribute?(4)

    # See the object as a user with label 200 only; attribute 1 disappears, but 3 and 4 remain
    robj = obj.dup_restricted(ra_200)
    assert (not obj.restricted?)
    assert robj.restricted?
    assert_equal "a", robj.first_attr(3).to_s
    assert_equal nil, robj.first_attr(1)
    assert_raises(RuntimeError) { robj.add_attr("b", 2) } # Restricted object is read only
    assert_equal "c", robj.first_attr(4).to_s
  end

  # --------------------------------------------------------------------------------------------------------

  def test_object_values_equal?
    make_obj = Proc.new do |v|
      obj = KObject.new()
      v.each { |a| obj.add_attr(*a) }
      obj
    end

    test_with_other_obj = Proc.new do |test_obj, all_result, desc1_result, v|
      other = make_obj.call(v)
      assert_equal all_result, test_obj.values_equal?(other)
      assert_equal all_result, other.values_equal?(test_obj)
      assert_equal desc1_result, test_obj.values_equal?(other, 1)
      assert_equal desc1_result, other.values_equal?(test_obj, 1)
    end

    obj1 = make_obj.call([ ["X", 1], ["Y", 1], ["Z", 2], [7, 2] ])

    assert_equal true, obj1.values_equal?(obj1)
    assert_equal true, obj1.values_equal?(obj1, 1)
    assert_equal true, obj1.values_equal?(obj1, 1, Q_NULL)
    assert_equal true, obj1.values_equal?(obj1.dup)
    assert_equal true, obj1.values_equal?(obj1.dup, 1)
    assert_equal true, obj1.values_equal?(obj1.dup, 1, Q_NULL)

    # Desc differs
    test_with_other_obj.call(obj1, false, true, [ ["X", 1], ["Y", 1], ["Z", 2], [7, 3] ])

    # Value differs
    test_with_other_obj.call(obj1, false, true, [ ["X", 1], ["Y", 1], ["Z", 2], [8, 2] ])

    # Order differs, but not within desc
    test_with_other_obj.call(obj1, true, true, [ ["Z", 2], ["X", 1], ["Y", 1], [7, 2] ])
    test_with_other_obj.call(obj1, false, true, [ ["X", 1], [7, 2], ["Z", 2], ["Y", 1] ])

    # Order differs within desc
    test_with_other_obj.call(obj1, false, true, [ ["X", 1], ["Y", 1], [8, 2], ["Z", 2] ])

    # Additional value in desc
    test_with_other_obj.call(obj1, false, true, [ ["X", 1], ["Y", 1], ["Z", 2], [7, 2], ["Ping", 2] ])

    # Q_NULL qualifier explicitly added
    test_with_other_obj.call(obj1, true, true, [ ["X", 1, Q_NULL], ["Y", 1, Q_NULL], ["Z", 2, Q_NULL], [7, 2, Q_NULL] ])

    # Qualifier changed
    test_with_other_obj.call(obj1, false, true, [ ["X", 1], ["Y", 1], ["Z", 2, 17], [7, 2] ])

    # More qualifier fun
    desc_qual_test = Proc.new do |test_obj, desc, qualifier, result, v|
      other = make_obj.call(v)
      assert_equal result, test_obj.values_equal?(other, desc, qualifier)
      assert_equal result, other.values_equal?(test_obj, desc, qualifier)
    end

    obj2 = make_obj.call([ ["Ping", 1], ["Pong", 1, 2], ["Zoink", 1], [23, 2] ])

    # Explicit Q_NULL, compares true because non-null qualifiers are ignored
    desc_qual_test.call(obj2, 1, Q_NULL, true, [ ["Ping", 1], ["Zoink", 1], ["!", 1, 23], [23, 2] ] )

    # Change one of the Q_NULL values
    desc_qual_test.call(obj2, 1, Q_NULL, false, [ ["Ping2", 1], ["Zoink", 1], ["!", 1, 23], [23, 2] ] )

    # Compared thing remains the same
    desc_qual_test.call(obj2, 1, 2, true, [ ["X", 1], ["Pong", 1, 2], ["Zoink", 4], [25, 2] ] )

    # Change one of the 2 qualifier values
    desc_qual_test.call(obj2, 1, 2, false, [ ["X", 1], ["Pong2", 1, 2], ["Zoink", 4], [25, 2] ] )

    # Can't specify any desc but give a qualifier
    assert_raises(RuntimeError) { obj1.values_equal?(obj2, nil, Q_NULL) }

  end

  # --------------------------------------------------------------------------------------------------------

  def test_dup_with_new_labels
    obj1 = KObject.new(KLabelList.new([1,2,3]))
    obj1.add_attr("a", 1)
    obj2 = obj1.dup_with_new_labels(KLabelList.new([5,6]))
    assert obj1.values_equal?(obj2)
    assert_equal [1,2,3], obj1.labels._to_internal.sort
    assert_equal [5,6], obj2.labels._to_internal.sort
  end

end

