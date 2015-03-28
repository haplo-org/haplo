# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JSPluginTests

  NAME_SETUP = 'test/_setup.js'
  NAME_TEARDOWN = 'test/_teardown.js'

  def initialize(app_id, plugin_name, test_partial_name)
    @app_id = app_id
    @plugin_name = plugin_name
    @test_partial_name = test_partial_name
  end

  def run
    raise "Can only run plugin testing when debugging support is loaded" unless PLUGIN_DEBUGGING_SUPPORT_LOADED
    # Run the tests in another thread so the environment is nice and clean, and there's no
    # change of polluting the calling thread's globals.
    thread = Thread.new do
      KApp.in_application(@app_id) do
        run_tests
      end
    end
    thread.join
    self
  end

  def results
    {
      :tests => @tests,
      :asserts => @asserts,
      :errors => @errors,
      :assert_fails => @assert_fails,
      :output => @output,
      :pass => (@errors == 0) && (@assert_fails == 0)
    }
  end

  # ---------------------------------------------------------------------------------------------------------------------------

private

  def run_tests
    plugin = KPlugin.get(@plugin_name)
    raise "Plugin not installed" if plugin == nil
    plugin_path = plugin.plugin_path
    # Get underlying Java runtime object
    @plugin_runtime = KJSPluginRuntime.current
    @runtime = @plugin_runtime.runtime

    @tests = 0
    @asserts = 0
    @errors = 0
    @assert_fails = 0
    @output = ''

    tests = {}
    Dir.glob("#{plugin_path}/test/**/*.js").sort.each do |path|
      tests[path[plugin_path.length + 1, path.length]] = path
    end

    # Setup/teardown scripts?
    setup_script = tests.delete(NAME_SETUP)
    teardown_script = tests.delete(NAME_TEARDOWN)

    # Ensure testing runtime support is loaded, and reset it
    @runtime_testing_support = @runtime.getTestingSupport()
    @runtime_testing_support.startTesting(self, @plugin_name)

    KApp.logger.info("Running tests for plugin #{@plugin_name}")

    begin
      run_test_script(setup_script, NAME_SETUP, true) if setup_script

      tests.each do |name, path|
        if @test_partial_name == nil || name.include?(@test_partial_name)
          @tests += 1
          run_test_script(path, name)
        end
      end

      run_test_script(teardown_script, NAME_TEARDOWN, true) if teardown_script
    ensure
      # Reset state after tests
      @runtime_testing_support.endTesting()
      # Log output and flush logs
      KApp.logger.info(@output)
      KApp.logger.flush_buffered
    end
  end

  def run_test_script(pathname, name, hide_name = false)
    @output << "** Running #{@plugin_name}/#{name} ...\n" unless hide_name
    success = false
    begin
      @plugin_runtime.using_runtime do
        # Run script with the plugin object as the P global
        @runtime.loadScript(pathname, "p/#{@plugin_name}/#{name}", "var P=#{@plugin_name}; ", nil)
      end
      success = true
    rescue => e
      message, backtrace = PluginDebugging::ErrorReporter.presentable_exception(e)
      if message == nil
        message = 'UNKNOWN ERROR'
        backtrace = []
      end
      @output << "** Failure in #{@plugin_name}/#{name}\n" if hide_name
      @output << message
      @output << "\n  "
      @output << backtrace.join("\n  ")
      @output << "\n\n"
      if message =~ /ASSERT FAILED/
        @assert_fails += 1
      else
        @errors += 1
      end
    end
    @asserts += @runtime_testing_support.getAndResetAssertCount()
    @output << "  OK\n\n" if success && !hide_name
  end

  # ---------------------------------------------------------------------------------------------------------------------------
  # Callbacks from the PluginTestingSupport host object

  def testStartTest
    @plugin_runtime._test_get_support_root._test_set_fake_controller(nil);
  end

  def testFinishTest
  end

  def testLogin(is_anonymous, user)
    user = User.cache[User::USER_ANONYMOUS] if is_anonymous
    AuthContext.set_user(user, user)
    @plugin_runtime._test_get_support_root._test_set_fake_controller(FakeController.new)
  end

  def testLogout()
    @plugin_runtime._test_get_support_root._test_set_fake_controller(nil);
  end

end
