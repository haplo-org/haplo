# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavaScriptDebugReportingTest < IntegrationTest
  include KConstants

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_debug_reporting/badly_coded_plugin")
  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_debug_reporting/syntax_error_plugin")

  def setup
    db_reset_test_data
    KPlugin.install_plugin("badly_coded_plugin")
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
    KPlugin.uninstall_plugin("syntax_error_plugin")
    KPlugin.uninstall_plugin("badly_coded_plugin")
    # Check in all the caches
    KApp.cache_checkin_all_caches
  end

  def test_reporting
    # This isn't a test which can be done in parallel
    return unless Thread.current[:_test_app_id] == FIRST_TEST_APP_ID

    # Make sure the plugin debugging support code has been loaded
    assert PLUGIN_DEBUGGING_SUPPORT_LOADED

    # Log in
    assert_login_as('authtest@example.com', 'pass1234')

    # Make sure there's a useful message when a file is uploaded, but wasn't expected
    multipart_post '/do/test_error/no_file_upload',
      {:ping => 'yes', :testfile => fixture_file_upload('files/example3.pdf','application/pdf')},
      {:expected_response_codes => [500]}
    assert response.body.include?("File upload received, but no arguments for the handler function are files.")

    # Call all the errors to see if they're reported properly
    TEST_CALLS.each do |path, error, location, syntax_error_plugin|
      # Need to install another plugin to provoke the final error
      if syntax_error_plugin
        # Will exception because it's got a syntax error, however, it will still be installed
        assert_raise Java::OrgMozillaJavascript::EvaluatorException do
          KPlugin.install_plugin("syntax_error_plugin")
        end
      end
      # Make request
      get path, nil, {:expected_response_codes => [500]}
      # Extract bits from the body
      body = response.body
      assert body =~ /<h1>(.+?)<\/h1>/
      title = $1
      assert body =~ /<h2>(.+?)<\/h2>/
      message = $1
      assert body =~ /<pre>\s*([^\n]+)/m
      first_line_in_backtrace = $1
      # Check against expected values
      assert_equal "Plugin error", title
      assert_equal error, message
      if path == '/do/test_error/stackoverflow'
        # Sometimes JRuby throws a Ruby SystemStackError instead, which doesn't have a backtrace
        assert((location == first_line_in_backtrace) || ("</pre>" == first_line_in_backtrace))
      else
        assert_equal location, first_line_in_backtrace
      end
      # Check the special header is set
      assert_equal "yes", response["X-ONEIS-Reportable-Error"]
    end

    # Disable the reporter so it's like a normal live installation
    KFramework.register_reportable_error_reporter(nil)

    # Uninstall the second plugin so it's not breaking everything
    KPlugin.uninstall_plugin("syntax_error_plugin")

    # Make sure each error has the plugin failure message
    TEST_CALLS.each do |path, error, location, syntax_error_plugin|
      if syntax_error_plugin
        assert_raise Java::OrgMozillaJavascript::EvaluatorException do
          KPlugin.install_plugin("syntax_error_plugin")
        end
      end
      get path, nil, {:expected_response_codes => [500]}
      assert_equal "<html><h1>Plugin error</h1><p>An error has occurred with one of the installed plugins. If the problem persists, please contact support.</p></html>", response.body
    end
  end

  # URL, Error, Location, Install syntax error plugin
  TEST_CALLS = [
    [
      '/do/tools/reports',  # org.mozilla.javascript.EcmaError (reporting via hook)
      'TypeError: Cannot find function ping in object [object Object].',
      'badly_coded_plugin/js/badly_coded_plugin.js (line 4)'
    ],[
      '/do/test_error/ruby_api', # JavaScriptAPIError (via request handler)
      'Unknown application information requested',
      'badly_coded_plugin/js/badly_coded_plugin.js (line 11)'
    ],[
      '/do/test_error/java_api', # com.oneis.javascript.OAPIException
      'Unexpected plugin registration.',
      'badly_coded_plugin/js/badly_coded_plugin.js (line 15)'
    ],[
      '/do/test_error/js_throw', # org.mozilla.javascript.JavaScriptException
      'Error: Bad DBTime creation',
      'badly_coded_plugin/js/badly_coded_plugin.js (line 19)'
    ],[
# Disabled because interface changed to throw exception with more accurate message
#      '/do/test_error/ar_notfound', # ActiveRecord::RecordNotFound
#      "Attempt to read something which doesn't exist.",
#      'badly_coded_plugin/js/badly_coded_plugin.js (line 23)'
#    ],[
      '/do/test_error/stackoverflow', # java.lang.StackOverflowError
      "Stack overflow. Check for recursive calls of functions in the stack trace.",
      'badly_coded_plugin/js/badly_coded_plugin.js (line 28)'
    ],[
      '/do/test_error/nullpointerexception', # java.lang.NullPointerException
      "Bad argument. undefined or null passed to an API function which expected a valid object.",
      'badly_coded_plugin/js/badly_coded_plugin.js (line 35)'
    ],[
      '/do/test_error/bad_standard_layout',
      "Unknown standard layout 'std:randomness'",
      '</pre>' # no error location
    ],[
      '/do/test_error/bad_schema_name',
      "Nothing found when attempting to retrieve property 'test:type:which-does-not-exist' from TYPE",
      'badly_coded_plugin/js/badly_coded_plugin.js (line 51)'
    ],[
      # MUST BE LAST TEST
      '/', # org.mozilla.javascript.EvaluatorException
      "missing } after property list",
      'syntax_error_plugin/js/syntax_error_plugin.js (line 5)',
      true # install the other plugin!
    ]
  ]

end

