# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# tests the application controller is working as expected
class ApplicationControllerTest < IntegrationTest
  include KHooks
  include KConstants
  include KObjectURLs
  include KPlugin
  include Application_TextHelper
  include Application_RenderHelper

  def test_task_list_hook_redirect
    db_reset_test_data
    restore_store_snapshot("basic")
    begin
      KPlugin.install_plugin('test_task_list_hook')
      assert_login_as('user1@example.com', 'password')
      get "/do/tasks"
      assert_redirected_to "/test"
    end
  end

end
  