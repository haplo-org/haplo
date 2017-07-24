# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class UserTest < Test::Unit::TestCase

  def setup
    db_reset_test_data
  end
  def teardown
    ApiKey.destroy_all
  end

  # --------------------------------------------------------------------------------

  def test_user_basics
    user42 = User.find(42)
    assert_equal [4,22], user42.groups_ids.sort
    assert user42.groups_ids.frozen?
    assert_equal user42.groups_ids.object_id, user42.groups_ids.object_id # is cached

    group22 = User.find(22)
    assert_equal [23], group22.member_group_ids.sort
    assert group22.member_group_ids.frozen?
    assert_equal group22.member_group_ids.object_id, group22.member_group_ids.object_id # is cached
  end

  # --------------------------------------------------------------------------------

  def test_user_name_whitespace_stripping
    # User
    user0 = User.new(:name_first => '  Hello   Ping   ', :name_last => '   Carrots   Stuff   ', :email => 'example@example.com')
    user0.kind = User::KIND_USER
    user0.set_invalid_password
    user0.save!
    user0reload = User.find(user0.id)
    assert_equal "Hello Ping", user0reload.name_first
    assert_equal "Carrots Stuff", user0reload.name_last
    assert_equal "Hello Ping Carrots Stuff", user0reload.name
    # Group
    group0 = User.new(:name => "   Nice\tGroup   ")
    group0.kind = User::KIND_GROUP
    group0.save!
    group0reload = User.find(group0.id)
    assert_equal "Nice Group", group0reload.name
  end

  # --------------------------------------------------------------------------------

  def test_user_objref
    user42 = User.find(42)
    assert_equal nil, user42.objref
    user42.objref = O_TYPE_PERSON
    user42.save!

    user43 = User.find(43)
    user43.objref = O_TYPE_BOOK
    user43.save!

    assert_equal 42, User.find_active_user_by_objref(O_TYPE_PERSON).id

    user42.kind = User::KIND_USER_BLOCKED
    user42.save!

    assert_equal nil, User.find_active_user_by_objref(O_TYPE_PERSON)
  end

  # --------------------------------------------------------------------------------

  def test_recovery_tokens
    user0 = User.new(:name_first => 'A', :name_last => 'B', :email => 't@example.com')
    user0.kind = User::KIND_USER
    user0.set_invalid_password
    user0.save!

    welcome = user0.generate_recovery_urlpath(:welcome)
    assert welcome =~ /\A\/do\/authentication\/welcome\/((\d+)-\d+-12-[a-f0-9]+)\z/ # 12 = NEW_USER_WELCOME_LINK_VALIDITY
    welcome_token = $1; uid = $2.to_i
    assert_equal user0.id, uid
    assert_equal user0.id, User.get_user_for_recovery_token(welcome_token).id
    assert user0.recovery_token =~ /\A\$/ # bcrypt
    assert user0.recovery_token != welcome_token

    recovery = user0.generate_recovery_urlpath()
    assert recovery =~ /\A\/do\/authentication\/r\/((\d+)-\d+-1-[a-f0-9]+)\z/ # 1 = RECOVERY_VALIDITY_TIME
    recovery_token = $1; uid = $2.to_i
    assert_equal user0.id, uid
    assert_equal user0.id, User.get_user_for_recovery_token(recovery_token).id

    # Old one is no longer valid
    assert_equal nil, User.get_user_for_recovery_token(welcome_token)

    # Change UID in token
    user44 = User.find(44)
    assert nil != user44 && user0.id != user44.id
    assert_equal nil, user44.recovery_token
    changed_uid_token = recovery_token.gsub(/\A\d+/,'44')
    assert_equal nil, User.get_user_for_recovery_token(changed_uid_token)
    assert_equal user0.id, User.get_user_for_recovery_token(recovery_token).id
    user44.generate_recovery_urlpath()
    assert_equal nil, User.get_user_for_recovery_token(changed_uid_token)
    assert_equal user0.id, User.get_user_for_recovery_token(recovery_token).id

    # Time based checks
    [
      [-100, true], # first check a reasonable one does work, to check this test
      [0-(10+(60*60*24)), false], # too long in the past
      [100, false]  # start time the future
    ].each do |diff, should_work|
      user0.generate_recovery_urlpath(:r, Time.now.to_i + diff) =~ /\/r\/(.+?)\z/
      token = $1
      if should_work
        assert user0.id, User.get_user_for_recovery_token(token).id
      else
        assert_equal nil, User.get_user_for_recovery_token(token)
      end
    end
  end

  # --------------------------------------------------------------------------------

  def test_user_change_auditing
    about_to_create_an_audit_entry
    # Create user
    user0 = User.new(:name_first => 'Hello', :name_last => 'There', :email => 'hello@example.com')
    user0.kind = User::KIND_USER
    user0.set_invalid_password
    user0.save!
    user0.generate_recovery_urlpath()
    assert_audit_entry(:kind => 'USER-NEW', :entity_id => user0.id, :data => {"name_first" => 'Hello', "name_last" => 'There', "email" => 'hello@example.com'})
    # Set group membership
    user0.set_groups_from_ids([21,22])
    assert_audit_entry(:kind => 'GROUP-MEMBERSHIP', :entity_id => user0.id, :data => {"groups" => [21,22]})
    assert_equal [21,22], user0.direct_groups_ids.sort
    # Check group memberships is de-duplicated
    user0.set_groups_from_ids([22,22])
    assert_audit_entry(:kind => 'GROUP-MEMBERSHIP', :entity_id => user0.id, :data => {"groups" => [22]})
    assert_equal [22], user0.direct_groups_ids.sort
    # Create a password and blank the recovery token, like welcome / recovery
    user0.password = "ping2376@!"
    user0.recovery_token = nil
    user0.save!
    assert_audit_entry(:kind => 'USER-SET-PASS', :entity_id => user0.id, :data => nil)
    # Change the password
    user0.password = "ping2376@!2"
    user0.save!
    assert_audit_entry(:kind => 'USER-CHANGE-PASS', :entity_id => user0.id, :data => nil)
    # Change the ref
    user0.objref = KObjRef.from_presentation('12345')
    user0.save!
    assert_audit_entry(:kind => 'USER-REF', :entity_id => user0.id, :data => {"ref" => "12345"})
    user0.objref = nil
    user0.save!
    assert_audit_entry(:kind => 'USER-REF', :entity_id => user0.id, :data => {"ref" => nil})
    # Set OTP token
    user0.otp_identifier = "0123456789"
    user0.save!
    assert_audit_entry(:kind => 'USER-OTP-TOKEN', :entity_id => user0.id, :data => {"identifier" => "0123456789"})
    # Unset OTP token
    user0.otp_identifier = nil
    user0.save!
    assert_audit_entry(:kind => 'USER-OTP-TOKEN', :entity_id => user0.id, :data => {"identifier" => nil})
    # Block, enable, disable, etc
    [
      [User::KIND_USER_BLOCKED, 'USER-BLOCK'],
      [User::KIND_USER_DELETED, 'USER-DELETE'],
      [User::KIND_USER, 'USER-ENABLE']
    ].each do |user_kind, audit_kind|
      user0.kind = user_kind
      user0.save!
      assert_audit_entry(:kind => audit_kind, :entity_id => user0.id)
    end
    # Change attributes
    user0.name_last = 'Elsewhere'
    user0.save!
    assert_audit_entry(:kind => 'USER-MODIFY', :entity_id => user0.id, :data => {"name_last" => 'Elsewhere', "old" => {"name_last" => "There"}})
    user0.name_first = 'Ping'
    user0.email = "ping11@example.com"
    user0.save!
    assert_audit_entry(:kind => 'USER-MODIFY', :entity_id => user0.id,
        :data => {"name_first" => 'Ping', "email" => 'ping11@example.com', "old" => {"name_first" => "Hello", "email" => 'hello@example.com'}})

    # API key
    api_key = ApiKey.new(:user => user0, :path => '/api/test', :name => 'Test key')
    api_key.set_random_api_key
    api_key.save!
    assert_audit_entry(:kind => 'USER-API-KEY-NEW', :displayable => false, :entity_id => user0.id,
        :data => {"key_id" => api_key.id, "path" => "/api/test", "name" => "Test key"})
    # Simulate a couple of views
    2.times { KNotificationCentre.notify(:user_api_key, :view, api_key) }
    assert_audit_entry(:kind => 'USER-API-KEY-VIEW', :displayable => false, :entity_id => user0.id, :data => {"key_id" => api_key.id})
    # Delete
    api_key.destroy
    assert_audit_entry(:kind => 'USER-API-KEY-DELETE', :displayable => false, :entity_id => user0.id,
        :data => {"key_id" => api_key.id, "path" => "/api/test", "name" => "Test key"})

    # Policies
    Policy.transaction do
      Policy.new(:user_id => user0.id, :perms_allow => 1, :perms_deny => 2).save!
      Policy.new(:user_id => 21, :perms_allow => 8, :perms_deny => 16).save!
    end
    # Check entries only written after notification buffers flushed
    assert_no_more_audit_entries_written
    KNotificationCentre.send_buffered_then_end_on_thread
    KNotificationCentre.start_on_thread
    assert_audit_entry(
      {:kind => 'POLICY-CHANGE', :entity_id => user0.id, :data => {"allow" => 1, "deny" => 2}},
      {:kind => 'POLICY-CHANGE', :entity_id => 21, :data => {"allow" => 8, "deny" => 16}}
    )

    # Permission rules
    PermissionRule.transaction do
      r0 = PermissionRule.new(:user_id => user0.id, :label_id => 786, :statement => 0, :permissions => 176)
      r0.save!
      r0.destroy
      PermissionRule.new(:user_id => user0.id, :label_id => 786, :statement => 1, :permissions => 123).save!
      PermissionRule.new(:user_id => user0.id, :label_id => 182, :statement => 2, :permissions => 928).save!
      PermissionRule.new(:user_id => 21, :label_id => 198, :statement => 0, :permissions => 176).save!
    end
    assert_no_more_audit_entries_written
    KNotificationCentre.send_buffered_then_end_on_thread
    KNotificationCentre.start_on_thread
    assert_audit_entry(
      {:kind => 'PERMISSION-RULE-CHANGE', :entity_id => user0.id, :data => {"rules" => [[182,2,928],[786,1,123]]}},
      {:kind => 'PERMISSION-RULE-CHANGE', :entity_id => 21, :data => {"rules" => [[198,0,176]]}}
    )

    # Create group
    group0 = User.new(:name => "Nice Group")
    group0.kind = User::KIND_GROUP
    group0.save!
    assert_audit_entry(:kind => 'GROUP-NEW', :entity_id => group0.id, :data => {"name" => "Nice Group"})
    [
      [User::KIND_GROUP_DISABLED, 'GROUP-DISABLE'],
      [User::KIND_GROUP, 'GROUP-ENABLE']
    ].each do |group_kind, audit_kind|
      group0.kind = group_kind
      group0.save!
      assert_audit_entry(:kind => audit_kind, :entity_id => group0.id)
    end
    # Members
    group0.update_members!([41,42,43])
    assert_audit_entry(:kind => 'GROUP-MEMBERSHIP', :entity_id => group0.id, :data => {"members" => [41,42,43]})
    # Change name
    group0.name = 'New Name'
    group0.save!
    assert_audit_entry(:kind => 'GROUP-MODIFY', :entity_id => group0.id, :data => {"name" => "New Name", "old" => {"name" => 'Nice Group'}})
  end

  # --------------------------------------------------------------------------------

  class PluginUseStoreInsidePermHooksTestPlugin < KTrustedPlugin
    _PluginName "Plugin Use Store Inside Perm Hooks Test"
    _PluginDescription "Test"
    def check_states
      raise "Not locked" unless AuthContext.state.locked
      raise "Bad user" unless KObjectStore.external_user_id == 0
      raise "Bad permissions" unless KObjectStore.user_permissions.permissions.kind_of?(KLabelStatementsSuperUser)
    end
    def hUserPermissionRules(response, user)
      check_states()
      response.rules = {"rules"=>[]}
    end
    def hUserLabelStatements(response, user)
      check_states()
      # Just do any store operation which attempts to use permissions
      KObjectStore.query_and.link(KConstants::O_TYPE_BOOK,KConstants::A_TYPE).execute()
      Thread.current[:_test_store_delays_permission_calcs_hook_called] += 1
      # Try to change the context?
      if Thread.current[:_test_store_delays_permission_calcs_try_auth_context_change]
        AuthContext.with_user(User.cache[41]) {}
      end
    end
  end

  def test_store_delays_permission_calcs
    db_reset_test_data
    begin
      assert KPlugin.install_plugin("user_test/plugin_use_store_inside_perm_hooks_test")

      # Check it's OK to do a store query inside a hook which calculates permissions, making sure
      # that superuser is set, and the store delays calculating permissions until it actually needs
      # to use them.
      Thread.current[:_test_store_delays_permission_calcs_hook_called] = 0
      User.invalidate_cached
      AuthContext.with_user(User.cache[41]) do
        # No users calculated yet
        assert_equal 0, Thread.current[:_test_store_delays_permission_calcs_hook_called]
        User.cache[43].permissions
        # Getting the permissions triggered calculations
        assert_equal 1, Thread.current[:_test_store_delays_permission_calcs_hook_called]
        AuthContext.with_user(User.cache[42]) do
          assert_equal 1, Thread.current[:_test_store_delays_permission_calcs_hook_called]
          KObjectStore.query_and.link(KConstants::O_TYPE_BOOK,KConstants::A_TYPE).execute()
          assert_equal 2, Thread.current[:_test_store_delays_permission_calcs_hook_called]
        end
      end
      assert_equal 2, Thread.current[:_test_store_delays_permission_calcs_hook_called]

      # Check that the user can't be changed inside the hook
      User.invalidate_cached
      Thread.current[:_test_store_delays_permission_calcs_try_auth_context_change] = true
      assert_raises(JavaScriptAPIError) do
        User.cache[42].permissions
      end

    ensure
      KPlugin.uninstall_plugin("user_test/plugin_use_store_inside_perm_hooks_test")
    end
  end

end
