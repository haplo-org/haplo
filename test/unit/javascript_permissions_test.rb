# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavascriptPermissionsTest < Test::Unit::TestCase
  include JavaScriptTestHelper

  def test_common_labelling
    restore_store_snapshot("basic")
    db_reset_test_data

    user1 = 41 # group1
    user2 = 42 # group2
    user3 = 43 # group3 > group1, group2.  ADMINISTRATORS
    group1 = 21
    group2 = 22
    group3 = 23

    PermissionRule.new_rule! :deny, User::GROUP_EVERYONE, KConstants::O_LABEL_COMMON, :create, :read, :update, :delete
    PermissionRule.new_rule! :allow, group1, KConstants::O_LABEL_COMMON, :read
    PermissionRule.new_rule! :reset, group2, KConstants::O_LABEL_COMMON, :read
    PermissionRule.new_rule! :allow, group2, KConstants::O_LABEL_COMMON, :delete
    PermissionRule.new_rule! :allow, user2, KConstants::O_LABEL_COMMON, :create
    PermissionRule.new_rule! :deny, user2, KConstants::O_LABEL_COMMON, :read

    book = KObject.new()
    book.add_attr(KConstants::O_TYPE_BOOK, KConstants::A_TYPE)
    with_user(user1) do
      assert_raise_js(/^Operation create not permitted for object [0-9qv-z]+ with labels \[7551\]$/) do
        JSKObjectSupport.createObject(book)
      end
    end

    with_user(user2) do
      JSKObjectSupport.createObject(book)
    end

    with_user(user2) do
      assert_raise_js(/^Operation read not permitted for object [0-9qv-z]+ with labels \[7551\]$/) do
        JSKObjectSupport.readObject(book.objref)
      end
    end

    with_user(user1) do
      new_book = JSKObjectSupport.readObject(book.objref).dup
      assert_equal book.objref, new_book.objref
      new_book.add_attr("Foo", A_TITLE)
      assert_raise_js(/^Operation update not permitted for object [0-9qv-z]+ with labels \[7551\]$/) do
        JSKObjectSupport.updateObject(new_book)
      end
    end

    PermissionRule.new_rule! :allow, user1, KConstants::O_LABEL_COMMON, :update

    with_user(user1) do
      book = book.dup
      book.add_attr("Foo", A_TITLE)
      JSKObjectSupport.updateObject(book)
    end

    with_user(user1) do
      assert_raise_js(/^Operation delete not permitted for object [0-9qv-z]+ with labels \[7551\]$/) do
        JSKObjectSupport.deleteObject(book)
      end
    end

    with_user(user3) do
      JSKObjectSupport.deleteObject(book)
    end

    PermissionRule.delete_all
  end

  def test_setup_group_and_group_permissions
    restore_store_snapshot("basic")
    db_reset_test_data
    install_grant_privileges_plugin_with_privileges('pSetupSystem')
    begin
      # Set up some interesting permissions for checking
      PermissionRule.new_rule! :reset, 22, KConstants::O_LABEL_COMMON, :create
      PermissionRule.new_rule! :allow, 42, KConstants::O_LABEL_COMMON, :read
      PermissionRule.new_rule! :deny, 41, KConstants::O_LABEL_COMMON, :read

      # Testing that the javascript can create this group, so check it doesn't already exist
      assert User.where(:name => 'Test group').length == 0

      run_javascript_test(:file, 'unit/javascript/javascript_permissions/test_setup_group.js')

      # Check group created properly
      groups = User.where(:name => 'Test group')
      assert_equal 1, groups.length
      assert_equal User::KIND_GROUP, groups.first.kind
      assert_equal 'Test group', groups.first.name
      # Check group memberships
      assert_equal [16,21], groups.first.direct_groups_ids.sort
      # Invalidate all cached users to be sure
      User.invalidate_cached

      all_perms_ob = create_self_labelled_object
      read_only_ob = create_self_labelled_object
      editable_only_ob = create_self_labelled_object

      PermissionRule.new_rule! :allow, groups.first, all_perms_ob.objref, *KPermissionRegistry.lookup.keys
      PermissionRule.new_rule! :allow, groups.first, read_only_ob.objref, :read
      PermissionRule.new_rule! :allow, groups.first, editable_only_ob.objref, :create, :update

      # Run another javascript test to check it's got in the SCHEMA constants (ie was invalidated)
      run_javascript_test(:file, 'unit/javascript/javascript_permissions/test_setup_group2.js', {
        'GROUP_ID' => groups.first.id,
        'ALL_PERMS_REF' => all_perms_ob.objref.to_s,
        'READ_ONLY_REF' => read_only_ob.objref.to_s,
        'EDITABLE_ONLY_REF' => editable_only_ob.objref.to_s,
      })
    ensure
      uninstall_grant_privileges_plugin
    end
  end

  def assert_raise_js(message_re)
    begin
      yield
    rescue RuntimeError => e
      message, bt = PluginDebugging::ErrorReporter.presentable_exception e
      assert_not_nil message_re =~ message, "Exception raised, but message did not match expected: #{message}"
    else
      assert false, "Expected exception, but no exception raised."
    end
  end

  def create_self_labelled_object
    new_ob = KObject.new
    new_ob.add_attr(KConstants::O_TYPE_BOOK, KConstants::A_TYPE)
    KObjectStore.create new_ob
    KObjectStore.relabel(new_ob, KLabelChanges.new([new_ob.objref.obj_id], [KConstants::O_LABEL_COMMON]))
    new_ob
  end

  def with_user(uid)
    old_state = AuthContext.set_user(User.cache[uid], User.cache[uid])
    begin
      yield
    ensure
      AuthContext.restore_state old_state
    end
  end

end