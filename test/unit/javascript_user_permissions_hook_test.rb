# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavascriptUserPermissionsHookTest < Test::Unit::TestCase
  include JavaScriptTestHelper
  include KPlugin::HookSite

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_user_permissions_hook/test_user_permissions_plugin")

  def setup
    db_reset_test_data
    KPlugin.install_plugin("test_user_permissions_plugin")
    PermissionRule.delete_all
  end

  def teardown
    KPlugin.uninstall_plugin("test_user_permissions_plugin")
  end

  # -------------------------------------------------------------------------------------------------------------

  def test_hook_presence_doesnt_affect_permissions
    make_user "unchanged" do |user|
      rule = PermissionRule.new_rule! :allow, user, O_LABEL_COMMON, *KPermissionRegistry.lookup.keys
      assert_equal [O_LABEL_COMMON], user.permissions._internal_states[0][:create]
      rules = PermissionRule.find :all
      assert_equal 1, rules.length
      assert_equal rule.attributes, rules[0].attributes
    end
  end

  def test_adding_rule
    make_user "deny-common" do |user|
      rules = (call_hook(:hUserPermissionRules) { |hooks| hooks.run(user); }).rules["rules"]
      assert_equal 1, rules.length
      plugin_name, label, rule_type, bitmask = rules[0]
      assert_equal "test_user_permissions_plugin", plugin_name
      assert_equal O_LABEL_COMMON, label
      assert_equal PermissionRule::DENY, rule_type
      assert_equal bitmask, KPermissionRegistry.to_bitmask(*KPermissionRegistry.lookup.keys)
    end
  end

  def test_adding_multiple
    make_user "rcommon-cubook" do |user|
      rules = (call_hook(:hUserPermissionRules) { |hooks| hooks.run(user); }).rules["rules"]
      assert_equal 2, rules.length
      assert_equal([
        ["test_user_permissions_plugin", O_LABEL_COMMON, PermissionRule::ALLOW, KPermissionRegistry.to_bitmask(:read) ],
        ["test_user_permissions_plugin", O_TYPE_BOOK, PermissionRule::ALLOW, KPermissionRegistry.to_bitmask(:create, :update)  ],
        ], rules)
    end
  end

  def test_user_permissions_include_rules
    assert_equal 0, PermissionRule.find(:all).length
    make_user "deny-common" do |user|
      assert_equal 0, PermissionRule.find(:all).length # Check the plugin rules aren't being persisted
      assert_permissions(
        :user => user,
        :allow => {},
        :deny => all_operations(O_LABEL_COMMON)
      )
    end
  end

  def test_conflicting
    make_user "conflicting" do |user|
      rules = (call_hook(:hUserPermissionRules) { |hooks| hooks.run(user); }).rules["rules"]
      assert_permissions(
        :user => user,
        :allow => {:delete => [O_LABEL_COMMON]},
        :deny => {:read => [O_LABEL_COMMON], :create => [O_LABEL_COMMON]}
      )
    end
  end

  def test_plugin_overrides_other_rules
    make_user "rcommon-cubook" do |user|
      PermissionRule.new_rule! :deny, user, O_LABEL_COMMON, *KPermissionRegistry.lookup.keys
      PermissionRule.new_rule! :deny, User::GROUP_EVERYONE, O_TYPE_BOOK, :update, :read
      assert_permissions(
        :user => user,
        :allow =>{:read=>[O_LABEL_COMMON], :create=>[O_TYPE_BOOK], :update=>[O_TYPE_BOOK], :delete=>[], :approve=>[]},
        :deny => {:read=>[O_TYPE_BOOK], :create=>[O_LABEL_COMMON], :update=>[O_LABEL_COMMON], :relabel=>[O_LABEL_COMMON], :delete=>[O_LABEL_COMMON], :approve=>[O_LABEL_COMMON]}
      )
    end
  end

  def test_bad_rules
    (1..8).each do |user_num|
      make_user "bad-#{user_num}" do |user|
        assert_raise JavaScriptAPIError, Java::OrgMozillaJavascript::JavaScriptException, "bad-#{user_num}" do
          user.permissions
        end
      end
    end
  end

  def test_cache_invalidation
    laptop = KObject.new
    laptop.add_attr O_TYPE_LAPTOP, A_TYPE
    laptop.add_attr "DENY", A_TITLE
    laptop = KObjectStore.create(laptop).dup

    make_user "laptop-title" do |user|
      # Laptop has DENY, so deny all common
      assert_permissions(:user => user, :allow => {}, :deny => all_operations(O_LABEL_COMMON))

      laptop.delete_attrs! A_TITLE
      laptop.add_attr "ALLOW", A_TITLE
      laptop = KObjectStore.update(laptop).dup

      # Object updated, but user permissions still cached...
      assert_permissions(:user => user, :allow => {}, :deny => all_operations(O_LABEL_COMMON))

      User.invalidate_cached

      assert_permissions(:user => user, :allow => all_operations(O_LABEL_COMMON), :deny => {})

      laptop.delete_attrs! A_TITLE
      laptop.add_attr "DENY", A_TITLE
      KObjectStore.update laptop

      assert_permissions(:user => user, :allow => all_operations(O_LABEL_COMMON), :deny => {})
      # Test that the javascript reloadUserPermissions does the same thing
      run_javascript_test(:inline, 'TEST(function() { O.reloadUserPermissions(); });')
      assert_permissions(:user => user, :allow => {}, :deny => all_operations(O_LABEL_COMMON))
    end
  end

  def test_with_empty_cache
    # Impersonation inside hUserPermissionRules and hUserLabelStatements is dangerous, because KObjectStore.set_user
    # will attempt to call .permissions on the user as the auth context changes. When it's a user which isn't in the
    # cache and doesn't have permissions set, it'll recursively start calculating permissions again.
    # This checks that calling O.impersonate(O.SYSTEM, ...) inside a hook doesn't call a problem now. Later on it
    # should be modified to prevent it being called.
    User.invalidate_cached
    AuthContext.set_user(User.cache[41], User.cache[41])
  end

  # -------------------------------------------------------------------------------------------------------------

  def test_hUserLabelStatements_hook
    # Even with the hook, the label statements come out normally
    make_user "normal" do |user|
      assert user.permissions.kind_of? KLabelStatementsOps
    end
    # But if the hook does modify it, it comes out correctly, and the 'b' statement looks like the one created by the plugin
    make_user "modify-statements" do |user|
      assert user.permissions.kind_of? KLabelStatementsOr
      b = user.permissions.instance_variable_get(:@b)
      assert b.kind_of? KLabelStatementsOps
      assert_equal [99774422], b._internal_states.first[:read]
    end
  end

  # -------------------------------------------------------------------------------------------------------------

  def make_user(name)
    new_user = User.new(
      :name_first => name,
      :name_last => "permission-rules",
      :email => name + '@example.com')
    new_user.kind = User::KIND_USER
    new_user.password = 'pass1234'
    new_user.save!
    yield new_user
    PermissionRule.delete_all
    new_user.destroy
  end

  def all_operations(*labels)
    Hash[KPermissionRegistry.lookup.keys.map {|op| [op, labels.clone]}]
  end

  def assert_permissions(opts)
    clean_user = User.cache[opts[:user].id]
    allows = all_operations
    denies = all_operations
    (opts[:allow] || {}).each_pair { |op, labels| allows[op] += labels }
    (opts[:deny] || {}).each_pair { |op, labels| denies[op] += labels }
    assert_equal [allows, denies], clean_user.permissions._internal_states
  end

end