# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavascriptPluginTestsTest < Test::Unit::TestCase

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_plugin_tests/tested_plugin")

  def test_one
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

end
