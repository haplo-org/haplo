# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class WorkUnitTest < Test::Unit::TestCase

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/work_unit/work_unit_notifications")

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/work_unit/work_unit_pre_save_hook")

  def setup
    db_reset_test_data
  end

  def teardown
    delete_all WorkUnit
  end

  # -------------------------------------------------------------------------------------------------------

  def test_work_unit_data
    wu = WorkUnit.new
    wu.work_type = 'test1'
    wu.opened_at = Time.now
    wu.created_by_id = 41
    wu.actionable_by_id = 42
    wu.data = {"x"=>2}
    wu.save
    assert_equal '{"x":2}', wu.data_json
    wu2 = WorkUnit.read(wu.id)
    assert_equal 2, wu2.data["x"]
  end

  # -------------------------------------------------------------------------------------------------------

  def test_work_unit_tags
    wus = [
      {"a"=>"b","c"=>"d"},
      {"a"=>"d","x"=>"y","e"=>''},
      {"x"=>"y"},
      {"a"=>"4","x"=>"x"},
      {"a"=>"4","x"=>"q","z"=>"'s'\""},
    ].map do |tags|
      # Tag creation uses string representation
      wu = WorkUnit.new
      wu.work_type = 'test1'
      wu.opened_at = Time.now
      wu.created_by_id = 41
      wu.actionable_by_id = 42
      wu.tags = PgHstore.generate_hstore(tags)
      wu.save
      wu2 = WorkUnit.read(wu.id)
      assert wu2.tags.kind_of?(String)
      assert_equal tags, PgHstore.parse_hstore(wu2.tags)
      wu
    end
    # Check where clause generation
    query1 = WorkUnit.where_tag('a', 'b').select()
    assert_equal 1, query1.length
    assert_equal wus[0].id, query1[0].id
    query2 = WorkUnit.where_tag('x', 'y').order(:id).select()
    assert_equal 2, query2.length
    assert_equal wus[1].id, query2[0].id
    assert_equal wus[2].id, query2[1].id
    query3 = WorkUnit.where_tag_is_empty_string_or_null('e').select()
    assert_equal 5, query3.length
    query4 = WorkUnit.where_tag_is_empty_string_or_null('a').select()
    assert_equal 1, query4.length
  end

  # -------------------------------------------------------------------------------------------------------

  def test_work_unit_auto_visible
    restore_store_snapshot("basic")

    # Check defaults are as expected
    wu_defaults = WorkUnit.new
    wu_defaults.work_type = 'test2'
    wu_defaults.opened_at = Time.new
    wu_defaults.created_by_id = 41
    wu_defaults.actionable_by_id = 42
    assert_equal true, wu_defaults.visible
    assert_equal true, wu_defaults.auto_visible
    wu_defaults.save
    wu_defaults = WorkUnit.read(wu_defaults.id)
    assert_equal true, wu_defaults.visible
    assert_equal true, wu_defaults.auto_visible

    permission_rule = PermissionRule.new_rule!(:deny, User::GROUP_EVERYONE, 9999, :read)

    test_visible = Proc.new do |auto_visible, initial_visible, closed_work_unit, &block|
      obj = KObject.new([KConstants::O_LABEL_COMMON])
      obj.add_attr(KConstants::O_TYPE_BOOK, KConstants::A_TYPE)
      obj.add_attr("Test workunit auto_visible #{auto_visible}", KConstants::A_TITLE)
      KObjectStore.create(obj)

      wu = WorkUnit.new
      wu.work_type = 'test3'
      wu.opened_at = Time.new
      wu.created_by_id = 41 # member of group 21 to which permission_rule applies
      wu.actionable_by_id = 41
      wu.objref = obj.objref
      wu.auto_visible = auto_visible
      wu.visible = initial_visible
      wu.set_as_closed_by(User.read(21)) if closed_work_unit
      wu.save
      block.call(wu, initial_visible)

      # Change labelling
      obj = KObjectStore.relabel(obj, KLabelChanges.new([9999],[]))
      assert_equal false, User.cache[41].permissions.allow?(:read, obj.labels)
      wu = WorkUnit.read(wu.id); block.call(wu, false) # now denied by permission_rule

      obj = KObjectStore.relabel(obj, KLabelChanges.new([],[9999]))
      assert_equal true, User.cache[41].permissions.allow?(:read, obj.labels)
      wu = WorkUnit.read(wu.id); block.call(wu, true) # now visible again

      # Delete & undelete
      obj = KObjectStore.delete(obj)
      wu = WorkUnit.read(wu.id); block.call(wu, false)

      obj = KObjectStore.undelete(obj)
      wu = WorkUnit.read(wu.id); block.call(wu, true)

      # Change actionable always changes it to true if auto_visible
      [true, false].each do |allow_obj_read|
        obj = KObjectStore.relabel(obj, allow_obj_read ? KLabelChanges.new([],[9999]) : KLabelChanges.new([9999],[]))
        assert_equal allow_obj_read, User.cache[42].permissions.allow?(:read, obj.labels)

        wu = WorkUnit.read(wu.id)
        wu.visible = initial_visible
        wu.save
        wu.actionable_by_id = 42
        wu.save
        wu = WorkUnit.read(wu.id)
        assert_equal (auto_visible ? true : initial_visible), wu.visible

        wu.visible = false
        wu.save

        # Changing actionable to a group always makes it visible
        wu.actionable_by_id = 21
        wu.save
        wu = WorkUnit.read(wu.id)
        assert_equal (auto_visible ? true : false), wu.visible

        wu.actionable_by_id = 41; wu.visible = initial_visible; wu.auto_visible = auto_visible; wu.save # reset
      end
    end

    test_visible.call(true, true, false) do |wu, expected|
      assert_equal true, wu.auto_visible
      assert_equal expected, wu.visible
    end

    test_visible.call(true, false, false) do |wu, expected|
      assert_equal true, wu.auto_visible
      assert_equal expected, wu.visible
    end

    test_visible.call(false, true, false) do |wu, expected|
      assert_equal false, wu.auto_visible
      assert_equal true, wu.visible
    end

    test_visible.call(false, false, false) do |wu, expected|
      assert_equal false, wu.auto_visible
      assert_equal false, wu.visible
    end

    # Closed units don't have their visibility changed
    [[true,true], [true,false], [false,true], [false,false]].each do |auto_visible, initial_visible|
      test_visible.call(auto_visible, initial_visible, true) do |wu, expected|
        assert_equal auto_visible, wu.auto_visible
        assert_equal initial_visible, wu.visible
      end
    end
  end

  # -------------------------------------------------------------------------------------------------------

  NOTIFY_TYPE = "work_unit_notifications:test_auto_notify"

  def test_automatic_notifications
    email_template = EmailTemplate.new
    email_template.name = "Notify Template"
    email_template.code = "test:email-template:notify-template"
    email_template.description = "d1"
    email_template.from_email_address = "bob@example.com"
    email_template.from_name = "Bob"
    email_template.in_menu = true
    email_template.header = "<p>ALTERNATIVE TEMPLATE</p>"
    email_template.save

    begin
      assert KPlugin.install_plugin("work_unit_notifications")
      email_del_size = EmailTemplate.test_deliveries.size

      # Create: No user active, email sent
      tau_create_wu({:work_type => NOTIFY_TYPE, :opened_at => Time.now, :actionable_by_id => 41, :created_by_id => 41,
        :data => {"notify"=>{}}
      }).save
      assert_equal (email_del_size+=1), EmailTemplate.test_deliveries.size
      assert_equal ["user1@example.com"], EmailTemplate.test_deliveries.last.header.to

      # Create: No notify data returned, no email sent
      tau_create_wu({:work_type => NOTIFY_TYPE, :opened_at => Time.now, :actionable_by_id => 41, :created_by_id => 41,
        :data => {"notifyDataNotReturned"=>false}
      }).save
      assert_equal email_del_size, EmailTemplate.test_deliveries.size

      # Create: Actionable by user active, no email sent
      AuthContext.with_user(User.cache[41]) do
        tau_create_wu({:work_type => NOTIFY_TYPE, :opened_at => Time.now, :actionable_by_id => 41, :created_by_id => 41,
          :data => {"notify"=>{}}
        }).save
      end
      assert_equal email_del_size, EmailTemplate.test_deliveries.size

      # Create: Non-actionable by user active, email sent
      AuthContext.with_user(User.cache[42]) do
        tau_create_wu({:work_type => NOTIFY_TYPE, :opened_at => Time.now, :actionable_by_id => 41, :created_by_id => 41,
          :data => {"notify"=>{}}
        }).save
      end
      assert_equal (email_del_size+=1), EmailTemplate.test_deliveries.size
      assert_equal ["user1@example.com"], EmailTemplate.test_deliveries.last.header.to

      # Check all the strings appear in the email, and the body looks vaguely right
      tau_create_wu({:work_type => NOTIFY_TYPE, :opened_at => Time.now, :actionable_by_id => 41, :created_by_id => 41,
        :data => {"notify"=>{
          "action" => "/action/url",
          "status" => "Status Message <>",
          "notesHTML" => '<div class="x">NOTE</div>',
          "button" => "Button <> Text",
          "endHTML" => '<div class="end">END TEXT</div>'
        }}
      }).save
      assert_equal (email_del_size+=1), EmailTemplate.test_deliveries.size
      body = EmailTemplate.test_deliveries.last.body.last.body.unpack("M*").first
      assert body =~ /http:\/\/www#{_TEST_APP_ID}.example.com(:\d+)?\/action\/url/
      assert body.include?("Status Message &lt;&gt;") # escapes
      assert body.include?('<div class="x">NOTE</div>')
      assert body.include?('Button &lt;&gt; Text')
      assert body.include?('<div class="end">END TEXT</div>')
      assert_equal 1, body.scan('<body>').length # make sure the fake body tags are removed
      assert_equal 1, body.scan('</body>').length
      assert ! body.include?('ALTERNATIVE TEMPLATE')

      # Modifications
      # Create work unit, no notify data yet
      wu = tau_create_wu({:work_type => NOTIFY_TYPE, :opened_at => Time.now, :actionable_by_id => 41, :created_by_id => 41,
        :data => {"notifyDataNotReturned"=>false}
      })
      wu.save
      assert_equal email_del_size, EmailTemplate.test_deliveries.size

      # Save the work unit, with notify details, changing actionable, goes to new user
      wu.actionable_by_id = 42
      wu.data = {"notify"=>{}}
      wu.save
      assert_equal (email_del_size+=1), EmailTemplate.test_deliveries.size
      assert_equal ["user2@example.com"], EmailTemplate.test_deliveries.last.header.to
      assert EmailTemplate.test_deliveries.last.body.last.body.unpack("M*").first !~ /ALTERNATIVE TEMPLATE/ # default template

      # Save the work unit again, actionable not changed (with actual set and no set), no notification
      wu.actionable_by_id = 42
      wu.data = {"notify"=>{"button"=>"Hello"}}
      wu.save
      assert_equal email_del_size, EmailTemplate.test_deliveries.size
      wu.data = {"notify"=>{"button"=>"Hello2"}}
      wu.save
      assert_equal email_del_size, EmailTemplate.test_deliveries.size

      # Save the work unit again, changing actionable, but with the user active so no email would be sent
      AuthContext.with_user(User.cache[41]) do
        wu.actionable_by_id = 41
        wu.data = {"notify"=>{"button"=>"Hello3"}}
        wu.save
        assert_equal email_del_size, EmailTemplate.test_deliveries.size
      end

      # Close doesn't send notify, even if actionable changes
      assert ! wu.attribute_changed?(:actionable_by_id)
      wu.set_as_closed_by(User.cache[43])
      wu.actionable_by_id = 42
      assert wu.attribute_changed?(:actionable_by_id)
      wu.save
      assert_equal email_del_size, EmailTemplate.test_deliveries.size

      # Check email template selection
      [
        "test:email-template:notify-template",
        "Notify Template" # check backwards compatible fallback
      ].each do |template_code|
        tau_create_wu({:work_type => NOTIFY_TYPE, :opened_at => Time.now, :actionable_by_id => 41, :created_by_id => 41,
          :data => {"notify"=>{"template" => template_code}}
        }).save
        assert_equal (email_del_size+=1), EmailTemplate.test_deliveries.size
        body = EmailTemplate.test_deliveries.last.body.last.body.unpack("M*").first
        assert body.include?('ALTERNATIVE TEMPLATE')
      end

      # Unknown template names default to the default template
      tau_create_wu({:work_type => NOTIFY_TYPE, :opened_at => Time.now, :actionable_by_id => 41, :created_by_id => 41,
        :data => {"notify"=>{"template" => "Notify Template Not Exist"}}
      }).save
      assert_equal (email_del_size+=1), EmailTemplate.test_deliveries.size
      body = EmailTemplate.test_deliveries.last.body.last.body.unpack("M*").first
      assert ! body.include?('ALTERNATIVE TEMPLATE')

      # Don't send notifications for objects with opened_at significantly in the future
      [
        [-2073600, 1],
        [-3600, 1],
        [0, 1],
        [3600, 1], # 1 hour in future, 1 email expected to be sent
        [39600, 1],
        [46800, 0],
        [2073600, 0]
      ].each do |future, expected|
        open_in_future = Time.now + future
        AuthContext.with_user(User.cache[42]) do
          tau_create_wu({:work_type => NOTIFY_TYPE, :opened_at => open_in_future, :actionable_by_id => 41, :created_by_id => 41,
            :data => {"notify"=>{}}
          }).save
        end
        assert_equal (email_del_size+=expected), EmailTemplate.test_deliveries.size
      end

    ensure
      KPlugin.uninstall_plugin("work_unit_notifications")
      email_template.delete
    end
  end

  def tau_create_wu(attrs)
    wu = WorkUnit.new
    wu.work_type = attrs[:work_type]
    wu.opened_at = attrs[:opened_at]
    wu.actionable_by_id = attrs[:actionable_by_id]
    wu.created_by_id = attrs[:created_by_id]
    wu.data = attrs[:data]
    wu
  end

  # -------------------------------------------------------------------------------------------------------

  def test_work_unit_pre_save_hook
    tags = {"a"=>"b", "c"=>"d"}
    tags2 = {"test1"=>"testtest"}
    begin
      # Ruby plugin
      raise "Failed to install plugin" unless KPlugin.install_plugin("work_unit_pre_save_hook_test")
      wu = WorkUnit.new
      wu.work_type = 'test1'
      wu.opened_at = Time.now
      wu.created_by_id = 41
      wu.actionable_by_id = 42
      wu.data = {"x"=>2}
      wu.save
      wu4 = WorkUnit.read(wu.id)
      assert_equal tags, PgHstore.parse_hstore(wu4.tags)
    ensure
      KPlugin.uninstall_plugin("work_unit_pre_save_hook_test")
    end

    begin 
      # Javascript plugin
      raise "Failed to install plugin" unless KPlugin.install_plugin("work_unit_pre_save_hook")
      wu2 = WorkUnit.new
      wu2.work_type = 'test1'
      wu2.opened_at = Time.now
      wu2.created_by_id = 41
      wu2.actionable_by_id = 4
      wu2.save
      wu3 = WorkUnit.read(wu2.id)
      assert_equal "123", wu3.data["test"]
      assert_equal tags2, PgHstore.parse_hstore(wu3.tags)
    ensure
      KPlugin.uninstall_plugin("work_unit_pre_save_hook")
    end
  end

end

class WorkUnitPreSaveHookTestPlugin < KTrustedPlugin
  _PluginName "Work Unit Pre-save Hook Test Plugin"
  _PluginDescription "Test"
  def hPreWorkUnitSave(response, workUnit)
    workUnit.tags = PgHstore.generate_hstore({"a"=>"b", "c"=>"d"})
  end
end