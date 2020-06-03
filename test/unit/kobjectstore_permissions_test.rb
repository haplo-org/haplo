# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KObjectStorePermissionsTest < Test::Unit::TestCase
  include KConstants

  A_LABEL_NAMES = 100
  A_ANOTHER_ATTR = 120
  A_X_ATTR = 150

  # Add each of ALLOW_CREATE1, ALLOW_READ2, DENY_READ2... to the class, with unique numeric values
  label_num = 10
  KPermissionRegistry.lookup.keys.each do |operation|
      operation_name = operation.to_s.upcase
      ["ALLOW", "DENY"].each do |permission|
          (1..2).each do |num|
              KObjectStorePermissionsTest.const_set("#{permission}_#{operation_name}#{num}", label_num)
              label_num +=1
          end
      end
  end

  def setup
    restore_store_snapshot("min")
    # Set up the default permissions
    @perms = KLabelStatementsOps.new
    @perms.statement(:create, KLabelList.new([ALLOW_CREATE1,ALLOW_CREATE2]), KLabelList.new([DENY_CREATE1,DENY_CREATE2]))
    @perms.statement(:read, KLabelList.new([ALLOW_READ1,ALLOW_READ2]), KLabelList.new([DENY_READ1,DENY_READ2]))
    @perms.statement(:update, KLabelList.new([ALLOW_UPDATE1,ALLOW_UPDATE2]), KLabelList.new([DENY_UPDATE1,DENY_UPDATE2]))
    @perms.statement(:relabel, KLabelList.new([ALLOW_RELABEL1,ALLOW_RELABEL2]), KLabelList.new([DENY_RELABEL1,DENY_RELABEL2]))
    @perms.statement(:delete, KLabelList.new([ALLOW_DELETE1,ALLOW_DELETE2]), KLabelList.new([DENY_DELETE1,DENY_DELETE2]))
    set_mock_objectstore_user(10, @perms)
  end

  # -----------------------------------------------------------------------------------------------------

  def test_cant_fake_store_object_labels
    with_new_obj([ALLOW_READ1,ALLOW_READ2]) do |obj|
      # Check permissions are working by re-reading object
      obj = KObjectStore.read(obj.objref).dup
      obj.__send__(:instance_variable_set, :@labels, KLabelList.new([ALLOW_CREATE1,ALLOW_READ1,ALLOW_RELABEL1,ALLOW_DELETE1]))
      assert_raises(KObjectStore::PermissionDenied) { KObjectStore.update(obj) }
      assert_raises(KObjectStore::PermissionDenied) { KObjectStore.delete(obj) }
      assert_raises(KObjectStore::PermissionDenied) { KObjectStore.relabel(obj, KLabelChanges.new([ALLOW_CREATE1], [])) }
    end
  end

  def test_create_permissions
    make_obj_with_labels([ALLOW_CREATE1], nil)
    make_obj_with_labels([ALLOW_CREATE2], nil)
    assert_raises(KObjectStore::PermissionDenied) { make_obj_with_labels([DENY_CREATE1], nil) }
    assert_raises(KObjectStore::PermissionDenied) { make_obj_with_labels([ALLOW_CREATE1,DENY_CREATE2], nil) }
    assert_raises(KObjectStore::PermissionDenied) { make_obj_with_labels([ALLOW_READ1,ALLOW_READ2], nil) }
    assert_raises(KObjectStore::PermissionDenied) { make_obj_with_labels([999], nil) } # 999 has no rule for it
    # But it's the labels *after* changes which have the effect
    ox = KObject.new([ALLOW_CREATE1,DENY_CREATE2])
    assert_raises(KObjectStore::PermissionDenied) { KObjectStore.create(ox) }
    # Remove the deny from the label list on save..
    KObjectStore.create(ox, KLabelChanges.new([],[DENY_CREATE2]))
  end

  def test_read_permissions
    with_new_obj([ALLOW_CREATE1,ALLOW_CREATE2]) do |obj|
      assert_raises(KObjectStore::PermissionDenied) { KObjectStore.read(obj.objref) }
    end

    with_new_obj([ALLOW_READ1]) do |obj|
      o = KObjectStore.read(obj.objref)
      assert_equal "x", o.first_attr(A_X_ATTR).to_s
    end

    with_new_obj([ALLOW_READ1,DENY_READ1]) do |obj|
      assert_raises(KObjectStore::PermissionDenied) { KObjectStore.read(obj.objref) }
      # But can suspend permission enforcement and get it
      with_superuser_permissions_return_value = KObjectStore.with_superuser_permissions do
        KObjectStore.read(obj.objref)
        :return_value_is_correct
      end
      assert_equal :return_value_is_correct, with_superuser_permissions_return_value
      # Enforced again
      assert_raises(KObjectStore::PermissionDenied) { KObjectStore.read(obj.objref) }
    end
  end

  def test_update_permissions
    with_new_obj([ALLOW_READ1,ALLOW_READ2]) do |obj|
      o = KObjectStore.read(obj.objref).dup
      o.add_attr("b", A_ANOTHER_ATTR)
      assert_raises(KObjectStore::PermissionDenied) { KObjectStore.update(o) }
    end
    with_new_obj([ALLOW_READ1,ALLOW_READ2,ALLOW_UPDATE1]) do |obj|
      obj.add_attr("c", A_ANOTHER_ATTR)
      KObjectStore.update(obj)
    end
    with_new_obj([ALLOW_UPDATE1]) do |obj|
      # But you only need :update
      obj.add_attr("d", A_ANOTHER_ATTR)
      KObjectStore.update(obj)
    end
  end

  def test_relabel_permissions
    with_new_obj([ALLOW_CREATE1]) do |obj|
      assert_raises(KObjectStore::PermissionDenied) { KObjectStore.relabel(obj, KLabelChanges.new([ALLOW_CREATE2],[])) }
      assert_raises(KObjectStore::PermissionDenied) { KObjectStore.relabel(obj.objref, KLabelChanges.new([ALLOW_CREATE2],[])) }
    end
    with_new_obj([ALLOW_CREATE1,ALLOW_RELABEL1]) do |obj|
      new_obj = KObjectStore.relabel(obj, KLabelChanges.new([ALLOW_CREATE2],[]))
      assert_equal [ALLOW_CREATE1,ALLOW_CREATE2,ALLOW_RELABEL1].sort, new_obj.labels._to_internal
      assert_equal [ALLOW_CREATE1,ALLOW_CREATE2,ALLOW_RELABEL1].sort, KObjectStore.labels_for_ref(obj.objref)._to_internal
    end
    with_new_obj([ALLOW_CREATE1,ALLOW_RELABEL1]) do |obj|
      # And again using obj rather than objref
      new_obj = KObjectStore.relabel(obj.objref, KLabelChanges.new([ALLOW_CREATE2],[]))
      assert_equal [ALLOW_CREATE1,ALLOW_CREATE2,ALLOW_RELABEL1].sort, new_obj.labels._to_internal
    end
    with_new_obj([ALLOW_CREATE1,ALLOW_RELABEL1]) do |obj|
      # Shortcut when changes empty
      new_obj = KObjectStore.relabel(obj, KLabelChanges.new([],[]))
      assert_equal [ALLOW_CREATE1,ALLOW_RELABEL1].sort, new_obj.labels._to_internal
    end
    with_new_obj([ALLOW_CREATE1]) do |obj|
      # Shortcut when changes empty still enforces permissions
      assert_raises(KObjectStore::PermissionDenied) { KObjectStore.relabel(obj, KLabelChanges.new([],[])) }
    end
    # Changes don't match :create labels
    with_new_obj([ALLOW_CREATE1,ALLOW_RELABEL1]) do |obj|
      assert_raises(KObjectStore::PermissionDenied) { KObjectStore.relabel(obj, KLabelChanges.new([DENY_CREATE1],[])) } # add a deny
    end
    with_new_obj([ALLOW_CREATE1,ALLOW_RELABEL1]) do |obj|
      assert_raises(KObjectStore::PermissionDenied) { KObjectStore.relabel(obj, KLabelChanges.new([],[ALLOW_CREATE1])) } # remove all the allows
    end
    # Can't fake the labels
    with_new_obj([ALLOW_READ1,ALLOW_READ2]) do |obj|
      obj.__send__(:instance_variable_set, :@labels, KLabelList.new([ALLOW_CREATE1,ALLOW_UPDATE1,ALLOW_RELABEL1,ALLOW_DELETE1]))
      assert_raises(KObjectStore::PermissionDenied) { KObjectStore.relabel(obj, KLabelChanges.new([ALLOW_CREATE1],[])) }
    end
  end

  def test_relabel_permissions_enforcement_on_update
    # Should act like an update followed by a re-label (only if labels have changed)
    with_new_obj([ALLOW_UPDATE1,ALLOW_UPDATE2]) do |obj|
      obj.add_attr("t", A_ANOTHER_ATTR)
      obj = KObjectStore.update(obj).dup
      obj.add_attr("u", A_ANOTHER_ATTR)

      assert_raises(KObjectStore::PermissionDenied) { KObjectStore.update(obj, KLabelChanges.new([ALLOW_CREATE1],[])) }
      assert_raises(KObjectStore::PermissionDenied) { KObjectStore.update(obj, KLabelChanges.new([],[ALLOW_UPDATE2])) }
      assert_raises(KObjectStore::PermissionDenied) { KObjectStore.update(obj, KLabelChanges.new([9999],[0])) }

      obj = KObjectStore.update(obj, KLabelChanges.new([],[])).dup
      obj = KObjectStore.update(obj, KLabelChanges.new([ALLOW_UPDATE1,ALLOW_UPDATE2],[])).dup
      # 10000 isn't in the label list, so removing it has no effect
      KObjectStore.update(obj, KLabelChanges.new([],[10000]))
    end
    with_new_obj([ALLOW_UPDATE1,ALLOW_RELABEL1]) do |obj|
      KObjectStore.update(obj, KLabelChanges.new([ALLOW_CREATE1],[]))
      assert_equal [ALLOW_CREATE1,ALLOW_UPDATE1,ALLOW_RELABEL1].sort, KObjectStore.labels_for_ref(obj.objref)._to_internal
    end
    with_new_obj([ALLOW_UPDATE1,ALLOW_RELABEL1]) do |obj|
      # User doesn't have :create on ALLOW_RELABEL 'label'
      assert_raises(KObjectStore::PermissionDenied) { KObjectStore.update(obj, KLabelChanges.new([ALLOW_RELABEL2],[])) }
    end
  end

  def test_deletes
    with_new_obj([ALLOW_CREATE1,ALLOW_READ1,ALLOW_UPDATE1]) do |obj|
      assert_raises(KObjectStore::PermissionDenied) { KObjectStore.delete(obj) }
    end
    with_new_obj([ALLOW_DELETE1]) do |obj|
      KObjectStore.delete(obj)
      obj = KObjectStore.with_superuser_permissions { KObjectStore.read obj.objref }
      assert obj.labels.include? O_LABEL_DELETED
      assert_equal [ALLOW_DELETE1, O_LABEL_DELETED.to_i].sort, obj.labels._to_internal
    end
  end

  def test_undelete
    with_new_obj([ALLOW_CREATE1,ALLOW_READ1,ALLOW_UPDATE1]) do |obj|
      KObjectStore.with_superuser_permissions { KObjectStore.delete(obj) }
      obj = KObjectStore.read obj.objref
      assert_raises(KObjectStore::PermissionDenied) { KObjectStore.undelete(obj) }
      KObjectStore.with_superuser_permissions { KObjectStore.undelete(obj) }
      obj = KObjectStore.read obj.objref
      assert !obj.labels.include?(O_LABEL_DELETED)
    end
    with_new_obj([ALLOW_DELETE1]) do |obj|
      KObjectStore.delete obj
      obj = KObjectStore.with_superuser_permissions { KObjectStore.read obj.objref }
      KObjectStore.undelete obj
      obj = KObjectStore.with_superuser_permissions { KObjectStore.read obj.objref }
      assert !obj.labels.include?(O_LABEL_DELETED)
      assert_equal [ALLOW_DELETE1], obj.labels._to_internal
    end
  end

  def test_object_history_respects_corrent_permissions
    obj = KObjectStore.with_superuser_permissions do
      obj = make_obj_with_labels([ALLOW_CREATE1,ALLOW_CREATE2,ALLOW_READ1,ALLOW_UPDATE1], nil).dup
      obj = KObjectStore.update(obj, KLabelChanges.new([], [ALLOW_CREATE1,ALLOW_READ1])).dup # Remove CREATE1 and READ1
      obj = KObjectStore.update(obj, KLabelChanges.new([ALLOW_READ1,999], [])).dup # Add back READ1 & a special label
      obj
    end
    obj_history = KObjectStore.history(obj.objref)
    assert_equal 1, obj_history.versions.length # have two old versions, but can only see one
    assert_equal [ALLOW_CREATE1,ALLOW_CREATE2,ALLOW_READ1,ALLOW_UPDATE1].sort, obj_history.versions.first.object.labels._to_internal
    assert_equal [ALLOW_CREATE2,ALLOW_READ1,ALLOW_UPDATE1,999].sort, obj_history.object.labels._to_internal
    # And via explicit reads
    assert 3, obj.version
    assert KObjectStore.read_version(obj.objref, 3).kind_of?(KObject)
    assert_raises(KObjectStore::PermissionDenied) { KObjectStore.read_version(obj.objref, 2) }
    assert KObjectStore.read_version(obj.objref, 1).kind_of?(KObject)
    # Fake updated times in database and check with read at time
    KApp.with_pg_database { |db| db.perform "UPDATE #{KApp.db_schema_name}.os_objects_old SET updated_at=NOW() - (interval '1 day' * (3-version) * 2) WHERE id=#{obj.objref.to_i}" }
    assert KObjectStore.read_version_at_time(obj.objref, Time.now).kind_of?(KObject)
    assert_raises(KObjectStore::PermissionDenied) { KObjectStore.read_version_at_time(obj.objref, Time.now - 1) }
    assert KObjectStore.read_version_at_time(obj.objref, Time.now - (3*KFramework::SECONDS_IN_DAY)).kind_of?(KObject)
    # Check that history can't be read if user can't read latest version
    no_read_perms = KLabelStatementsOps.new
    no_read_perms.statement(:read, KLabelList.new([ALLOW_READ1,ALLOW_READ2]), KLabelList.new([DENY_READ1,DENY_READ2,999]))
    set_mock_objectstore_user(10, no_read_perms)
    assert_raises(KObjectStore::PermissionDenied) { KObjectStore.read(obj.objref) }
    assert_raises(KObjectStore::PermissionDenied) { KObjectStore.history(obj.objref) }
    assert_raises(KObjectStore::PermissionDenied) { KObjectStore.read_version(obj.objref, 1) }
    assert_raises(KObjectStore::PermissionDenied) { KObjectStore.read_version_at_time(obj.objref, Time.now - (3*KFramework::SECONDS_IN_DAY)) }
  end

  def test_searching
    KObjectStore.with_superuser_permissions do
      make_obj_with_labels([100,200], "a")
      make_obj_with_labels([200,300], "b")
      make_obj_with_labels([200,300,400], "c")
      make_obj_with_labels([200,300,500], "d")
      make_obj_with_labels([600], "e")
    end
    # And index them
    run_outstanding_text_indexing

    # Check all looks good without permissions
    check_search(["a","b","c","d","e"], Proc.new {})
    check_search([    "b","c","d","e"], Proc.new { |query| query.add_exclude_labels([100]) })
    check_search([        "c"        ], Proc.new { |query| query.add_label_constraints([200,400]) })

    # Apply permissions
    @perms = KLabelStatementsOps.new
    @perms.statement(:read, KLabelList.new([200,300]), KLabelList.new([400]))
    set_mock_objectstore_user(19, @perms)

    # And again with the permissions applied - finds a few less
    check_search(["a","b","d"], Proc.new {})

    # And add an additional label filter
    check_search(["b","d"], Proc.new { |query| query.add_exclude_labels([100]) })

    # Check superuser permissions
    set_mock_objectstore_user(19, KLabelStatements.super_user)
    check_search(["a","b","c","d","e"], Proc.new {})
    assert_equal 19, KObjectStore.external_user_id
  end

  # -----------------------------------------------------------------------------------------------------

  def test_plugin_permissions_hook
    Thread.current[:test_plugin_permissions_hook__hook_calls] = []
    AuthContext.with_system_user do # to prevent delegate trying to update the mock object
      assert KPlugin.install_plugin("k_object_store_permissions_test/permissions_hook")
    end
    begin
      # Default permissions will allow all these operations, so the plugin hook won't be called
      obj1 = make_obj_with_labels([ALLOW_READ1,ALLOW_CREATE2,ALLOW_UPDATE1], "a")
      assert_permhook_was_not_called

      KObjectStore.read(obj1.objref)
      assert_permhook_was_not_called

      KObjectStore.update(obj1.dup)
      assert_permhook_was_not_called

      # Try something with a deny
      obj2 = make_obj_with_labels([DENY_READ1,ALLOW_CREATE1,DENY_UPDATE1,DENY_DELETE1], "b")

      assert_raises(KObjectStore::PermissionDenied) { KObjectStore.read(obj2.objref) }
      hook_user, hook_object, hook_operation = permhook_pop_args
      assert_equal 10, hook_user.id
      assert_equal :read, hook_operation
      assert_equal obj2.objref, hook_object.objref

      assert_raises(KObjectStore::PermissionDenied) { KObjectStore.update(obj2.dup) }
      hook_user, hook_object, hook_operation = permhook_pop_args
      assert_equal :update, hook_operation

      assert_raises(KObjectStore::PermissionDenied) { make_obj_with_labels([DENY_CREATE1], "c") }
      hook_user, hook_object, hook_operation = permhook_pop_args
      assert_equal :create, hook_operation

      permhook_with_allow do
        make_obj_with_labels([DENY_CREATE1], "c")
        hook_user, hook_object, hook_operation = permhook_pop_args
        assert_equal :create, hook_operation
      end

    ensure
      Thread.current[:test_plugin_permissions_hook__hook_calls] = nil
      AuthContext.with_system_user { KPlugin.uninstall_plugin("k_object_store_permissions_test/permissions_hook") }
    end
  end

  class PermissionsHookPlugin < KTrustedPlugin
    _PluginName "Permissions Hook Test Plugin"
    _PluginDescription "Test"
    def hOperationAllowOnObject(response, user, object, operation)
      Thread.current[:test_plugin_permissions_hook__hook_calls].push([user, object, operation])
      if Thread.current[:test_plugin_permissions_hook__should_allow]
        response.allow = true
      end
    end
  end

  # Test helper functions
  def permhook_with_allow
    begin; Thread.current[:test_plugin_permissions_hook__should_allow] = true
      yield
    ensure; Thread.current[:test_plugin_permissions_hook__should_allow] = nil; end
  end
  def permhook_pop_args
    assert_equal 1, Thread.current[:test_plugin_permissions_hook__hook_calls].length
    Thread.current[:test_plugin_permissions_hook__hook_calls].pop
  end
  def assert_permhook_was_not_called
    assert_equal 0, Thread.current[:test_plugin_permissions_hook__hook_calls].length
  end

  # -----------------------------------------------------------------------------------------------------
  # Helper functions

  def make_obj_with_labels(labels, name)
    obj = KObject.new(labels)
    obj.add_attr(labels.map { |l| "xyz label#{l}" } .join(' '), A_LABEL_NAMES)
    obj.add_attr(name, A_X_ATTR) if name
    KObjectStore.create(obj)
  end

  def with_new_obj(labels)
    obj = KObjectStore.with_superuser_permissions { make_obj_with_labels(labels, "x") }
    yield obj.dup
    KObjectStore.with_superuser_permissions { KObjectStore.erase(obj.objref) }
  end

  def check_search(expected, alter_query)
    query = KObjectStore.query_and.free_text('xyz')
    alter_query.call(query)
    results = query.execute(:all, :title).map { |o| o.first_attr(A_X_ATTR).to_s } .sort
    assert_equal expected, results
  end

end