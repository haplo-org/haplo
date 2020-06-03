# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Tests elements system, including home page

class ElementsTest < IntegrationTest
  include KConstants
  include KPlugin::HookSite

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/elements/test_elements")

  def setup
    db_reset_test_data
    # Create groups
    @group = User.new
    @group.name = 'Test group'
    @group.kind = User::KIND_GROUP
    @group.save
    # Create user
    @user = User.new
    @user.name_first = 'first'
    @user.name_last = "last"
    @user.email = 'authtest@example.com'
    @user.kind = User::KIND_USER
    @user.password = 'pass1234'
    @user.save
    @user.set_groups_from_ids([@group.id])
    # Reset home page elements to defaults
    KApp.set_global(:home_page_elements, '');
    KPlugin.install_plugin('std_home_page_elements')
    # Log in
    assert_login_as('authtest@example.com', 'pass1234')
  end

  def teardown
    KPlugin.uninstall_plugin("test_elements")
  end

  # ====================================================================================================

  def test_home_page
    restore_store_snapshot("basic") # so recent Element doesn't exception because schema doesn't exist
    # Check default home page
    get '/'
    check_element_titles(HOME_LEFT, 'Noticeboard')
    check_element_titles(HOME_RIGHT, 'Recent additions', 'Quick links')
    # Change the order, use numeric group IDs and group codes
    KApp.set_global(:home_page_elements,
      "std:group:everyone right std:quick_links\nstd:group:everyone left std:noticeboard\n4 right std:recent\n")
    get '/'
    check_element_titles(HOME_LEFT, 'Noticeboard')
    check_element_titles(HOME_RIGHT, 'Quick links', 'Recent additions')
    # Check hiding by group works
    KApp.set_global(:home_page_elements,
      "4 right std:quick_links\n4 left std:noticeboard\n#{@group.id} right std:recent\n")
    get '/'
    check_element_titles(HOME_LEFT, 'Noticeboard')
    check_element_titles(HOME_RIGHT, 'Quick links', 'Recent additions')
    @user.set_groups_from_ids([])
    get '/'
    check_element_titles(HOME_LEFT, 'Noticeboard')
    check_element_titles(HOME_RIGHT, 'Quick links')
    @user.set_groups_from_ids([@group.id])
    get '/'
    check_element_titles(HOME_LEFT, 'Noticeboard')
    check_element_titles(HOME_RIGHT, 'Quick links', 'Recent additions')
  end

  # ====================================================================================================

  EXPECTED_ELEMENTS = %w(std:attached_image std:banners std:browser_check std:contact_notes std:created_objects std:linked_objects std:noticeboard std:object std:object_tasks std:quick_links std:recent std:sidebar_object test_elements:links test_elements:opts test_elements:test)
  ITEM_PAGE_ONLY_ELEMENTS = %w(std:attached_image std:contact_notes std:linked_objects std:sidebar_object)

  def test_plugin_elements
    KPlugin.install_plugin("test_elements")
    # Check the discovery mechanism
    elements = nil
    call_hook(:hElementDiscover) do |hooks|
      elements = hooks.run.elements
    end
    assert elements != nil
    # Check elements are available as expected
    sorted_elements = elements.sort {|a,b| a.first <=> b.first}
    assert_equal EXPECTED_ELEMENTS.length, sorted_elements.length
    EXPECTED_ELEMENTS.each_with_index do |name, i|
      assert_equal 2, sorted_elements[i].length
      assert_equal name, sorted_elements[i].first
      assert sorted_elements[i].last =~ /[A-Z][a-z]/ # make sure there's some capitalised text there
    end
    # Apply a JS plugin elements to the home page
    KApp.set_global(:home_page_elements,
      "4 right std:quick_links\n4 right test_elements:links\n4 left test_elements:test")
    get '/'
    check_element_titles(HOME_RIGHT, 'Quick links', 'Test Links')
    check_element_titles(HOME_LEFT, 'Simple Test')
    # Optional "s in response to allow for squished results
    assert response.body =~ /<div class="?z__home_page_main_action_link"?><a href="\/path1">Line 1<\/a><\/div>/
    assert response.body =~ /<div class="?z__home_page_main_action_link"?><a href="\/path2">Two<\/a><\/div>/
    assert_select '#test_element_test', :test => 'Test from test_elements'
    # Try some options
    KApp.set_global(:home_page_elements,
      "4 right std:quick_links\n4 right test_elements:opts\n4 left test_elements:test")
    get '/'
    check_element_titles(HOME_RIGHT, 'Quick links', 'Options')
    check_element_titles(HOME_LEFT, 'Simple Test')
    assert_select '#options_display', :count => 1
    assert_select '#options_display div', :count => 0
    KApp.set_global(:home_page_elements,
      %Q!4 right std:quick_links\n4 right test_elements:opts {"o1":34,"option2":"carrots"}\n4 left test_elements:test!)
    get '/'
    check_option "o1", "34"
    check_option "option2", "carrots"
    # Try with an empty string title, to make sure stuff it output without titles
    KApp.set_global(:home_page_elements,
      %Q!4 right std:quick_links\n4 right test_elements:opts {"title":"","opt1":"hello"}\n4 left test_elements:test!)
    get '/'
    check_element_titles(HOME_RIGHT, 'Quick links') # No 'Options'
    check_option "opt1", "hello"
    # Invalid JSON options
    KApp.set_global(:home_page_elements,
      %Q!4 right std:quick_links\n4 right test_elements:opts {"title":"","opt1":"hello","x}\n4 left test_elements:test!)
    get '/'
    check_element_titles(HOME_RIGHT, 'Quick links', 'Options')
    assert ! (response.body.include?("opt1"))

    # Check item page only elements will only display an error on the home page
    ITEM_PAGE_ONLY_ELEMENTS.each do |element|
      KApp.set_global(:home_page_elements, %Q!4 left #{element}!)
      get '/'
      check_element_titles(HOME_LEFT, element)
      assert response.body.include?("Element can only be displayed on an item page")
    end

    org = KObject.new()
    org.add_attr(O_TYPE_ORGANISATION, A_TYPE)
    org.add_attr("TESTORG", A_TITLE)
    KObjectStore.create(org)

    person = KObject.new()
    person.add_attr(O_TYPE_PERSON, A_TYPE)
    person.add_attr("TESTPERSON", A_TITLE)
    person.add_attr(org, A_WORKS_FOR)
    KObjectStore.create(person)

    unperson = KObject.new()
    unperson.add_attr(O_TYPE_PERSON, A_TYPE)
    unperson.add_attr("UNPERSON", A_TITLE)
    KObjectStore.create(unperson)

    project = KObject.new()
    project.add_attr(O_TYPE_PROJECT, A_TYPE)
    project.add_attr("TESTPROJECT", A_TITLE)
    project.add_attr(org, A_CLIENT)
    KObjectStore.create(project)

    contact_note = KObject.new()
    contact_note.add_attr(O_TYPE_CONTACT_NOTE, A_TYPE)
    contact_note.add_attr("TESTNOTE", A_TITLE)
    contact_note.add_attr(org, A_PARTICIPANT)
    contact_note.add_attr(person, A_PARTICIPANT)
    KObjectStore.create(contact_note)

    # Make requests, and check default Elements integration picks up the right objects
    get "/#{org.objref.to_presentation}"
    assert response.body.include?("TESTPERSON") # linked on right
    assert response.body.include?("TESTNOTE") # contact note
    assert ! response.body.include?("UNPERSON") # doesn't work for them

    get "/#{person.objref.to_presentation}"
    assert response.body.include?("TESTORG") # in infocard on right
    assert response.body.include?("TESTNOTE") # contact note
  end

  # ====================================================================================================

  HOME_LEFT = '#z__ws_content > div:not(.z__right_column) >'
  HOME_RIGHT = '#z__right_column'

  def check_element_titles(context, *titles)
    tags = select_tags("#{context} .z__home_page_panel_title")
    assert_equal titles.length, tags.length
    titles.each_with_index do |title, i|
      assert_equal title, tags[i].children.first.to_s
    end
  end

  def check_option(key, value)
    assert_select "#options_display .od_#{key}", :text => value
  end

end

