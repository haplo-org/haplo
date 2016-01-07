# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# See also: script/test
#   This copies in a test plugin to make sure it's registered from the tmp/plugins-test directory.

class JavaScriptPluginLoadingTest < IntegrationTest

  NEW_PLUGIN_SOURCE = "#{File.dirname(__FILE__)}/javascript/javascript_plugin_loading/new_3p_plugin"
  NEW_PLUGIN_DEST_DIR = "#{PLUGINS_LOCAL_DIRECTORY}/test"
  NEW_PLUGIN_DEST = "#{NEW_PLUGIN_DEST_DIR}/new_3p_plugin"

  def test_plugin_setup_and_dirs
    # Make sure the test script has copied the test plugin to the directory
    assert File.directory?("#{PLUGINS_LOCAL_DIRECTORY}/test/thirdparty_plugin")
    # Make sure the developer_loader plugin has created it's directory
    assert File.directory?("#{PLUGINS_LOCAL_DIRECTORY}/loader.dev")
    # And there should be a versions file there too
    assert File.exists?("#{PLUGINS_LOCAL_DIRECTORY}/versions.yaml")
  end

  def test_thirdparty_plugins
    # Only do this in one app, because it's a global thing
    return unless _TEST_APP_ID == FIRST_TEST_APP_ID

    db_reset_test_data

    begin
      # Check the added plugin isn't there yet
      if File.directory?(NEW_PLUGIN_DEST)
        puts "Warning: #{NEW_PLUGIN_DEST} exists, deleting"
        FileUtils.rm_r NEW_PLUGIN_DEST
      end

      # Check the plugin's path doesn't respond
      get '/do/thirdparty_plugin/test', nil, {:expected_response_codes => [404]}

      # Check a plugin can be installed, writes an audit entry, and bumps the files version number
      about_to_create_an_audit_entry
      first_appearance_serial = KApp.global(:appearance_update_serial)
      KPlugin.install_plugin('thirdparty_plugin')
      assert_equal first_appearance_serial + 1, KApp.global(:appearance_update_serial)
      assert_audit_entry(:kind => 'PLUGIN-INSTALL', :data => {'names' => ['thirdparty_plugin']})

      # Check it works
      get '/do/thirdparty_plugin/test'
      assert_select '#z__ws_content p', 'Test plugin!'

      # Check the second plugin's path doesn't work yet
      get '/do/new_thirdparty_plugin/test', nil, {:expected_response_codes => [404]}

      # Install before it's registered available, then check path still doesn't work
      KPlugin.install_plugin('new_3p_plugin')
      get '/do/new_thirdparty_plugin/test', nil, {:expected_response_codes => [404]}

      # Now add another plugin to the directory
      FileUtils.cp_r(NEW_PLUGIN_SOURCE, NEW_PLUGIN_DEST_DIR)
      assert File.directory?(NEW_PLUGIN_DEST)

      # And reload the plugins
      do_plugin_reloading

      # Still doesn't work
      get '/do/new_thirdparty_plugin/test', nil, {:expected_response_codes => [404]}

      # Install plugin, then it works
      KPlugin.install_plugin('new_3p_plugin')
      assert_equal first_appearance_serial + 2, KApp.global(:appearance_update_serial)
      get '/do/new_thirdparty_plugin/test'
      assert_select '#z__ws_content p', 'Another loaded plugin'
      assert_audit_entry(:kind => 'PLUGIN-INSTALL', :data => {'names' => ['new_3p_plugin']})

      # Rewrite a file, check it doesn't appear yet because it's still cached
      File.open("#{NEW_PLUGIN_DEST}/template/test.html", "w") { |f| f.write("<p>New contents</p>") }
      get '/do/new_thirdparty_plugin/test'
      assert_select '#z__ws_content p', 'Another loaded plugin'

      # Prompt a reload
      do_plugin_reloading
      assert_equal first_appearance_serial + 2, KApp.global(:appearance_update_serial) # not changed
      assert_no_more_audit_entries_written

      # But because we didn't change the version number, it hasn't been noticed yet
      get '/do/new_thirdparty_plugin/test'
      assert_select '#z__ws_content p', 'Another loaded plugin'

      # So rewrite the version number, and try again
      File.open("#{NEW_PLUGIN_DEST}/version", "w") { |f| f.write(KRandom.random_api_key) }
      do_plugin_reloading
      assert_equal first_appearance_serial + 3, KApp.global(:appearance_update_serial)
      assert_audit_entry(:kind => 'PLUGIN-RELOAD', :data => {'names' => ['new_3p_plugin']})
      get '/do/new_thirdparty_plugin/test'
      assert_select '#z__ws_content p', 'New contents'

    ensure
      # Clean up after the test
      if File.directory? NEW_PLUGIN_DEST
        FileUtils.rm_r NEW_PLUGIN_DEST
      end
      KPlugin.uninstall_plugin('thirdparty_plugin')
      KPlugin.uninstall_plugin('new_3p_plugin')
      db_reset_test_data
    end
  end

  def do_plugin_reloading
    # Do this in a different thread so there's no current app
    # Using without_application messes with the caches a bit.
    Thread.new {
      KJavaScriptPlugin.reload_third_party_plugins
    } .join
    # Make sure app globals are reloaded in this thread
    KApp._thread_context.app_globals = nil
  end

  # -------------------------------------------------------------------------------------------------------------

  # When the test is loaded (before it's run), make some test plugins to test plugin load order
  ORDER_TESTING_PLUGINS = [
      ['aaa_plugin1', nil],
      ['aaa_plugin2', nil],
      ['bbb_plugin3', 1000],
      ['bbb_plugin4', 1000],
      ['bbb_plugin5', 100],
      ['ddd_plugin6', 250],
    ].shuffle # so the order is always different to test sorting properly
  # But they should always be loaded in this order
  EXPECTED_PLUGIN_LOAD_ORDER = ["bbb_plugin5", "ddd_plugin6", "bbb_plugin3", "bbb_plugin4", "aaa_plugin1", "aaa_plugin2"]

  ORDER_TESTING_PLUGINS.each do |plugin_name, load_priority|
    plugin_dir = "#{PLUGINS_LOCAL_DIRECTORY}/#{plugin_name}"
    FileUtils.mkdir_p("#{plugin_dir}/js")
    File.open("#{plugin_dir}/js/#{plugin_name}.js", "w") do |f|
      f.write <<__E
        if(!$registry.LOAD_ORDER_RESULT) { $registry.LOAD_ORDER_RESULT = []; }
        $registry.LOAD_ORDER_RESULT.push("#{plugin_name}");
        $registry.LOAD_ORDER_RESULT_JSON = JSON.stringify($registry.LOAD_ORDER_RESULT);
__E
    end
    File.open("#{plugin_dir}/plugin.json", "w") do |f|
      f.write <<__E
        {
          "pluginName": "#{plugin_name}",
          "pluginAuthor": "TESTING",
          "pluginVersion": 1000,
          "displayName": "TEST #{plugin_name}",
          "displayDescription": "For testing",
          "apiVersion": 4,
          "load": ["js/#{plugin_name}.js"]
__E
      f.write %Q!,"loadPriority": #{load_priority}\n! if load_priority
      f.write "}\n"
    end
    KJavaScriptPlugin.register_javascript_plugin(plugin_dir)
  end

  # Test that they're actually loaded in the right order
  def test_plugin_loading_order_with_priority
    begin
      ORDER_TESTING_PLUGINS.each { |plugin_name,p| KPlugin.install_plugin(plugin_name) }

      # Check the factory has them in the right order
      interesting_plugins_in_order = KPlugin.get_plugins_for_current_app.
          map { |plugin| plugin.name }.
          select { |name| name =~ /\A\w\w\w_plugin\d\z/ }
      assert interesting_plugins_in_order.length > 2  # not empty!
      assert_equal EXPECTED_PLUGIN_LOAD_ORDER, interesting_plugins_in_order

      # Fish out the variable from the plugin runtime
      js_root_scope = KJSPluginRuntime.current.runtime.getJavaScriptScope()
      registry = js_root_scope.get("$registry", js_root_scope)
      load_order_result_json = registry.get("LOAD_ORDER_RESULT_JSON", registry)
      assert_equal EXPECTED_PLUGIN_LOAD_ORDER, JSON.parse(load_order_result_json)
    ensure
      ORDER_TESTING_PLUGINS.each { |plugin_name,p| KPlugin.uninstall_plugin(plugin_name) }
    end
  end

end

