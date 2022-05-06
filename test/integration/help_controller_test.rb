# Haplo Platform                                     http://haplo.org
# (c) Avalara, Inc 2021
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# tests the application controller is working as expected
class HelpControllerTest < IntegrationTest
  
  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/help_controller/test_help_page_hook")

  def setup
    db_reset_test_data
    restore_store_snapshot("basic")
    assert_login_as('user1@example.com', 'password')
  end

  def test_help_hook_redirect
    begin
      get "/do/help/pop"
      assert_select('title', 'Help : Haplo')

      KPlugin.install_plugin('test_help_page_hook')
      get_302 "/do/help/pop"
      assert_redirected_to "/help-test"
    ensure
      KPlugin.uninstall_plugin('test_help_page_hook')
    end
  end
end
  
