# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class DisplayControllerTest < IntegrationTest
  include KConstants
  include KObjectURLs

  # The display controller gets quite a bit of testing in other tests, being a central part of the platorm

  def test_plugin_redirect_away_from_object
    db_reset_test_data
    restore_store_snapshot("basic")
    begin
      raise "Failed to install plugin" unless KPlugin.install_plugin("display_controller_test/display_controller_test")

      redirect_obj, no_redirect_obj = ["redirect", "no redirect"].map do |title|
        obj = KObject.new
        obj.add_attr(O_TYPE_BOOK, A_TYPE)
        obj.add_attr(title, A_TITLE)
        KObjectStore.create(obj)
        obj
      end

      assert_login_as('user1@example.com', 'password')

      get object_urlpath(no_redirect_obj)
      assert_select('h1', 'no redirect')

      get_302 object_urlpath(redirect_obj)
      assert_redirected_to "/do/redirected-away"

    ensure
      KPlugin.uninstall_plugin("display_controller_test/display_controller_test")
    end
  end

  class DisplayControllerTestPlugin < KTrustedPlugin
    _PluginName "Display Controller Test Plugin"
    _PluginDescription "Test"
    def hPreObjectDisplay(response, object)
      if object.first_attr(KConstants::A_TITLE).to_s == 'redirect'
        response.redirectPath = "/do/redirected-away"
      end
    end
  end

end

