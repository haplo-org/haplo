# encoding: UTF-8

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavaScriptControllerTest < IntegrationTest
  include JavaScriptTestHelper

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_controller/test_response_plugin")
  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_controller/test_request_callbacks")
  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_controller/test_user_login")

  def setup
    db_reset_test_data
    drop_all_javascript_db_tables
    StoredFile.destroy_all
    KPlugin.install_plugin("test_response_plugin")
    @user = User.new(
      :name_first => 'first',
      :name_last => "last",
      :email => 'authtest@example.com')
    @user.kind = User::KIND_USER
    @user.password = 'pass1234'
    @user.save!
  end

  def teardown
    @user.destroy
    # Uninstall plugins
    KPlugin.uninstall_plugin("test_response_plugin")
    KPlugin.uninstall_plugin("test_request_callbacks")
    KPlugin.uninstall_plugin("test_user_login")
    # Check in all the caches
    KApp.cache_checkin_all_caches
  end

  # -----------------------------------------------------------------------------------------------------------------------------------

  def login
    assert_login_as('authtest@example.com', 'pass1234')
  end

  # -----------------------------------------------------------------------------------------------------------------------------------

  def test_simple_response
    restore_store_snapshot("basic")

    # Currently using the anonymous user
    get "/do/plugin_test/current_user"
    assert_response :success
    assert_equal "USER 2 'ANONYMOUS' 'null' 'null' 'null'", response.body
    get "/do/plugin_test/current_user_has_permission_to_create_intranet_page"
    assert_equal "NO", response.body

    # Simple response without layout
    get '/do/plugin_test/test1/ping'
    assert_response :success
    assert_equal "TEST RESPONSE (test1,ping)", response.body
    assert_equal "text/html", response.content_type
    get '/do/plugin_test/test1'
    assert_response :success
    assert_equal "TEST RESPONSE (test1)", response.body
    assert_equal "text/plain", response.content_type
    get '/do/plugin_test'
    assert_response :success
    assert_equal "TEST RESPONSE ()", response.body
    assert_equal "text/plain", response.content_type

    # Test layout and page title
    get '/do/plugin_test/with_layout'
    assert_response :success
    assert_select("title", "From JS Plugin &lt;&amp;escaped?&gt; : Haplo")
    assert_select("h1", "From JS Plugin &lt;&amp;escaped?&gt;") # page title should be HTML escaped
    assert_select("#z__ws_content", "TEST PLUGIN")
    assert_select("#z__heading_back_nav a", "&lt;BackLink&gt;")
    assert_select("a[href=/hello/backlink]", "&lt;BackLink&gt;")

    # Test parameters
    get '/do/plugin_test/param_out/ping?hello=1&ping=TWENTY'
    assert_response :success
    assert_equal 'TWENTY', response.body
    get_a_page_to_refresh_csrf_token
    post '/do/plugin_test/param_out/something', {:hello => 'ping', :something => 'carrots', :pants => 4}
    assert_response :success
    assert_equal 'carrots', response.body

    # Access to raw body
    post '/do/plugin_test/body', {"foo" => "bar"}
    assert response.body =~ /\A\!foo=bar&__=.+?\!\z/
    post '/do/plugin_test/body2', {"bar" => "foo"}
    assert response.body =~ /\A_bar=foo&__=.+?_\z/

    # Can use id and action parameters (and Rails compatibility doesn't override them)
    get '/do/plugin_test/param_out/id?id=12345'
    assert_equal '12345', response.body
    post '/do/plugin_test/param_out/id', {:id => '12345'}
    assert_equal '12345', response.body
    get '/do/plugin_test/param_out/action?action=walk'
    assert_equal 'walk', response.body
    post '/do/plugin_test/param_out/action', {:action => 'walk'}
    assert_equal 'walk', response.body

    # Test remote address
    get '/do/plugin_test/remote_addr'
    assert_equal 'IPv4 127.0.0.1', response.body

    # Test headers
    get '/do/plugin_test/header_out/Accept'
    assert_equal '["*/*"]', response.body
    get '/do/plugin_test/header_out/X-Hello', nil, {'X-Hello' => 'test value'}
    assert_equal '["test value"]', response.body

    # Test invalid response
    get '/do/plugin_test/invalid_response', nil, {:expected_response_codes => [500]}
    assert_select('h2', "The response body (usually E.response.body) set by test_response_plugin is not valid, must be a String, StoredFile, or a generator (O.generate) object. JSON responses should be encoded using JSON.stringify by the request handler.")
    # ... but make sure it's happy with nothing being returned.
    get '/do/plugin_test/no_response_at_all_was_called'
    assert_equal 'no', response.body
    get_404 '/do/plugin_test/no_response_at_all'
    assert_equal '404', response.code
    assert_select('h1', 'Not found')
    get '/do/plugin_test/no_response_at_all_was_called'
    assert_equal 'yes', response.body

    # Test calling stop
    get '/do/plugin_test/stop/simple'
    assert_equal '200', response.code
    assert_select '#z__ws_content .z__general_alert', "Stopping request early"
    assert response.body.include? "<title>Error"
    assert (not response.body.include? "should not be seen")
    assert response.body.include? "Haplo Test Application"

    get '/do/plugin_test/stop/dont_stop'
    assert_equal '200', response.code
    assert response.body.include?'should not be seen hello'

    get '/do/plugin_test/stop/text'
    assert_equal '200', response.code
    assert response.body =~ /\A\<div class="?z__general_alert"?\>Stop called\<\/div\>\z/ # written as regexp so test can be run after deployment processing

    # Test failures of argument validation return a consise but understandable message
    [
      '/do/plugin_test/arg_test0/carrots',
      '/do/plugin_test/arg_test1/xHELLOx',
      '/do/plugin_test/arg_test2/pants',
      '/do/plugin_test/arg_test3/345',
      '/do/plugin_test/arg_test4',
      '/do/plugin_test/arg_test5/notjson',
      '/do/plugin_test/arg_test5',
      '/do/plugin_test/arg_test/something/jjjj/aaa?a1=345'
    ].each do |url|
      get_400 url
      assert_equal 'Bad request (failed validation)', response.body
    end
    # Check passing validation
    [
      ['/do/plugin_test/arg_test0/xHELLOx', '{"value":"xHELLOx"}'],
      ['/do/plugin_test/arg_test0/HELLO', '{"value":"HELLO"}'],
      ['/do/plugin_test/arg_test2/100', '{"value":100}'],
      ['/do/plugin_test/arg_test3/15', '{"value":15}'],
      ['/do/plugin_test/arg_test4/anything', '{"value":"anything"}'],
      ['/do/plugin_test/arg_test5/{"a":[1,2,3]}', '{"value":{"a":[1,2,3]}}']
    ].each do |url, text|
      get url
      assert_equal text, response.body
    end

    # Test argument reading
    ref1 = KObjRef.new(9274)
    obj = KObject.new()
    obj.add_attr(O_TYPE_BOOK, A_TYPE)
    obj.add_attr('TEST OBJECT', A_TITLE)
    KObjectStore.create(obj)
    # Will fail because the anonymous user isn't allowed to read the object just created
    argtest_url = "/do/plugin_test/arg_test/something/-HELLO-/#{ref1.to_presentation}?a1=345&load=#{obj.objref.to_presentation}"
    get_400 argtest_url
    assert_equal 'Bad request (failed validation)', response.body
    # Login and try again
    login
    get argtest_url
    assert_response :success
    assert_equal 'P[-HELLO-] N[345/number] R[9274] OT[TEST OBJECT]', response.body
    # Try with the optional ref argument
    get "/do/plugin_test/arg_test/something/HELLO?a1=2345&load=#{obj.objref.to_presentation}&pingpong=2356"
    assert_equal '200', response.code
    assert_equal 'P[HELLO] N[2345/number] R[none] OT[TEST OBJECT]', response.body

    # Current user
    get "/do/plugin_test/current_user"
    assert_response :success
    assert_equal "USER #{@user.id} 'first last' 'first' 'last' 'authtest@example.com'", response.body

    # Render that object!
    get "/do/plugin_test/render/#{obj.objref.to_presentation}"
    assert_equal '200', response.code
    assert_equal 'application/json', response.content_type
    oresp = JSON.parse(response.body)
    assert oresp != nil
    assert_equal "/#{obj.objref.to_presentation}/test-object", oresp['urlpath']
    assert oresp['url'] =~ /\Ahttps?:\/\/[^\/]+\/#{obj.objref.to_presentation}\/test-object\z/
    assert oresp['rendered'].include? %Q!href="/#{obj.objref.to_presentation}/test-object">TEST OBJECT</a>!

    # Template rendering
    ['z', 'zyx ping something', 'ping <&>'].each do |p|
      post "/do/plugin_test/template1", {:random => p}
      assert_select 'h1', "TEST TITLE"
      assert_select '#testresponse', "Hello, the parameter was '#{ERB::Util::h(p)}'" # tests escaping
      assert_equal "text/html", response.content_type
    end
    post "/do/plugin_test/template2", {:name => "Fred"}
    assert_equal "Hello: Fred", response.body
    assert_equal "text/plain", response.content_type
    get "/do/plugin_test/template_partial"
    assert_equal response.body, "Partial test: 42\nP1: ping=pong\nP2: hello there!"
    get "/do/plugin_test/template_partial2"
    assert_equal response.body, "Partial test: 42\nP1: ping=pong\nP2: hello there!"
    get "/do/plugin_test/template_partial_in_dir"
    assert_equal response.body, "DIR: Hello: ABC123"
    get "/do/plugin_test/auto_template/junk/elements"
    assert_select '#testresponse', "Automatically chosen template."
    get "/do/plugin_test/auto_template2"
    assert_select '#testresponse', "Automatically chosen template 2 (x=64)."

    # Standard templates
    get "/do/plugin_test/std_template1"
    assert_select '#z__ws_content p', "(TEST TEMPLATE hello)"
    get "/do/plugin_test/std_template2/#{obj.objref.to_presentation}"
    assert_select '#z__ws_content p:nth-of-type(1)', "Including standard template"
    assert_select '#z__ws_content p:nth-of-type(2)', "(TEST TEMPLATE second)"
    assert_select '#z__ws_content p:nth-of-type(3)', "Value 49"
    assert response.body.include?(%Q!TEMPLATE:<input type="hidden" name="__" value="#{current_discovered_csrf_token}">:HELPER:<input type="hidden" name="__" value="#{current_discovered_csrf_token}">:!)
    assert response.body.include?(%Q!<a href="/#{obj.objref.to_presentation}/test-object">TEST OBJECT</a>!)

    # Standard templates implemented in Ruby
    get "/do/plugin_test/ruby_template1"
    assert_response :success
    assert_select '#z__ws_content p:nth-of-type(1)', "Hello there"
    assert response.body.include?('!Object title!') # make sure editor was included
    check_response_includes_javascript('keditor.js') # make sure it's including the javascripts into the response
    assert_select '#z__ws_content p:nth-of-type(2)', "End note"
    assert response.body.include?('Random-book') # make sure object rendering was included
    assert_select '#z__ws_content p:nth-of-type(3)', "End object"

    # Standard templates implemented in Ruby as Handlebars helpers
    get "/do/plugin_test/ruby_hb_helpers/#{obj.objref.to_presentation}"
    assert_select '#obj1 a', 'TEST OBJECT'
    assert_select '#obj2 a', 'TEST OBJECT'
    assert_select '#obj_render1 .z__keyvalue_col2', 'TEST OBJECT'
    assert_select '#obj_render2 .z__linked_heading a', 'TEST OBJECT'

    # Standard UI
    # -- std:ui:confirm
    get "/do/plugin_test/std_ui_confirm"
    assert_select '#z__ws_content div p:nth-of-type(1)', "P1"
    assert_select '#z__ws_content div p:nth-of-type(2)', "P2"
    assert_select '#z__ws_content div a', {:text => "Cancel button&gt;", :attributes => {'href' => '/do/cancelled'}}
    assert_select '#z__ws_content form', {:count => 2}
    # Option 1
    assert_select '#z__ws_content div div:nth-of-type(2) form', {:attributes => {'method' => 'POST', 'action' => '/do/option1'}}
    assert_select '#z__ws_content div div:nth-of-type(2) form input[type=submit]', {:attributes => {'value' => 'First option'}}
    assert_select '#z__ws_content div div:nth-of-type(2) form input[name=__]', {:count => 1}
    assert_select '#z__ws_content div div:nth-of-type(2) form input:nth-of-type(2)', {:attributes => {"type" => "hidden", "name" => "a&lt;&gt;", "value" => "&lt;b&gt;"}}
    assert_select '#z__ws_content div div:nth-of-type(2) form input:nth-of-type(3)', {:attributes => {"type" => "hidden", "name" => "c", "value" => "d"}}
    # Option 2
    assert_select '#z__ws_content div div:nth-of-type(3) form', {:attributes => {'method' => 'POST', 'action' => '/do/option-two'}}
    assert_select '#z__ws_content div div:nth-of-type(3) form input[type=submit]', {:attributes => {'value' => '&lt;Option two&gt;'}}
    assert_select '#z__ws_content div div:nth-of-type(3) form input[name=__]', {:count => 1}
    assert_select '#z__ws_content div div:nth-of-type(3) form input[type=hidden]', {:count => 1}
    # -- std:ui:choose
    get "/do/plugin_test/std_ui_choose"
    assert_select '#z__ws_content div a', {:count => 2}
    assert_select '#z__ws_content div a.z__ui_choose_option_entry_highlight', {:count => 1}
    # Option 1
    assert_select '#z__ws_content div a:nth-of-type(1)', {:attributes => {'href' => '/do/option1'}}
    assert_select '#z__ws_content div a:nth-of-type(1) span', {:count => 2}
    assert_select '#z__ws_content div a:nth-of-type(1) span:nth-of-type(1)', "First option"
    assert_select '#z__ws_content div a:nth-of-type(1) span:nth-of-type(2)', "Hello notes"
    # Option 2
    assert_select '#z__ws_content div a:nth-of-type(2)', {:attributes => {'href' => '/do/option-two'}}
    assert_select '#z__ws_content div a:nth-of-type(2) span', {:count => 1}
    assert_select '#z__ws_content div a:nth-of-type(2).z__ui_choose_option_entry_highlight span', {:count => 1}
    assert_select '#z__ws_content div a:nth-of-type(2) span:nth-of-type(1)', '&lt;Option two&gt;'
    # -- std:search_results (but not all of it's functionality)
    get "/do/plugin_test/std_search_results"
    assert response.body =~ /TEST OBJECT/
    assert response.body =~ /Search within/

    # Use of plugin static resources
    get "/do/plugin_test/client_side_resources"
    assert response.body =~ /<link href="\/~\d+\/\w+\/teststyle.css" rel="stylesheet" type="text\/css">/
    assert response.body =~ /<script src="\/~\d+\/\w+\/testscript.js"><\/script>/
    assert_equal 1, response.body.scan(/testscript\.js/).length  # check it was deduplicated

    # Use of plugin static resources and includes via templates
    get "/do/plugin_test/client_side_resources_templates"
    assert response.body =~ /<link href="\/~\d+\/\w+\/teststyle.css" rel="stylesheet" type="text\/css">/ # plugin:static:teststyle.css
    assert response.body =~ /<script src="\/~\d+\/\w+\/testscript.js"><\/script>/ # plugin:static:testscript.js
    assert_equal 1, response.body.scan(/testscript\.js/).length  # check it was deduplicated
    check_response_includes_javascript('plugin_adaptor.js') # std:resource:plugin_adaptor
    assert response.body.include? '<script src="/random/javascript1.js"></script>' # std:resources
    assert response.body.include? '<script src="/random/javascript2.js"></script>' # std:resources
    assert response.body.include? '<link href="/random/css/file" rel="stylesheet" type="text/css">' # std:resources
    get "/do/plugin_test/client_side_resources_templates?testResourceHTML=1"
    assert response.body =~ Regexp.new('\s*<link href="/~\d+/\w+/teststyle.css" rel="stylesheet" type="text/css"><script src="/~\d+/\w+/testscript.js"></script><link href="/random/css/file" rel="stylesheet" type="text/css"><script src="/random/javascript1.js"></script><script src="/random/javascript2.js"></script>\s*\z')

    # Check permission again
    get "/do/plugin_test/current_user_has_permission_to_create_intranet_page"
    assert_equal "YES", response.body

    # Database access
    # STORE
    post "/do/plugin_test/db_store", {:name => "Hello there"}
    assert_response :success
    assert response.body =~ /\A\d+\z/
    db_1_id = response.body.to_i
    post "/do/plugin_test/db_store", {:name => "Ping something or other <>"}
    assert_response :success
    assert response.body =~ /\A\d+\z/
    db_2_id = response.body.to_i
    # BAD POST
    post_400 "/do/plugin_test/db_store", {:pong => "Bad very bad"}
    assert_equal '400', response.code
    assert_equal 'Bad request (failed validation)', response.body
    # GET ROWS
    get "/do/plugin_test/db_get/#{db_1_id}"
    assert_response :success
    assert_equal "Hello there", response.body
    get "/do/plugin_test/db_get/#{db_2_id}"
    assert_response :success
    assert_equal "Ping something or other <>", response.body
    # GET A ROW WHICH DOESN'T EXIST
    get_400 "/do/plugin_test/db_get/#{db_2_id+220}"
    assert_equal 'Bad request (failed validation)', response.body

    # WorkUnit defaults when in a request
    get "/do/plugin_test/work_unit_defaults/#{@user.id}"
    assert_equal 'WORK UNIT HAS RIGHT DEFAULTS', response.body

    # WorkUnit parameter tests
    work_unit_id = 999
    get_400 "/do/plugin_test/work_unit_simple/#{work_unit_id}"
    assert_equal "400", response.code

    begin
      different_user = User.new(
        :name_first => 'first',
        :name_last => "last",
        :email => 'different@example.com')
      different_user.kind = User::KIND_USER
      different_user.password = 'pass1234'
      different_user.save!

      work_unit = WorkUnit.new(:work_type => "plugin_test:unit", :opened_at => Time.now,
                               :created_at => Time.now, :created_by_id => @user.id,
                               :actionable_by => @user)
      work_unit.save()
      different_work_unit = WorkUnit.new(:work_type => "plugin_test:different", :opened_at => Time.now,
                                         :created_at => Time.now, :created_by_id => @user.id,
                                         :actionable_by => different_user)
      different_work_unit.save()

      get "/do/plugin_test/work_unit_simple/#{work_unit.id}"
      assert_equal "200", response.code
      assert_equal work_unit.id.to_s, response.body

      get "/do/plugin_test/work_unit_parameters?o=#{work_unit.id}&all=#{work_unit.id}&type=#{work_unit.id}&different=#{different_work_unit.id}"
      assert_equal "200", response.code
      assert_equal("[#{work_unit.id},#{work_unit.id},#{work_unit.id},#{different_work_unit.id}]", response.body)

      # Without optional parameters
      get "/do/plugin_test/work_unit_parameters?o=#{work_unit.id}"
      assert_equal "200", response.code
      assert_equal("[#{work_unit.id},null,null,null]", response.body)

      # Invalid workTypes
      get "/do/plugin_test/work_unit_parameters?o=#{work_unit.id}&type=#{work_unit.id}"
      assert_equal "200", response.code
      get_400 "/do/plugin_test/work_unit_parameters?o=#{work_unit.id}&type=#{different_work_unit.id}"
      assert_equal "400", response.code

      # Wrong User
      get "/do/plugin_test/work_unit_parameters?o=#{work_unit.id}&all=#{different_work_unit.id}"
      assert_equal "200", response.code
      get_400 "/do/plugin_test/work_unit_parameters?o=#{different_work_unit.id}&all=#{different_work_unit.id}"
      assert_equal "400", response.code
    ensure
      work_unit.delete()
      different_work_unit.delete()
      different_user.delete()
    end

    # Headers
    get_302 "/do/plugin_test/redirect"
    assert_redirected_to '/pants'
    assert_equal %Q!<html><body><p><a href="/pants">Redirect</a></p></body></html>!, response.body
    get "/do/plugin_test/headers"
    assert_equal "Carrots", response['x-ping']
    assert_equal "Hello", response['x-pong']

    # Returning generated files
    ['no_finish','finish'].each do |finish_opt|
      get "/do/plugin_test/xls/#{finish_opt}"
      assert_response :success
      assert_equal "application/vnd.ms-excel", response['content-type']
      assert_equal "yes", response['x-madestuff']
      assert_equal 'attachment; filename="Excel_Test.xls"', response['content-disposition']
      ['Randomness','Hello','There','(DELETED)'].each do |t|
        assert response.body.include?(t)
      end
      # File.open("test.xls", "w") { |f| f.write response.body }
    end

    # Rewriting CSS and url of static files
    get '/do/plugin_test/css_rewrite'
    assert_equal %Q!div {background: url(#{KPlugin.get('test_response_plugin').static_files_urlpath}/ping.png)} p {color:#000077}!, response.body
    assert_equal KPlugin.get('test_response_plugin').static_files_urlpath, response['X-staticDirectoryUrl']
    assert response['X-staticDirectoryUrl'] !~ /\/\z/ # make sure it doesn't end with a /
    # CSS 'static' files get rewriting too
    get "#{KPlugin.get('test_response_plugin').static_files_urlpath}/teststyle.css"
    assert_equal <<__E, response.body
div {background:url(#{KPlugin.get('test_response_plugin').static_files_urlpath}/hello.gif)}
p {color:#000077}
b {color:#0000ff}
i {color:#ff0000}
__E
    # Other static files don't geyt rewritten
    get "#{KPlugin.get('test_response_plugin').static_files_urlpath}/testscript.js"
    assert_equal '(function() { return "APPLICATION_COLOUR_MAIN"; })();', response.body

    # Null and undefined arguments to templates
    get '/do/plugin_test/special_arguments_to_templates/null'
    assert_equal "NO OBJECT NO OBJECT", response.body
    get '/do/plugin_test/special_arguments_to_templates/undefined'
    assert_equal "NO OBJECT NO OBJECT", response.body

    # Expiry times
    [1, 4, 1000, 23069, 347343].each do |seconds|
      request_time = DateTime.current
      get "/do/plugin_test/expiry/#{seconds}"
      assert_equal "s=#{seconds}", response.body
      assert_equal "private, max-age=#{seconds}", response['Cache-Control']
      # Check date - should be either the before or after time. Will fail if it takes longer than a second, but that's bad too!
      found_ok = false
      [request_time.advance(:seconds => seconds), DateTime.current.advance(:seconds => seconds)].each do |time|
        found_ok = true if time.to_formatted_s(:rfc822) == response['Expires']
      end
      assert found_ok
    end

    # File uploads
    multipart_post '/do/plugin_test/file_upload', {:testfile => fixture_file_upload('files/example.pages','application/x-iwork-pages-sffpages')}
    fileinfo = JSON.parse(response.body)
    assert_equal 'example.pages', fileinfo["filename"]
    assert_equal 'application/x-iwork-pages-sffpages', fileinfo["mimeType"]
    assert_equal '2d7e68dc7ace5b2085e765a1e53d9438828767c19479b4458fbb81bd5ce1e1eb', fileinfo["digest"]
    assert_equal 106106, fileinfo["fileSize"]
    # Stored file can be set as a response by a plugin
    get "/do/plugin_test/get_stored_file_by_digest", {:digest => '2d7e68dc7ace5b2085e765a1e53d9438828767c19479b4458fbb81bd5ce1e1eb'}
    assert_equal File.open("test/fixtures/files/example.pages", "rb") { |f| f.read }, response.body
    assert_equal 'application/x-iwork-pages-sffpages', response['Content-Type']
    assert_equal 'attachment; filename="example.pages"', response['Content-Disposition']
    # Load object
    fileupload_obj = KObjectStore.read(KObjRef.from_presentation(fileinfo["ref"])).dup
    assert_equal 'Test file', fileupload_obj.first_attr(KConstants::A_TITLE).to_s
    uploaded_identifier = fileupload_obj.first_attr(KConstants::A_FILE)
    assert uploaded_identifier != nil
    assert uploaded_identifier.kind_of?(KIdentifierFile)
    assert_equal "example.pages", uploaded_identifier.presentation_filename
    assert_equal "application/x-iwork-pages-sffpages", uploaded_identifier.mime_type
    # Load the stored file, and check it
    uploaded_stored_file = uploaded_identifier.find_stored_file
    assert uploaded_stored_file != nil
    assert_equal "2d7e68dc7ace5b2085e765a1e53d9438828767c19479b4458fbb81bd5ce1e1eb", uploaded_stored_file.digest
    assert_equal File.open("test/fixtures/files/example.pages") {|f|f.read}, File.open(uploaded_stored_file.disk_pathname) {|f|f.read}
    # Check optional file uploads work
    multipart_post '/do/plugin_test/optional_file_upload', {:ping => 'yes'}
    assert_equal 'no file', response.body
    multipart_post '/do/plugin_test/optional_file_upload', {:ping => 'yes', :testfile => ''} # Some browsers send empty text field for no file
    assert_equal 'no file', response.body
    multipart_post '/do/plugin_test/optional_file_upload', {:ping => 'yes', :testfile => fixture_file_upload('files/example.pages','application/x-iwork-pages-sffpages')}
    assert_equal 'have file', response.body
    # Make sure that the response to bad file uploads doesn't include any HTML characters and is useful
    multipart_post_400 '/do/plugin_test/optional_file_upload', {:ping => 'yes', "hello<there>" => fixture_file_upload('files/example3.pdf','application/pdf')}
    assert_equal "A file was uploaded, but it was not expected by the application. Field name: 'hello&lt;there&gt;'", response.body
    # NOTE: There's a check for no file upload instructions given in the javascript_debug_reporting_test.rb

    # Upload to string conversion
    multipart_post '/do/plugin_test/file_upload_readasstring', {:file => fixture_file_upload('files/example8_utf8nobom.txt','text/plain')}
    assert_equal response.body.force_encoding(Encoding::UTF_8), File.open("test/fixtures/files/example8_utf8nobom.txt") { |f| f.read }
    assert_equal (1024*1024*16), Java::OrgHaploUtils::StringUtils.MAXIMUM_READ_FILE_AS_STRING_SIZE

    # HTML & paths for the file
    run_all_jobs({}) # make sure thumbnailing is done
    png_stored_file = StoredFile.from_upload(fixture_file_upload('files/example5.png', 'image/png'))

    post_fid = Proc.new do |fn, json|
      post "/do/plugin_test/file_identifier_text", {:r => fileupload_obj.objref.to_presentation, :f => fn, :i => json}
    end
    post_fid.call "url", "null"
    assert_equal "/file/#{uploaded_stored_file.digest}/#{uploaded_stored_file.size}/example.pages", response.body
    post_fid.call "url", '{"asFullURL":false}'
    assert_equal "/file/#{uploaded_stored_file.digest}/#{uploaded_stored_file.size}/example.pages", response.body
    post_fid.call "url", '{"asFullURL":true}'
    assert_equal "http://www#{_TEST_APP_ID}.example.com#{KApp::SERVER_PORT_EXTERNAL_CLEAR_IN_URL}/file/#{uploaded_stored_file.digest}/#{uploaded_stored_file.size}/example.pages", response.body
    post_fid.call "url", '{"authenticationSignature":true}'
    assert response.body =~ /\A\/file\/#{uploaded_stored_file.digest}\/#{uploaded_stored_file.size}\/example\.pages\?s=[0-9a-f]+\z/
    signed_file_url = response.body
    anon_user = open_session; anon_user.extend(IntegrationTestUtils)
    anon_user.get_a_page_to_refresh_csrf_token # make sure there's a session
    anon_user.session[:file_auth_key] = session[:file_auth_key] # copy signature value
    anon_user.get signed_file_url # make sure the signature works
    assert anon_user.response.body =~ /\APK\x03\x04/ # header for ZIP file
    assert_equal anon_user.response.body.length, uploaded_stored_file.size
    anon_user.get_302 signed_file_url.gsub(/s=[0-9a-f]/,'s=123456789123456789') # break the signature
    assert anon_user.response.kind_of?(Net::HTTPRedirection)
    assert anon_user.response.body !~ /\APK\x03\x04/
    assert anon_user.response.body.length != uploaded_stored_file.size

    post_fid.call "url", '{"authenticationSignature":true,"forceDownload":true}'
    assert response.body =~ /\A\/file\/#{uploaded_stored_file.digest}\/#{uploaded_stored_file.size}\/example\.pages\?s=[0-9a-f]+\&attachment\=1\z/
    anon_user.get response.body
    assert anon_user.response.body =~ /\APK\x03\x04/
    assert_equal anon_user.response.body.length, uploaded_stored_file.size

    post_fid.call "url", '{"forceDownload":true}'
    assert_equal "/file/#{uploaded_stored_file.digest}/#{uploaded_stored_file.size}/example.pages?attachment=1", response.body
    post_fid.call "fileThumbnailHTML", "null"
    assert_equal %Q!<img src="/_t/#{uploaded_stored_file.digest}/#{uploaded_stored_file.size}" width="49" height="64" alt="">!, response.body
    post_fid.call "fileThumbnailHTML", %Q!{"linkToDownload":true}!
    assert_equal %Q!<a href="/file/#{uploaded_stored_file.digest}/#{uploaded_stored_file.size}/example.pages"><img src="/_t/#{uploaded_stored_file.digest}/#{uploaded_stored_file.size}" width="49" height="64" alt=""></a>!, response.body
    post_fid.call "fileThumbnailHTML", %Q!{"linkToDownload":true,"asFullURL":true}!
    assert_equal %Q!<a href="http://www#{_TEST_APP_ID}.example.com#{KApp::SERVER_PORT_EXTERNAL_CLEAR_IN_URL}/file/#{uploaded_stored_file.digest}/#{uploaded_stored_file.size}/example.pages"><img src="http://www#{_TEST_APP_ID}.example.com#{KApp::SERVER_PORT_EXTERNAL_CLEAR_IN_URL}/_t/#{uploaded_stored_file.digest}/#{uploaded_stored_file.size}" width="49" height="64" alt=""></a>!, response.body
    post_fid.call "fileThumbnailHTML", %Q!{"linkToDownload":true,"authenticationSignature":true}!
    assert response.body =~ /\A<a href="(\/file\/#{uploaded_stored_file.digest}\/#{uploaded_stored_file.size}\/example\.pages\?s=([0-9a-f]+))"><img src="(\/_t\/#{uploaded_stored_file.digest}\/#{uploaded_stored_file.size}\?s=([0-9a-f]+))" width="49" height="64" alt=""><\/a>\z/
    signed_file_url = $1
    signed_thumbnail_url = $3
    assert $2 != $4 # signatures are different
    assert signed_file_url != signed_thumbnail_url
    anon_user.get signed_file_url # get the file...
    assert_equal File.open("test/fixtures/files/example.pages", "r:binary") {|f|f.read}, anon_user.response.body
    anon_user.get signed_thumbnail_url # get the thumbnail image...
    assert anon_user.response.body =~ /\A.PNG/ # make sure it's a PNG
    anon_user.get_302 signed_thumbnail_url.gsub('s=','s=a') # bad signature
    assert anon_user.response.kind_of?(Net::HTTPRedirection)

    # Request HTML for a non-image file, returns a thumbnail
    post_fid.call "toHTML", '{}'
    assert_equal %Q!<img src="/_t/#{uploaded_stored_file.digest}/#{uploaded_stored_file.size}" width="49" height="64" alt="">!, response.body

    # Resizing images
    fileupload_obj.delete_attrs!(A_FILE)
    fileupload_obj.add_attr(KIdentifierFile.new(png_stored_file), A_FILE)
    fileupload_obj = KObjectStore.update(fileupload_obj).dup
    run_all_jobs({}) # make sure thumbnailing is done
    post_fid.call "url", '{"transform":"w100"}'
    assert_equal "/file/#{png_stored_file.digest}/#{png_stored_file.size}/w100/example5.png", response.body
    post_fid.call "url", '{"transform":"w100","authenticationSignature":true}'
    assert response.body =~ /\A\/file\/#{png_stored_file.digest}\/#{png_stored_file.size}\/w100\/example5\.png\?s=[0-9a-f]+\z/
    anon_user.get response.body
    assert anon_user.response.body =~ /\A.PNG/
    assert anon_user.response.body != File.open("test/fixtures/files/example5.png") {|f|f.read}
    # Scaled images wrapped in IMG
    post_fid.call "toHTML", '{"transform":"w100"}'
    assert_equal %Q!<img src="/file/#{png_stored_file.digest}/#{png_stored_file.size}/w100/example5.png" width="100" height="200">!, response.body
    post_fid.call "toHTML", '{"transform":"s"}' # small image
    assert_equal %Q!<img src="/file/#{png_stored_file.digest}/#{png_stored_file.size}/s/example5.png" width="128" height="256">!, response.body
    # Thumbnails
    post_fid.call "toHTML", '{"transform":"thumbnail"}'
    assert_equal %Q!<img src="/_t/#{png_stored_file.digest}/#{png_stored_file.size}" width="32" height="64" alt="">!, response.body
    # With signatures
    post_fid.call "toHTML", '{"transform":"w103","authenticationSignature":true}'
    assert response.body =~ /\A<img src="(\/file\/#{png_stored_file.digest}\/#{png_stored_file.size}\/w103\/example5\.png\?s=[0-9a-f]+)" width="103" height="206">\z/
    anon_user.get $1
    assert anon_user.response.body =~ /\A.PNG/
    assert anon_user.response.body != File.open("test/fixtures/files/example5.png") {|f|f.read}

    # Put the old file identifier back
    fileupload_obj.delete_attrs!(A_FILE)
    fileupload_obj.add_attr(uploaded_identifier, A_FILE)
    fileupload_obj = KObjectStore.update(fileupload_obj).dup

    # Layouts
    get '/do/plugin_test/layouts?layout=false&value=hello' # no layout
    assert_equal '<p>VALUE="hello"</p>', response.body
    get '/do/plugin_test/layouts?layout=undefined&value=hello2' # standard layout
    assert response.body =~ /<div id="?z__page"?>/ # check for standard layout, regex to allow for minimisation
    assert response.body.include?('<p>VALUE="hello2"</p>')
    get '/do/plugin_test/layouts?layout=std:standard&value=hello3' # standard layout, explicitly requested
    assert response.body =~ /<div id="?z__page"?>/ # check for standard layout
    assert response.body.include?('<p>VALUE="hello3"</p>')
    get '/do/plugin_test/layouts?layout=std:wide&value=helloWide' # wide layout
    assert response.body =~ /<div id="?z__page"? class="?z__page_wide_layout"?>/ # check for standard layout with wide class added
    assert response.body.include?('<p>VALUE="helloWide"</p>')
    get '/do/plugin_test/layouts?layout=std:minimal&value=hello4' # minimal layout
    assert response.body =~ /<body class="?z__webfonts_enabled z__minimal_layout"?>/ # check for minimal layout
    assert response.body.include?('<p>VALUE="hello4"</p>')
    get '/do/plugin_test/layouts?layout=test_layout&value=hello5' # layout defined by plugin
    assert ! (response.body =~ /<div id="?z__page"?>/) # check NOT standard layout
    assert ! (response.body =~ /<body class="?z__minimal_layout"?>/) # check for minimal layout
    assert_equal '<html><body><p>Using example layout</p><p>VALUE="hello5"</p></body></html>', response.body
    # NOTE: Bad standard template name reporting checked in javascript_debug_reporting_test.rb

    # Tray
    get '/do/plugin_test/tray_get'
    assert_equal '', response.body
    tray_objref_s1 = make_obj_for_tray("ONE")
    tray_objref_s2 = make_obj_for_tray("TWO")
    get "/api/tray/change/#{tray_objref_s1}"
    get '/do/plugin_test/tray_get'
    assert_equal tray_objref_s1, response.body
    get "/api/tray/change/#{tray_objref_s2}"
    get '/do/plugin_test/tray_get'
    assert_equal tray_objref_s1+','+tray_objref_s2, response.body
    get "/api/tray/change/#{tray_objref_s1}?remove=1"
    get '/do/plugin_test/tray_get'
    assert_equal tray_objref_s2, response.body

    # Handlebars helper functions
    get '/do/plugin_test/hbhelper1'
    assert_equal 'START<div class="bhhelper">VALUE</div>END', response.body
    get '/do/plugin_test/hbhelper2'
    assert_equal 'START<div class="bhhelper">VALUE2</div>|X-SOMETHINGEND', response.body
    get '/do/plugin_test/hbhelper3'
    assert_equal 'START<div class="bhhelper">VALUE2</div>|Y-SOMETHINGEND', response.body

    # Sidebar rendering
    get '/do/plugin_test/render_into_sidebar'
    assert_select '#z__page #z__right_column div.test_sidebar:nth-of-type(1)', 'Sidebar One'
    assert_select '#z__page #z__right_column div.test_sidebar:nth-of-type(2)', 'Second Sidebar'
    assert_select '#z__page #z__right_column div.test_sidebar:nth-of-type(3)', 'AS HTML'

    # Check that request context is reset properly after calling non-request context hook.
    # Checking by attempting to render a standard template & returning the flag
    get '/do/plugin_test/test_std_template_with_hook_during_request'
    assert response.body =~ /IN_REQUEST/ # flag
    assert response.body =~ /TEST BOOK/ # result of rendering standard template
  end

  def test_hlabellinguserinterface_hook
    login

    types = {}
    KObjectStore.delay_schema_reload_during do
      KObjectStore.with_superuser_permissions do
        ["book", "book_selected", "nonexistant", "multiple", "invalid"].each do |name|
          new_type = KObject.new
          new_type.add_attr O_TYPE_APP_VISIBLE, A_TYPE
          new_type.add_attr "add_label_option-#{name}", A_TITLE
          new_type.add_attr KObjRef.new(O_LABEL_COMMON), A_TYPE_APPLICABLE_LABEL
          new_type.add_attr KObjRef.new(A_TITLE), A_RELEVANT_ATTR
          new_type.add_attr O_TYPE_BEHAVIOUR_PHYSICAL, A_TYPE_BEHAVIOUR
          KObjectStore.create(new_type, KLabelChanges.new([O_LABEL_STRUCTURE], []))
          types[name] = new_type
        end
      end
    end

    get "/do/edit?new=#{O_TYPE_BOOK}"
    assert !(response.body.include?("z__editor_labelling_additional"))

    [false, true].each do |selected|
      type = types[selected ? "book_selected" : "book"]
      get "/do/edit?new=#{type.objref.to_presentation}"
      assert_equal [["Book", KObjRef.new(O_TYPE_BOOK).to_presentation, (selected) ? true : false]], thluih_get_displayed_label_options
    end

    get_500 "/do/edit?new=#{types["nonexistant"].objref.to_presentation}"

    new_rule = PermissionRule.new_rule! :deny, @user, O_TYPE_BOOK, :read
    get "/do/edit?new=#{types["book"].objref.to_presentation}"
    assert_equal [["Book", KObjRef.new(O_TYPE_BOOK).to_presentation, false]], thluih_get_displayed_label_options
    new_rule.destroy

    new_rule = PermissionRule.new_rule! :deny, @user, O_TYPE_BOOK, :create
    get "/do/edit?new=#{types["book"].objref.to_presentation}"
    assert_equal [], thluih_get_displayed_label_options
    new_rule.destroy

    get "/do/edit?new=#{types["multiple"].objref.to_presentation}"
    assert_equal([
      ["Book", KObjRef.new(O_TYPE_BOOK).to_presentation, false],
      ["Laptop", KObjRef.new(O_TYPE_LAPTOP).to_presentation, true]
      ], thluih_get_displayed_label_options)

    get_500 "/do/edit?new=#{types["invalid"].objref.to_presentation}"

  end

  def thluih_get_displayed_label_options
    options = []
    select_tags(".z__editor_labelling_additional label").each do |label|
      input, text = label.children
      assert_equal "input", input.name
      assert_equal "checkbox", input.attributes["type"]
      assert_equal "add_label", input.attributes["name"]
      assert text.is_a? HTML::Text
      options << [text.to_s, input.attributes["value"], input.attributes["checked"] ? true : false]
    end
    options
  end

  def test_audit_table_querying
    # Returning audit query tables
    login
    AuditEntry.delete_all
    db_load_table_fixtures :audit_entries
    begin
      # Basic test
      get "/do/plugin_test/audit_table/auditEntryType/ref"
      assert_response :success
      assert_equal "application/json", response['content-type']
      data = JSON.parse(response.body)
      assert_equal ["test:kind1","4x"], data[0]
      assert_equal ["USER-LOGIN",nil], data[-1]
      assert_equal 8, data.length

      #Get all columns
      all_columns = ['userId', 'authenticatedUserId', 'auditEntryType',
                     'ref', 'entityId', 'displayable', 'data',
                     'creationDate', 'remoteAddress']
      get "/do/plugin_test/audit_table/#{all_columns.join('/')}"
      assert_response :success
      filtered_data = JSON.parse(response.body)
      assert_equal 8, filtered_data.length
      assert_equal([120, 121, 'test:kind1', '4x', nil, true, {"XX" => 8},
                    '2013-06-27 09:54:57.691', '192.168.222.2'], filtered_data[0])

      get "/do/plugin_test/audit_table/#{all_columns.join('/')}?all=true"
      assert_response :success
      data = JSON.parse(response.body)
      assert_equal 9, data.length
      assert_equal data[1..8], filtered_data
      assert_equal([120, 121, 'test:kind9', '4x', nil, true, {"XX" => 9},
                    '2013-06-27 09:55:57.691', '192.168.222.2'], data[0])
    ensure
      AuditEntry.delete_all
    end
  end

  def check_response_includes_javascript(name)
    if File.exist?('static/squishing_mappings.yaml')
      @@squishing_mappings ||= File.open('static/squishing_mappings.yaml') { |f| YAML::load(f.read) }
      mapped_name = @@squishing_mappings[:javascript][name]
      raise "Bad mapping" if mapped_name == nil # don't assert to avoid changing the count of assertions
      assert response.body.include?("/-/#{mapped_name}")
    else
      assert response.body.include?("javascripts/#{name}")
    end
  end

  def make_obj_for_tray(title)
    obj = KObject.new()
    obj.add_attr(title, A_TITLE)
    KObjectStore.create(obj)
    obj.objref.to_presentation
  end

  # -----------------------------------------------------------------------------------------------------------------------------------

  def test_string_encoding
    restore_store_snapshot("basic")
    AuditEntry.destroy_all
    get '/do/plugin_test/test_string_encoding?output=table'
    query_data = data = JSON.parse(response.body)
    # This is a direct copy of the string in test_requests.js.  Copied manually because we're testing
    # String encoding, so can't pass these things around too easily.
    badStrings = ["Hello World", "κόσμε", "£10/€20", "\u0080", "\u8000", "\u0800",
                  "\u0001\u0000", "\u0100\u0000", "\u0020\u0000", "\u2000\u0000",
                  "\u0400\u0000", "\u0004\u0000", "\u007F", "\u7F00", "\u07FF",
                  "\uFF07", "\uFFFF", "\u001F\uFFFF", "\u1F00\uFFFF", "\u00FF", "\u00FF",
                  "\uFFFF\uFFFF", "Before\u0000After"];
    assert_equal badStrings.length, query_data.length
    query_data.zip(badStrings).each do |audit_row, expected_string|
      _, audit_data = audit_row
      assert_equal [expected_string], audit_data.keys
      assert_equal [expected_string], audit_data.values
    end

    title = "£45/€55 - κόσμε ಮಣ್ಣಾಗಿ"
    object = KObject.new
    object.add_attr O_TYPE_BOOK, A_TYPE
    object.add_attr title, A_TITLE
    KObjectStore.create object

    get "/do/plugin_test/object_title_encoding/#{object.objref.to_presentation}"
    assert_equal "PASS #{title}", response.body.force_encoding("UTF-8")
  end

  # -----------------------------------------------------------------------------------------------------------------------------------

  def test_request_session
    s1 = open_session
    s2 = open_session

    # DO NOT log in or call anything which would create a CSRF token to check
    # that sessions are created when required.

    # Check there's an exception when a key without a : is used
    s1.get_500 '/do/plugin_test/session_set/nonamespace/ping'
    assert s1.response.kind_of?(Net::HTTPInternalServerError)

    # Check setting and getting values in the session
    s1.get '/do/plugin_test/session_get/t:test1'
    assert_equal 'undefined', s1.response.body
    s1.get '/do/plugin_test/session_set/t:test1/value1'
    s1.get '/do/plugin_test/session_get/t:test1'
    assert_equal '"value1"', s1.response.body

    # Check that the second session doesn't know about it
    s2.get '/do/plugin_test/session_get/t:test1'
    assert_equal 'undefined', s2.response.body

    # Set a value in the second session, with a different key, then check it still doesn't know about the first one
    s2.get '/do/plugin_test/session_set/t:random/ping'
    s2.get '/do/plugin_test/session_get/t:test1'
    assert_equal 'undefined', s2.response.body
    s2.get '/do/plugin_test/session_get/t:random'
    assert_equal '"ping"', s2.response.body

    # Check first session
    s1.get '/do/plugin_test/session_get/t:random'
    assert_equal 'undefined', s1.response.body

    # Check value set in both sessions will be different
    s1.get '/do/plugin_test/session_set/t:random/hello'
    s2.get '/do/plugin_test/session_get/t:random'
    assert_equal '"ping"', s2.response.body
    s1.get '/do/plugin_test/session_get/t:random'
    assert_equal '"hello"', s1.response.body
  end

  # -----------------------------------------------------------------------------------------------------------------------------------

  def test_request_callbacks
    # Install plugin
    KPlugin.install_plugin("test_request_callbacks")

    login
    # Make requests and check the results indicate the right procdure was followed
    # Check all the callbacks happen in order
    get '/do/test_request_callbacks/req1'
    assert_equal "/do/test_request_callbacks/req1-yes-req1-x-LOCAL VAR-after", response.body
    # Check simple abort in requestBeforeHandler() returns forbidden
    get '/do/test_request_callbacks/req2', nil, {:expected_response_codes => [403]}
    assert response.kind_of? Net::HTTPForbidden
    # Check rendering in requestBeforeHandle() works, requestBeforeRender() is called, but requestAfterHandle() handler isn't called
    get '/do/test_request_callbacks/req3'
    assert_equal 'Request3-yes', response.body
    # Check simple output of text in requestBeforeHandle() works
    get '/do/test_request_callbacks/req4'
    assert_equal 'Request Four', response.body
  end

  def test_link_to_object_with_ref
    # Install plugin
    KPlugin.install_plugin("test_request_callbacks")

    login

    obj = KObject.new()
    obj.add_attr(O_TYPE_BOOK, A_TYPE)
    obj.add_attr('TEST OBJECT', A_TITLE)
    KObjectStore.create(obj)

    get '/do/plugin_test/compare_link_to_object/' + obj.objref.to_presentation
    assert_equal 'OK', response.body
  end

  # -----------------------------------------------------------------------------------------------------------------------------------

  def test_js_logging_in_as_user
    assert KPlugin.install_plugin("test_user_login")
    login
    assert_equal @user.id, session[:uid]
    get '/do/test-user-login/user'
    assert_equal "first last", response.body
    about_to_create_an_audit_entry
    get '/do/test-user-login/set-user/42'
    assert_equal "42", response.body
    assert_equal 42, session[:uid]
    assert_audit_entry(:kind => 'USER-LOGIN', :displayable => false, :user_id => 42, :data => {"autologin" => false, "provider" => "plugin:test_user_login", "details" => "USER AUDIT INFO"})
    get '/do/test-user-login/user'
    assert_equal "User 2", response.body
    assert_equal 42, session[:uid]
  end

end
