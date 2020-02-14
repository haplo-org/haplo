# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavascriptPluginTestsTest < Test::Unit::TestCase

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_plugin_tests/tested_plugin")
  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_plugin_tests/tested_plugin_failures")

  def test_one
    return unless should_test_plugin_debugging_features?
    db_reset_test_data
    restore_store_snapshot("basic")
    KPlugin.install_plugin("tested_plugin")
    db_reset_test_data
    begin
      tester = JSPluginTests.new(KApp.current_application, "tested_plugin", nil)
      tester.run # in another thread
      results = tester.results
      unless results[:pass]
        # Dump the output from the tests so it's easy to see what went wrong
        puts results[:output]
      end
      assert_equal true, results[:pass]
      # Make sure something happened
      assert_equal 3, results[:tests]
      assert results[:asserts] > 10
    ensure
      KPlugin.uninstall_plugin("tested_plugin")
    end
  end

  def test_two
    return unless should_test_plugin_debugging_features?
    db_reset_test_data
    restore_store_snapshot("basic")
    KPlugin.install_plugin("tested_plugin_failures")
    db_reset_test_data
    begin
      tester = JSPluginTests.new(KApp.current_application, "tested_plugin_failures", nil)
      tester.run # in another thread
      results = tester.results
      unless results[:tests] === results[:assert_fails] + results[:errors]
        # Dump the output from the tests so it's easy to see what went wrong
        puts results[:output]
      end
      assert !(results[:output].include? "OK")
      assert_equal false, results[:pass]
      # Make sure something happened
      assert_equal results[:tests], results[:assert_fails] + results[:errors]
      assert results[:tests] === 14
      assert results[:asserts] === 10
      assert results[:assert_fails] === 9
      assert results[:errors] === 5
    ensure
      KPlugin.uninstall_plugin("tested_plugin_failures")
    end
  end
end
