
# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# (c) Avalara, Inc 2021
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KObjectStoreTest < Test::Unit::TestCase
  include KConstants

  def test_store
    restore_store_snapshot("min")
    # Object creation
    obj = KObject.new()
    obj.add_attr('Pants', 1);
    obj.add_attr(14, 2);

    assert obj == obj
    assert obj.obj_creation_time != nil && obj.obj_creation_time == obj.obj_update_time
    assert_equal 0, obj.version
    # No user ID set yet on the object
    assert_equal nil, obj.creation_user_id
    assert_equal nil, obj.last_modified_user_id

    # Test has_attr?
    assert obj.has_attr?('Pants')
    assert obj.has_attr?('Pants', 1)
    assert obj.has_attr?(KText.new('Pants'))
    assert obj.has_attr?(14, 2)
    assert_equal false, obj.has_attr?(14.1, 2)
    assert_equal false, obj.has_attr?('Pants', 2)
    assert_equal false, obj.has_attr?(14, 1)
    assert_equal false, obj.has_attr?('Stuff')

    obj_q = KObject.new()
    obj_q.add_attr('Pants', 1, 98);
    assert obj_q.has_attr?('Pants')
    assert obj_q.has_attr?('Pants', 1)
    assert obj_q.has_attr?('Pants', 1, 98)
    assert_equal false, obj_q.has_attr?('Pants', 1, 99)
    assert_equal false, obj_q.has_attr?('Pants', 2)
    assert_equal false, obj_q.has_attr?('Pants2')

    # Another object with same content
    obj2 = KObject.new()
    obj2.add_attr('Pants', 1);
    obj2.add_attr(14, 2);

    assert obj2 == obj

    # Another object, same content, but different labels
    obj3 = KObject.new([O_LABEL_STRUCTURE])
    obj3.add_attr('Pants', 1);
    obj3.add_attr(14, 2);

    assert obj3 != obj

    # Change ID
    obj2.objref = KObjRef.new(3)
    assert obj2 != obj

    # Replace value
    obj4 = KObject.new([O_LABEL_STRUCTURE])
    obj4_initial_vals = ["Ping", "Pong", "Hello", 13, 14]
    obj4_initial_vals.each { |x| obj4.add_attr(x, 10) }
    assert_equal obj4_initial_vals.map(&:to_s), obj4.all_attrs(10).map(&:to_s)
    obj4.replace_values! do |v,d,q|
      (v.to_s == "Pong") ? "Carrots" : v
    end
    assert_equal ["Ping", "Carrots", "Hello", "13", "14"], obj4.all_attrs(10).map(&:to_s)
    assert obj4.has_attr?(KText.new("Carrots"), 10, nil)

    # Create an object, check ref & labels are set
    assert obj.objref == nil
    assert obj.labels == KLabelList.new([])
    assert_equal false, obj.is_stored?
    KObjectStore.create(obj)
    assert_equal true, obj.is_stored?
    assert obj.frozen?  # create freezes the object to prevent further modification
    assert obj.objref != nil
    assert_equal 1, obj.version
    assert obj.labels == KLabelList.new([O_LABEL_UNLABELLED])
    assert_equal [O_LABEL_UNLABELLED.to_i], obj.labels._to_internal
    # Load it back from the object store, check everything is as expected
    retrieved = KObjectStore.read(obj.objref)
    assert retrieved.frozen?
    assert retrieved == obj
    assert_equal 1, retrieved.version
    assert_equal [O_LABEL_UNLABELLED.to_i], retrieved.labels._to_internal

    # Frozen objects can't be created
    frozen_obj = KObject.new();
    frozen_obj.add_attr("x", 1)
    frozen_obj.freeze
    assert_raises(RuntimeError) { KObjectStore.create(frozen_obj) }

    # Objects returned from queries are frozen
    run_outstanding_text_indexing
    [:reference, :reference, :all].each do |option|
      [true, false].each do |do_ensure|
        fq = KObjectStore.query_and.free_text('pants').execute(option)
        assert_equal 1, fq.length
        fq.ensure_range_loaded(0,1) if do_ensure
        assert fq[0].kind_of?(KObject)
        assert fq[0].frozen?
      end
    end

    # Check reads of unknown objects return nil
    assert_equal nil, KObjectStore.read(KObjRef.new(99999999))
    assert_equal nil, KObjectStore.history(KObjRef.new(99999999))
    assert_equal nil, KObjectStore.labels_for_ref(KObjRef.new(99999999))

    # Check the stored objects doesn't include the lables
    dbr = KApp.with_pg_database { |pg| pg.exec("SELECT object,labels FROM #{KApp.db_schema_name}.os_objects WHERE id=#{obj.objref.obj_id}") }
    assert_equal '{100}', dbr.first[1] # O_LABEL_UNLABELLED
    unmarshaled = Marshal.load(PGconn.unescape_bytea(dbr.first[0]))
    assert_equal nil, unmarshaled.labels
    assert_equal nil, unmarshaled.__send__(:instance_variable_get, :@labels)

    # Set some labels directly on the row in the database, then read the object, checking the labels updated
    KApp.with_pg_database { |pg| pg.perform("UPDATE #{KApp.db_schema_name}.os_objects SET labels='{8,5,10}'::int[] WHERE id=#{obj.objref.obj_id}") }
    retrieved2 = KObjectStore.read(obj.objref)
    assert retrieved2.frozen?
    assert_equal 1, retrieved2.version # doesn't change version
    assert_equal [5,8,10], retrieved2.labels._to_internal
    assert_equal [5,8,10], KObjectStore.labels_for_ref(obj.objref)._to_internal # check the object store API agrees

    # Make sure the ID is in the correct range
    assert obj.objref.obj_id > KConstants::MAX_RESERVED_OBJID

    # Test the user ID
    assert_equal User::USER_SYSTEM, obj.creation_user_id
    assert_equal User::USER_SYSTEM, obj.last_modified_user_id

    # Set user ID
    set_mock_objectstore_user(87)

    # Create an object with a pre-allocated ID
    obj_pre_alloc_id = KObject.new([O_LABEL_UNLABELLED])
    obj_pre_alloc_id.add_attr("PREALLOC", 100)
    assert_equal nil, obj_pre_alloc_id.objref
    assert_equal false, obj_pre_alloc_id.is_stored?
    KObjectStore.preallocate_objref(obj_pre_alloc_id)
    assert obj_pre_alloc_id.objref.kind_of? KObjRef
    assert_equal false, obj_pre_alloc_id.is_stored?
    assert_equal nil, KObjectStore.read(obj_pre_alloc_id.objref)
    obj_pre_alloc_id_obj_id = obj_pre_alloc_id.objref.to_i
    assert obj_pre_alloc_id_obj_id > KObjectStore::MAX_RESERVED_OBJID
    assert_equal obj.objref.obj_id + 1, obj_pre_alloc_id_obj_id
    # Create another object
    obj_non_alloc = KObject.new([O_LABEL_UNLABELLED])
    obj_non_alloc.add_attr("NON_ALLOC", 100)
    assert_equal false, obj_non_alloc.is_stored?
    KObjectStore.create(obj_non_alloc)
    assert_equal true, obj_non_alloc.is_stored?
    assert obj_non_alloc.objref.obj_id != obj_pre_alloc_id_obj_id
    # Then create the pre-allocated object and check
    assert_equal false, obj_pre_alloc_id.is_stored?
    KObjectStore.create(obj_pre_alloc_id)
    assert_equal true, obj_pre_alloc_id.is_stored?
    assert_equal obj_pre_alloc_id_obj_id, obj_pre_alloc_id.objref.to_i
    obj_pre_alloc_id_r = KObjectStore.read(KObjRef.new(obj_pre_alloc_id_obj_id))
    assert_equal "PREALLOC", obj_pre_alloc_id_r.first_attr(100).to_s

    # Create another
    KObjectStore.create(obj3, KLabelChanges.new([89,128,2387], [O_LABEL_STRUCTURE]))
    assert_equal 1, obj3.version
    assert_equal [89,128,2387], KObjectStore.labels_for_ref(obj3.objref)._to_internal
    obj3_after_initial = obj3.dup

    # Check labels in database
    dbr = KApp.with_pg_database { |pg| pg.exec("SELECT labels FROM #{KApp.db_schema_name}.os_objects WHERE id=#{obj3.objref.obj_id}") }
    assert_equal '{89,128,2387}', dbr.first[0]

    # Change labels, update, check again
    obj3 = obj3.dup
    KObjectStore.update(obj3, KLabelChanges.new([4,1],[2387]))
    assert obj3.frozen?
    assert_equal 2, obj3.version
    dbr = KApp.with_pg_database { |pg| pg.exec("SELECT labels FROM #{KApp.db_schema_name}.os_objects WHERE id=#{obj3.objref.obj_id}") }
    assert_equal '{1,4,89,128}', dbr.first[0]

    # Check that you can't update from a pvrevious version
    assert_equal 1, obj3_after_initial.version
    obj3_after_initial.add_attr(2,5)
    assert_raises(RuntimeError) do
      KObjectStore.update(obj3_after_initial)
    end

    # Check user ID
    assert_equal 87, obj3.creation_user_id
    assert_equal 87, obj3.last_modified_user_id

    # Make sure it cannot be used to create another
    assert_raises(RuntimeError) do
      KObjectStore.create(obj3)
    end

    # Check that you can create an object with a specified ID
    obj5_8 = KObject.new([KConstants::O_LABEL_STRUCTURE])
    obj5_8.add_attr('String', 1)
    assert_raises(RuntimeError) do
      KObjectStore.create(obj5_8, nil, 0) # some IDs not allowed
    end
    assert_raises(RuntimeError) do
      KObjectStore.create(obj5_8, nil, -100) # some IDs not allowed
    end
    KObjectStore.create(obj5_8, nil, 80000)
    assert obj5_8.objref.obj_id == 80000

    # Check that it's not possible to create another object with the same ID as a previous one
    assert_raises(RuntimeError) do
      objdup = KObject.new([KConstants::O_LABEL_STRUCTURE])
      objdup.add_attr('X', 1)
      KObjectStore.create(objdup, nil, obj.objref.obj_id)
    end

    # Check an update isn't possible for an object which hasn't been created
    assert_raises(RuntimeError) do
      objn = KObject.new([KConstants::O_LABEL_STRUCTURE])
      objn.add_attr('Y', 1)
      KObjectStore.update(objn)
    end

    # Update the original object, check it comes out again with an updated last update time and the right user ID
    set_mock_objectstore_user(91)
    obj_last_update = obj.obj_update_time
    obj_creation_time = obj.obj_creation_time
    obj = obj.dup
    obj.add_attr("Hello World!", 1)
    assert retrieved != obj # check it's different now
    KObjectStore.update(obj)
    updated_obj = KObjectStore.read(obj.objref)
    assert updated_obj == obj
    assert obj_creation_time == obj.obj_creation_time
    assert obj_last_update < updated_obj.obj_update_time
    assert_equal User::USER_SYSTEM, obj.creation_user_id
    assert_equal User::USER_SYSTEM, updated_obj.creation_user_id
    assert_equal 91, obj.last_modified_user_id
    assert_equal 91, updated_obj.last_modified_user_id

    # Can't erase because permissions active
    set_mock_objectstore_user(91, KLabelStatementsOps.new.freeze)
    assert_raises(KObjectStore::PermissionDenied) do
      KObjectStore.erase(obj)
    end

    # Unset user ID and permissions
    set_mock_objectstore_user(0)

    # Delete the object
    KObjectStore.erase(obj)
    assert KObjectStore.read(obj.objref) == nil

    # Check that deleting the object again isn't appreciated
    assert_raises(RuntimeError) do
      KObjectStore.erase(obj)
    end

    # Erase an object which doesn't exist
    assert_raises(RuntimeError) do
      KObjectStore.erase(KObjRef.new(199))
    end

    # Erase history of an object
    assert_equal 1, KObjectStore.history(obj3.objref).versions.length
    assert_equal 1, KApp.with_pg_database { |db| db.exec("SELECT COUNT(*) FROM #{KApp.db_schema_name}.os_objects_old WHERE id=#{obj3.objref.to_i}").first.first.to_i }
    set_mock_objectstore_user(91, KLabelStatementsOps.new.freeze)
    assert_raises(KObjectStore::PermissionDenied) do
      KObjectStore.erase_history(obj3)
    end
    set_mock_objectstore_user(0)
    KObjectStore.erase_history(obj3)
    assert_equal 0, KObjectStore.history(obj3.objref).versions.length
    assert nil != KObjectStore.read(obj3.objref)
    assert_equal 0, KApp.with_pg_database { |db| db.exec("SELECT COUNT(*) FROM #{KApp.db_schema_name}.os_objects_old WHERE id=#{obj3.objref.to_i}").first.first.to_i }

    # ----------------------------------------------------------------------------------------
    # Create a root parent object
    root_obj = KObject.new([KConstants::O_LABEL_STRUCTURE])
    root_obj.add_attr("Root object", 1)
    root_obj.add_attr(42, 1237)
    root_obj.add_attr(Time.now, 44)
    KObjectStore.create(root_obj, nil, 100)
    assert_equal 100, root_obj.objref.obj_id

    # Create a new object, with a parent
    child_obj = KObject.new()
    child_obj.add_attr(root_obj.objref, KConstants::A_PARENT)
    KObjectStore.create(child_obj)

    # And another object, with the child as it's parent
    child_child_obj = KObject.new()
    child_child_obj.add_attr(child_obj, KConstants::A_PARENT)  # use the object itself this time
    child_child_obj.add_attr("This is a long string, and and Hello and and hello hello", 22)
    child_child_obj.add_attr(Time.now, 44)
    KObjectStore.create(child_child_obj)

    # Check adding a parent is OK
    o2 = KObject.new([KConstants::O_LABEL_STRUCTURE])
    o2.add_attr('New parent', 1)
    KObjectStore.create(o2)
    root_obj = root_obj.dup
    root_obj.add_attr(o2, KConstants::A_PARENT)
    KObjectStore.update(root_obj)
    # Remove parent
    root_obj = root_obj.dup
    root_obj.delete_attrs!(KConstants::A_PARENT)
    KObjectStore.update(root_obj)

    # Check that changing another parent
    c = child_child_obj.dup
    c.delete_attrs!(KConstants::A_PARENT)
    c.add_attr(root_obj, KConstants::A_PARENT)
    KObjectStore.update(c)

    # Check that creating an object with a specified obj_id works
    specified_obj = KObject.new()
    KObjectStore.create(specified_obj, nil, 1000)
    assert_equal 1000, specified_obj.objref.obj_id

    # Check that the next object has an id greater than that
    spec_obj2 = KObject.new()
    KObjectStore.create(spec_obj2)
    assert spec_obj2.objref.obj_id > specified_obj.objref.obj_id

    # And now check adding one with a lesser ID
    spec_obj3 = KObject.new()
    KObjectStore.create(spec_obj3, nil, 998)
    assert_equal 998, spec_obj3.objref.obj_id
  end

  def test_filter_id_list_based_on_type
    restore_store_snapshot("min")
    # Create some objects
    id_of_obj_of_type = Proc.new do |t|
      obj = KObject.new()
      obj.add_attr(t, A_TYPE)
      obj.add_attr("t "+t.to_presentation, A_TITLE)
      KObjectStore.create(obj)
      obj.objref.obj_id
    end
    book0 = id_of_obj_of_type.call(O_TYPE_BOOK)
    label0 = id_of_obj_of_type.call(O_TYPE_LABEL)
    label1 = id_of_obj_of_type.call(O_TYPE_LABEL)
    person0 = id_of_obj_of_type.call(O_TYPE_PERSON)
    all = [book0, person0, label1, label0]  # ordering different
    assert all != all.sort
    # Filter some lists
    assert_equal [label0, label1], KObjectStore.filter_id_list_to_ids_of_type(all, [O_TYPE_LABEL])
    assert_equal [label0, label1], KObjectStore.filter_id_list_to_ids_of_type(all.map(&:to_s), [O_TYPE_LABEL]) # check wrong types
    assert_equal [label1], KObjectStore.filter_id_list_to_ids_of_type([label1], [O_TYPE_LABEL])
    assert_equal [book0], KObjectStore.filter_id_list_to_ids_of_type(all, [O_TYPE_BOOK])
    assert_equal [book0, person0], KObjectStore.filter_id_list_to_ids_of_type(all, [O_TYPE_BOOK, O_TYPE_PERSON])
  end

  def test_link_to_non_existing_object
    restore_store_snapshot("min")

    retrieve_all_objects_linking_to = Proc.new do |obj_or_objref, desc|
      query = KObjectStore.query_and.link(obj_or_objref, desc)
      query.add_label_constraints([O_LABEL_STRUCTURE])
      query.execute(:all, :any)
    end

    # It's possible to create a link to an object which doesn't exist yet.
    # Check that the indexing works OK, and that the links work as expected when the
    # object does exist.
    root_obj = KObject.new([KConstants::O_LABEL_STRUCTURE])
    root_obj.add_attr("Root object", 1)
    KObjectStore.create(root_obj, nil, 100)

    # Make sure an object doesn't exist
    unlinked_ref = KObjRef.new(123)
    assert_equal nil,KObjectStore.read(unlinked_ref)
    unlinked_ref2 = KObjRef.new(124)
    assert_equal nil,KObjectStore.read(unlinked_ref2)

    # Create a new object with it as a link
    obj1 = KObject.new([KConstants::O_LABEL_STRUCTURE])
    obj1.add_attr("Linkless", 1)
    obj1.add_attr(unlinked_ref, 2)
    KObjectStore.create(obj1, nil, 110)

    # Check that a query for that object works, even if the object it's linking to doesn't exist yet.
    objs = retrieve_all_objects_linking_to.call(unlinked_ref, 2)
    assert_equal 1, objs.length

    # Find all linked to root
    objs_from_root1 = retrieve_all_objects_linking_to.call(root_obj, 2)
    assert_equal 0, objs_from_root1.length

    # Create another object linked to the second unlinked object
    obj1b = KObject.new([KConstants::O_LABEL_STRUCTURE])
    obj1b.add_attr("Linkless2", 1)
    obj1b.add_attr(unlinked_ref2, 2)
    KObjectStore.create(obj1b, nil, 111)
    # Can query for objects linking to the objects which don't exist yet
    objs = retrieve_all_objects_linking_to.call(unlinked_ref, 2)
    assert_equal 1, objs.length
    objs = retrieve_all_objects_linking_to.call(unlinked_ref2, 2)
    assert_equal 1, objs.length
    # But hierarchical queries from the root don't work yet, because an object which doesn't exist yet can't have a parent
    objs_from_root1 = retrieve_all_objects_linking_to.call(root_obj, 2)
    assert_equal 0, objs_from_root1.length

    # Now create the object corresponding to the unlinked ref
    obj2 = KObject.new([KConstants::O_LABEL_STRUCTURE])
    obj2.add_attr("Linking", 1)
    obj2.add_attr(root_obj.objref, A_PARENT)
    KObjectStore.create(obj2, nil, unlinked_ref.obj_id)
    assert_equal unlinked_ref, obj2.objref

    # Then do the searches again
    objs2 = retrieve_all_objects_linking_to.call(unlinked_ref, 2)
    assert_equal 1, objs2.length
    assert_equal obj1.objref, objs2.objref(0)
    # And from the root this time
    objs_from_root2 = retrieve_all_objects_linking_to.call(root_obj, 2)
    assert_equal 1, objs_from_root2.length
    assert_equal obj1.objref, objs_from_root2.objref(0)

    # Create the second unlinked object
    obj2b = KObject.new([KConstants::O_LABEL_STRUCTURE])
    obj2b.add_attr("Linking2", 1)
    obj2b.add_attr(root_obj.objref, A_PARENT)
    KObjectStore.create(obj2b, nil, unlinked_ref2.obj_id)
    assert_equal unlinked_ref, obj2.objref

    # Then do the searches again
    objs2b = retrieve_all_objects_linking_to.call(unlinked_ref, 2)
    assert_equal 1, objs2b.length
    assert_equal obj1.objref, objs2b.objref(0)
    objs2c = retrieve_all_objects_linking_to.call(unlinked_ref2, 2)
    assert_equal 1, objs2c.length
    assert_equal obj1b.objref, objs2c.objref(0)
    # And from the root this time
    objs_from_root2b = retrieve_all_objects_linking_to.call(root_obj, 2)
    assert_equal 2, objs_from_root2b.length
    assert_equal [obj1.objref, obj1b.objref], (0 .. objs_from_root2b.length - 1).collect {|n| objs_from_root2b.objref(n)} .sort {|a,b| a.obj_id <=> b.obj_id}
  end

  # ---------------------------------------------------------------------------------------------------------------

  def test_store_read_caching
    restore_store_snapshot("min")

    obj0 = KObject.new([1234,9876])
    obj0.add_attr("a", 100)
    KObjectStore.create(obj0)
    obj1 = KObject.new()
    obj1.add_attr("b", 100)
    KObjectStore.create(obj1)

    # Only cached on read
    assert ! objectstore_cache.include?(obj0.objref.to_i)
    assert ! objectstore_cache.include?(obj1.objref.to_i)

    objectstore_cache.clear

    assert_equal 0, objectstore_cache.length

    obj0_read = expecting_store_cache_hit(0) do
      KObjectStore.read(obj0.objref)
    end
    assert obj0 == obj0_read
    assert_equal 1, objectstore_cache.length
    expecting_store_cache_hit do
      o = KObjectStore.read(obj0.objref)
      assert o.equal?(obj0_read)
    end

    obj1_read = expecting_store_cache_hit(0) do
      KObjectStore.read(obj1.objref)
    end
    assert_equal 2, objectstore_cache.length
    5.times do
      expecting_store_cache_hit do
        KObjectStore.read(obj1.objref)
      end
    end
    expecting_store_cache_hit do
      rip = KObjectStore.read_if_permitted(obj1.objref)
      assert rip.kind_of? KObject
      assert_equal obj1.objref, rip.objref
    end

    assert_equal 2, objectstore_cache.length

    expecting_store_cache_hit do
      assert_equal [O_LABEL_UNLABELLED.to_i], KObjectStore.labels_for_ref(obj1.objref)._to_internal
    end

    # Check permissions are enforced on reads of cached objects
    perms = KLabelStatementsOps.new
    perms.statement(:read, KLabelList.new([1234]), KLabelList.new([9876]))
    set_mock_objectstore_user(87, perms)
    expecting_store_cache_hit do
      assert_raises(KObjectStore::PermissionDenied) do
        KObjectStore.read(obj0.objref)
      end
    end
    expecting_store_cache_hit do
      # Check the convenience function for reading only if permitted
      assert_equal nil, KObjectStore.read_if_permitted(obj0.objref)
    end
    set_mock_objectstore_user(0)

    obj1_update = obj1.dup
    obj1_update.add_attr("x", 101)
    expecting_store_to_uncache(obj1.objref) do
      KObjectStore.update(obj1_update)
    end

    # Can plugins mess up the cache if they load an object during an update operation?
    assert KPlugin.install_plugin("k_object_store_test/load_object_during_update")
    begin
      KObjectStore.update(obj1_update.dup)
      assert_equal obj1_update.version + 1, KObjectStore.read(obj1.objref).version
    ensure
      KPlugin.uninstall_plugin("k_object_store_test/load_object_during_update")
    end

    expecting_store_to_uncache(obj1.objref) do
      KObjectStore.relabel(obj1.objref, KLabelChanges.new([10000],[999]))
    end

    expecting_store_to_uncache(obj1.objref) do
      KObjectStore.delete(obj1.objref)
    end
    expecting_store_to_uncache(obj1.objref) do
      KObjectStore.undelete(obj1.objref)
    end

    expecting_store_to_uncache(obj1.objref, false) do
      KObjectStore.erase(obj1.objref)
    end
  end

  def objectstore_cache
    KObjectStore.store.instance_variable_get(:@object_cache)
  end

  def expecting_store_cache_hit(inc = 1)
    expected = KObjectStore.statistics.cache_hit + inc
    r = yield
    assert_equal expected, KObjectStore.statistics.cache_hit
    r
  end

  def expecting_store_to_uncache(objref, read_into_cache = true)
    start_cache_length = objectstore_cache.length
    assert objectstore_cache.include?(objref.to_i)
    r = yield
    assert ! objectstore_cache.include?(objref.to_i)
    assert_equal start_cache_length - 1, objectstore_cache.size
    if read_into_cache
      # Get it back in the cache so it's easier to write the next test
      expecting_store_cache_hit(0) { KObjectStore.read(objref) }
      assert objectstore_cache.include?(objref.to_i)
    end
    r
  end

  class LoadObjectDuringUpdatePlugin < KTrustedPlugin
    def hLabelUpdatedObject(response, object)
      KObjectStore.read(object.objref)
    end
  end

  # ---------------------------------------------------------------------------------------------------------------

  class TestLabelObjectsPlugin < KTrustedPlugin
    def hLabelObject(result, object)
      result.changes.add(777788)
    end
  end

  def test_store_labelling_through_delegate_and_plugins
    restore_store_snapshot("basic")

    book = KObject.new()
    book.add_attr(O_TYPE_BOOK, A_TYPE)
    book.add_attr("Book1", A_TITLE)
    # Make sure this has empty labels
    assert book.labels.empty?
    # Then check the object store gives the expected labels through the lookup
    assert_equal [O_LABEL_COMMON.to_i], KObjectStore.label_changes_for_new_object(book).change(book.labels)._to_internal
    # But doesn't modify the object's labels
    assert book.labels.empty?
    KObjectStore.create(book)
    # Labels applied as predicted
    assert_equal [O_LABEL_COMMON.to_i], book.labels._to_internal

    # Now try this again with a plugin
    assert KPlugin.install_plugin("k_object_store_test/test_label_objects")
    begin
      book2 = KObject.new()
      book2.add_attr(O_TYPE_BOOK, A_TYPE)
      book2.add_attr("Book2", A_TITLE)
      assert book2.labels.empty?
      assert_equal [O_LABEL_COMMON.to_i, 777788], KObjectStore.label_changes_for_new_object(book2).change(book2.labels)._to_internal
      assert book2.labels.empty?
      KObjectStore.create(book2)
      assert_equal [O_LABEL_COMMON.to_i, 777788], book2.labels._to_internal
    ensure
      KPlugin.uninstall_plugin("k_object_store_test/test_label_objects")
    end
  end

  # ---------------------------------------------------------------------------------------------------------------

  class AttributeRestrictionsHookPlugin < KTrustedPlugin
    def self.set_mapping(mappings)
      Thread.current[:test_user_attribute_restrictions] = mappings
    end
    def hUserAttributeRestrictionLabels(result, user)
      # Code to make sure queries can be used during this hook
      unless Thread.current[:test_user_attribute_restrictions_in_query]
        Thread.current[:test_user_attribute_restrictions_in_query] = true
        KObjectStore.query_and().free_text("hello").execute();
        Thread.current[:test_user_attribute_restrictions_in_query] = false
      end
      # Get labels from mappings
      m = Thread.current[:test_user_attribute_restrictions]
      if m.has_key?(user.id)
        result.userLabels.add([m[user.id]])
      end
    end
  end

  def test_attribute_restrictions
    restore_store_snapshot("app")
    db_reset_test_data
    AttributeRestrictionsHookPlugin.set_mapping({41 => [O_LABEL_COMMON.to_i],
                                                 42 => [],
                                                 43 => [O_LABEL_COMMON.to_i, O_LABEL_CONFIDENTIAL.to_i]})

    p = KObject.new([O_LABEL_CONFIDENTIAL])
    p.add_attr(O_TYPE_STAFF, A_TYPE)
    p.add_attr("Herbet Simpkins", A_TITLE)
    tn = KIdentifierTelephoneNumber.new_with_plain_text("01234 567 890", A_TELEPHONE_NUMBER)
    p.add_attr(tn, A_TELEPHONE_NUMBER)
    KObjectStore.create(p)
    # Check everything is allowed before the load
    p_ra_none = KObject::RestrictedAttributes.new(p, [])
    p_ra_common = KObject::RestrictedAttributes.new(p, [O_LABEL_COMMON.to_i])
    p_ra_confidential = KObject::RestrictedAttributes.new(p, [O_LABEL_CONFIDENTIAL.to_i])

    assert p_ra_common.can_read_attribute?(A_TITLE)
    assert p_ra_none.can_read_attribute?(A_TITLE)

    assert p_ra_common.can_read_attribute?(A_TELEPHONE_NUMBER)
    assert p_ra_confidential.can_read_attribute?(A_TELEPHONE_NUMBER)
    assert p_ra_confidential.can_modify_attribute?(A_TELEPHONE_NUMBER)
    assert p_ra_none.can_read_attribute?(A_TELEPHONE_NUMBER)
    assert p_ra_common.can_modify_attribute?(A_TELEPHONE_NUMBER)
    assert p_ra_none.can_modify_attribute?(A_TELEPHONE_NUMBER)
    assert_equal [], p_ra_none.hidden_attributes()
    assert_equal [], p_ra_common.hidden_attributes()
    assert_equal [], p_ra_confidential.hidden_attributes()
    assert_equal [], p_ra_none.read_only_attributes()
    assert_equal [], p_ra_common.read_only_attributes()
    assert_equal [], p_ra_confidential.read_only_attributes()

    p_as_nobody = p.dup_restricted(nil, KObject::RestrictedAttributes.new(p, []))
    assert_equal tn, p_as_nobody.first_attr(A_TELEPHONE_NUMBER)

    # Restrict view of telephone numbers on confidential objects to people with label 'common' or 'confidential'
    # Restrict editing of telephone numbers on confidential objects to people with label 'confidential'
    parser = SchemaRequirements::Parser.new()
    parser.parse("test_javascript_schema", StringIO.new(<<__E))
restriction test:restriction:hide-telephones
    title: Restrict view of staff telephone numbers
    restrict-if-label std:label:confidential
    label-unrestricted std:label:common
    label-unrestricted std:label:confidential
    attribute-restricted std:attribute:telephone
restriction test:restriction:ro-telephones
    title: Restrict editing of staff telephone numbers
    restrict-if-label std:label:confidential
    label-unrestricted std:label:confidential
    attribute-read-only std:attribute:telephone
restriction test:restriction:hide-title
    title: Restrict view of staff names
    restrict-if-label std:label:confidential
    label-unrestricted std:label:confidential
    attribute-restricted dc:attribute:title
__E
    applier = SchemaRequirements::Applier.new(SchemaRequirements::APPLY_APP, parser, SchemaRequirements::AppContext.new(parser))
    applier.apply.commit
    assert_equal 0, applier.errors.length
    KObjectStore._test_reset_currently_selected_store
    # Check things are now restricted
    p_ra_none = KObject::RestrictedAttributes.new(p, [])
    p_ra_common = KObject::RestrictedAttributes.new(p, [O_LABEL_COMMON.to_i])
    p_ra_confidential = KObject::RestrictedAttributes.new(p, [O_LABEL_CONFIDENTIAL.to_i])

    assert p_ra_confidential.can_read_attribute?(A_TITLE)
    assert (not p_ra_none.can_read_attribute?(A_TITLE))
    assert (not p_ra_common.can_read_attribute?(A_TITLE))

    assert p_ra_common.can_read_attribute?(A_TELEPHONE_NUMBER)
    assert p_ra_confidential.can_read_attribute?(A_TELEPHONE_NUMBER)
    assert p_ra_confidential.can_modify_attribute?(A_TELEPHONE_NUMBER)
    assert (not p_ra_none.can_read_attribute?(A_TELEPHONE_NUMBER))
    assert (not p_ra_common.can_modify_attribute?(A_TELEPHONE_NUMBER))
    assert (not p_ra_none.can_modify_attribute?(A_TELEPHONE_NUMBER))
    assert_equal [A_TITLE, A_TELEPHONE_NUMBER], p_ra_none.hidden_attributes()
    assert_equal [A_TITLE], p_ra_common.hidden_attributes()
    assert_equal [], p_ra_confidential.hidden_attributes()
    assert_equal [A_TELEPHONE_NUMBER], p_ra_none.read_only_attributes()
    assert_equal [A_TELEPHONE_NUMBER], p_ra_common.read_only_attributes()
    assert_equal [], p_ra_confidential.read_only_attributes()

    p_as_nobody = p.dup_restricted(nil, KObject::RestrictedAttributes.new(p, []))
    p_as_common = p.dup_restricted(nil, KObject::RestrictedAttributes.new(p, [O_LABEL_COMMON.to_i]))
    p_as_confidential = p.dup_restricted(nil, KObject::RestrictedAttributes.new(p, [O_LABEL_CONFIDENTIAL.to_i]))

    # Can add additional hidden attributes (convenience method for displaying objects)
    p_ra_none_with_additional = KObject::RestrictedAttributes.new(p, [])
    p_ra_none_with_additional.hide_additional_attributes([A_URL])
    assert_equal [A_TITLE, A_URL, A_TELEPHONE_NUMBER], p_ra_none_with_additional.hidden_attributes()

    # Check ability to read A_TELEPHONE_NUMBER from p, p_as_common, p_as_confidential
    assert_equal tn, p.first_attr(A_TELEPHONE_NUMBER)
    assert_equal tn, p_as_common.first_attr(A_TELEPHONE_NUMBER)
    assert_equal tn, p_as_confidential.first_attr(A_TELEPHONE_NUMBER)

    # Check inability to do the above from everyone else
    assert_equal nil, p_as_nobody.first_attr(A_TELEPHONE_NUMBER)

    # Now, p was not restricted when it was created, so we'll create a fresh object
    # to test indexing.
    p = KObject.new([O_LABEL_COMMON, O_LABEL_CONFIDENTIAL])
    p.add_attr(O_TYPE_STAFF, A_TYPE)
    p.add_attr("Herbet Simpkins Jr", A_TITLE)
    tn_text = "01234 890 567"
    tn = KIdentifierTelephoneNumber.new_with_plain_text(tn_text, A_TELEPHONE_NUMBER)
    p.add_attr(tn, A_TELEPHONE_NUMBER)
    KObjectStore.create(p)

    run_outstanding_text_indexing()

    # Install hooks
    assert KPlugin.install_plugin("k_object_store_test/attribute_restrictions_hook")

    ## AS SUPERUSER: Finds the telephone number

    # Test attribute index
    query = KObjectStore.query_and.identifier(tn, A_TELEPHONE_NUMBER)
    query_result = query.execute(:reference, :relevance)
    assert_equal [p.objref], query_result.map {|o| o.objref }

    # Test free text - that field
    query = KObjectStore.query_and.free_text("890567", A_TELEPHONE_NUMBER)
    query_result = query.execute(:reference, :relevance)
    assert_equal [p.objref], query_result.map {|o| o.objref }

    # Test free text - all fields
    query = KObjectStore.query_and.free_text("890567")
    query_result = query.execute(:reference, :relevance)
    assert_equal [p.objref], query_result.map {|o| o.objref }

    ## AS A SUITABLY LABELLED USER: Finds the telephone number

    # Become a user that the hooks return O_COMMON for
    u = User.read(41) # User 41 from test fixture data
    assert u.permissions.allow?(:read, p.labels)
    original_state = AuthContext.set_user(u,u)

    assert_equal 41, KObjectStore.external_user_id

    # Test attribute index
    query = KObjectStore.query_and.identifier(tn, A_TELEPHONE_NUMBER)
    query_result = query.execute(:reference, :relevance)
    assert_equal [p.objref], query_result.map {|o| o.objref }

    # Test free text - that field
    u.__send__(:remove_instance_variable, :@attribute_restriction_label_cache) # ensure hUserAttributeRestrictionLabels called
    query = KObjectStore.query_and.free_text("890567", A_TELEPHONE_NUMBER)
    query_result = query.execute(:reference, :relevance)
    assert_equal [p.objref], query_result.map {|o| o.objref }

    # Test free text - all fields
    u.__send__(:remove_instance_variable, :@attribute_restriction_label_cache) # ensure hUserAttributeRestrictionLabels called
    query = KObjectStore.query_and.free_text("890567")
    query_result = query.execute(:reference, :relevance)
    assert_equal [p.objref], query_result.map {|o| o.objref }

    # Test free text title - that field - title
    u.__send__(:remove_instance_variable, :@attribute_restriction_label_cache) # ensure hUserAttributeRestrictionLabels called
    query = KObjectStore.query_and.free_text("Jr", A_TITLE)
    query_result = query.execute(:reference, :relevance)
    assert_equal [], query_result.map {|o| o.objref }

    # Test free text title - all fields - title
    u.__send__(:remove_instance_variable, :@attribute_restriction_label_cache) # ensure hUserAttributeRestrictionLabels called
    query = KObjectStore.query_and.free_text("Jr")
    query_result = query.execute(:reference, :relevance)
    assert_equal [], query_result.map {|o| o.objref }

    # Become a user that the hooks return O_COMMON and O_CONFIDENTIAL for
    u = User.read(43) # User 43 from test fixture data
    assert u.permissions.allow?(:read, p.labels)
    AuthContext.set_user(u,u)

    assert_equal 43, KObjectStore.external_user_id

    # Test attribute index
    query = KObjectStore.query_and.identifier(tn, A_TELEPHONE_NUMBER)
    query_result = query.execute(:reference, :relevance)
    assert_equal [p.objref], query_result.map {|o| o.objref }

    # Test free text - that field
    query = KObjectStore.query_and.free_text("890567", A_TELEPHONE_NUMBER)
    query_result = query.execute(:reference, :relevance)
    assert_equal [p.objref], query_result.map {|o| o.objref }

    # Test free text - all fields
    query = KObjectStore.query_and.free_text("890567")
    query_result = query.execute(:reference, :relevance)
    assert_equal [p.objref], query_result.map {|o| o.objref }

    # Test free text title - that field - title
    query = KObjectStore.query_and.free_text("Jr", A_TITLE)
    query_result = query.execute(:reference, :relevance)
    assert_equal [p.objref], query_result.map {|o| o.objref }

    # Test free text title - all fields - title
    query = KObjectStore.query_and.free_text("Jr")
    query_result = query.execute(:reference, :relevance)
    assert_equal [p.objref], query_result.map {|o| o.objref }

    ## AS NOBODY USER: Finds nothing

    # Become a user that the hooks return no labels for
    u = User.read(42) # User 42 from test fixture data
    assert u.permissions.allow?(:read, p.labels)
    assert_equal [], u.attribute_restriction_labels
    AuthContext.set_user(u,u)

    # Test attribute index
    query = KObjectStore.query_and.identifier(tn, A_TELEPHONE_NUMBER)
    query_result = query.execute(:reference, :relevance)
    assert_equal [], query_result.map {|o| o.objref }

    # Test free text - all fields
    query = KObjectStore.query_and.free_text("890567")
    query_result = query.execute(:reference, :relevance)
    assert_equal [], query_result.map {|o| o.objref }

    # Test free text - that field
    query = KObjectStore.query_and.free_text("890567", A_TELEPHONE_NUMBER)
    query_result = query.execute(:reference, :relevance)
    assert_equal [], query_result.map {|o| o.objref }

    # Relabel so restrictions don't apply
    p = KObjectStore.relabel(p, KLabelChanges.new([],[O_LABEL_CONFIDENTIAL]))
    assert u.permissions.allow?(:read, p.labels)
    run_outstanding_text_indexing()
    AuthContext.set_user(u,u)

    # And now this user can find the object
    assert_equal 42, KObjectStore.external_user_id
    # Test attribute index
    query = KObjectStore.query_and.identifier(tn, A_TELEPHONE_NUMBER)
    query_result = query.execute(:reference, :relevance)
    assert_equal [p.objref], query_result.map {|o| o.objref }

    # Test free text - all fields
    query = KObjectStore.query_and.free_text("890567")
    query_result = query.execute(:reference, :relevance)
    assert_equal [p.objref], query_result.map {|o| o.objref }

    # Test free text - that field
    query = KObjectStore.query_and.free_text("890567", A_TELEPHONE_NUMBER)
    query_result = query.execute(:reference, :relevance)
    assert_equal [p.objref], query_result.map {|o| o.objref }

    # Relabel so restrictions apply again
    p = KObjectStore.relabel(p, KLabelChanges.new([O_LABEL_CONFIDENTIAL],[]))
    assert u.permissions.allow?(:read, p.labels)
    run_outstanding_text_indexing()
    AuthContext.set_user(u,u)

    # User can't see them again
    assert_equal 42, KObjectStore.external_user_id
    # Test attribute index
    query = KObjectStore.query_and.identifier(tn, A_TELEPHONE_NUMBER)
    query_result = query.execute(:reference, :relevance)
    assert_equal [], query_result.map {|o| o.objref }

    # Test free text - all fields
    query = KObjectStore.query_and.free_text("890567")
    query_result = query.execute(:reference, :relevance)
    assert_equal [], query_result.map {|o| o.objref }

    # Test free text - that field
    query = KObjectStore.query_and.free_text("890567", A_TELEPHONE_NUMBER)
    query_result = query.execute(:reference, :relevance)
    assert_equal [], query_result.map {|o| o.objref }

    # Remove hooks
    AuthContext.restore_state(original_state)
    assert KPlugin.uninstall_plugin("k_object_store_test/attribute_restrictions_hook")
  end

  class UnhelpfulPreIndexObjectPlugin < KTrustedPlugin
    def hPreIndexObject(result, object)
      r = KObject.new
      object.each { |v,d,q| r.add_attr(v,d,q) }
      result.replacementObject = r
    end
  end

  def test_attribute_restrictions_with_unhelpful_hpreindexobject
    # Install a plugin which wipes out the labels used for selecting restrictions,
    # then run the test above again.
    assert KPlugin.install_plugin("k_object_store_test/unhelpful_pre_index_object")
    test_attribute_restrictions()
  ensure
    KPlugin.uninstall_plugin("k_object_store_test/unhelpful_pre_index_object")
  end

  # ---------------------------------------------------------------------------------------------------------------

  class ListenForObjectChangeHookPlugin < KTrustedPlugin
    Change = Struct.new(:object, :operation, :previous)
    def hPostObjectChange(result, object, operation, previous)
      Thread.current[:test_last_post_object_change] = Change.new(object, operation, previous)
    end
    def self.last
      Thread.current[:test_last_post_object_change]
    end
  end

  def test_return_values_labels_and_change_hook
    restore_store_snapshot("min")

    assert KPlugin.install_plugin("k_object_store_test/listen_for_object_change_hook")

    obj = KObject.new()
    obj.add_attr("x", 100)
    assert obj.objref.nil?
    create_r = KObjectStore.create(obj)
    assert create_r.equal?(obj) # same object passed in
    assert ! obj.objref.nil?
    assert obj.frozen?
    assert_equal [O_LABEL_UNLABELLED.to_i], obj.labels._to_internal
    assert_equal [O_LABEL_UNLABELLED.to_i], ListenForObjectChangeHookPlugin.last.object.labels._to_internal
    assert_equal :create, ListenForObjectChangeHookPlugin.last.operation

    read_r = KObjectStore.read(obj.objref)
    assert read_r.kind_of? KObject
    assert ! (read_r.equal?(obj))
    assert_equal [O_LABEL_UNLABELLED.to_i], read_r.labels._to_internal
    assert read_r.labels.frozen?

    obj = obj.dup

    obj.add_attr("b", 101)
    update_r = KObjectStore.update(obj, KLabelChanges.new([1000]))
    assert update_r.equal?(obj) # same object returned
    assert update_r.frozen?
    assert_equal [O_LABEL_UNLABELLED.to_i, 1000], obj.labels._to_internal
    assert_equal :update, ListenForObjectChangeHookPlugin.last.operation
    assert_equal [O_LABEL_UNLABELLED.to_i], ListenForObjectChangeHookPlugin.last.previous.labels._to_internal
    assert_equal [O_LABEL_UNLABELLED.to_i, 1000], ListenForObjectChangeHookPlugin.last.object.labels._to_internal
    obj = update_r

    check_labels_for_ref = Proc.new do
      labels_for_ref_r = KObjectStore.labels_for_ref(obj.objref)
      assert labels_for_ref_r.kind_of? KLabelList
      assert labels_for_ref_r.frozen?
      assert_equal [O_LABEL_UNLABELLED.to_i, 1000], labels_for_ref_r._to_internal
    end
    KObjectStore.read(obj.objref) # to get it into the cache
    expecting_store_cache_hit(1) { check_labels_for_ref.call() }
    objectstore_cache.clear
    expecting_store_cache_hit(0) { check_labels_for_ref.call() }

    relabel_r = KObjectStore.relabel(obj, KLabelChanges.new([], [O_LABEL_UNLABELLED]))
    assert relabel_r.kind_of? KObject
    assert relabel_r.frozen?
    assert ! (relabel_r.equal?(obj)) # not same object passed in
    assert_equal [1000], relabel_r.labels._to_internal
    assert_equal [O_LABEL_UNLABELLED.to_i,1000], obj.labels._to_internal  # original isn't changed
    assert_equal :relabel, ListenForObjectChangeHookPlugin.last.operation
    assert_equal [1000], ListenForObjectChangeHookPlugin.last.object.labels._to_internal
    obj = relabel_r

    relabel_empty_r = KObjectStore.relabel(obj, KLabelChanges.new([],[]))
    assert relabel_empty_r.kind_of? KObject
    assert ! relabel_empty_r.equal?(obj) # even shortcut returns different object

    delete_r = KObjectStore.delete(obj)
    assert delete_r.kind_of? KObject
    assert ! (delete_r.equal?(obj)) # returns an object, but not the one you passed in
    assert delete_r.frozen?
    assert_equal [O_LABEL_DELETED.to_i,1000], delete_r.labels._to_internal
    assert_equal [1000], obj.labels._to_internal # obj passed in not modified
    assert_equal :relabel, ListenForObjectChangeHookPlugin.last.operation
    assert_equal [O_LABEL_DELETED.to_i,1000], ListenForObjectChangeHookPlugin.last.object.labels._to_internal
    assert_equal [1000], ListenForObjectChangeHookPlugin.last.previous.labels._to_internal
    obj = delete_r

    undelete_r = KObjectStore.undelete(obj)
    assert undelete_r.kind_of? KObject
    assert undelete_r.frozen?
    assert ! (undelete_r.equal?(obj)) # returns an object, but not the one you passed in
    assert_equal [1000], undelete_r.labels._to_internal
    assert_equal [O_LABEL_DELETED.to_i,1000], obj.labels._to_internal # not modified
    obj = undelete_r

    history_r = KObjectStore.history(obj.objref)
    assert history_r.kind_of? KObjectStore::ObjectHistory
    assert_equal 1, history_r.versions.length

    KObjectStore.with_superuser_permissions do
      assert_equal nil, KObjectStore.erase_history(obj)
      assert_equal :erase_history, ListenForObjectChangeHookPlugin.last.operation
    end

    KObjectStore.with_superuser_permissions do
      assert_equal nil, KObjectStore.erase(obj)
      assert_equal :erase, ListenForObjectChangeHookPlugin.last.operation
    end

    assert KPlugin.uninstall_plugin("k_object_store_test/listen_for_object_change_hook")
  end

  # ---------------------------------------------------------------------------------------------------------------

  def make_two_book_objects
    books = KObjectStore.with_superuser_permissions do
      ["a", "b"].map do |name|
        ob = KObject.new
        ob.add_attr O_TYPE_BOOK, A_TYPE
        ob.add_attr name, A_TITLE
        KObjectStore.create ob
        ob
      end
    end
    run_outstanding_text_indexing
    books
  end

  def results_to_titles(results)
    results.map { |object| object.first_attr(A_TITLE).to_s } .sort
  end

  def test_query_for_deleted_objects
    restore_store_snapshot("basic")

    book_a, book_b = make_two_book_objects

    results = KObjectStore.query_and.link(KObjRef.new(O_TYPE_BOOK), A_TYPE).execute
    assert_equal ["a", "b"], results_to_titles(results)

    KObjectStore.delete book_a
    results = KObjectStore.query_and.link(KObjRef.new(O_TYPE_BOOK), A_TYPE).execute
    assert_equal ["b"], results_to_titles(results)
    results = KObjectStore.query_and.link(KObjRef.new(O_TYPE_BOOK), A_TYPE).include_deleted_objects(:exclude_deleted).execute # :exclude_deleted is default
    assert_equal ["b"], results_to_titles(results)
    results = KObjectStore.query_and.link(KObjRef.new(O_TYPE_BOOK), A_TYPE).include_deleted_objects(:deleted_only).execute
    assert_equal ["a"], results_to_titles(results)
    results = KObjectStore.query_and.link(KObjRef.new(O_TYPE_BOOK), A_TYPE).include_deleted_objects(:ignore_deletion_label).execute
    assert_equal ["a", "b"], results_to_titles(results)

    KObjectStore.undelete book_a
    results = KObjectStore.query_and.link(KObjRef.new(O_TYPE_BOOK), A_TYPE).execute
    assert_equal ["a", "b"], results_to_titles(results)
  end

  def test_deleting_object
    object = KObject.new
    KObjectStore.create object

    assert !object.deleted?
    delete_ret = KObjectStore.delete object
    assert delete_ret.kind_of? KObject
    assert delete_ret.objref == object.objref
    assert ! delete_ret.equal?(object)
    assert ! object.deleted? # because it was the one passed in
    assert delete_ret.deleted?
    object_copy = KObjectStore.read object.objref
    assert object_copy.deleted?

    object = KObjectStore.undelete object
    assert !object.deleted?
    object_copy = KObjectStore.read object.objref
    assert !object_copy.deleted?
  end

  # ---------------------------------------------------------------------------------------------------------------

  def test_query_for_archived_objects
    restore_store_snapshot("basic")

    book_a, book_b = make_two_book_objects

    results = KObjectStore.query_and.link(KObjRef.new(O_TYPE_BOOK), A_TYPE).execute
    assert_equal ["a", "b"], results_to_titles(results)

    KObjectStore.relabel(book_a, KLabelChanges.new([O_LABEL_ARCHIVED],[]))

    results = KObjectStore.query_and.link(KObjRef.new(O_TYPE_BOOK), A_TYPE).execute
    assert_equal ["b"], results_to_titles(results)
    results = KObjectStore.query_and.link(KObjRef.new(O_TYPE_BOOK), A_TYPE).include_archived_objects(:exclude_archived).execute # :exclude_archived is default
    assert_equal ["b"], results_to_titles(results)
    results = KObjectStore.query_and.link(KObjRef.new(O_TYPE_BOOK), A_TYPE).include_archived_objects(:include_archived).execute
    assert_equal ["a", "b"], results_to_titles(results)

    # Interaction with deletions
    KObjectStore.delete book_a
    results = KObjectStore.query_and.link(KObjRef.new(O_TYPE_BOOK), A_TYPE).include_archived_objects(:include_archived).execute
    assert_equal ["b"], results_to_titles(results)
    KObjectStore.undelete book_a
    results = KObjectStore.query_and.link(KObjRef.new(O_TYPE_BOOK), A_TYPE).include_archived_objects(:include_archived).execute
    assert_equal ["a", "b"], results_to_titles(results)

    KObjectStore.relabel(book_a, KLabelChanges.new([],[O_LABEL_ARCHIVED]))
    results = KObjectStore.query_and.link(KObjRef.new(O_TYPE_BOOK), A_TYPE).execute
    assert_equal ["a", "b"], results_to_titles(results)
  end
  # ---------------------------------------------------------------------------------------------------------------

  def test_attribute_updating_links
    object = KObject.new
    object.add_attr("X", A_TITLE)
    KObjectStore.create(object)
    check = Proc.new do |expected|
      assert_equal(expected ? 1 : 0, KObjectStore.query_and.link(object.objref).execute().length)
    end
    check.call(false)
    o2 = KObject.new
    o2.add_attr("Y",A_TITLE)
    KObjectStore.create(o2)
    check.call(false)
    o2 = o2.dup
    o2.add_attr(object.objref, A_CLIENT)
    KObjectStore.update(o2)
    check.call(true)
    o2 = o2.dup
    o2.delete_attrs!(A_CLIENT)
    KObjectStore.update(o2)
    check.call(false)
  end

  def test_object_history
    restore_store_snapshot("min")
    first_uid = 1000 # > 100 so doesn't conflict with labels used by store
    uid = first_uid
    objs = Array.new
    obj_version = Array.new
    obj_creator = Array.new
    obj_modifier = Array.new
    obj_history = Array.new
    [
      0,1,0,2,1,0,1,1,2,3,0,0,1,1,0,2,2,3,0,1,1,3,4,5,6,3,5,4,6,4,6,6,6
    ].each do |obj_number|
      # Set UID
      set_mock_objectstore_user(uid)

      # Create or update object?
      obj = objs[obj_number]
      objs[obj_number] = obj = obj.dup unless obj.nil?
      if obj == nil
        # Create
        obj = KObject.new([uid])
        obj.add_attr(uid, 3)
        KObjectStore.create(obj)
        objs[obj_number] = obj
        obj_version[obj_number] = 1
        obj_creator[obj_number] = uid
        obj_modifier[obj_number] = uid
        obj_history[obj_number] = Array.new
      else
        # Update
        obj.delete_attrs!(3)
        obj.add_attr(uid, 3)
        KObjectStore.update(obj, KLabelChanges.changing(obj.labels, KLabelList.new([uid])))
        obj_history[obj_number] << [obj_version[obj_number], obj_creator[obj_number], obj_modifier[obj_number], uid, obj_modifier[obj_number]]
        obj_version[obj_number] += 1
        obj_modifier[obj_number] = uid
        assert uid != obj_creator[obj_number] # test this test!
      end

      # Check object uids
      assert_equal obj_creator[obj_number], obj.creation_user_id
      assert_equal obj_modifier[obj_number], obj.last_modified_user_id

      # Check the os_objects table matches
      r = KApp.with_pg_database { |db| db.exec("SELECT created_by,updated_by,version FROM #{KApp.db_schema_name}.os_objects WHERE id=#{objs[obj_number].objref.to_i}") }
      assert_equal 1, r.length
      assert_equal obj_creator[obj_number], r.first[0].to_i
      assert_equal obj_modifier[obj_number], r.first[1].to_i
      assert_equal obj_version[obj_number], r.first[2].to_i

      # Check searching by user_id matches
      first_uid.upto(uid) do |user_id|
        # Query by API
        q1 = KObjectStore.query_and.created_by_user_id(user_id)
        # Parsed query
        q2 = KObjectStore.query_and
        qq = KQuery.new("#U#{user_id}#")
        errors = []
        qq.add_query_to(q2, errors)
        assert errors.empty?
        [q1,q2].each do |query|
          found_by_query = query.execute(:all, :any)
          objects_by_this_user = Hash.new
          found_by_query.each { |testobj| objects_by_this_user[testobj.objref] = true }
          objs.each_with_index do |testobj, index|
            if obj_creator[index] == user_id
              assert objects_by_this_user.has_key?(testobj.objref)
            else
              assert ! objects_by_this_user.has_key?(testobj.objref)
            end
          end
        end
      end

      # Check the history matches -- order by retired_by to get the array in time order
      r = KApp.with_pg_database { |db| db.exec("SELECT version,created_by,updated_by,retired_by,labels FROM #{KApp.db_schema_name}.os_objects_old WHERE id=#{obj.objref.obj_id} ORDER BY retired_by") }
      history = Array.new
      r.each do |row|
        # Change labels into a UID
        assert row.last =~ /\A{(\d+)}\z/
        row[row.length-1] = $1
        # Add to history
        history << row.map { |x| x.to_i }
      end
      assert_equal obj_history[obj_number], history

      # Ask the store for history, check it matches our view
      store_history = KObjectStore.history(obj.objref)
      assert_equal obj_version[obj_number], store_history.object.version
      assert_equal obj_history[obj_number].length, store_history.versions.length
      obj_history[obj_number].each_with_index do |entry, index|
        version,created_by,updated_by,retired_by,labels = entry
        version_entry = store_history.versions[index]
        assert_equal version, version_entry.version
        assert_equal index + 1, version_entry.object.version
        assert version_entry.update_time.kind_of? Time
        assert_equal Time.now.year, version_entry.update_time.year
        assert_equal obj.objref, version_entry.object.objref
      end

      # Read the versions back
      latest_version_for_history = [obj_version[obj_number] ,:dummy_val]
      (obj_history[obj_number] + [latest_version_for_history]).each_with_index do |entry, index|
        version,created_by,updated_by,retired_by,labels = entry
        objv = KObjectStore.read_version(obj.objref, version)
        assert_equal version, objv.version
        assert_equal obj.objref, objv.objref
      end

      # Current version?
      version_at_now = KObjectStore.read_version_at_time(obj.objref, Time.now)
      assert_equal obj.objref, version_at_now.objref
      assert_equal obj_version[obj_number], version_at_now.version
      # No version a year ago
      version_year_ago = KObjectStore.read_version_at_time(obj.objref, Time.now - (365*KFramework::SECONDS_IN_DAY))
      assert_equal nil, version_year_ago
      # Reading version at creation time works with small adjustments
      [
        [0,true,true],
        [1,true],
        [-1,true,true],
        [3,true],   # because it's in the future
        [-3,false,true]  # but not in the past
      ].each do |adjustment, should_find, check_is_version_1|
        version_at_creation = KObjectStore.read_version_at_time(obj.objref, obj.obj_creation_time + adjustment)
        if should_find
          assert_equal obj.objref, version_at_creation.objref
          if check_is_version_1
            assert_equal 1, version_at_creation.version
          end
        else
          assert_equal nil, version_at_creation
        end
      end

      # Update
      uid += 1
    end

    KObjectStore.with_superuser_permissions do
      # Check erase really erases everything
      counts_in_tables = Proc.new do |objref|
        ['os_objects', 'os_objects_old'].map do |table|
          KApp.with_pg_database { |db| db.exec("SELECT COUNT(*) FROM #{KApp.db_schema_name}.#{table} WHERE id=#{objref.to_i}").first.first.to_i }
        end
      end
      objref0 = objs[0].objref
      assert_equal [1,6], counts_in_tables.call(objref0)
      KObjectStore.erase(objs[0])
      assert_equal [0,0], counts_in_tables.call(objref0)
      #
      objref6 = objs[6].objref
      assert_equal [1,4], counts_in_tables.call(objref6)
      KObjectStore.erase(objs[6])
      assert_equal [0,0], counts_in_tables.call(objref6)

      # Try to read a version of an erased object
      assert_raises(KObjectStore::PermissionDenied) do
        KObjectStore.read_version(objs[0].objref, 1)
      end
      # Try to read a version of an object which never existed
      assert_raises(KObjectStore::PermissionDenied) do
        KObjectStore.read_version(KObjRef.new(999999999), 1)
      end
    end
  end

  def test_object_history_read_at_time
    restore_store_snapshot("min")

    obj = KObject.new()
    obj.add_attr(O_TYPE_BOOK, A_TYPE)
    obj.add_attr("Read at time", A_TITLE)
    KObjectStore.create(obj)

    # Check non-datatime things can't be passed in
    assert_raises(RuntimeError) { KObjectStore.read_version_at_time(obj.objref, "date") }
    assert_raises(RuntimeError) { KObjectStore.read_version_at_time(obj.objref, nil) }
    assert_raises(RuntimeError) { KObjectStore.read_version_at_time(obj.objref, 12445) }

    # Make some versions
    5.times do
      obj = obj.dup
      obj.add_attr("version", 3466)
      KObjectStore.update(obj)
    end
    assert_equal 6, obj.version

    # Hack the times in the database for testing, so it looks like an update every two days for the last 6 days
    KApp.with_pg_database { |pg| pg.perform "UPDATE #{KApp.db_schema_name}.os_objects_old SET updated_at=NOW() - (interval '1 day' * (6-version) * 2) WHERE id=#{obj.objref.to_i}" }

    # Read versions at the given time
    1.upto(6) do |version|
      old_obj = KObjectStore.read_version_at_time(obj.objref, Time.now - ((((5-version)*2)+1)*KFramework::SECONDS_IN_DAY))
      assert_equal obj.objref, old_obj.objref
      assert_equal version, old_obj.version
    end
    assert_equal nil, KObjectStore.read_version_at_time(obj.objref, Time.now - (16*KFramework::SECONDS_IN_DAY))
  end

  def test_schema
    # Get the app's schema loaded
    restore_store_snapshot("basic")

    # Get the schema object from the store
    schema = KObjectStore.schema

    assert schema.frozen?

    # Check a couple entries
    assert_equal A_TITLE, schema.attr_desc_by_name('title')
    # Check errors
    assert_equal nil, schema.attr_desc_by_name('no-attr-desc')

    # Codes
    assert_equal "dc:attribute:title", schema.attribute_descriptor(A_TITLE).code
    assert_equal "std:type:book", schema.type_descriptor(O_TYPE_BOOK).code
    assert_equal "std:aliased-attribute:year", schema.aliased_attribute_descriptor(AA_YEAR).code
    assert_equal "dc:qualifier:alternative", schema.qualifier_descriptor(Q_ALTERNATIVE).code
    assert_equal "std:qualifier:mobile", schema.qualifier_descriptor(Q_MOBILE).code

    # Check taxonomy UI selection works - for both normal attributes and aliases
    assert_equal false, schema.attribute_descriptor(A_JOB_TITLE).uses_taxonomy_editing_ui?(schema)
    assert_equal false, schema.attribute_descriptor(A_WORKS_FOR).uses_taxonomy_editing_ui?(schema)
    assert_equal false, schema.aliased_attribute_descriptor(AA_PARENT_ORGANISATION).uses_taxonomy_editing_ui?(schema)
    assert_equal true, schema.attribute_descriptor(A_SUBJECT).uses_taxonomy_editing_ui?(schema)
    assert_equal true, schema.aliased_attribute_descriptor(AA_EXPERTISE).uses_taxonomy_editing_ui?(schema)

    # Check the parent/children relationship on a type
    org_type_desc = schema.type_descriptor(O_TYPE_ORGANISATION)
    assert_equal nil, org_type_desc.parent_type
    assert_equal [O_TYPE_CLIENT, O_TYPE_SUPPLIER, O_TYPE_ORG_CLIENT_PAST, O_TYPE_ORG_CLIENT_PROSPECTIVE, O_TYPE_ORG_PARTNER, O_TYPE_ORG_PRESS, O_TYPE_ORG_PROFESSIONAL_ASSOCIATION,O_TYPE_ORG_COMPETITOR,O_TYPE_ORG_THIS], org_type_desc.children_types.sort
    client_type_desc = schema.type_descriptor(O_TYPE_CLIENT)
    assert_equal O_TYPE_ORGANISATION, client_type_desc.parent_type
    assert_equal [], client_type_desc.children_types

    # Check an aliased attribute
    aa1 = schema.aliased_attribute_descriptor(AA_NAME)
    assert_equal A_TITLE, aa1.alias_of
    assert_equal T_TEXT_PERSON_NAME, aa1.specified_data_type
    assert_equal [Q_NULL,Q_ALTERNATIVE,Q_NICKNAME], aa1.specified_qualifiers
    assert_equal [], aa1.specified_linked_types
    assert_equal [], aa1.specified_linked_types_with_children
    # There aren't really any interesting aliased attributes, so make up a new one
    KObjectLoader.load_from_string(<<__E)
obj [O_LABEL_STRUCTURE] 4
    A_TYPE              O_TYPE_ATTR_ALIAS_DESC
    A_TITLE             'TestAlias'
    A_ATTR_SHORT_NAME   'testalias'
    A_ATTR_ALIAS_OF     A_RELATION
    A_ATTR_DATA_TYPE    T_OBJREF
    A_ATTR_QUALIFIER    Q_MOBILE
    A_ATTR_QUALIFIER    Q_OFFICE
    A_ATTR_CONTROL_BY_TYPE  O_TYPE_COMPUTER
__E
    # Reload the schema
    schema = KObjectStore.schema
    # Find the new attribute
    aa2_desc = schema.aliased_attr_desc_by_name('testalias')
    assert aa2_desc != nil && aa2_desc != 0
    aa2 = schema.aliased_attribute_descriptor(aa2_desc)
    assert aa2 != nil
    assert_equal A_RELATION, aa2.alias_of
    assert_equal T_OBJREF, aa2.specified_data_type
    assert_equal [Q_MOBILE,Q_OFFICE], aa2.specified_qualifiers
    assert_equal [O_TYPE_COMPUTER], aa2.specified_linked_types
    assert_equal [O_TYPE_COMPUTER,O_TYPE_LAPTOP], aa2.specified_linked_types_with_children

    # Make an object to test the qualifiers
    obj = KObject.new()
    obj.add_attr("t1", A_TITLE, 1)
    assert_equal "t1", obj.first_attr(A_TITLE).text
    obj.add_attr("t2", A_TITLE, 2)
    assert_equal "t1", obj.first_attr(A_TITLE).text
    obj.add_attr("t3", A_TITLE, 3)
    assert_equal "t1", obj.first_attr(A_TITLE).text
    assert_equal "t3", obj.first_attr(A_TITLE, 3).text
    assert_equal "t2", obj.first_attr(A_TITLE, 2).text
    assert_equal "t1", obj.first_attr(A_TITLE, 1).text

    # Check the schema is updated when creating a new attribute
    ado = KObject.new([O_LABEL_STRUCTURE])
    ado.add_attr(O_TYPE_ATTR_DESC, A_TYPE)
    ado.add_attr('Test', A_TITLE)
    ado.add_attr('test', A_ATTR_SHORT_NAME)
    ado.add_attr(T_TEXT, A_ATTR_DATA_TYPE)
    KObjectStore.create(ado)
    schema2 = KObjectStore.schema
    assert_not_equal schema.object_id, schema2.object_id  # check not the same object

    # Create a type structure object, and make sure the schema isn't changed
    ty = KObject.new([O_LABEL_STRUCTURE])
    # Must not have A_TYPE set to O_TYPE_APP_VISIBLE as this would rightfully reload the schema
    ty.add_attr('Thing object test 1', A_TITLE)
    KObjectStore.create(ty)
    schema3 = KObjectStore.schema
    assert_equal schema2.object_id, schema3.object_id # check exactly the same object

    # Create a type structure object, and make sure the schema isn't changed
    ty2 = KObject.new([O_LABEL_STRUCTURE])
    ty2.add_attr(O_TYPE_APP_VISIBLE, A_TYPE)
    ty2.add_attr('Thing object test 2', A_TITLE)
    ty2.add_attr('thing', A_ATTR_SHORT_NAME)
    ty2.add_attr('thing object TWO', A_ATTR_SHORT_NAME)
    ty2.add_attr('typename2', A_RENDER_TYPE_NAME)
    ty2.add_attr('E207,1,f E418,4,e', A_RENDER_ICON)
    KObjectStore.create(ty2)
    schema4 = KObjectStore.schema
    assert_not_equal schema2.object_id, schema4.object_id # check not the same object

    # Test the type objects from the schema
    type_desc2 = schema4.type_descriptor(ty2.objref)
    assert_not_equal nil, type_desc2
    assert_equal ty2.objref, type_desc2.objref
    assert_equal 'Thing object test 2', type_desc2.printable_name
    assert_equal ['thing', 'thing object two'], type_desc2.short_names
    assert_equal :typename2, type_desc2.render_type
    assert_equal "E207,1,f E418,4,e", type_desc2.render_icon

    # Test it doesn't get random type definitions
    assert_equal nil, schema4.type_descriptor(O_TYPE_ATTR_DESC)

    # Test that info about controlled fields are there
    creator_attr_desc = schema4.attribute_descriptor(A_CREATOR)
    assert_equal [O_TYPE_PERSON,O_TYPE_ORGANISATION], creator_attr_desc.control_by_types
    assert_equal nil, creator_attr_desc.control_relaxed

    # Test that you get an empty array if there's no controlled types
    assert_equal [],schema4.attribute_descriptor(A_TITLE).control_by_types

    # Test multiple control by types
    ado = ado.dup
    ado.add_attr(O_TYPE_PERSON, A_ATTR_CONTROL_BY_TYPE)
    ado.add_attr(O_TYPE_BOOK, A_ATTR_CONTROL_BY_TYPE)
    KObjectStore.update(ado)
    assert_equal [O_TYPE_PERSON,O_TYPE_BOOK], KObjectStore.schema.attribute_descriptor(ado.objref.to_desc).control_by_types

    # Test finding type lists from types
    check_type_list_from_short_names(schema4, 'book journal intranet page', ["Book", "Intranet page", "Journal"], '')
    check_type_list_from_short_names(schema4, 'book journal intranet pants page', ["Book", "Intranet page", "Journal"], 'intranet pants') # gets more because the intranet bit doesn't match, so doesn't make 'page' more specific
    check_type_list_from_short_names(schema4, 'x1 book x2', ["Book"], 'x1 x2')
    check_type_list_from_short_names(schema4, 'book x2', ["Book"], 'x2')
    check_type_list_from_short_names(schema4, 'x1 book', ["Book"], 'x1')
    check_type_list_from_short_names(schema4, 'intranet', [], 'intranet')
    check_type_list_from_short_names(schema4, 'intranet page', ['Intranet page'], '')
    check_type_list_from_short_names(schema4, 'x1 intranet page x2', ['Intranet page'], 'x1 x2')
    check_type_list_from_short_names(schema4, 'x1 intranet page', ['Intranet page'], 'x1')
    check_type_list_from_short_names(schema4, 'intranet page x2', ['Intranet page'], 'x2')
    check_type_list_from_short_names(schema4, 'x1 x2', [], 'x1 x2')
    check_type_list_from_short_names(schema4, '', [], '')
    check_type_list_from_short_names(schema4, 'thing', ['Thing object test 2'], '')
    check_type_list_from_short_names(schema4, 'thing object', ['Thing object test 2'], 'object')
    check_type_list_from_short_names(schema4, 'thing object two', ['Thing object test 2'], '')
    check_type_list_from_short_names(schema4, 'thing two object', ['Thing object test 2'], 'two object')
    check_type_list_from_short_names(schema4, 'thing two object two', ['Thing object test 2'], 'two object two')

    # Check "types used for choices" updates properly
    # * check results from default schema ('Relationship manager' attribute)
    schema = KObjectStore.schema
    assert_equal [O_TYPE_STAFF], schema.types_used_for_choices
    # * modify 'Works for' to have the UI option
    works_for_attr = KObjectStore.read(KObjRef.from_desc(A_WORKS_FOR)).dup
    works_for_attr.add_attr('dropdown', A_ATTR_UI_OPTIONS)
    KObjectStore.update(works_for_attr)
    # * check new schema includes sub-types of Organisation
    schema = KObjectStore.schema
    expected_choice_types = [O_TYPE_STAFF, O_TYPE_ORGANISATION]
    KObjectStore.query_and.link(O_TYPE_ORGANISATION, A_PARENT).execute().each { |o| expected_choice_types << o.objref }
    assert expected_choice_types.length > 4 # to make sure something interesting is going on
    assert_equal expected_choice_types.sort, schema.types_used_for_choices.sort

    # Check aliased attributes inherit ui options and data type options correctly
    date_attr2 = KObject.new([O_LABEL_STRUCTURE])
    date_attr2.add_attr(O_TYPE_ATTR_DESC, A_TYPE)
    date_attr2.add_attr("Random date", A_TITLE)
    date_attr2.add_attr("random-date", A_ATTR_SHORT_NAME)
    date_attr2.add_attr(T_DATETIME, A_ATTR_DATA_TYPE)
    date_attr2.add_attr('Y,n,n,n,n', A_ATTR_UI_OPTIONS)
    date_attr2.add_attr('dt-options', A_ATTR_DATA_TYPE_OPTIONS)
    KObjectStore.create(date_attr2)
    date_alias = KObject.new([O_LABEL_STRUCTURE])
    date_alias.add_attr(O_TYPE_ATTR_ALIAS_DESC, A_TYPE)
    date_alias.add_attr("Random Date Alias", A_TITLE)
    date_alias.add_attr("date-alias", A_ATTR_SHORT_NAME)
    date_alias.add_attr(date_attr2.objref, A_ATTR_ALIAS_OF)
    KObjectStore.create(date_alias)
    # Check inheritance because no type specified on alias
    schema = KObjectStore.schema
    da_desc = schema.aliased_attribute_descriptor(date_alias.objref.to_desc)
    assert_equal "Random Date Alias", da_desc.printable_name.to_s
    assert_equal 'Y,n,n,n,n', da_desc.ui_options # inherited from attr
    assert_equal 'dt-options', da_desc.data_type_options # inherited from attr
    # But it one is, it's not inherited any more
    date_alias = date_alias.dup
    date_alias.add_attr(T_DATETIME, A_ATTR_DATA_TYPE)
    KObjectStore.update(date_alias)
    schema = KObjectStore.schema
    da_desc = schema.aliased_attribute_descriptor(date_alias.objref.to_desc)
    assert_equal "Random Date Alias", da_desc.printable_name.to_s
    assert_equal nil, da_desc.ui_options
    assert_equal nil, da_desc.data_type_options
    # And if it now gets the options, these are reported
    date_alias = date_alias.dup
    date_alias.add_attr('o0', A_ATTR_UI_OPTIONS)
    date_alias.add_attr('o1', A_ATTR_DATA_TYPE_OPTIONS)
    KObjectStore.update(date_alias)
    schema = KObjectStore.schema
    da_desc = schema.aliased_attribute_descriptor(date_alias.objref.to_desc)
    assert_equal "Random Date Alias", da_desc.printable_name.to_s
    assert_equal 'o0', da_desc.ui_options
    assert_equal 'o1', da_desc.data_type_options
  end

  def test_schema2
    # Get the app's schema loaded
    restore_store_snapshot("basic")

    # Get the schema object from the store
    schema = KObjectStore.schema

    # Create new type
    KObjectLoader.load_from_string(<<_OBJS)
obj [O_LABEL_STRUCTURE] 228877
  A_TYPE        O_TYPE_APP_VISIBLE
  A_TITLE       "XYZ1"
  A_ATTR_SHORT_NAME 'xyz2'
  A_RELEVANT_ATTR   A_TITLE
  A_RELEVANT_ATTR   A_AUTHOR
  A_RENDER_TYPE_NAME  'xyz3'
  A_RENDER_ICON 'E209,1,f E223,0,c'
  A_RENDER_CATEGORY 0

_OBJS
    schema_test_create_data = KObjectStore.schema
    schema_test_create_typeinfo = schema_test_create_data.type_descriptor(KObjRef.new(228877))
    assert_equal 'XYZ1', schema_test_create_typeinfo.printable_name.to_s
    assert_equal :xyz3, schema_test_create_typeinfo.render_type

    # Check inheritance of type attributes
    # -- add some bits to the project type
    # -- make sure that render category defaults to zero in root objects
    project_type = KObjectStore.read(O_TYPE_PROJECT).dup
    project_type.delete_attrs!(A_RENDER_CATEGORY)
    KObjectStore.update(project_type)
    assert_equal 0, KObjectStore.schema.type_descriptor(O_TYPE_PROJECT).render_category
    # -- create a subtype
    project_subtype = KObject.new([O_LABEL_STRUCTURE])
    project_subtype.add_attr(O_TYPE_APP_VISIBLE, A_TYPE)
    project_subtype.add_attr(O_TYPE_PROJECT, A_PARENT)
    project_subtype.add_attr('Randomness', A_TITLE)
    project_subtype.add_attr('randomness', A_ATTR_SHORT_NAME)
    KObjectStore.create(project_subtype)
    # -- run through and check the attributes are equal, after adding various attributes
    checked_method = Hash.new
    [
      [nil],
      [A_RENDER_TYPE_NAME, :render_type,
          ["rtype1"], :rtype1,
          ["rtype2"], :rtype2],
      [A_RENDER_ICON, :render_icon,
          ["E209,1,f E505,0,e"], "E209,1,f E505,0,e",
          ["E212,1,f"], "E212,1,f"],
      [A_RENDER_CATEGORY, :render_category,
          [5], 5,
          [2], 2],
    ].each do |desc,desc_method,values,expected,sub_values,sub_expected|
      if desc != nil
        project_type = project_type.dup
        project_type.delete_attrs!(desc)
        values.each { |v| project_type.add_attr(v,desc) }
        KObjectStore.update(project_type)
      end
      # Get the schema and descs
      schema_tst = KObjectStore.schema
      project_type_desc = schema_tst.type_descriptor(O_TYPE_PROJECT)
      project_subtype_type_desc = schema_tst.type_descriptor(project_subtype.objref)
      assert project_type_desc != project_subtype_type_desc
      # Check the given attribute on the root type
      if desc_method != nil
        assert_equal expected, project_type_desc.send(desc_method)
      end
      # Check all inheritable attributes
      [:relevancy_weight,:term_inclusion,:attributes,:render_type,:render_icon,:render_category,
      :creation_ui_position,:behaviours].each do |method_name|
        unless checked_method[method_name]
          assert_equal project_type_desc.send(method_name), project_subtype_type_desc.send(method_name)
        end
      end
      # Add the attribute to the sub-type, and check it changes
      if desc != nil
        project_subtype = project_subtype.dup
        project_subtype.delete_attrs!(desc)
        sub_values.each { |v| project_subtype.add_attr(v,desc) }
        KObjectStore.update(project_subtype)
        # Check it's stored
        schema_tst2 = KObjectStore.schema
        root_v = schema_tst2.type_descriptor(O_TYPE_PROJECT).send(desc_method)
        sub_v = schema_tst2.type_descriptor(project_subtype.objref).send(desc_method)
        assert root_v != sub_v
        assert_equal sub_expected, sub_v
      end
      # Don't check this method next time round
      checked_method[desc_method] = true
    end
    # -- check attributes can be removed in subtypes
    project_subtype = project_subtype.dup
    project_subtype.add_attr(KObjRef.from_desc(A_DOCUMENT), A_RELEVANT_ATTR_REMOVE)
    KObjectStore.update(project_subtype)
    schema_tst2 = KObjectStore.schema
    assert schema_tst2.type_descriptor(O_TYPE_PROJECT).attributes.include?(A_DOCUMENT)
    assert ! ( schema_tst2.type_descriptor(project_subtype.objref).attributes.include?(A_DOCUMENT) )

    # Check handling of Q_NULL (checks change of behaviour in Next)
    assert_equal Q_NULL, KObjRef.new(Q_NULL).to_desc
    assert_equal KObjRef.new(Q_NULL), KObjRef.from_desc(Q_NULL)

    # Check queries find objects linked to Q_NULL
    q_null_query = KObjectStore.query_and.link(KObjRef.new(Q_NULL)).execute()
    assert q_null_query.length > 0
  end

  def test_restrictions_schema
    restore_store_snapshot("app")

    assert_equal [], KObjectStore.schema.all_restriction_labels

    parser = SchemaRequirements::Parser.new()
    parser.parse("test_javascript_schema", StringIO.new(<<__E))
type test:type:restricted
    title: Test type with restrictions
    search-name: test type with restrictions
    attribute dc:attribute:title
    attribute dc:attribute:date
    label-base std:label:concept
restriction test:restriction:one
    title: Test restriction 1
    restrict-type test:type:restricted
    # laptop is not a root type, but restrictions will be applied to the root
    restrict-type std:type:equipment:laptop
    label-unrestricted std:label:common
    label-unrestricted std:label:concept
    attribute-restricted std:attribute:notes
    attribute-restricted std:attribute:project
    attribute-read-only dc:attribute:author
restriction test:restriction:two
    title: Test restriction two
    restrict-type test:type:restricted
    label-unrestricted std:label:common
    label-unrestricted std:label:archived
    attribute-restricted dc:attribute:subject
    attribute-restricted std:attribute:notes
restriction test:restriction:three
    title: Test restriction three
    # Applies to all types, but only with confidential label
    restrict-if-label std:label:confidential
    label-unrestricted std:label:common
    attribute-restricted std:attribute:file
__E
    applier = SchemaRequirements::Applier.new(SchemaRequirements::APPLY_APP, parser, SchemaRequirements::AppContext.new(parser))
    applier.apply.commit
    assert_equal 0, applier.errors.length

    assert_equal 3, KObjectStore.query_and().link(O_TYPE_RESTRICTION, A_TYPE).add_label_constraints([O_LABEL_STRUCTURE]).execute().length

    schema = KObjectStore.schema
    # label list -> sorted obj_id
    lo = Proc.new { |ll| ll.map { |l| l.obj_id } .sort }

    assert_equal lo.call([O_LABEL_COMMON, O_LABEL_CONCEPT, O_LABEL_ARCHIVED]), schema.all_restriction_labels

    test_file_obj = KObject.new; test_file_obj.add_attr(O_TYPE_FILE, A_TYPE)
    file_restrictions = schema._get_restricted_attributes_for_object(test_file_obj)
    assert_equal({}, file_restrictions.hidden)
    assert_equal({}, file_restrictions.read_only)

    test_equipment_obj = KObject.new; test_equipment_obj.add_attr(O_TYPE_EQUIPMENT, A_TYPE)
    equipment_restrictions = schema._get_restricted_attributes_for_object(test_equipment_obj)
    assert_equal({
      A_NOTES => lo.call([O_LABEL_COMMON, O_LABEL_CONCEPT]),
      A_PROJECT => lo.call([O_LABEL_COMMON, O_LABEL_CONCEPT])
    }, equipment_restrictions.hidden)
    assert_equal({
      A_AUTHOR => lo.call([O_LABEL_COMMON, O_LABEL_CONCEPT])
    }, equipment_restrictions.read_only)

    # Subtypes always use restrictions of parent
    test_laptop_obj = KObject.new; test_laptop_obj.add_attr(O_TYPE_LAPTOP, A_TYPE)
    laptop_restrictions = schema._get_restricted_attributes_for_object(test_laptop_obj)
    assert_equal(equipment_restrictions.hidden, laptop_restrictions.hidden)
    assert_equal(equipment_restrictions.read_only, laptop_restrictions.read_only)
    # And aubtypes don't have restrictions in type descriptor, even if they were used in schema requirements
    assert_equal(nil, schema.type_descriptor(O_TYPE_LAPTOP).restrictions)

    restrict_td = KObjectStore.schema.root_type_descs_sorted_by_printable_name.find { |t| t.code == "test:type:restricted" }
    assert restrict_td != nil
    test_restrict_obj = KObject.new(); test_restrict_obj.add_attr(restrict_td.objref, A_TYPE)
    restrict_type_restrictions = schema._get_restricted_attributes_for_object(test_restrict_obj)
    assert_equal({
      A_NOTES => lo.call([O_LABEL_COMMON, O_LABEL_ARCHIVED, O_LABEL_CONCEPT]),
      A_PROJECT => lo.call([O_LABEL_COMMON, O_LABEL_CONCEPT]),
      A_SUBJECT => lo.call([O_LABEL_COMMON, O_LABEL_ARCHIVED])
    }, restrict_type_restrictions.hidden)
    assert_equal({
      A_AUTHOR => lo.call([O_LABEL_COMMON, O_LABEL_CONCEPT])
    }, restrict_type_restrictions.read_only)

    # Restriction which applies based on labels (only)
    test_equipment_obj_conf = KObject.new([O_LABEL_CONFIDENTIAL]); test_equipment_obj_conf.add_attr(O_TYPE_EQUIPMENT, A_TYPE)
    equipment_restrictions2 = schema._get_restricted_attributes_for_object(test_equipment_obj_conf)
    assert_equal({
      A_NOTES => lo.call([O_LABEL_COMMON, O_LABEL_CONCEPT]),
      A_PROJECT => lo.call([O_LABEL_COMMON, O_LABEL_CONCEPT]),
      A_FILE => lo.call([O_LABEL_COMMON])
    }, equipment_restrictions2.hidden)
    # Change it so it has a type constraint too
    parser2 = SchemaRequirements::Parser.new()
    parser2.parse("test_javascript_schema", StringIO.new(<<__E))
restriction test:restriction:three
    restrict-type std:type:book
__E
    SchemaRequirements::Applier.new(SchemaRequirements::APPLY_APP, parser2, SchemaRequirements::AppContext.new(parser2)).apply.commit
    schema = KObjectStore.schema
    # Try again with same labelled object
    equipment_restrictions3 = schema._get_restricted_attributes_for_object(test_equipment_obj_conf)
    assert_equal({
      A_NOTES => lo.call([O_LABEL_COMMON, O_LABEL_CONCEPT]),
      A_PROJECT => lo.call([O_LABEL_COMMON, O_LABEL_CONCEPT])
    }, equipment_restrictions3.hidden)
    # But a labeled book gets the restriction
    conf_book_obj = KObject.new([O_LABEL_CONFIDENTIAL]); conf_book_obj.add_attr(O_TYPE_BOOK, A_TYPE)
    conf_book_restrictions = schema._get_restricted_attributes_for_object(conf_book_obj)
    assert({
      A_FILE => lo.call([O_LABEL_COMMON])
    }, conf_book_restrictions.hidden);
    # And an unlabelled one doesn't
    book_obj = KObject.new(); book_obj.add_attr(O_TYPE_BOOK, A_TYPE)
    book_restrictions = schema._get_restricted_attributes_for_object(book_obj)
    assert({}, book_restrictions.hidden);
  end

  def test_query_results_load_labels
    restore_store_snapshot("min")

    # Create objects
    1.upto(31) do |n|
      obj = KObject.new([n, 1 + (n % 8)])
      obj.add_attr("obj#{n} xyz", 100)
      obj.add_attr(n, 102)
      KObjectStore.create(obj)
    end
    run_outstanding_text_indexing
    # Tester proc
    check_obj = Proc.new do |obj|
      n = obj.first_attr(102)
      assert n >= 1 && n <= 31
      assert_equal [n, 1 + (n % 8)].sort, obj.labels._to_internal
      assert_equal "obj#{n} xyz", obj.first_attr(100).to_s
    end
    # Iterate over entries, making sure they all have their labels
    [:each, :index, :index_with_ensure].each do |method|
      [:reference, :all].each do |how|
        r = KObjectStore.query_and.free_text("xyz").execute(how, :any)
        assert_equal 31, r.length
        if method == :index_with_ensure
          # For one of the runs, ensure the range is loaded first
          r.ensure_range_loaded(0, 20)
        end
        if method == :each
          r.each { |obj| check_obj.call(obj) }
        else
          0.upto(30) do |n|
            check_obj.call(r[n])
          end
        end
      end
    end
  end

  def test_free_text_search
    restore_store_snapshot("min")

    fts_make_obj(1, "aaa bbb ccc", "xxx δδδ") # δδδ are unicode chars from greek alphabet, for testing character encoding
    fts_make_obj(2, "aaa aaa bbb ccc xxx", "xxx δδδ")
    to_update = fts_make_obj(3, "aaa aaa aaa bbb ccc", "δδδ zzz")
    update2 = fts_make_obj(4, "bbb bbb", "zzz zzz zzz")
    fts_make_obj(5, "aaa", "zzz", "zzz")

    run_outstanding_text_indexing

    # Global searches
    assert_equal [3, 2, 5, 1], fts_search('aaa')
    assert_equal [2, 1], fts_search('aaa xxx')
    assert_equal [2, 1], fts_search('xxx')
    assert_equal [4, 1, 3, 2], fts_search('bbb')
    assert_equal [4, 5, 3], fts_search('zzz')
    assert_equal [1, 3, 2], fts_search('δδδ')

    # Searches on one field only
    assert_equal [2], fts_search('xxx', 2)
    assert_equal [1, 2], fts_search('xxx', 3)
    assert_equal [1, 2], fts_search('δδδ xxx', 3)
    assert_equal [], fts_search('δδδ xxx', 2)

    # Really long search terms don't break anything
    assert_equal [], fts_search('012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345670123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456701234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567')

    # And some truncated words
    # TEMP - truncated words not supported
#    assert_equal [3, 5], fts_search('zzz aaa')
#    assert_equal [3, 5], fts_search('zzz a')
#    assert_equal [3, 5], fts_search('z aaa')
#    assert_equal [3, 5], fts_search('z a')

    # Use the full API
    query = KObjectStore.query_and.free_text('zzz aaa')
    query_result = query.execute(:reference, :relevance)
    assert_equal [5, 3], query_result.map {|o| o.first_attr(1) }

    # Test that empty queries are OK
    empty_query = KObjectStore.query_and
    empty_result = empty_query.execute(:all, :date)
    assert_equal 0, empty_result.length

    # Test that indicies get updated
    obj_up = KObjectStore.read(to_update).dup
    obj_up.delete_attrs!(3)
    obj_up.add_attr("ppp", 3)
    KObjectStore.update(obj_up)
    run_outstanding_text_indexing
    assert_equal [1, 2], fts_search('δδδ')
    assert_equal [3], fts_search('ppp')
    # And delete to make sure they're dropped
    KObjectStore.with_superuser_permissions do
      KObjectStore.erase(to_update)
    end
    run_outstanding_text_indexing
    assert_equal [], fts_search('ppp')

    # Test searching on qualifiers also works
    obj_up2 = KObjectStore.read(update2).dup
    obj_up2.add_attr("www", 2, 999)
    KObjectStore.update(obj_up2)
    run_outstanding_text_indexing
    assert_equal [], fts_search('www', 3)
    assert_equal [4], fts_search('www', 2)
    assert_equal [4], fts_search('www', 2, 999)
    assert_equal [], fts_search('bbb', 2, 999)
    assert fts_search('bbb', 2).include?(4)
  end
  def fts_make_obj(n, s1, s2, s3 = nil)
    o = KObject.new()
    o.add_attr(n, 1)
    o.add_attr(s1, 2)
    o.add_attr(s2, 3)
    o.add_attr(s3, 3) if s3 != nil
    KObjectStore.create(o)
    o.objref
  end
  def fts_search(q, desc = nil, qual = nil)
    query = KObjectStore.query_and.free_text(q, desc, qual)
    query.add_exclude_labels([O_LABEL_STRUCTURE])
    res = query.execute(:all, :relevance).map {|o| o.first_attr(1) }
    # Check ensure_range_loaded doesn't mess things up
    res2_r = query.execute(:reference, :relevance)
    res2_r.ensure_range_loaded(0,res2_r.length-1)
    assert_equal res,res2_r.map {|o| o.first_attr(1) }
    # return original results
    res
  end

  def test_date_ordering
    restore_store_snapshot("min")
    # This tests that the very simple date ordering works as currently implemented.
    # It's not the best way of doing it ever, as it doesn't discriminate on field, but does the job for now.
    # This test ensures that modifiations are noticed.

    time_base = Time.utc(2010, 02, 01, 12, 00)
    objs = Hash.new
    [
      # Identifier, [Date shift, Field for shifted date]
      [0, [[0, A_DATE]]],
      [1, [[20, A_NOTES], [-10, A_DATE]]],
      [2, [[10, A_DATE], [-15, A_NOTES]]],
      [3, [[5, A_DOCUMENT]]],
      [4, [[25, A_NOTES], [19, A_NOTES]]],
      [5, [[2, A_AUTHOR]]]
    ].each do |ident, attrs|
      o = KObject.new()
      o.add_attr(ident, 4)
      attrs.each { |s,a| o.add_attr((time_base + s*86400), a) } # 86400 = seconds in day
      o.add_attr('FINDTHIS',9) # something for the search to find
      KObjectStore.create(o)
      objs[ident] = o
    end
    run_outstanding_text_indexing
    assert_equal [4,1,2,3,5,0], tdo_do_query()

    # Adjust
    middle = objs[3].dup
    middle.delete_attrs!(A_DOCUMENT)
    middle.add_attr((time_base + 30*86400), A_DATE)
    KObjectStore.update(middle)
    assert_equal [3,4,1,2,5,0], tdo_do_query()
  end

  def tdo_do_query
    results = KObjectStore.query_and.free_text('FINDTHIS').execute(:all, :date)
    rids = results.map { |o| o.first_attr(4) }
    rids
  end

  def test_time_constraints_and_result_limits
    restore_store_snapshot("min")
    # Make some test objects with sorting dates set at day spacing.
    time_base = Time.utc(2006, 06, 01, 12, 00)
    0.upto(30) do |day|
      o = KObject.new()
      o.add_attr(day, 4)
      o.add_attr((time_base + day*86400), A_DATE)
      o.add_attr('FINDTHIS',9) # something for the search to find
      KObjectStore.create(o)
    end

    run_outstanding_text_indexing

    # Test various queries
    [
      [nil, nil],
      [0,30],
      [1,2],
      [nil,5],
      [5,nil]
    ].each do |i|
      start_day,end_day = i

      # Query the store
      query = KObjectStore.query_and.free_text('FINDTHIS')
      query.constrain_to_time_interval(
          (start_day != nil) ? (time_base + start_day*86400) : nil,
          (end_day != nil)   ? (time_base + end_day*86400)   : nil
        )
      results = query.execute(:all, :date_asc)

      # Start and ends for the checking
      res_start = (start_day == nil) ? 0 : start_day
      res_end = (end_day == nil) ? 30 : end_day

      # Check the right number are returned (remembering that end is not included)
      assert_equal (res_end - res_start + (end_day == nil ? 1 : 0)), results.length

      # Check the right ones are returned
      x = res_start
      results.each do |o|
        assert_equal x, o.first_attr(4)
        x += 1
      end
    end

    # Test constrained by update time query
    [
      [nil, Time.now + KFramework::SECONDS_IN_DAY, true],
      [Time.now + KFramework::SECONDS_IN_DAY, nil, false],
      [Time.now - (4*KFramework::SECONDS_IN_DAY), Time.now + (4*KFramework::SECONDS_IN_DAY), true],
      [Time.now + (4*KFramework::SECONDS_IN_DAY), Time.now + (8*KFramework::SECONDS_IN_DAY), false],
      [nil, nil, true]
    ].each do |start, endtime, haveresults|
      update_time_query = KObjectStore.query_and.free_text('FINDTHIS')
      update_time_query.constrain_to_updated_time_interval(start, endtime)
      results = update_time_query.execute(:all, :any)
      if haveresults
        assert_equal 31, results.length
      else
        assert_equal 0, results.length
      end
    end

    # Test bad result limits throw exception
    test_for_badness_query = KObjectStore.query_and
    assert_raises(RuntimeError) { test_for_badness_query.maximum_results(0) }
    assert_raises(RuntimeError) { test_for_badness_query.maximum_results(-1) }
    assert_raises(RuntimeError) { test_for_badness_query.maximum_results("pants") }
    assert_raises(RuntimeError) { test_for_badness_query.maximum_results('0') }

    # Test limiting the number of results
    [1, 3, 5, 6, 20].each do |num|
      query = KObjectStore.query_and.free_text('FINDTHIS')
      query.maximum_results(num)
      results = query.execute(:all, :date_asc)
      # Check number and order
      x = 0
      results.each do |o|
        assert_equal x, o.first_attr(4)
        x += 1
      end
      assert_equal num, x
      assert_equal num, results.length
    end

    # Test a limit which is more than the results to return
    q_over_limit = KObjectStore.query_and.free_text('FINDTHIS')
    q_over_limit.maximum_results(100)
    assert_equal 31, q_over_limit.execute(:ref, :any).length
  end

  def test_offsetting
    restore_store_snapshot("min")
    # Make some test objects with sorting dates set at day spacing.
    time_base = Time.utc(2006, 06, 01, 12, 00)
    0.upto(30) do |day|
      o = KObject.new()
      o.add_attr(day, 4)
      o.add_attr((time_base + day*86400), A_DATE)
      o.add_attr('FINDTHIS',9) # something for the search to find
      KObjectStore.create(o)
    end

    run_outstanding_text_indexing

    # Test bad offset starts throw exception
    test_for_badness_query = KObjectStore.query_and
    assert_raises(RuntimeError) { test_for_badness_query.offset(-1) }
    assert_raises(RuntimeError) { test_for_badness_query.offset("pants") }
    assert_raises(RuntimeError) { test_for_badness_query.offset('0') }

    # Test offsetting the number of results
    q_no_limit = KObjectStore.query_and.free_text('FINDTHIS').execute(:ref, :any).length
    [0, 1, 3, 5, 6, 20].each do |num|
      query = KObjectStore.query_and.free_text('FINDTHIS')
      query.offset(num)
      results = query.execute(:all, :date_asc)
      # Check number and order
      x = num
      results.each do |o|
        assert_equal x, o.first_attr(4)
        x += 1
      end
      assert_equal num, q_no_limit - results.length
    end

    # Test an offset which is more than the results to return
    q_over_limit = KObjectStore.query_and.free_text('FINDTHIS')
    q_over_limit.offset(100)
    assert_equal 0, q_over_limit.execute(:ref, :any).length
  end

  def check_type_list_from_short_names(schema, list, expected_types, rejects)
    (t,r) = schema.types_from_short_names(list)
    t = t.map {|t| t.printable_name }
    # p list; p t; p r
    assert_equal expected_types, t
    assert_equal rejects, r
  end

  # ---------------------

  def test_label_query_clauses
    restore_store_snapshot("min")
    [
      [[1,2,3], "a"],
      [[2], "b"],
      [[2,3], "c"],
      [[1,2], "d"],
      [[1,3], "e"]
    ].each do |labels,title|
      obj = KObject.new(labels)
      obj.add_attr(title,A_TITLE)
      obj.add_attr("wordx", A_TITLE, Q_ALTERNATIVE)
      KObjectStore.create(obj)
    end
    run_outstanding_text_indexing
    assert_equal ["a","d","e"],         tlqc_exec {|q| q.any_label([KObjRef.new(1)]) }
    assert_equal ["a","d","e"],         tlqc_exec {|q| q.all_labels([KObjRef.new(1)]) }
    assert_equal ["a","c","d","e"],     tlqc_exec {|q| q.any_label([KObjRef.new(1),3]) }
    assert_equal ["a","e"],             tlqc_exec {|q| q.all_labels([KObjRef.new(1),3]) }
    assert_equal ["a","b","c","d","e"], tlqc_exec {|q| q.any_label([2,3]) }
    assert_equal ["a","c"],             tlqc_exec {|q| q.all_labels([2,3]) }
    assert_equal [],                    tlqc_exec {|q| q.all_labels(["'"]) } # check can't inject bad things
  end

  def tlqc_exec
    q = KObjectStore.query_and.free_text('wordx')
    yield q
    q.execute().map { |o| o.first_attr(A_TITLE).to_s } .sort
  end

  # ---------------------

  def test_special_query_clauses
    restore_store_snapshot("app")
    # Match nothing clause
    q0 = KObjectStore.query_and.link(O_TYPE_APP_VISIBLE, A_TYPE)
    assert q0.execute().length > 0
    q1 = KObjectStore.query_and.link(O_TYPE_APP_VISIBLE, A_TYPE).match_nothing
    assert q1.execute().length == 0
  end

  # ---------------------

  def test_datetime_ranges
    restore_store_snapshot("min")
    # Build some test data
    base_date = Time.new(2010, 10, 23, 0, 0)
    [
      # ident, offset start, offset end
      [0, 0, 10],
      [1, 10, 12],
      [2, 10, 14],
      [3, 5, 12],
      [4, 0, 5],
      [5, 10, 14],
      [6, 100, 120],
      [7, -10, -5]
    ].each do |ident, ostart, oend|
      obj = KObject.new()
      obj.add_attr(ident, 4)
      obj.add_attr(KDateTime.new(
        base_date + (ostart * KFramework::SECONDS_IN_DAY),
        base_date + ((oend - 1) * KFramework::SECONDS_IN_DAY), # -1 because the KDateTime precision will go to the END of that day
        'd'
      ), 5)
      obj.add_attr('FINDTHIS', 6)
      KObjectStore.create(obj)
    end
    run_outstanding_text_indexing
    # Run some searches!
    [
      # min, max, expected results
      [nil, 0, [7]],
      [0, nil, [0,1,2,3,4,5,6]],
      [0, 10, [0,3,4]],
      [120, 121, []], # top end of datetime range is not included
      [120, nil, []],
      [nil, -10, []], # top end of search range is not included
      [-12, -10, []],
      [-100, 200, [0,1,2,3,4,5,6,7]],
      [10, 100, [1,2,3,5]],
      [-6, 1, [0,4,7]],
      [1, 1, [0,4]], # point in time
      [10, 10, [1,2,3,5]], # 0 isn't included because 10 is the top of the range
    ].each do |min_date, max_date, expected|
      q = KObjectStore.query_and.date_range(
        (min_date != nil) ? (base_date + (min_date * KFramework::SECONDS_IN_DAY)) : nil,
        (max_date != nil) ? (base_date + (max_date * KFramework::SECONDS_IN_DAY)) : nil)
      r = q.execute(:all, :any).map { |obj| obj.first_attr(4) } .sort
      assert_equal expected, r
    end

    # DateTime can't be used
    e = assert_raises(RuntimeError) { KObjectStore.query_and.date_range(DateTime.new(2012,2,1), nil) }
    assert_equal 'DateRangeClause min value must be Time object', e.message
    e = assert_raises(RuntimeError) { KObjectStore.query_and.date_range(nil, DateTime.new(2012,2,1)) }
    assert_equal 'DateRangeClause max value must be Time object', e.message
  end

  # ---------------------

  def test_linked_queries_results
    # Get the app's schema loaded
    restore_store_snapshot("basic")

    # Make the structure
    # use desc A_AUTHOR for links everything...
    #   a -> b -> c
    #   e -> b -> c
    #   f -> g -> c
    #        i -> c   # exception this one, which has desc A_SUBJECT
    #   h -> i -> j
    c = tlqr_make('c')
    b = tlqr_make('b', [A_AUTHOR, c])
    a = tlqr_make('a', [A_AUTHOR, b])
    e = tlqr_make('e', [A_AUTHOR, b])
    g = tlqr_make('g', [A_AUTHOR, c])
    f = tlqr_make('f', [A_AUTHOR, g])
    j = tlqr_make('j')
    i = tlqr_make('i', [A_SUBJECT, c], [A_TITLE, j])
    h = tlqr_make('h', [A_AUTHOR, i])

    run_outstanding_text_indexing

    # Then query on it
    tlqr_query(">> c", "b g i")
    tlqr_query(">author> c", "b g")
    tlqr_query(">subject> c", "i")
    tlqr_query(">> >> c", "a e f h")
    tlqr_query(">> b >> c", "a e")
    tlqr_query(">> h >> c", "")
    tlqr_query(">> g", "f")
    tlqr_query(">> j", "i")
    tlqr_query(">> >> j", "h")
    tlqr_query("a >> >> c", "a")
    tlqr_query("a >> >>", "a")    # arrows with nothing after them are ignored
    tlqr_query("b >>", "b")       # another check of that
  end

  def tlqr_make(title, *a)
    obj = KObject.new()
    # put the actual 'title' in a seperate field so linked object text inclusion doesn't break the results
    obj.add_attr("X#{title}", A_TITLE)
    obj.add_attr(title, 42)
    a.each do |d,v|
      obj.add_attr(v,d)
    end
    KObjectStore.create(obj)
    obj
  end

  def tlqr_query(query_string, results)
    pa = KQuery.from_string(query_string)
    qu = KObjectStore.query_and
    qu.add_exclude_labels([O_LABEL_STRUCTURE])
    errs = Array.new
    pa.add_query_to(qu, errs)
    assert errs.empty?
    re = qu.execute(:all, :title).map {|o| o.first_attr(42).to_s}
    ex = results.split.sort
    # p re; p ex
    assert_equal ex, re
  end

  # ---------------------

  def test_attribute_relevance_ranking
    restore_store_snapshot("min")
    KObjectLoader.load_from_string(<<_OBJS)
obj [O_LABEL_STRUCTURE] Q_MEDIUM
  A_TYPE        O_TYPE_QUALIFIER_DESC
  A_TITLE       'Q1'
  A_ATTR_SHORT_NAME 'q1'

obj [O_LABEL_STRUCTURE] Q_ALTERNATIVE
  A_TYPE        O_TYPE_QUALIFIER_DESC
  A_TITLE       'Q2'
  A_ATTR_SHORT_NAME 'q2'

obj [O_LABEL_STRUCTURE] A_IDENTIFIER
  A_TYPE        O_TYPE_ATTR_DESC
  A_TITLE       'X1'
  A_ATTR_SHORT_NAME 'x1'
  A_RELEVANCY_WEIGHT  2000
  A_RELEVANCY_WEIGHT/Q_ALTERNATIVE 500
  A_ATTR_DATA_TYPE  T_TEXT

obj [O_LABEL_STRUCTURE] A_DESCRIPTION
  A_TYPE        O_TYPE_ATTR_DESC
  A_TITLE       'X2'
  A_ATTR_SHORT_NAME 'x2'
  A_ATTR_DATA_TYPE  T_TEXT

obj [O_LABEL_STRUCTURE] A_DOCUMENT
  A_TYPE        O_TYPE_ATTR_DESC
  A_TITLE       'Text'
  A_ATTR_SHORT_NAME	'text'
  A_ATTR_DATA_TYPE  T_TEXT_DOCUMENT
  A_RELEVANCY_WEIGHT  750

obj [O_LABEL_STRUCTURE] O_TYPE_APP_VISIBLE
  A_TITLE   "! Type of Thing"

obj [O_LABEL_STRUCTURE] O_TYPE_BOOK
  A_TYPE    O_TYPE_APP_VISIBLE
  A_TITLE       "Book"

obj [O_LABEL_STRUCTURE] O_TYPE_SERIAL
  A_TYPE    O_TYPE_APP_VISIBLE
  A_TITLE       "Serial"

obj [] nil
  A_TYPE O_TYPE_BOOK
  A_TITLE "obj1"
  A_IDENTIFIER "pp a pp a pp"
  A_IDENTIFIER/Q_ALTERNATIVE "qq a qq a qq a qq a qq a qq a qq a qq a qq a qq"
  A_DESCRIPTION "qq a qq ww"

obj [] nil
  A_TYPE O_TYPE_SERIAL
  A_TITLE "obj2"
  A_IDENTIFIER "pp a pp"
  A_IDENTIFIER/Q_ALTERNATIVE "qq a qq a qq"
  A_DESCRIPTION "qq a qq a qq ww"

_OBJS

    run_outstanding_text_indexing :expected_reindex => true

    tarr_check('pp', 'obj1 obj2')
    tarr_check('qq', 'obj1 obj2')

    # Adjust weighting of attribute
    s = KObjectStore.schema
    o = KObjectStore.read(KObjRef.from_desc(A_DESCRIPTION)).dup
    o.add_attr(4000,A_RELEVANCY_WEIGHT)
    KObjectStore.update(o);
    run_outstanding_text_indexing :expected_reindex => true

    # Check it's made the expected change
    tarr_check('qq', 'obj2 obj1')

    # Adjust weighting of type
    o = KObjectStore.read(O_TYPE_BOOK).dup
    o.add_attr(4000,A_RELEVANCY_WEIGHT)
    KObjectStore.update(o);
    run_outstanding_text_indexing :expected_work => true, :expected_reindex => false

    # Check it's made the expected change
    tarr_check('qq', 'obj1 obj2')

    # Adjust weighting of other type
    o = KObjectStore.read(O_TYPE_SERIAL).dup
    o.add_attr(8000,A_RELEVANCY_WEIGHT)
    KObjectStore.update(o);
    run_outstanding_text_indexing :expected_work => true, :expected_reindex => false

    # Check it's made the expected change
    tarr_check('qq', 'obj2 obj1')

    # Adjust weighting to exlude an attribute
    tarr_check('ww', 'obj2 obj1') # checks it's indexed before the change is made to the weighting
    o = KObjectStore.read(KObjRef.from_desc(A_DESCRIPTION)).dup
    o.delete_attrs!(A_RELEVANCY_WEIGHT)
    o.add_attr(0,A_RELEVANCY_WEIGHT)
    KObjectStore.update(o)
    run_outstanding_text_indexing :expected_work => true, :expected_reindex => true
    # Check nothing is found
    tarr_check('ww', '')
    # Set to the minimum weight, check things are found again
    o = o.dup
    o.delete_attrs!(A_RELEVANCY_WEIGHT)
    o.add_attr(1,A_RELEVANCY_WEIGHT)
    KObjectStore.update(o)
    run_outstanding_text_indexing :expected_work => true, :expected_reindex => true
    tarr_check('ww', 'obj2 obj1')

    # Check reindexing will set expected number of reindex operations
    KApp.with_pg_database do |db|
      current_number_of_operations = Proc.new { db.exec("SELECT COUNT(*) FROM public.os_store_reindex WHERE app_id=$1", _TEST_APP_ID).first.first.to_i }
      assert_equal 0, current_number_of_operations.call()

      o = KObjectStore.read(KObjRef.from_desc(A_DESCRIPTION)).dup
      o.delete_attrs!(A_RELEVANCY_WEIGHT)
      o.add_attr(0,A_RELEVANCY_WEIGHT)
      KObjectStore.update(o)
      assert_equal 1, current_number_of_operations.call()

      o = KObjectStore.read(KObjRef.from_desc(A_DOCUMENT)).dup
      o.delete_attrs!(A_RELEVANCY_WEIGHT)
      o.add_attr(1,A_RELEVANCY_WEIGHT)
      KObjectStore.update(o)
      assert_equal 2, current_number_of_operations.call()

      # Reindex all removes the two outstanding jobs & replaces with one which covers all objects
      KObjectStore.reindex_all_objects
      assert_equal 1, current_number_of_operations.call()
    end
  end

  def tarr_check(query_string, results)
    pa = KQuery.from_string(query_string)
    qu = KObjectStore.query_and
    errs = Array.new
    pa.add_query_to(qu, errs)
    assert errs.empty?
    re = qu.execute(:all, :relevance).map {|o| o.first_attr(A_TITLE).to_s}
    ex = results.split
    # p re; p ex
    assert_equal ex, re
  end

  # ---------------------

  def test_term_inclusion_spec_parsing
    # Get the app's schema loaded
    restore_store_snapshot("basic")
    schema = KObjectStore.schema

    # Check default inclusions
    tmisp_check2(schema, KSchema::DEFAULT_TERM_INCLUSION_SPECIFICATION, [
        [A_TITLE, 1000]
      ])

    # Check inclusions
    tmisp_check(schema, "", [ # title gets automatically added
        [A_TITLE, 1000]
      ])
    tmisp_check(schema, "1.2 title", [ # but isn't added if it already exists
        [A_TITLE, 1200]
      ])
    tmisp_check(schema, "0.5\t  title  ", [
        [A_TITLE, 500]
      ])
    tmisp_check(schema, "0.5 relationship-manager\n  ", [
        [A_TITLE, 1000],    # automatic title gets added first
        [A_RELATIONSHIP_MANAGER, 500]
      ])
    tmisp_check(schema, "   \n0.863 subject\n  \n0.23 author", [
        [A_TITLE, 1000],
        [A_SUBJECT, 863],
        [A_AUTHOR, 230]
      ])

    # Check reindexing change requirements testing
    change0 = KSchema::TermInclusionSpecification.new("2 title", schema)
    change1 = KSchema::TermInclusionSpecification.new("3 title", schema)
    change2 = KSchema::TermInclusionSpecification.new("3 title\n10 subject", schema)
    change3 = KSchema::TermInclusionSpecification.new("10 subject\n 3 title", schema)
    change4 = KSchema::TermInclusionSpecification.new(" 1 subject\n 3 title", schema)
    assert_equal false, change0.reindexing_required_for_change_to?(change0)
    assert_equal true,  change0.reindexing_required_for_change_to?(change1)
    assert_equal true,  change0.reindexing_required_for_change_to?(change2)
    assert_equal false, change2.reindexing_required_for_change_to?(change2)
    assert_equal false, change2.reindexing_required_for_change_to?(change3)
    assert_equal false, change3.reindexing_required_for_change_to?(change2)
    assert_equal true,  change3.reindexing_required_for_change_to?(change4)
    assert_equal true,  change4.reindexing_required_for_change_to?(change2)
    assert_equal false, change4.reindexing_required_for_change_to?(change4)
    # Check changes to default spec
    change_default = KSchema::TermInclusionSpecification.new("", schema)
    assert_equal false, change_default.reindexing_required_for_change_to?(KSchema::DEFAULT_TERM_INCLUSION_SPECIFICATION)
    assert_equal false, KSchema::DEFAULT_TERM_INCLUSION_SPECIFICATION.reindexing_required_for_change_to?(KSchema::DEFAULT_TERM_INCLUSION_SPECIFICATION)

    # And some errors
    s0 = KSchema::TermInclusionSpecification.new("1.0 ping", schema)
    assert_equal ["Unknown attribute 'ping'"], s0.errors
    s1 = KSchema::TermInclusionSpecification.new("pants title", schema)
    assert_equal ["Bad relevancy weight 'pants'"], s1.errors
    s2 = KSchema::TermInclusionSpecification.new(" 1.0 title *   \n", schema)
    assert_equal ["Bad specification line '1.0 title *'"], s2.errors
  end
  def tmisp_check(schema, spec, inclusions)
    is = KSchema::TermInclusionSpecification.new(spec, schema)
    tmisp_check2(schema, is, inclusions)
  end
  def tmisp_check2(schema, is, inclusions)
    i = is.inclusions
    assert_equal inclusions.length, i.length
    0.upto(i.length - 1) do |l|
      x = i[l]
      desc,weight = inclusions[l]
      assert_equal desc, x.desc
      assert_equal weight, x.relevancy_weight
    end
    # Check another thing while we're here
    assert_equal true, KSchema::TermInclusionSpecification.new("1000 title", schema).reindexing_required_for_change_to?(is)
  end

  # ---------------------

  def test_term_inclusion_and_search_constraints
    destroy_all FileCacheEntry
    destroy_all StoredFile

    # Get the app's schema loaded
    restore_store_snapshot("basic")
    schema = KObjectStore.schema

    # Generate a subject heirarchy
    hroot = KObject.new()
    hroot.add_attr(O_TYPE_TAXONOMY_TERM, A_TYPE)
    hroot.add_attr('subjroot', A_TITLE)
    KObjectStore.create(hroot)
    subj_name = 'subjaa'
    subj_name_replacements = {
      'subjbax' => 'ping',
      'subjabx' => 'excursions' # repeated stemming going excursions -> excurs -> excur, ie changes again. Checks a bug fix worked
    }
    # Check that repeated stemming works as we expect to provoke the fixed bug
    assert_equal "excursions:excurs ", KTextAnalyser.text_to_terms("excursions",true)
    assert_equal "excurs:excur ", KTextAnalyser.text_to_terms("excurs",true)
    # Make subjects
    sr = Struct.new(:object,:name,:parent,:book_names,:book_names_heir)
    subjects = [sr.new(hroot,'subjroot',nil,Array.new,Array.new)]
    0.upto(200) do |n|
      sparent = subjects[n / 4]
      so = KObject.new()
      so.add_attr(O_TYPE_TAXONOMY_TERM,A_TYPE)
      so.add_attr(sparent.object, A_PARENT)
      st = subj_name + 'x'
      if subj_name_replacements.has_key?(st)
        st = subj_name_replacements.delete(st)
      end
      subj_name.succ!
      so.add_attr(st,A_TITLE)
      KObjectStore.create(so)
      subjects << sr.new(so,st,sparent,Array.new,Array.new)
    end
    # Check we did the replacements
    assert_equal 0, subj_name_replacements.length
    # Remove the root object
    subjects.shift

    # Generate some test objects - books with specific authors and
    ar = Struct.new(:name,:num_books,:book_names)
    authors = [ar.new(nil, 8), ar.new(nil, 9), ar.new(nil, 12), ar.new(nil, 90)]
    books = Array.new
    author_name = 'autha'
    book_name = 'bookaa'
    subj_index = 1
    authors.each do |x|
      x.name = author_name + 'x'  # stop stemming
      author_name.succ!
      x.book_names = Array.new

      ao = KObject.new()
      ao.add_attr(O_TYPE_PERSON, A_TYPE)
      ao.add_attr(x.name, A_TITLE)
      KObjectStore.create(ao)

      1.upto(x.num_books) do |n|
        bo = KObject.new()
        # Title
        bo.add_attr(O_TYPE_BOOK, A_TYPE)
        bn = book_name + 'x'  # stop stemming
        bo.add_attr(bn, A_TITLE)
        x.book_names << bn
        book_name.succ!
        # Author
        bo.add_attr(ao, A_AUTHOR)
        # Subject
        bo.add_attr(subjects[subj_index].object, A_SUBJECT)
        subjects[subj_index].book_names << bn # store name of book
        h = subjects[subj_index]
        while h != nil
          h.book_names_heir << bn
          h = h.parent
        end
        subj_index += 1
        subj_index = 0 if subj_index >= subjects.length
        KObjectStore.create(bo)
        books << bo
      end
    end

    run_outstanding_text_indexing

    # Test basic link query to an object which exists...
    basiclq = KObjectStore.query_and.link(O_TYPE_BOOK, A_TYPE).execute(:all, :any)
    assert_equal books.length, basiclq.length
    # ... and to an object which doesn't, to make sure it doesn't return bad results.
    ref_of_object_which_doesnt_exist = KObjRef.new(1234567)
    assert_equal nil, KObjectStore.read(ref_of_object_which_doesnt_exist) # check it really doesn't exist
    assert_equal 0, KObjectStore.query_and.link(ref_of_object_which_doesnt_exist).execute(:all, :any).length

    # Test "any link" queries to find all books with an author
    alq = KObjectStore.query_and.link_to_any(A_AUTHOR).execute(:all, :title)
    authors_sum = 0; authors.each { |a| authors_sum += a.num_books }
    assert_equal authors_sum, alq.length
    alq_titles = alq.map { |o| o.first_attr(A_TITLE).to_s } .sort
    assert_equal authors.map { |a| a.book_names } .flatten.sort, alq_titles
    # Any link queries without desc should just return nothing, and not break
    assert_equal 0, KObjectStore.query_and.link_to_any(nil).execute(:all, :title).length
    assert_equal 0, KObjectStore.query_and.link_to_any(nil, Q_ALTERNATIVE).execute(:all, :title).length

    # Now do searches for authors names, term inclusion means authors names will match objects linking to those authors
    authors.each do |x|
      [:date, :date_asc, :relevance, :any, :title, :title_desc].each do |sort_by|
        q2 = KObjectStore.query_and.free_text(x.name)
        s2 = q2.execute(:all, sort_by)
        titles = s2.map {|o| o.first_attr(A_TITLE).to_s } .sort
        assert_equal [x.name] + x.book_names, titles
      end
    end

    # Now do subjects, test:
    #  - heirarchical searching
    #  - exact searching
    #  - term inclusion on searching
    subjects.each do |s|
      # Find all querying exact
      s2 = KObjectStore.query_and.link_exact(s.object, A_SUBJECT).execute(:all, :title)
      assert_equal s.book_names, s2.map {|o| o.first_attr(A_TITLE).to_s } .sort

      # Find all querying heirarchy
      s3 = KObjectStore.query_and.link(s.object, A_SUBJECT).execute(:all, :title)
      assert_equal s.book_names_heir, s3.map {|o| o.first_attr(A_TITLE).to_s } .sort

      # Find all querying heirarchy with a parsed query -- checks the parser goes heirarchical
      s3q_qt = KQuery.from_string("subject:#{s.name}")
      s3q_qu = KObjectStore.query_and
      errs = Array.new
      s3q_qt.add_query_to(s3q_qu, errs)
      assert errs.empty?
      s3q = s3q_qu.execute(:all, :title)
      assert_equal s.book_names_heir, s3q.map {|o| o.first_attr(A_TITLE).to_s } .sort

      # Term inclusion finds linked objects
      s4 = KObjectStore.query_and.free_text(s.name).link(O_TYPE_BOOK,A_TYPE).execute(:all, :title)
      assert_equal s.book_names_heir, s4.map {|o| o.first_attr(A_TITLE).to_s } .sort
    end

    # Test
    #  1) separate constraints in searching
    #  2) term inclusion to match on subject + author
    has_intersect = 0
    different = 0
    sc = Struct.new(:subject,:author,:books)
    subjects[0..12].each do |s|
      authors.each do |a|
        # Get intersection
        intersect = s.book_names_heir & a.book_names
        # Check test coverage
        has_intersect += 1 unless intersect.empty?
        different += 1 if s.book_names_heir != a.book_names

        # Do search with a constraint, checking term inclusion works
        q = KObjectStore.query_and.free_text(a.name)
        q.constraints_container.link(s.object)
        res = q.execute(:all, :title)
        titles = res.map {|o| o.first_attr(A_TITLE).to_s }
        assert_equal intersect, titles

        # Check a similar search using the effects of term inclusion
        q2 = KObjectStore.query_and.free_text(a.name + ' ' + s.name)
        res2 = q2.execute(:all, :title)
        titles2 = res2.map {|o| o.first_attr(A_TITLE).to_s }
        assert_equal intersect, titles2

        # And again, but with relevancy ordering
        q3 = KObjectStore.query_and.free_text(a.name + ' ' + s.name)
        res3 = q3.execute(:all, :relevance)
        titles3 = res3.map {|o| o.first_attr(A_TITLE).to_s } .sort # sort for comparison
        assert_equal intersect, titles3
      end
    end
    # Make sure test doesn't change
    assert_equal 34, has_intersect
    assert_equal 52, different

    # Test auto-inclusion of linked objects in search results
    # (not specifically to do with term inclusion)
    authors.each do |a|
      pa = KQuery.from_string("author:#{a.name}")
      qu = KObjectStore.query_and
      errs = Array.new
      pa.add_query_to(qu, errs)
      assert errs.empty?
      re = qu.execute(:all, :title).map {|o| o.first_attr(A_TITLE).to_s}
      assert_equal a.book_names, re
    end
    # Check this works with multiple control by types too
    author_ado = KObjectStore.read(KObjRef.from_desc(A_AUTHOR)).dup
    author_ado.add_attr(O_TYPE_BOOK, A_ATTR_CONTROL_BY_TYPE)
    KObjectStore.update(author_ado)
    # Add a book in the author field
    obj_with_book_as_author = KObject.new()
    obj_with_book_as_author.add_attr(O_TYPE_BOOK, A_TYPE)
    obj_with_book_as_author.add_attr('ppppppx', A_TITLE)
    obj_with_book_as_author.add_attr(books.first.objref, A_AUTHOR)
    KObjectStore.create(obj_with_book_as_author)
    run_outstanding_text_indexing
    # Now search for it
    owbaa_q = KObjectStore.query_and
    owbaa_q_text = "author:#{books.first.first_attr(A_TITLE).to_s}"
    KQuery.from_string(owbaa_q_text).add_query_to(owbaa_q, Array.new);
    re = owbaa_q.execute(:all, :title).map {|o| o.first_attr(A_TITLE).to_s}
    assert_equal 1, re.length
    assert_equal 'ppppppx', re.first
    # Check authors still match OK
    authors.each do |a|
      pa = KQuery.from_string("author:#{a.name}")
      qu = KObjectStore.query_and
      errs = Array.new
      pa.add_query_to(qu, errs)
      assert errs.empty?
      re = qu.execute(:all, :title).map {|o| o.first_attr(A_TITLE).to_s}
      assert_equal a.book_names, re
    end

    # New book
    bookin5 = KObject.new()
    bookin5.add_attr(O_TYPE_BOOK,A_TYPE)
    bookin5.add_attr('FIVE',A_TITLE)
    bookin5.add_attr(subjects.first.object.objref, A_SUBJECT)
    KObjectStore.create(bookin5)
    run_outstanding_text_indexing
    testsecq1 = KObjectStore.query_and.free_text(subjects.first.name)
    assert nil != testsecq1.execute(:all, :any).find { |o| o.first_attr(A_TITLE).to_s == 'FIVE' }

    # Check that constrained text works with term inclusions
    alsotitle = KObjectStore.query_and.link(O_TYPE_BOOK,A_TYPE)
    alsotitle.or.free_text(subjects[1].name).free_text('FIVE',A_TITLE)
    alsotitler = alsotitle.execute(:all, :any)
    assert nil != alsotitler.find { |o| o.first_attr(A_TITLE).to_s == 'FIVE' }
    assert_equal subjects[1].book_names_heir.length + 1, alsotitler.length
    assert subjects[1].book_names_heir.length > 0

    # Check that modifying an object will update the terms included in other objects
    changing_author = KObject.new()
    changing_author.add_attr(O_TYPE_PERSON, A_TYPE)
    changing_author.add_attr("Changing author", A_TITLE)
    changing_author.add_attr("X11PINGX", A_NOTES)
    KObjectStore.create(changing_author)
    0.upto(2) do |i|
      b = KObject.new()
      b.add_attr(O_TYPE_BOOK, A_TYPE)
      b.add_attr("CB#{i}X", A_TITLE)
      b.add_attr(changing_author, A_AUTHOR)
      KObjectStore.create(b)
    end
    run_outstanding_text_indexing
    # proc for checking results found
    check_changing_found = Proc.new do |should_find, text|
      q = KObjectStore.query_and.link(O_TYPE_BOOK,A_TYPE).free_text(text)
      results = q.execute(:all, :title) .map { |b| b.first_attr(A_TITLE).to_s }
      if should_find
        assert_equal ['CB0X', 'CB1X', 'CB2X'], results
      else
        assert_equal [], results
      end
    end
    check_changing_found.call(true, 'changing author')
    check_changing_found.call(false, 'X11PINGX')
    check_changing_found.call(false, 'XcarrotsX')
    # Add term to author
    changing_author = changing_author.dup
    changing_author.add_attr('XcarrotsX', A_TITLE)
    KObjectStore.update(changing_author)
    check_changing_found.call(false, 'XcarrotsX') # not found until indexed
    run_outstanding_text_indexing
    check_changing_found.call(true, 'XcarrotsX') # found now!

    # Change term inclusion spec on type
    person_type = KObjectStore.read(O_TYPE_PERSON).dup
    person_type.add_attr("4 notes", A_TERM_INCLUSION_SPEC)
    KObjectStore.update(person_type)
    check_changing_found.call(false, 'X11PINGX') # not until indexed
    run_outstanding_text_indexing
    check_changing_found.call(true, 'X11PINGX')

    # Check that files aren't used in term inclusion, as it would be very slow and ruin the results
    stored_file = StoredFile.from_upload(fixture_file_upload('files/example2.doc', 'application/msword'))
    run_all_jobs :expected_job_count => 1
    changing_author = changing_author.dup
    changing_author.add_attr(KIdentifierFile.new(stored_file), A_NOTES)
    KObjectStore.update(changing_author)
    run_outstanding_text_indexing
    # ... not found in books
    check_changing_found.call(false, 'FORSEARCHING')
    # ... but found in authors
    assert_equal ['Changing author'], KObjectStore.query_and.free_text('FORSEARCHING').execute(:all, :any).map { |o| o.first_attr(A_TITLE).to_s }

    # And then undo use of notes fields (AFTER the file check)
    person_type = person_type.dup
    person_type.delete_attrs!(A_TERM_INCLUSION_SPEC)
    KObjectStore.update(person_type)
    check_changing_found.call(true, 'X11PINGX') # not until index
    run_outstanding_text_indexing
    check_changing_found.call(false, 'X11PINGX')

    # Change name of type, do normal free text query
    free_text_search_in_type_field = Proc.new do |text|
      KObjectStore.query_and.free_text(text, A_TYPE).execute(:all, :title).map { |o| o.first_attr(A_TITLE).to_s }
    end
    assert_equal ["authax", "authbx", "authcx", "authdx", "Changing author"], free_text_search_in_type_field.call('person')
    person_type = person_type.dup
    person_type.delete_attrs!(A_TITLE)
    person_type.add_attr("XPersonX", A_TITLE)
    KObjectStore.update(person_type)
    run_outstanding_text_indexing
    assert_equal [], free_text_search_in_type_field.call('person')
    assert_equal ["authax", "authbx", "authcx", "authdx", "Changing author"], free_text_search_in_type_field.call('xpersonx')
  end

  # ------------------------------------------------------------------------

  def test_linked_subquery_queries
    restore_store_snapshot("basic")

    # Subject heirarchy
    s1 = tlsq_make_subject([1111], "S1")
    s2 = tlsq_make_subject([1111], "S2")
    s3 = tlsq_make_subject([], "S3", s2)
    s4 = tlsq_make_subject([], "S4", s3)

    # Make some people
    p1 = tlsq_make_person([2222], "P1")
    p2 = tlsq_make_person([3333], "P2") { |o| o.add_attr(s1, A_SUBJECT) }
    p3 = tlsq_make_person([], "P3")
    p4 = tlsq_make_person([], "P4")

    # Make some books
    b1 = tlsq_make_book([], "B1", [p1], [])
    b2 = tlsq_make_book([5555], "B2", [p1, p2], [s2])
    b3 = tlsq_make_book([], "B3", [p2], [s3]) { |o| o.add_attr(p1, A_NOTES) }
    b4 = tlsq_make_book([4444], "B4", [p3, p2], [s1,s4])

    run_outstanding_text_indexing

    # ---------------- LINKED TO ----------------

    tlsq_query(["B2","B3","B4"]) do |q|
      q.add_linked_to_subquery(:exact, A_AUTHOR).subquery_container.free_text("p2")
    end
    tlsq_parsed_query(["B2","B3","B4"], ">author> p2")
    tlsq_query(["B2","B3","B4"]) do |q|
      q.add_linked_to_subquery(:exact, A_AUTHOR).subquery_container.or.free_text("p2").free_text("p3")
    end
    tlsq_parsed_query(["B2","B3","B4"], ">author> p2 or p3")

    # B3 linked to P1 in non-author field, check it appears here
    tlsq_query(["B1","B2","B3"]) do |q|
      q.add_linked_to_subquery(:exact).subquery_container.free_text("p1")
    end
    tlsq_parsed_query(["B1","B2","B3"], ">> p1")
    # And with the author restriction
    tlsq_query(["B1","B2"]) do |q|
      q.add_linked_to_subquery(:exact, A_AUTHOR).subquery_container.free_text("p1")
    end
    tlsq_parsed_query(["B1","B2"], ">author> p1")
    tlsq_parsed_query(["B1","B2"], "author:p1") # means roughly the same thing, requires underlying linked to subquery

    # Subjects for hierarchy
    tlsq_query(["B2"]) do |q|
      q.add_linked_to_subquery(:exact, A_SUBJECT).subquery_container.free_text("S2", A_TITLE)
    end
    # parsed queries choose exist/hierarchical automatically, but if field isn't specified, it'll do an exact as it won't know any better
    tlsq_parsed_query(["B2","S3"], ">> title:s2") # s3 has parent link
    tlsq_query(["B2","B3","B4"]) do |q|
      q.add_linked_to_subquery(:hierarchical, A_SUBJECT).subquery_container.free_text("S2", A_TITLE)
    end
    tlsq_parsed_query(["B2","B3","B4"], ">subject> s2")
    tlsq_parsed_query(["B2","B3","B4"], "subject:s2")
    tlsq_query(["B3","B4"]) do |q|
      q.add_linked_to_subquery(:hierarchical, A_SUBJECT).subquery_container.free_text("S3", A_TITLE)
    end
    tlsq_parsed_query(["B3","B4"], ">subject> s3")
    tlsq_parsed_query(["B3","B4"], "subject:s3")
    tlsq_query(["B4","P2"]) do |q|
      q.add_linked_to_subquery(:hierarchical, A_SUBJECT).subquery_container.free_text("S1", A_TITLE)
    end
    tlsq_parsed_query(["B4","P2"], ">subject> s1")
    tlsq_parsed_query(["B4","P2"], "subject:s1")
    tlsq_parsed_query(["P2"], ">expertise> s1") # make sure aliases work as expected
    tlsq_parsed_query(["P2"], "expertise:s1")

    # Labels in linked queries
    tlsq_query(["B3","B4"]) do |q|
      q.add_exclude_labels([5555]) # excludes B2 at top level of query
      q.add_linked_to_subquery(:exact, A_AUTHOR).subquery_container.free_text("p2")
    end
    tlsq_query([]) do |q|
      q.add_exclude_labels([3333]) # excludes P2 in subquery, so nothing is found
      q.add_linked_to_subquery(:exact, A_AUTHOR).subquery_container.free_text("p2")
    end

    # ---------------- LINKED FROM ----------------

    tlsq_query(["P1"]) do |q|
      q.add_linked_from_subquery(A_AUTHOR).subquery_container.free_text("b1", A_TITLE)
    end
    tlsq_parsed_query(["P1"], "<author< b1")
    tlsq_query(["P1","P2"]) do |q|
      q.add_linked_from_subquery(A_AUTHOR).subquery_container.free_text("b2", A_TITLE)
    end
    tlsq_parsed_query(["P1","P2"], "<author< b2")
    tlsq_query(["P1","P2","P3"]) do |q|
      q.add_linked_from_subquery(A_AUTHOR).subquery_container.or.free_text("b1", A_TITLE).free_text("b4", A_TITLE)
    end
    tlsq_parsed_query(["P1","P2","P3"], "<author< b1 or b4")
    tlsq_query(["P1","P2","P3","S1","S4"]) do |q|
      q.add_linked_from_subquery().subquery_container.or.free_text("b1", A_TITLE).free_text("b4", A_TITLE)
    end
    tlsq_parsed_query(["P1","P2","P3","S1","S4"], "<< b1 or b4")
    tlsq_query([]) do |q|
      q.add_linked_from_subquery(A_AUTHOR).subquery_container.free_text('pants', A_TITLE)
    end
    tlsq_parsed_query([], "<author< pants")
    tlsq_query([]) do |q|
      q.add_linked_from_subquery(A_AUTHOR).subquery_container.free_text('s1', A_TITLE) # subjects don't actually link to anything
    end
    tlsq_parsed_query([], "<author< title:s1")
    tlsq_query(["S1"]) do |q|
      q.add_linked_from_subquery(A_SUBJECT).subquery_container.free_text('p2', A_TITLE)
    end
    tlsq_parsed_query(["S1"], "<subject< title:p2")
    tlsq_query(["S1"]) do |q|
      q.add_linked_from_subquery().subquery_container.free_text('p2', A_TITLE)
    end
    tlsq_parsed_query(["S1"], "<< title:p2")
    tlsq_query(["P1","P2","S2"]) do |q|
      q.add_linked_from_subquery().subquery_container.free_text('b2', A_TITLE)
    end
    tlsq_parsed_query(["P1","P2","S2"], "<< title:b2")
    tlsq_query(["P1","P2"]) do |q|
      q.add_linked_from_subquery(A_AUTHOR).subquery_container.free_text('b2', A_TITLE)
    end
    tlsq_parsed_query(["P1","P2"], "<author< title:b2")
    tlsq_query(["S2"]) do |q|
      q.add_linked_from_subquery(A_SUBJECT).subquery_container.free_text('b2', A_TITLE)
    end
    tlsq_parsed_query(["S2"], "<subject< title:b2")

    # Labels in linked queries
    tlsq_query(["P2","P3"]) do |q|
      q.add_exclude_labels([2222]) # excludes P1 at top of query
      q.add_linked_from_subquery(A_AUTHOR).subquery_container.or.free_text("b1", A_TITLE).free_text("b4", A_TITLE)
    end
    tlsq_query(["P1"]) do |q|
      q.add_exclude_labels([4444]) # excludes B4 in sub query
      q.add_linked_from_subquery(A_AUTHOR).subquery_container.or.free_text("b1", A_TITLE).free_text("b4", A_TITLE)
    end
  end

  def tlsq_make_subject(labels, name, parent = nil)
    o = KObject.new(labels); o.add_attr(O_TYPE_TAXONOMY_TERM, A_TYPE); o.add_attr(name, A_TITLE)
    o.add_attr(parent, A_PARENT) if parent != nil
    KObjectStore.create(o); o
  end
  def tlsq_make_person(labels, name)
    o = KObject.new(labels); o.add_attr(O_TYPE_PERSON, A_TYPE); o.add_attr(name, A_TITLE)
    yield o if block_given?
    KObjectStore.create(o); o
  end
  def tlsq_make_book(labels, name, people, subjects)
    o = KObject.new(labels); o.add_attr(O_TYPE_BOOK, A_TYPE); o.add_attr(name, A_TITLE)
    people.each { |p| o.add_attr(p, A_AUTHOR) }
    subjects.each { |s| o.add_attr(s, A_SUBJECT) }
    yield o if block_given?
    KObjectStore.create(o); o
  end
  def tlsq_query(expected)
    q = KObjectStore.query_and
    q.add_exclude_labels([O_LABEL_STRUCTURE])
    yield q
    assert_equal expected, tlsq_exec(q)
  end
  def tlsq_parsed_query(expected, query)
    tlsq_query(expected) do |q|
      qq = KQuery.new(query)
      assert_equal query, qq.minimal_query_string.gsub(/[\(\)]/,'').downcase # check it's reformed correctly (ignoring the pesky brackets)
      errors = []
      qq.add_query_to q, errors
      assert errors.empty?
    end
  end
  def tlsq_exec(q)
    q.execute(:all, :title).map { |o| o.first_attr(A_TITLE).to_s }
  end

  # ------------------------------------------------------------------------

  def test_identifier_basics
    restore_store_snapshot("min")
    # Check identifiers compare properly and go in arrays
    isbn1a = KIdentifierISBN.new('0977616630')
    isbn1b = KIdentifierISBN.new('0977616630')
    isbn2  = KIdentifierISBN.new('1902505840')
    assert isbn1a == isbn1b
    assert isbn1a != isbn2
    assert isbn1b != isbn2
    ary1 = [isbn1a, isbn2]
    assert ary1.include?(isbn1a)  # actually in it
    assert ary1.include?(isbn1b)  # just equal
    assert ary1.include?(isbn2)
    assert ary1.include?(KIdentifierISBN.new('1902505840'))
    assert ! ary1.include?(KIdentifierISBN.new('0000000000'))
    fs1 = KIdentifierFile.new(tib_make_stored_file(:digest => 'ff1003f5f8ba5c667415503669896c2940814fd64a846f08e879891864e06a06', :size => 1823, :upload_filename => 'T.doc', :mime_type => 'text/plain'))
    fs2 = KIdentifierFile.new(tib_make_stored_file(:digest => 'ff1003f5f8ba5c667415503669896c2940814fd64a846f08e879891864e06a06', :size => 1823, :upload_filename => 'T.doc', :mime_type => 'text/rtf'))
    assert fs1 != isbn1a
    assert fs1 == fs1
    assert fs1 != fs2
  end

  def tib_make_stored_file(a)
    stored_file = StoredFile.new
    stored_file.digest = a[:digest]
    stored_file.size = a[:size]
    stored_file.upload_filename = a[:upload_filename]
    stored_file.mime_type = a[:mime_type]
    stored_file
  end

  def test_identifier_searches
    # Get the app's schema loaded
    restore_store_snapshot("basic")

    # Create a couple of objects which don't have identifiers
    obj_no_ident1 = KObject.new()
    obj_no_ident1.add_attr(O_TYPE_PERSON, A_TYPE)
    obj_no_ident1.add_attr('author obj', A_TITLE)
    obj_no_ident1.add_attr('0977616630', A_DESCRIPTION)    # ISBN we'll use later in identifier
    KObjectStore.create(obj_no_ident1)
    obj_no_ident2 = KObject.new()
    obj_no_ident2.add_attr(O_TYPE_BOOK, A_TYPE)
    obj_no_ident2.add_attr(obj_no_ident1, A_AUTHOR)
    obj_no_ident2.add_attr('book obj', A_TITLE)
    KObjectStore.create(obj_no_ident2)      # no identifier like thing here

    # Create a identifier object
    obj_with_ident1 = KObject.new()
    obj_with_ident1.add_attr(O_TYPE_BOOK, A_TYPE)
    obj_with_ident1.add_attr('book with ident', A_TITLE)
    obj_with_ident1.add_attr(KIdentifierISBN.new('0977616630'), A_IDENTIFIER)
    KObjectStore.create(obj_with_ident1)

    # And another unreleated object with a different identifier
    obj_with_ident2 = KObject.new()
    obj_with_ident2.add_attr(O_TYPE_BOOK, A_TYPE)
    obj_with_ident2.add_attr('Principles of data management', A_TITLE)
    obj_with_ident2.add_attr(KIdentifierISBN.new('1902505840'), A_IDENTIFIER)
    KObjectStore.create(obj_with_ident2)

    run_outstanding_text_indexing

    # Do a search for the identifier
    q1 = KObjectStore.query_and.identifier(KIdentifierISBN.new('0977616630'))
    res1 = q1.execute(:all, :any)
    assert_equal 1, res1.length
    assert_equal 'book with ident', res1[0].first_attr(A_TITLE).text

    # Check the desc/qual stuff has an effect
    q2 = KObjectStore.query_and.identifier(KIdentifierISBN.new('0977616630'), A_DESCRIPTION)
    res2 = q2.execute(:all, :any)
    assert_equal 0, res2.length

    # Check this particular one is also found via free text
    q3 = KObjectStore.query_and.free_text('1902505840')
    res3 = q3.execute(:all, :any)
    assert_equal 1, res3.length
    assert_equal 'Principles of data management', res3[0].first_attr(A_TITLE).text

    # Check any identifer finds both the books
    q4 = KObjectStore.query_and.any_indentifier_of_type(T_IDENTIFIER_ISBN, A_IDENTIFIER)
    res4 = q4.execute(:all, :title)
    assert_equal 2, res4.length
    assert_equal ['book with ident','Principles of data management'], res4.map { |o| o.first_attr(A_TITLE).to_s }
    # Check other any queries
    assert_equal 0, KObjectStore.query_and.any_indentifier_of_type(T_IDENTIFIER_EMAIL_ADDRESS, A_IDENTIFIER).execute().length
    assert_equal 0, KObjectStore.query_and.any_indentifier_of_type(T_IDENTIFIER_ISBN, A_NOTES).execute().length
    assert_equal 2, KObjectStore.query_and.any_indentifier_of_type(T_IDENTIFIER_ISBN, A_IDENTIFIER).execute().length

    # Check that removing an identifier from an object stops it being found
    # (check for fixed bug in original introduction of identifiers in r507)
    obj_with_ident1 = obj_with_ident1.dup
    obj_with_ident1.delete_attr_if { |value,d,q| value.k_typecode == T_IDENTIFIER_ISBN }
    KObjectStore.update(obj_with_ident1)
    assert_equal 0, KObjectStore.query_and.identifier(KIdentifierISBN.new('0977616630')).execute(:all, :any).length

    # Test email identifier is case insensitive
    obj_email1 = KObject.new()
    obj_email1.add_attr(O_TYPE_BOOK, A_TYPE)
    obj_email1.add_attr('testemail1', A_TITLE)
    obj_email1.add_attr(KIdentifierEmailAddress.new('x@Y.tLd'), A_IDENTIFIER)
    KObjectStore.create(obj_email1)
    eq1 = KObjectStore.query_and.identifier(KIdentifierEmailAddress.new('X@y.TlD'), A_IDENTIFIER)
    eq1r = eq1.execute(:all,:any)
    assert_equal 1, eq1r.length
    assert_equal 'testemail1', eq1r[0].first_attr(A_TITLE).text

    # Platform configuration identifiers
    obj_identified = KObject.new()
    obj_identified.add_attr(O_TYPE_BOOK, A_TYPE)
    obj_identified.add_attr("hello! this has a config identifier", A_TITLE)
    obj_identified.add_attr(KIdentifierConfigurationName.new("plugin:special_stuff"), A_IDENTIFIER)
    KObjectStore.create(obj_identified)
    oiq1 = KObjectStore.query_and.identifier(KIdentifierConfigurationName.new("plugin:special_stuff"), A_IDENTIFIER).execute(:all,:any)
    assert_equal 1, oiq1.length
    assert_equal obj_identified.objref, oiq1[0].objref
    assert_equal 0, KObjectStore.query_and.free_text("special_stuff").execute(:all,:any).length # not indexed
  end

  def test_uuid_identifier
    restore_store_snapshot("basic")
    uuid1 = KIdentifierUUID.new("9553ade8-625d-efb0-8660-c4e908e4ea70")
    uuid2 = KIdentifierUUID.new("  0bbc260e-56a0-6fc9-c601-f5c090064eb3  ")
    assert_raises(RuntimeError) { KIdentifierUUID.new("not a UUID") }

    assert uuid1 != "9553ade8-625d-efb0-8660-c4e908e4ea70" # string representation, but still not equal
    assert_equal "9553ade8-625d-efb0-8660-c4e908e4ea70", uuid1.to_s
    assert_equal "0bbc260e-56a0-6fc9-c601-f5c090064eb3", uuid2.to_s

    assert uuid1 != uuid2
    assert uuid1 != KIdentifierUUID.new("c53466b0-b9f8-c3df-a5f2-d8abe14afb42")

    assert_equal KIdentifierUUID.new("0bbc260e-56a0-6fc9-c601-f5c090064eb3"), uuid2
    assert_equal KIdentifierUUID.new("0BBC260E-56A0-6FC9-C601-F5C090064EB3"), uuid2
    assert_equal KIdentifierUUID.new("0bbc260e-56a0-6fc9-c601-F5C090064EB3"), uuid2

    obj1 = KObject.new()
    obj1.add_attr(O_TYPE_BOOK, A_TYPE)
    obj1.add_attr("book1", A_TITLE)
    obj1.add_attr(uuid1, 1777)
    KObjectStore.create(obj1)
    obj2 = KObject.new()
    obj2.add_attr(O_TYPE_BOOK, A_TYPE)
    obj2.add_attr("book2", A_TITLE)
    obj2.add_attr(uuid2, 1777)
    KObjectStore.create(obj2)

    check1 = Proc.new do |uuidstr, expected_title|
      r = KObjectStore.query_and().identifier(KIdentifierUUID.new(uuidstr), 1777).execute()
      assert_equal 1, r.length
      assert_equal expected_title, r[0].first_attr(A_TITLE).to_s
    end
    check1.call('9553ade8-625d-efb0-8660-c4e908e4ea70', 'book1')
    check1.call('9553ADE8-625D-EFB0-8660-C4E908E4EA70', 'book1') # all upper case
    check1.call('0bbc260e-56a0-6fc9-c601-f5c090064eb3', 'book2')
    check1.call('0bbc260e-56a0-6fc9-c601-F5C090064EB3', 'book2') # partial upper case
  end

  # ------------------------------------------------------------------------

  def tetm_m(q)
    # Order by :date with latest first, so that the inbuilt fallback ordering of id DESC gives a predicable ordering
    q.execute(:all, :date).map {|o| o.objref}
  end

  def test_exact_title_matches
    restore_store_snapshot("min")
    # NOTE: Text is transformed as per sortas_title, so KTextPersonName objects won't work as anticipiated.

    # Make a few of test objects
    obj1 = KObject.new()
    obj1.add_attr('pants', A_TITLE)
    obj1.add_attr('carrot', A_DESCRIPTION)
    KObjectStore.create(obj1);

    obj2 = KObject.new()
    obj2.add_attr('Pant', A_TITLE)
    obj2.add_attr('carrots', A_DESCRIPTION)
    KObjectStore.create(obj2);

    obj3 = KObject.new()
    obj3.add_attr('carrots', A_TITLE)
    obj3.add_attr('pant', A_DESCRIPTION)
    KObjectStore.create(obj3);

    obj4 = KObject.new()
    obj4.add_attr('something & something else', A_TITLE)
    KObjectStore.create(obj4);

    run_outstanding_text_indexing

    # Do searches
    assert_equal [obj1.objref], tetm_m(KObjectStore.query_and.exact_title('pants'))
    assert_equal [obj1.objref], tetm_m(KObjectStore.query_and.exact_title('Pants')) # check for case insensitivity
    assert_equal [obj2.objref], tetm_m(KObjectStore.query_and.exact_title('pant'))  # different case
    assert_equal [obj2.objref], tetm_m(KObjectStore.query_and.exact_title('Pant'))
    assert_equal [obj4.objref], tetm_m(KObjectStore.query_and.exact_title('something & something else'))
    assert_equal [obj3.objref, obj2.objref, obj1.objref], tetm_m(KObjectStore.query_and.free_text('pants'))
    assert_equal [obj3.objref, obj2.objref, obj1.objref], tetm_m(KObjectStore.query_and.free_text('pant'))
    assert_equal [], tetm_m(KObjectStore.query_and.exact_title('carrot'))
    assert_equal [obj3.objref], tetm_m(KObjectStore.query_and.free_text('carrot', A_TITLE))
    assert_equal [obj3.objref], tetm_m(KObjectStore.query_and.free_text('carrots', A_TITLE))

  end

  # ------------------------------------------------------------------------

  TPPC_Node = Struct.new(:obj, :linked_objs)

  # Test that changing the parent path updates the indicies by creating lots of objects
  # linked in heirachies, then doing searches to find them. Then change things around
  # in the parent paths, and make sure the searches still find the right things.

  def test_parent_path_changes
    restore_store_snapshot("min")
    # Make an array of arrays of objects.
    # Each object has two other objects linked to it.
    nodes = Array.new
    0.upto(4) do |group|
      n = Array.new
      parent = nil
      0.upto(10) do |heir|
        # Make object
        obj = KObject.new()
        obj.add_attr(parent.objref, A_PARENT) if parent != nil
        obj.add_attr("#{group}_#{heir}", A_TITLE)
        KObjectStore.create(obj)
        parent = obj
        # Make things classified under it
        linked = Array.new
        0.upto(2) do |lnk|
          l = KObject.new()
          l.add_attr(obj.objref, A_AUTHOR)
          l.add_attr("#{group}_#{heir}_#{lnk}", A_TITLE)
          KObjectStore.create(l)
          linked << l.objref
        end
        # Make a node
        nd = TPPC_Node.new(obj, linked)
        n << nd
      end
      nodes << n
    end
    # Now verify it all looks OK so far
    tppc_verify(nodes)

    # Break a chain, then verify
    tppc_break(nodes, 0, 4)
    assert_equal [4,11,11,11,11,7], nodes.map {|e| e.length}  # check tppc_break
    tppc_verify(nodes)

    # Join two together
    tppc_join(nodes, 1, 2)
    assert_equal [4,22,0,11,11,7], nodes.map {|e| e.length}  # check tppc_join
    tppc_verify(nodes)

    # And again, for fun
    tppc_break(nodes, 1, 18)
    assert_equal [4,18,0,11,11,7,4], nodes.map {|e| e.length}
    tppc_verify(nodes)

    # Join two broken bits together
    tppc_join(nodes, 5, 6)
    assert_equal [4,18,0,11,11,11,0], nodes.map {|e| e.length}
    tppc_verify(nodes)

    # And more!
    tppc_join(nodes, 1, 3)
    tppc_join(nodes, 1, 4)
    assert_equal [4,40,0,0,0,11,0], nodes.map {|e| e.length}
    tppc_verify(nodes)

    # That should do.
  end

  def tppc_verify(nodes)
    checks = 0
    nodes.each do |list|
      0.upto(list.length-1) do |i|
        # Collect the linked objrefs of this and descendants
        objrefs = Hash.new
        i.upto(list.length-1) do |x|
          list[x].linked_objs.each do |o|
            assert !objrefs.has_key?(o)
            objrefs[o] = true
          end
          # Children of the object will appear too.
          if x > i
            objrefs[list[x].obj.objref] = true
          end
        end
#p objrefs.size
        # Now do a search
        KObjectStore.query_and.link(list[i].obj.objref).execute(:all,:any).each do |obj|
          objref = obj.objref
          # Check the objref is in the list
          assert objrefs.has_key?(objref)
          # Remove
          objrefs.delete(objref)
          # Keep a count
          checks += 1
        end
        # Check everything was found
        assert objrefs.empty?
      end
    end
    assert checks > 500 # checks that something significant happened
  end

  # Break the heirarchical chain, creating a new list at the end
  def tppc_break(nodes, list_index, entry_index)
    l = nodes[list_index]
    o = l[entry_index].obj.dup
    l[entry_index].obj = o  # store back duped object
    o.delete_attrs!(A_PARENT)
    KObjectStore.update(o)
    nodes << l.slice!(entry_index, 1000)
  end

  # Join two lists together, making the latter one the empty list
  def tppc_join(nodes, index1, index2)
    l1 = nodes[index1]
    l2 = nodes[index2]
    o1 = l1.last.obj
    o2 = l2.first.obj
    have_parent = false
    o2.each(A_PARENT) {|v,d,q| have_parent = true}
    assert_equal false, have_parent
    o2 = o2.dup
    o2.add_attr(o1.objref, A_PARENT)
    KObjectStore.update(o2)
    l2.each {|e| l1 << e}
    l2.delete_if {|i| true}
  end

  # ------------------------------------------------------------------------

  def test_truncated_search
    restore_store_snapshot("min")
    # Basic type object
    type_obj = KObject.new([O_LABEL_STRUCTURE])
    type_obj.add_attr('test type', A_TITLE)
    KObjectStore.create(type_obj)
    # Use words which stem down quite a bit to create a couple of test objects
    #   -- note that they should have unique first letters so the tests below work as expected
    obj1 = KObject.new()
    obj1.add_attr(type_obj, A_TYPE)
    obj1.add_attr('Federation of Random Stuff', A_TITLE)
    obj1.add_attr('Xandy Bloggs', A_AUTHOR)
    KObjectStore.create(obj1)
    obj2 = KObject.new()
    obj2.add_attr(type_obj, A_TYPE)
    obj2.add_attr('Something Automatically doing stuff', A_TITLE)
    obj2.add_attr('Org promotion of Punctuation', A_TITLE, Q_ALTERNATIVE)
    KObjectStore.create(obj2)

    # Index
    run_outstanding_text_indexing

    # Do searches
    [
      ['FEDERATION', nil, nil, [obj1.objref]],
      ['FEDERATION', A_TITLE, nil, [obj1.objref]],
      ['FEDERATION', A_TITLE, Q_ALTERNATIVE, []],
      ['Automatically', nil, nil, [obj2.objref]],
      ['Automatically', A_TITLE, nil, [obj2.objref]],
      ['Automatically', A_TITLE, Q_ALTERNATIVE, []],
      ['Punctuation', nil, nil, [obj2.objref]],
      ['Punctuation', A_TITLE, nil, [obj2.objref]],
      ['Punctuation', A_TITLE, Q_ALTERNATIVE, [obj2.objref]],
      ['Xandy', A_AUTHOR, nil, [obj1.objref]],      # Would be stemmed as 'Xandi', so make sure it's not!
      ['of', nil, nil, [obj1.objref, obj2.objref]]
    ].each do |word, desc, qual, expected|
      0.upto(word.length - 1) do |len|
        search_for = word[0 .. len]
        q = KObjectStore.query_and
        q.free_text(search_for+'*', desc, qual)
        q.add_exclude_labels([O_LABEL_STRUCTURE])
        r = q.execute(:all, :any).map { |o| o.objref } .sort { |a,b| a.obj_id <=> b.obj_id }
        assert_equal expected, r
      end

    end
  end

  # ------------------------------------------------------------------------

  def test_spelling_correction
    restore_store_snapshot("min")
    type_obj = KObject.new([O_LABEL_STRUCTURE])
    type_obj.add_attr('test type', A_TITLE)
    KObjectStore.create(type_obj)
    ['ping', 'pants', 'carrots', 'something', 'xand'].each do |word|
      o = KObject.new()
      o.add_attr(type_obj, A_TYPE)
      o.add_attr(word, A_TITLE)
      KObjectStore.create(o)
    end
    run_outstanding_text_indexing

    q = KObjectStore.query_and

    # Some results
    assert_equal "ping", q.suggest_spellings("png")
    assert_equal "ping parsnips", q.suggest_spellings("png parsnips")
    assert_equal "parsnips ping", q.suggest_spellings("parsnips png")
    assert_equal "pants", q.suggest_spellings("panst")
    assert_equal "title:pants", q.suggest_spellings("title:panst")
    assert_equal "title:pants carrots", q.suggest_spellings("title:panst carrts")
    assert_equal "title:pants carrots", q.suggest_spellings("title:panst carrots")
    assert_equal "title:pants goldfish", q.suggest_spellings("title:panst goldfish")
    # No suggestion, no results
    assert_equal nil, q.suggest_spellings("pants")
    assert_equal nil, q.suggest_spellings("parsnips")
    # Complex, no results
    assert_equal nil, q.suggest_spellings("(panst)")
  end

  # ------------------------------------------------------------------------

  def test_superuser_permissions_with_user_invalidation
    # Make sure the system which updates the object store permissions when users are invalidation doesn't lose superuser permissions
    db_reset_test_data
    AuthContext.with_user(User.read(41)) do
      assert_equal false, KObjectStore.superuser_permissions_active?
      KObjectStore.with_superuser_permissions do
        assert_equal true, KObjectStore.superuser_permissions_active?
        User.invalidate_cached
        assert_equal true, KObjectStore.superuser_permissions_active?
      end
      assert_equal false, KObjectStore.superuser_permissions_active?
    end
  end

  # ------------------------------------------------------------------------

  def test_accounting
    restore_store_snapshot("min")
    KAccounting.setup_accounting
    KAccounting.set_counters_for_current_app

    beginning_object_count = KAccounting.get(:objects)
    assert beginning_object_count >= 0

    obj1 = KObject.new()
    obj1.add_attr("one", A_TITLE)
    KObjectStore.create(obj1)

    assert_equal beginning_object_count + 1, KAccounting.get(:objects)

    obj2 = KObject.new([O_LABEL_STRUCTURE])
    obj2.add_attr("structure", A_TITLE)
    KObjectStore.create(obj2)

    # O_LABEL_STRUCTURE labelled objects aren't counted
    assert_equal beginning_object_count + 1, KAccounting.get(:objects)

    KObjectStore.with_superuser_permissions { KObjectStore.erase(obj1) }
    assert_equal beginning_object_count, KAccounting.get(:objects)
  end

  # ------------------------------------------------------------------------

  def test_store_options
    restore_store_snapshot("min")
    assert_equal nil, KObjectStore.schema.store_options[:test_opt1]
    KObjectStore.set_store_option(:test_opt1, "hello")
    assert_equal 'hello', KObjectStore.schema.store_options[:test_opt1]
    assert_equal nil, KObjectStore.schema.store_options[:option2]
    KObjectStore.set_store_option(:option2, "pants")
    assert_equal 'hello', KObjectStore.schema.store_options[:test_opt1]
    assert_equal 'pants', KObjectStore.schema.store_options[:option2]
  end

  # ------------------------------------------------------------------------

  def test_persons_name_sorting
    restore_store_snapshot("basic")
    # Test objects
    [
      [1, {:first => 'Apples', :last => 'Xen', :middle => 'U', :title => 'Mr', :suffix => 'PhD'}],
      [2, {:first => 'Yellow', :last => 'Fish', :middle => 'Q', :title => 'Ms', :suffix => 'MSc'}],
      [3, {:first => 'Hello', :last => 'There', :middle => 'Middling'}],
      # These two non-western cultures don't have changed sort order
      [4, {:culture => :western_list, :first => 'Balloon', :last => 'Went', :middle => 'Ping'}],
      [5, {:culture => :eastern, :first => 'Pppp', :last => 'CCC'}]
    ].each do |num, name|
      o = KObject.new()
      o.add_attr(O_TYPE_PERSON, A_TYPE)
      o.add_attr(KTextPersonName.new(name), A_TITLE)
      o.add_attr(num.to_s, A_NOTES)
      KObjectStore.create(o)
    end
    # Searching, default option set
    assert_equal [5,2,3,4,1], tpns_search
    # Change...
    KObjectStore.set_store_option(:ktextpersonname_western_sortas, 'first_last')
    run_all_jobs :expected_job_count => 1
    # Test
    assert_equal [1,5,3,4,2], tpns_search
    # Change back
    KObjectStore.set_store_option(:ktextpersonname_western_sortas, 'last_first')
    run_all_jobs :expected_job_count => 1
    # Test
    assert_equal [5,2,3,4,1], tpns_search

    # Check text has whitespace trimmed when storing sortas form in the database
    wst = KObject.new()
    wst.add_attr(O_TYPE_BOOK, A_TYPE)
    wst.add_attr(" Pants stuff   ", A_TITLE)
    KObjectStore.create(wst)
    wst_r = KApp.with_pg_database { |pg| pg.exec("SELECT sortas_title FROM #{KApp.db_schema_name}.os_objects WHERE id=#{wst.objref.obj_id}") }
    assert_equal 'pants stuff', wst_r.first.first
  end

  def tpns_search
    q = KObjectStore.query_and
    q.link(O_TYPE_PERSON, A_TYPE)
    q.execute(:all, :title).map { |o| o.first_attr(A_NOTES).to_s.to_i }
  end

  # ------------------------------------------------------------------------

  def test_type_filtered_queries
    restore_store_snapshot("basic")

    # Objects to create
    creations = [
      # type, quantity, quantity of this type and subtypes
      [O_TYPE_BOOK, 4, 4],
      [O_TYPE_PERSON, 2, 11], # has subtypes
      [O_TYPE_STAFF, 3, 3],
      [O_TYPE_PERSON_ASSOCIATE, 6, 6],
      [O_TYPE_FILE, 4, 16], # has subtypes
      [O_TYPE_PRESENTATION, 1, 1],
      [O_TYPE_FILE_BROCHURE, 3, 3],
      [O_TYPE_FILE_AUDIO, 8, 8]
    ]
    total_objs = 0; creations.each {|a,b,c| total_objs += b }
    filters = Array.new
    creations.each { |t,q,qs| filters << [[t],q,qs]}
    filters += [
      [[O_TYPE_BOOK, O_TYPE_PERSON], 6, 15],
      [[O_TYPE_FILE_BROCHURE, O_TYPE_PERSON_ASSOCIATE], 9, 9],
      # And with subtypes...
      [[O_TYPE_BOOK], 4, 4, [O_TYPE_BOOK], :with_subtypes],
      [[O_TYPE_PERSON], 11, 11, [O_TYPE_PERSON, O_TYPE_STAFF, O_TYPE_PERSON_ASSOCIATE], :with_subtypes],
      [[O_TYPE_FILE], 16, 16, [O_TYPE_FILE, O_TYPE_PRESENTATION, O_TYPE_FILE_BROCHURE, O_TYPE_FILE_AUDIO], :with_subtypes],
      [[O_TYPE_FILE_BROCHURE], 3, 3, [O_TYPE_FILE_BROCHURE], :with_subtypes],
      [[O_TYPE_FILE, O_TYPE_PERSON], 27, 27, [O_TYPE_FILE, O_TYPE_PRESENTATION, O_TYPE_FILE_BROCHURE, O_TYPE_FILE_AUDIO, O_TYPE_PERSON, O_TYPE_STAFF, O_TYPE_PERSON_ASSOCIATE], :with_subtypes]
    ]

    # Make test objects
    creations.each do |type,quantity,quantity_with_subtypes|
      quantity.times do |i|
        o = KObject.new()
        o.add_attr(type, A_TYPE)
        o.add_attr("#{type.to_presentation} #{i}", A_TITLE)
        o.add_attr('hellox', A_NOTES)
        KObjectStore.create(o)
      end
    end
    run_outstanding_text_indexing

    # Check the right number of objects appear
    assert_equal total_objs, KObjectStore.query_and.free_text('hellox').execute().length

    # Check queries - by a single type and multiple types, with subtypes and without
    filters.each do |types,quantity,quantity_with_subtypes,all_types_in_results,type_filter_kind|
      all_types_in_results ||= types
      r = KObjectStore.query_and.free_text('hellox').execute(:all, :any, {:type_filter => types, :type_filter_kind => type_filter_kind})
      assert_equal quantity, r.length
      # Check the type counts
      creations.each do |d,q|
        assert_equal q, r.type_counts[d]
      end
      # Check the objects are right
      h = Hash.new
      all_types_in_results.each do |type|
        x = creations.detect { |a,b| a == type }
        x[1].times { |i| h["#{type.to_presentation} #{i}"] = true }
      end
      r.each do |obj|
        t = obj.first_attr(A_TITLE).to_s
        assert h.has_key?(t)
        h.delete(t)
      end
      assert_equal 0, h.length

      # Try query using the types clause
      otq = KObjectStore.query_and.object_types(types).execute(:all, :any)
      assert_equal quantity_with_subtypes, otq.length
    end

  end

  # ------------------------------------------------------------------------

  def test_plugins_can_change_indexing
    restore_store_snapshot("basic")
    # Plugin which implements the hPreIndexObject hook
    assert KPlugin.install_plugin("k_object_store_test/change_indexing")
    Thread.current[:_change_indexing_plugin_calls] = 0

    count_linked_to = Proc.new do |type|
      KObjectStore.query_and.link(type, A_TYPE).execute().length
    end
    count_text_results = Proc.new do |text, desc|
      KObjectStore.query_and.free_text(text, desc).execute().length
    end

    book = KObject.new()
    book.add_attr(O_TYPE_BOOK, A_TYPE)
    book.add_attr("Hello Book", A_TITLE)
    book.add_attr("X1234Y", A_NOTES)
    KObjectStore.create(book)
    run_outstanding_text_indexing
    assert_equal 2, Thread.current[:_change_indexing_plugin_calls] # object write, another for text indexing

    assert_equal 1, count_linked_to.call(O_TYPE_BOOK)
    assert_equal 0, count_linked_to.call(O_TYPE_PERSON)
    assert_equal 1, count_text_results.call('X1234Y', A_NOTES)
    assert_equal 0, count_text_results.call('ZZZ1111', A_NOTES)

    Thread.current[:_change_indexing_plugin_change] = true
    book = book.dup
    book.add_attr("Subtitle", A_TITLE, Q_ALTERNATIVE)
    KObjectStore.update(book)
    run_outstanding_text_indexing
    assert_equal 4, Thread.current[:_change_indexing_plugin_calls]

    # Check expected version
    assert_equal 2, KObjectStore.read(book.objref).version

    assert_equal 1, count_linked_to.call(O_TYPE_BOOK)
    assert_equal 1, count_linked_to.call(O_TYPE_PERSON) # added by plugin
    assert_equal 0, count_text_results.call('X1234Y', A_NOTES) # removed
    assert_equal 1, count_text_results.call('ZZZ1111', A_NOTES) # added
    assert_equal 0, count_text_results.call('MMM8877', A_NOTES) # not added yet

    # Do a text reindex without an object update
    KObjectStore.reindex_text_for_object(book.objref)
    run_outstanding_text_indexing
    assert_equal 5, Thread.current[:_change_indexing_plugin_calls] # not 6, only called for text indexing
    assert_equal 0, count_text_results.call('ZZZ1111', A_NOTES) # not added
    assert_equal 1, count_text_results.call('MMM8877', A_NOTES) # now added

    # Schema objects can't be changed by plugins
    KObjectStore.update(KObjectStore.read(O_TYPE_BOOK).dup)
    run_outstanding_text_indexing
    assert_equal 5, Thread.current[:_change_indexing_plugin_calls]

    # Test reindexing the object
    assert_equal 1, count_linked_to.call(O_TYPE_BOOK)
    assert_equal 1, count_linked_to.call(O_TYPE_PERSON) # added by plugin
    KObjectStore.reindex_object(book.objref)
    run_outstanding_text_indexing
    # unchanged ...
    assert_equal 1, count_linked_to.call(O_TYPE_BOOK)
    assert_equal 1, count_linked_to.call(O_TYPE_PERSON) # added by plugin
    assert_equal 1, count_text_results.call('MMM8877', A_NOTES) # now added
    # ... until the plugin is removed
    KPlugin.uninstall_plugin("k_object_store_test/change_indexing")
    KObjectStore.reindex_object(book.objref)
    run_outstanding_text_indexing
    assert_equal 1, count_linked_to.call(O_TYPE_BOOK)
    assert_equal 0, count_linked_to.call(O_TYPE_PERSON) # previous added by plugin
    assert_equal 0, count_text_results.call('MMM8877', A_NOTES) # previous added by plugin

    # Object was never changed
    assert_equal 2, KObjectStore.read(book.objref).version

  ensure
    KPlugin.uninstall_plugin("k_object_store_test/change_indexing")
  end

  class ChangeIndexingPlugin < KTrustedPlugin
    _PluginName "Change Indexing Plugin"
    _PluginDescription "Test"
    def hPreIndexObject(result, object)
      Thread.current[:_change_indexing_plugin_calls] += 1
      if Thread.current[:_change_indexing_plugin_change]
        r = object.dup
        r.add_attr(KConstants::O_TYPE_PERSON, KConstants::A_TYPE)
        r.delete_attrs!(KConstants::A_NOTES)
        keyword = (Thread.current[:_change_indexing_plugin_calls] > 4) ? 'MMM8877' : "ZZZ1111"
        r.add_attr(keyword, KConstants::A_NOTES)
        result.replacementObject = r
      end
    end
  end

  # ------------------------------------------------------------------------

  def test_configured_behaviour_queries
    restore_store_snapshot("basic")
    refs = {}
    [
      [:foo,        'test:behaviour:foo',       nil],
      [:bar,        'test:behaviour:bar',       nil],
      [:foochild,   nil,                        :foo],
      [:foochild2,  nil,                        :foochild],
      [:foochild3,  'test:behaviour:foochild3', :foo],
      [:barchild,   'test:behaviour:barchild',  :bar],
      [:nothing,    nil,                        nil]
    ].each do |sym, behaviour, parent|
      o = KObject.new
      o.add_attr(sym.to_s, A_TITLE)
      o.add_attr(KIdentifierConfigurationName.new(behaviour), A_CONFIGURED_BEHAVIOUR) if behaviour
      o.add_attr(refs[parent], A_PARENT) if parent
      KObjectStore.create(o)
      refs[sym] = o.objref
    end
    assert_equal('test:behaviour:foo', KObjectStore.behaviour_of(refs[:foo]))
    assert_equal('test:behaviour:foo', KObjectStore.behaviour_of_exact(refs[:foo]))

    assert_equal('test:behaviour:foo', KObjectStore.behaviour_of(refs[:foochild]))
    assert_equal(nil, KObjectStore.behaviour_of_exact(refs[:foochild]))

    assert_equal('test:behaviour:foo', KObjectStore.behaviour_of(refs[:foochild2]))
    assert_equal(nil, KObjectStore.behaviour_of_exact(refs[:foochild2]))

    assert_equal('test:behaviour:foo', KObjectStore.behaviour_of(refs[:foochild3]))
    assert_equal('test:behaviour:foochild3', KObjectStore.behaviour_of_exact(refs[:foochild3]))

    assert_equal('test:behaviour:bar', KObjectStore.behaviour_of(refs[:bar]))
    assert_equal('test:behaviour:bar', KObjectStore.behaviour_of(refs[:bar]))

    assert_equal('test:behaviour:bar', KObjectStore.behaviour_of(refs[:barchild]))
    assert_equal('test:behaviour:barchild', KObjectStore.behaviour_of_exact(refs[:barchild]))

    assert_equal(nil, KObjectStore.behaviour_of(refs[:nothing]))
    assert_equal(nil, KObjectStore.behaviour_of_exact(refs[:nothing]))

    assert_equal(refs[:foo], KObjectStore.behaviour_ref('test:behaviour:foo'))
    assert_equal(refs[:bar], KObjectStore.behaviour_ref('test:behaviour:bar'))
    assert_equal(refs[:foochild3], KObjectStore.behaviour_ref('test:behaviour:foochild3'))
    assert_equal(nil, KObjectStore.behaviour_ref('test:behaviour:BAR'))
  end

end
