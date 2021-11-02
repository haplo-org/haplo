# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# tests the application controller is working as expected
class TasksControllerTest < IntegrationTest
  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/elements/test_task_list_hook")
  
  def test_task_list_hook_redirect
    db_reset_test_data
    restore_store_snapshot("basic")
    KPlugin.install_plugin('test_task_list_hook')
    assert_login_as('user1@example.com', 'password')
    begin
      get_302 "/do/tasks"
      assert_redirected_to "/test"
    end
    KPlugin.uninstall_plugin('test_task_list_hook')
  end

end
  
