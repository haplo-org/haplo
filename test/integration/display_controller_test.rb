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
      assert_select('h1', 'no rdr modified')
      assert(response.body =~ /alt title/)

      get_302 object_urlpath(redirect_obj)
      assert_redirected_to "/do/redirected-away"

    ensure
      KPlugin.uninstall_plugin("display_controller_test/display_controller_test")
    end
  end

  class DisplayControllerTestPlugin < KTrustedPlugin
    include KConstants
    _PluginName "Display Controller Test Plugin"
    _PluginDescription "Test"
    def hPreObjectDisplay(response, object)
      if object.first_attr(A_TITLE).to_s == 'redirect'
        response.redirectPath = "/do/redirected-away"
      end
      if object.first_attr(A_TITLE).to_s == 'no redirect'
        r = object.dup
        r.delete_attrs!(A_TITLE)
        r.add_attr("no rdr modified", A_TITLE)
        r.add_attr("alt title", A_TITLE, Q_ALTERNATIVE)
        response.replacementObject = r
      end
    end
  end

  # -------------------------------------------------------------------------

  def test_restrictions_are_tested_against_unmodified_object
    db_reset_test_data
    restore_store_snapshot("basic")

    obj = KObject.new
    obj.add_attr(O_TYPE_BOOK, A_TYPE)
    obj.add_attr("Object for restrictions", A_TITLE)
    obj.add_attr("NOTES GO HERE", A_NOTES)
    KObjectStore.create(obj)

    assert_login_as('user1@example.com', 'password')

    get object_urlpath(obj)
    assert_select('h1', 'Object for restrictions')
    assert(response.body =~ /NOTES GO HERE/)

    # Add restriction
    restriction1 = KObject.new([O_LABEL_STRUCTURE])
    restriction1.add_attr(O_TYPE_RESTRICTION, A_TYPE)
    restriction1.add_attr(O_TYPE_BOOK, A_RESTRICTION_TYPE)
    restriction1.add_attr(KObjRef.new(100), A_RESTRICTION_UNRESTRICT_LABEL)
    restriction1.add_attr(KObjRef.new(A_NOTES), A_RESTRICTION_ATTR_RESTRICTED)
    KObjectStore.create(restriction1)

    # Notes aren't displayed
    get object_urlpath(obj)
    assert_select('h1', 'Object for restrictions')
    assert(response.body !~ /NOTES GO HERE/)

    # Install plugin which conditionally removes notes
    assert KPlugin.install_plugin("display_controller_test/display_controller_restrictions_test")

    get object_urlpath(obj)
    assert_select('h1', 'Replaced title')
    assert(response.body =~ /NOTES GO HERE/)  # as restriction is lifted by hook

    # But change title...
    obj = obj.dup
    obj.delete_attrs!(A_TITLE)
    obj.add_attr("New title", A_TITLE)
    KObjectStore.update(obj)

    get object_urlpath(obj)
    assert_select('h1', 'Replaced title')
    assert(response.body !~ /NOTES GO HERE/)  # restriction not lifted

  ensure
    KPlugin.uninstall_plugin("display_controller_test/display_controller_restrictions_test")
  end

  class DisplayControllerRestrictionsTestPlugin < KTrustedPlugin
    include KConstants
    _PluginName "Display Controller Restrictions Test Plugin"
    _PluginDescription "Test"
    def hPreObjectDisplay(response, object)
      # Modifies object changing title, to check hObjectAttributeRestrictionLabelsForUser uses the original title
      r = object.dup
      r.delete_attrs!(A_TITLE)
      r.add_attr("Replaced title", A_TITLE)
      response.replacementObject = r
    end
    def hObjectAttributeRestrictionLabelsForUser(response, user, object)
      if object.first_attr(A_TITLE).to_s == "Object for restrictions"
        response.userLabelsForObject.add(KObjRef.new(100))
      end
    end
  end

end

