# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class AuditOptionalWritesTest < IntegrationTest
  include KConstants
  include KFileUrls

  TEST_USER_ID = 41

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/audit_optional_writes/test_auditing_plugin")

  def setup
    restore_store_snapshot("basic")
    db_reset_test_data
    disable_all_optional_auditing
    KPlugin.uninstall_plugin("test_auditing_plugin")
  end

  def teardown
    disable_all_optional_auditing
    KPlugin.uninstall_plugin("test_auditing_plugin")
  end

  def disable_all_optional_auditing
    # Reset all auditing flags
    KApp.set_global_bool(:audit_object_display, false)
    KApp.set_global_bool(:audit_search,         false)
    KApp.set_global_bool(:audit_file_downloads, false)
  end

  def test_audit_optional_writes
    # Setup for tests
    StoredFile.destroy_all
    book0 = make_book("Book Zero")
    book0_url = "/#{book0.objref.to_presentation}/XX"
    book1 = make_book("Book One")
    book1_url = "/#{book1.objref.to_presentation}/XX"
    file0 = create_file('files/example5.png', 'image/png', 'PNG File')
    run_all_jobs :expected_job_count => 1 # so dimensions updated, and transformed file requests below work
    file0_identifier = file0.first_attr(A_FILE)
    assert nil != file0_identifier
    file0_stored_file = file0_identifier.find_stored_file
    html_book = make_book("HTML Book")
    app_book = make_book("Reading stuff on iPhones")
    xml_book = make_book("XML Book")

    # Login as one of the pre-defined users
    assert_login_as(User.find(TEST_USER_ID),'password')
    get_a_page_to_refresh_csrf_token

    # Reset so everything is clear
    reset_audit_trail

    # DISPLAY OBJECTS -----------------------------------------------------------------------------

    # Get the books pages, checking nothing audited by default
    get book0_url
    assert_no_more_audit_entries_written
    get book1_url
    assert_no_more_audit_entries_written

    # Set the flag to audit, and check entries written
    KApp.set_global_bool(:audit_object_display, true)
    assert_audit_entry(:kind => 'CONFIG')
    get book0_url
    assert_audit_entry(:kind => 'DISPLAY', :objref => book0.objref, :user_id => TEST_USER_ID, :remote_addr => '127.0.0.1', :data => nil)
    get book1_url
    assert_audit_entry(:kind => 'DISPLAY', :objref => book1.objref, :user_id => TEST_USER_ID)

    # Get them again, making sure no more audit entries are written because recent repeats are suppressed
    get book0_url
    get book1_url
    assert_no_more_audit_entries_written

    # Via insertable HTML API
    get "/api/display/html/#{html_book.objref.to_presentation}"
    assert response.body.include?("HTML Book")
    assert_audit_entry(:kind => 'DISPLAY', :objref => html_book.objref, :user_id => TEST_USER_ID, :data => nil)

    # SEARCHES -----------------------------------------------------------------------------------

    # But also check that export results are always audited

    get "/search?q=book"
    assert_no_more_audit_entries_written

    KApp.set_global_bool(:audit_search, true)
    assert_audit_entry(:kind => 'CONFIG')
    get "/search?q=hello"
    assert_audit_entry(:kind => 'SEARCH', :data => {"q" => "hello"}, :user_id => TEST_USER_ID)
    post "/search/export", {:q => "hello", :output_form => '', :output_format => 'xlsx'}
    assert_audit_entry(:kind => 'EXPORT', :data => {"q" => "hello"}, :user_id => TEST_USER_ID)
    get "/search?q=hello"
    assert_no_more_audit_entries_written
    post "/search/export", {:q => "hello", :output_form => '', :output_format => 'xlsx'}
    assert_audit_entry(:kind => 'EXPORT', :data => {"q" => "hello"}, :user_id => TEST_USER_ID) # exports aren't deduped
    get "/search?q=hello2"
    assert_audit_entry(:kind => 'SEARCH', :data => {"q" => "hello2"})
    post "/search/export", {:q => "hello2", :output_form => '', :output_format => 'xlsx'}
    assert_audit_entry(:kind => 'EXPORT', :data => {"q" => "hello2"}, :user_id => TEST_USER_ID) # exports aren't deduped

    # FILE DOWNLOADS -----------------------------------------------------------------------------

    get file_url_path(file0_stored_file)
    assert_no_more_audit_entries_written

    KApp.set_global_bool(:audit_file_downloads, true)
    assert_audit_entry(:kind => 'CONFIG')
    get file_url_path(file0_stored_file)
    assert_audit_entry(:kind => 'FILE-DOWNLOAD', :user_id => TEST_USER_ID, :entity_id => file0_stored_file.id, :data => {"digest" => file0_stored_file.digest, "size" => file0_stored_file.size})
    get file_url_path(file0_stored_file)
    assert_no_more_audit_entries_written  # doesn't repeat
    KApp.set_global_bool(:audit_file_downloads, false)
    assert_audit_entry(:kind => 'CONFIG')

    # INSTALL PLUGIN WHICH CHANGES STUFF ---------------------------------------------------------

    # Install the plugin which controls the auditing
    KPlugin.install_plugin("test_auditing_plugin")

    # Fetch the config page to check the declared policies are shown
    get "/do/admin/audit/config"
    assert_select('li', :count => 2)
    assert_select('ul :nth-child(1)', 'Policy declared by string.')
    assert_select('ul :nth-child(2)', 'Policy declared by function. 7263') # magic value to test 'this'

    # Start again, so no debounces in the way
    reset_audit_trail

    # DISPLAY OBJECTS -----------------------------------------------------------------------------

    # test_auditing_plugin sets the opposite write flags for "Book Zero"
    get book0_url
    assert_no_more_audit_entries_written
    get book1_url
    assert_audit_entry(:kind => 'DISPLAY', :objref => book1.objref, :user_id => TEST_USER_ID)

    # Change, and check again
    KApp.set_global_bool(:audit_object_display, false)
    assert_audit_entry(:kind => 'CONFIG')
    get book0_url
    assert_audit_entry(:kind => 'DISPLAY', :objref => book0.objref, :user_id => TEST_USER_ID)
    get book1_url
    assert_no_more_audit_entries_written

    # SEARCHES -----------------------------------------------------------------------------------

    # test_auditing_plugin sets write=false for searches containing /audit/,
    # sets write=true for /ping/, leaves all other searches to use default.
    get "/search?q=1audit2"
    assert_no_more_audit_entries_written
    get "/search?q=ping"
    assert_audit_entry(:kind => 'SEARCH', :data => {"q" => "ping"})
    get "/search?q=x123"
    assert_audit_entry(:kind => 'SEARCH', :data => {"q" => "x123"})
    KApp.set_global_bool(:audit_search, false)
    assert_audit_entry(:kind => 'CONFIG')
    get "/search?q=1audit22"
    assert_no_more_audit_entries_written
    post "/search/export", {:q => "abc349823", :output_form => '', :output_format => 'xlsx'}
    assert_audit_entry(:kind => 'EXPORT', :data => {"q" => "abc349823"}, :user_id => TEST_USER_ID) # exports always audited
    get "/search?q=ping2"
    assert_audit_entry(:kind => 'SEARCH', :data => {"q" => "ping2"})
    get "/search?q=x1232"
    assert_no_more_audit_entries_written

    # FILE DOWNLOADS -----------------------------------------------------------------------------

    # test_auditing_plugin sets write=false when transform includes w53,
    # sets write=true when transform includes w54, everything else uses default.
    KApp.set_global_bool(:audit_file_downloads, true)
    assert_audit_entry(:kind => 'CONFIG')
    get file_url_path(file0_stored_file, 'w53')
    assert_no_more_audit_entries_written
    KApp.set_global_bool(:audit_file_downloads, false)
    assert_audit_entry(:kind => 'CONFIG')
    get file_url_path(file0_stored_file, 'w54')
    assert_audit_entry(:kind => 'FILE-DOWNLOAD', :user_id => TEST_USER_ID, :data => {
        "digest" => file0_stored_file.digest, "size" => file0_stored_file.size, "transform" => ['w54']
    })

  end

  def make_book(title)
    o = KObject.new()
    o.add_attr(O_TYPE_BOOK, A_TYPE)
    o.add_attr(title, A_TITLE)
    KObjectStore.create(o)
    o
  end

end
