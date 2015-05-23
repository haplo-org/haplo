# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class WorkUnitTest < Test::Unit::TestCase

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/work_unit/work_unit_notifications")

  def setup
    db_reset_test_data
  end

  def teardown
    WorkUnit.delete_all
  end

  # -------------------------------------------------------------------------------------------------------

  def test_work_unit_data
    wu = WorkUnit.new({
      :work_type => 'test1',
      :opened_at => Time.now,
      :created_by_id  => 41,
      :actionable_by_id => 42,
      :data => {"x"=>2}
    })
    wu.save!
    assert_equal '{"x":2}', wu.read_attribute('data')
    wu2 = WorkUnit.find(wu.id)
    assert_equal 2, wu2.data["x"]
  end

  # -------------------------------------------------------------------------------------------------------

  def test_work_unit_tags
    wus = [
      {"a"=>"b","c"=>"d"},
      {"a"=>"d","x"=>"y"},
      {"x"=>"y"},
      {"a"=>"4","x"=>"x"},
      {"a"=>"4","x"=>"q","z"=>"'s'\""},
    ].map do |tags|
      # Tag creation uses string representation
      wu = WorkUnit.new({
        :work_type => 'test1',
        :opened_at => Time.now,
        :created_by_id  => 41,
        :actionable_by_id => 42,
        :tags => PgHstore.generate_hstore(tags)
      })
      wu.save!
      wu2 = WorkUnit.find(wu.id)
      assert wu2.tags.kind_of?(String)
      assert_equal tags, PgHstore.parse_hstore(wu2.tags)
      wu
    end
    # Check where clause generation
    query1 = WorkUnit.where(WorkUnit::WHERE_TAG, 'a', 'b')
    assert_equal 1, query1.length
    assert_equal wus[0].id, query1[0].id
    query2 = WorkUnit.where(WorkUnit::WHERE_TAG, 'x', 'y').order('id')
    assert_equal 2, query2.length
    assert_equal wus[1].id, query2[0].id
    assert_equal wus[2].id, query2[1].id
    # Count up the work units
    r = {}
    WorkUnit.group("tags -> 'a'").order("tags -> 'a'").select("tags -> 'a' as report_tag, COUNT(*) as report_count").each do |wu|
      r[wu.report_tag] = wu.report_count
    end
    assert_equal({"4"=>2,"b"=>1,"d"=>1,nil=>1},r)
  end

  # -------------------------------------------------------------------------------------------------------

  def test_work_unit_auto_visible
    restore_store_snapshot("basic")

    # Check defaults are as expected
    wu_defaults = WorkUnit.new({:work_type => 'test2', :opened_at => Time.new, :created_by_id => 41, :actionable_by_id => 42})
    assert_equal true, wu_defaults.visible
    assert_equal true, wu_defaults.auto_visible
    wu_defaults.save!
    wu_defaults.reload
    assert_equal true, wu_defaults.visible
    assert_equal true, wu_defaults.auto_visible

    permission_rule = PermissionRule.new_rule!(:deny, User::GROUP_EVERYONE, 9999, :read)

    test_visible = Proc.new do |auto_visible, initial_visible, closed_work_unit, &block|
      obj = KObject.new([KConstants::O_LABEL_COMMON])
      obj.add_attr(KConstants::O_TYPE_BOOK, KConstants::A_TYPE)
      obj.add_attr("Test workunit auto_visible #{auto_visible}", KConstants::A_TITLE)
      KObjectStore.create(obj)

      wu = WorkUnit.new({
        :work_type => 'test3',
        :opened_at => Time.new,
        :created_by_id => 41, # member of group 21 to which permission_rule applies
        :actionable_by_id => 41,
        :objref => obj.objref,
        :auto_visible => auto_visible,
        :visible => initial_visible
      })
      wu.set_as_closed_by(User.find(21)) if closed_work_unit
      wu.save!
      block.call(wu, initial_visible)

      # Change labelling
      obj = KObjectStore.relabel(obj, KLabelChanges.new([9999],[]))
      assert_equal false, User.cache[41].permissions.allow?(:read, obj.labels)
      wu.reload; block.call(wu, false) # now denied by permission_rule

      obj = KObjectStore.relabel(obj, KLabelChanges.new([],[9999]))
      assert_equal true, User.cache[41].permissions.allow?(:read, obj.labels)
      wu.reload; block.call(wu, true) # now visible again

      # Delete & undelete
      obj = KObjectStore.delete(obj)
      wu.reload; block.call(wu, false)

      obj = KObjectStore.undelete(obj)
      wu.reload; block.call(wu, true)

      # Change actionable always changes it to true if auto_visible
      [true, false].each do |allow_obj_read|
        obj = KObjectStore.relabel(obj, allow_obj_read ? KLabelChanges.new([],[9999]) : KLabelChanges.new([9999],[]))
        assert_equal allow_obj_read, User.cache[42].permissions.allow?(:read, obj.labels)

        wu.reload
        wu.visible = initial_visible
        wu.save!
        wu.actionable_by_id = 42
        wu.save!
        wu.reload
        assert_equal (auto_visible ? true : initial_visible), wu.visible

        wu.visible = false
        wu.save!

        # Changing actionable to a group always makes it visible
        wu.actionable_by_id = 21
        wu.save!
        wu.reload
        assert_equal (auto_visible ? true : false), wu.visible

        wu.actionable_by_id = 41; wu.visible = initial_visible; wu.auto_visible = auto_visible; wu.save! # reset
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
    email_template = EmailTemplate.new({
      :name => "Notify Template",
      :code => "test:email-template:notify-template",
      :description => "d1",
      :from_email_address => "bob@example.com",
      :from_name => "Bob",
      :in_menu => true,
      :header => "<p>ALTERNATIVE TEMPLATE</p>"
    })
    email_template.save!

    begin
      assert KPlugin.install_plugin("work_unit_notifications")
      email_del_size = EmailTemplate.test_deliveries.size

      # Create: No user active, email sent
      WorkUnit.new({:work_type => NOTIFY_TYPE, :opened_at => Time.now, :actionable_by_id => 41, :created_by_id => 41,
        :data => {"notify"=>{}}
      }).save!
      assert_equal (email_del_size+=1), EmailTemplate.test_deliveries.size
      assert_equal ["user1@example.com"], EmailTemplate.test_deliveries.last.header.to

      # Create: No notify data returned, no email sent
      WorkUnit.new({:work_type => NOTIFY_TYPE, :opened_at => Time.now, :actionable_by_id => 41, :created_by_id => 41,
        :data => {"notifyDataNotReturned"=>false}
      }).save!
      assert_equal email_del_size, EmailTemplate.test_deliveries.size

      # Create: Actionable by user active, no email sent
      AuthContext.with_user(User.cache[41]) do
        WorkUnit.new({:work_type => NOTIFY_TYPE, :opened_at => Time.now, :actionable_by_id => 41, :created_by_id => 41,
          :data => {"notify"=>{}}
        }).save!
      end
      assert_equal email_del_size, EmailTemplate.test_deliveries.size

      # Create: Non-actionable by user active, email sent
      AuthContext.with_user(User.cache[42]) do
        WorkUnit.new({:work_type => NOTIFY_TYPE, :opened_at => Time.now, :actionable_by_id => 41, :created_by_id => 41,
          :data => {"notify"=>{}}
        }).save!
      end
      assert_equal (email_del_size+=1), EmailTemplate.test_deliveries.size
      assert_equal ["user1@example.com"], EmailTemplate.test_deliveries.last.header.to

      # Check all the strings appear in the email, and the body looks vaguely right
      WorkUnit.new({:work_type => NOTIFY_TYPE, :opened_at => Time.now, :actionable_by_id => 41, :created_by_id => 41,
        :data => {"notify"=>{
          "action" => "/action/url",
          "status" => "Status Message <>",
          "notesHTML" => '<div class="x">NOTE</div>',
          "button" => "Button <> Text",
          "endHTML" => '<div class="end">END TEXT</div>'
        }}
      }).save!
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
      wu = WorkUnit.new({:work_type => NOTIFY_TYPE, :opened_at => Time.now, :actionable_by_id => 41, :created_by_id => 41,
        :data => {"notifyDataNotReturned"=>false}
      })
      wu.save!
      assert_equal email_del_size, EmailTemplate.test_deliveries.size

      # Save the work unit, with notify details, changing actionable, goes to new user
      wu.actionable_by_id = 42
      wu.data = {"notify"=>{}}
      wu.save!
      assert_equal (email_del_size+=1), EmailTemplate.test_deliveries.size
      assert_equal ["user2@example.com"], EmailTemplate.test_deliveries.last.header.to
      assert EmailTemplate.test_deliveries.last.body.last.body.unpack("M*").first !~ /ALTERNATIVE TEMPLATE/ # default template

      # Save the work unit again, actionable not changed (with actual set and no set), no notification
      wu.actionable_by_id = 42
      wu.data = {"notify"=>{"button"=>"Hello"}}
      wu.save!
      assert_equal email_del_size, EmailTemplate.test_deliveries.size
      wu.data = {"notify"=>{"button"=>"Hello2"}}
      wu.save!
      assert_equal email_del_size, EmailTemplate.test_deliveries.size

      # Close doesn't send notify, even if actionable changes
      wu.set_as_closed_by(User.cache[43])
      wu.actionable_by_id = 41
      wu.save!
      assert_equal email_del_size, EmailTemplate.test_deliveries.size

      # Check email template selection
      [
        "test:email-template:notify-template",
        "Notify Template" # check backwards compatible fallback
      ].each do |template_code|
        WorkUnit.new({:work_type => NOTIFY_TYPE, :opened_at => Time.now, :actionable_by_id => 41, :created_by_id => 41,
          :data => {"notify"=>{"template" => template_code}}
        }).save!
        assert_equal (email_del_size+=1), EmailTemplate.test_deliveries.size
        body = EmailTemplate.test_deliveries.last.body.last.body.unpack("M*").first
        assert body.include?('ALTERNATIVE TEMPLATE')
      end

      # Unknown template names default to the default template
      WorkUnit.new({:work_type => NOTIFY_TYPE, :opened_at => Time.now, :actionable_by_id => 41, :created_by_id => 41,
        :data => {"notify"=>{"template" => "Notify Template Not Exist"}}
      }).save!
      assert_equal (email_del_size+=1), EmailTemplate.test_deliveries.size
      body = EmailTemplate.test_deliveries.last.body.last.body.unpack("M*").first
      assert ! body.include?('ALTERNATIVE TEMPLATE')

    ensure
      KPlugin.uninstall_plugin("work_unit_notifications")
      email_template.destroy
    end
  end

end
