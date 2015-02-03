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

  NOTIFY_TYPE = "work_unit_notifications:test_auto_notify"

  def test_automatic_notifications
    email_template = EmailTemplate.new({
      :name => "Notify Template",
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
      WorkUnit.new({:work_type => NOTIFY_TYPE, :opened_at => Time.now, :actionable_by_id => 41, :created_by_id => 41,
        :data => {"notify"=>{"template" => "Notify Template"}}
      }).save!
      assert_equal (email_del_size+=1), EmailTemplate.test_deliveries.size
      body = EmailTemplate.test_deliveries.last.body.last.body.unpack("M*").first
      assert body.include?('ALTERNATIVE TEMPLATE')

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
