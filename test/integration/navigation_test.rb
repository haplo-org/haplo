# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class NavigationTest < IntegrationTest
  include KConstants
  include JavaScriptTestHelper

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/navigation/test_navigation_hooks")

  def setup
    restore_store_snapshot("basic")
    db_reset_test_data
    KPlugin.install_plugin("test_navigation_hooks")
  end

  def teardown
    KPlugin.uninstall_plugin("test_navigation_hooks")
  end

  def test_navigation
    obj1 = KObject.new()
    obj1.add_attr("object1", A_TITLE)
    KObjectStore.create(obj1)
    obj1_url = "/#{obj1.objref.to_presentation}/object1"

    assert_login_as(User.find(41), 'password')

    set_navigation([
        [4,"obj",obj1.objref.to_presentation,"O1"],
        [4,"link","/abc","ABC"]
      ])

    assert_equal [{"items"=>[["/", "Home"]]}, {"collapsed"=>false, "items"=>[[obj1_url, "O1"], ["/abc", "ABC"]]}], get_navigation();

    set_navigation([
        [4,"obj",obj1.objref.to_presentation,"O1"],
        [4,"obj",KObjRef.new(123).to_presentation,"XXX"],
        [4,"link","/abc","ABC"]
      ])

    # Can't see the extra entry because the current user doesn't have permission
    assert_equal [{"items"=>[["/", "Home"]]}, {"collapsed"=>false, "items"=>[[obj1_url, "O1"], ["/abc", "ABC"]]}], get_navigation();

    set_navigation([
        [4,"obj",obj1.objref.to_presentation,"O1"],
        [4,"separator",true], # collapsed
        [4,"link","/abc","ABC"],
        [4,"link","/def","def"],
        [4,"separator",false], # not collapsed
        [4,"link","/xyz","zyx"]
      ])

    assert_equal [{"items"=>[["/", "Home"]]}, {"collapsed"=>false, "items"=>[[obj1_url, "O1"]]}, {"collapsed"=>true, "items"=>[["/abc", "ABC"], ["/def", "def"]]}, {"collapsed"=>false, "items"=>[["/xyz", "zyx"]]}], get_navigation()

    set_navigation([
        [4,"obj",obj1.objref.to_presentation,"O1"],
        [21,"link","/yyy","YYY"],
        [22,"link","/abc","ABC"],
      ])

    # User 41 is not a member of group 22, but is of group 21
    assert_equal [{"items"=>[["/", "Home"]]}, {"collapsed"=>false, "items"=>[[obj1_url, "O1"], ["/yyy", "YYY"]]}], get_navigation();

    # Plugins can add entries
    set_navigation([
        [21,"link","/yyy","YYY"],
        [21,"plugin","test:position1"],
        [21,"link","/abc","ABC"],
      ])
    assert_equal [
        {"items"=>[["/", "Home"]]},
        {"collapsed"=>false, "items"=>[["/yyy", "YYY"], ["/position1", "POSITION ONE"]]},
        {"collapsed"=>false, "items"=>[["/link2", "Link 2"]]},
        {"collapsed"=>true, "items"=>[["/link3", "Link Three"], ["/abc", "ABC"]]}
      ], get_navigation()

    # API for invalidating navigation
    nav_version = KApp.global(:navigation_version)
    run_javascript_test(:inline, "TEST(function() { O.reloadNavigation(); });")
    assert_equal nav_version, KApp.global(:navigation_version) # delayed until request end, so same right now
    without_application {} # fake a request end
    assert_equal nav_version + 1, KApp.global(:navigation_version) # then it's changed
  end

  def set_navigation(nav_entries)
    KApp.set_global(:navigation, YAML::dump(nav_entries))
  end

  def get_navigation
    get '/api/navigation/left/123/567'
    assert response.body =~ /\AKNav\((.+)\)\s*\z/
    JSON.parse($1)
  end

end
