# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavascriptPluginTest < Test::Unit::TestCase
  include JavaScriptTestHelper
  include KPlugin::HookSite
  include DisplayHelper

  RuntimeException = Java::JavaLang::RuntimeException

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_plugin/test_plugin")
  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_plugin/test_plugin3")

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_plugin/test_provide_feature")
  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_plugin/test_use_feature")
  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_plugin/test_use_feature2")

  def setup
    # Register the second test plugin in the current application
    KPlugin.register_plugin(KJavaScriptPlugin.new("#{File.dirname(__FILE__)}/javascript/javascript_plugin/test_plugin2"), KApp.current_application)
  end

  def teardown
    # Uninstall plugins
    KPlugin.uninstall_plugin("test_plugin")
    KPlugin.uninstall_plugin("test_plugin2")
    # Check in all the caches
    KApp.cache_checkin_all_caches
  end

  # -------------------------------------------------------------------------------------------------------------

  def test_oninstall_and_onload
    assert_equal(nil, KPlugin.get("test_plugin"))

    # Reset plugin's app global, then make sure the current IDs are nil
    KApp.set_global(:_pjson_test_plugin, "{}")
    get_user_ids = Proc.new do
      d = JSON.parse(KApp.global(:_pjson_test_plugin));
      ["currentUserCodeEvaluate", "currentUserOnInstall", "currentUserOnLoad"].map { |n| d[n] }
    end
    assert_equal [nil, nil, nil], get_user_ids.call()

    # Will run things as the anonymous user, to check install, onload, etc are called as SYSTEM
    anonymous_user = User.cache[User::USER_ANONYMOUS]

    # Install, checking audit entry
    about_to_create_an_audit_entry
    AuthContext.with_user(anonymous_user) do
      assert_equal(true, KPlugin.install_plugin("test_plugin"))
    end
    assert_equal [User::USER_SYSTEM, User::USER_SYSTEM, User::USER_SYSTEM], get_user_ids.call()
    assert_audit_entry(:kind => 'PLUGIN-INSTALL', :data => {'names' => ['test_plugin']})

    assert(nil != KPlugin.get("test_plugin"))
    has_hook = false
    4.times do
      r = call_hook(:hTestOnLoadAndOnInstall) do |hooks|
        has_hook = true
        hooks.run
      end
      assert_equal 1, r.onInstallCallCount
      assert_equal 1, r.onLoadCallCount
    end
    assert has_hook
    # Invalidate the runtime
    KApp.cache_invalidate(KJSPluginRuntime::RUNTIME_CACHE)
    4.times do
      r = call_hook(:hTestOnLoadAndOnInstall) { |hooks| hooks.run }
      assert_equal 0, r.onInstallCallCount
      assert_equal 1, r.onLoadCallCount
    end
    # Uninstall, checking audit entry...
    about_to_create_an_audit_entry
    KPlugin.uninstall_plugin("test_plugin")
    assert_audit_entry(:kind => 'PLUGIN-UNINSTALL', :data => {'names' => ['test_plugin']})

    assert_equal(nil, KPlugin.get("test_plugin"))

    # Install again pretending to be the developer loader, check no audit trail
    # (creating an audit entry for each would result in huge numbers of entries)
    AuthContext.with_user(anonymous_user) do
      assert_equal(true, KPlugin.install_plugin("test_plugin", :developer_loader_apply))
    end
    assert_no_more_audit_entries_written
    assert_equal [User::USER_SYSTEM, User::USER_SYSTEM, User::USER_SYSTEM], get_user_ids.call()
    # And uninstall...
    KPlugin.uninstall_plugin("test_plugin")
    assert_audit_entry(:kind => 'PLUGIN-UNINSTALL')

    # ...and install again
    AuthContext.with_user(anonymous_user) do
      assert_equal(true, KPlugin.install_plugin("test_plugin"))
    end
    assert_equal [User::USER_SYSTEM, User::USER_SYSTEM, User::USER_SYSTEM], get_user_ids.call()
    assert_audit_entry(:kind => 'PLUGIN-INSTALL')
    assert(nil != KPlugin.get("test_plugin"))
    4.times do
      r = call_hook(:hTestOnLoadAndOnInstall) { |hooks| hooks.run }
      assert_equal 1, r.onInstallCallCount
      assert_equal 1, r.onLoadCallCount
    end
    # Invalidate the runtime again...
    KApp.cache_invalidate(KJSPluginRuntime::RUNTIME_CACHE)
    4.times do
      r = call_hook(:hTestOnLoadAndOnInstall) { |hooks| hooks.run }
      assert_equal 0, r.onInstallCallCount
      assert_equal 1, r.onLoadCallCount
    end
  end

  # -------------------------------------------------------------------------------------------------------------

  def test_basics
    restore_store_snapshot("basic")
    @hook_call_index = 0
    # Make sure the plugin isn't installed
    assert_equal(nil, KPlugin.get("test_plugin"))
    # Check the license key info can be obtained from the demand-loaded full plugin.json info
    test_plugin_object = KPlugin.get_plugin_without_installation("test_plugin")
    assert_equal "ABC123", test_plugin_object.plugin_json["installSecret"]
    # Install the plugin
    assert_equal(true, KPlugin.install_plugin("test_plugin"))
    assert(nil != KPlugin.get("test_plugin"))
    tb_check_hook_called
    # Invalid the plugin and runtime caches, make sure it still works
    KApp.cache_invalidate(KPlugin::PLUGINS_CACHE)
    KApp.cache_invalidate(KJSPluginRuntime::RUNTIME_CACHE)
    tb_check_hook_called
    # Check in all the caches, and try again
    KApp.cache_checkin_all_caches
    tb_check_hook_called

    # Check unknown hooks return nil
    assert_equal nil, call_hook(:hTotallyUnimplementedHook) { |hooks| hooks.run }

    # Check sending stuff in via the response works
    response = (call_hook(:hTestHook) { |hooks| hooks.run("test-1", nil) }) # Defaults are all nil for these values
    assert_equal "null: string symbol bool object array hash object-arg", response.testString
    hook_called = false
    call_hook(:hTestHook) do |hooks|
      hook_called = true
      response = hooks.response
      response.testString = nil
      response.testSymbol = nil
      response.testBool = nil
      response.testObject = nil
      response.testArray = nil
      response.testHash = nil
      hooks.run("test-1", nil)
      assert_equal "null: string symbol bool object array hash object-arg", response.testString
    end
    assert hook_called
    hook_called = false
    call_hook(:hTestHook) do |hooks|
      hook_called = true
      response = hooks.response
      response.testString = "Carrots"
      response.testSymbol = :parsnips
      response.testBool = false
      o = KObject.new()
      o.add_attr("Ping2", 76)
      response.testObject = o
      response.testArray = [1, 4, 6, 7]
      response.testHash = {"a"=>"b",:c=>4}
      hooks.run("test-2", nil)
      assert_equal "has-correct-value: string symbol bool object array hash", response.testString
      assert_equal nil, response.testArray
      assert_equal nil, response.testHash
    end
    assert hook_called
    # Check that missing properties or setting to objects of the wrong type cause exceptions with the Javascript.
    ['test-3','test-4','test-5','test-6','test-7'].each do |test_name|
      assert_raise RuntimeException do
        call_hook(:hTestHook) do |hooks|
          hooks.run(test_name, nil)
        end
      end
    end

    # Check work unit rendering (uses fast path rendering, or hooks)
    # Just a template
    rr = render_work_unit(WorkUnit.new(:work_type => "test_plugin:wu_one"), :object)
    assert_equal '<div class="z__work_unit_obj_display">BEGIN/(test_plugin:wu_one):object_display/END</div>', rr # legacy API means object -> object_display
    # Has a fullInfo link, but no custom text
    rr = render_work_unit(WorkUnit.new(:work_type => "test_plugin:wu_two"), :list)
    assert_equal '<div class="z__work_unit_obj_display"><div class="z__work_unit_right_info"><a href="/ping">Full info...</a></div>WU_TWO</div>', rr
    # fullInfo link, custom text
    rr = render_work_unit(WorkUnit.new(:work_type => "test_plugin:wu_three"), :object)
    assert_equal '<div class="z__work_unit_obj_display"><div class="z__work_unit_right_info"><a href="/ping">Carrots</a></div>WU_THREE</div>', rr
    # non-default template
    rr = render_work_unit(WorkUnit.new(:work_type => "test_plugin:wu_four"), :list)
    assert_equal '<div class="z__work_unit_obj_display">WU_FOUR: World</div>', rr
    # non-default template, specified as a template object
    rr = render_work_unit(WorkUnit.new(:work_type => "test_plugin:wu_five"), :object)
    assert_equal '<div class="z__work_unit_obj_display">WU_FIVE: Else</div>', rr

    # Check that multiple responders set with plugin.hook() work
    call_hook(:hTestMultipleHookDefinitionsInOnePlugin) do |hooks|
      assert_equal "1 two three", hooks.run().passedThrough
    end

    # Check plugin basics
    run_javascript_test(:file, 'unit/javascript/javascript_plugin/test_plugin_basics.js')

    # Uninstall to finish
    KPlugin.uninstall_plugin("test_plugin")

    # Check that hooks work during the onLoad() callback.
    # This is here, rather than in the more logical test_oninstall_and_onload, because it's easier to write
    # with the schema objects loaded, and they take a while to load.
    begin
      KPlugin.install_plugin("test_plugin3")
      assert (call_hook(:hTestPlugin3OnLoadOK) { |hooks| hooks.run() }).ok
    ensure
      KPlugin.uninstall_plugin("test_plugin3")
    end
  end

  def tb_check_hook_called
    KJSPluginRuntime.current.runtime.host.jsSet__debug_string("")
    val = "index#{@hook_call_index}"
    obj = KObject.new()
    obj_attr = "attr#{@hook_call_index}"
    obj.add_attr(obj_attr, 5)
    hook_called = false
    call_hook(:hTestHook) do |hooks|
      hook_called = true
      response = hooks.run(val, obj)
      assert_equal "ping", response.testDefaultValue
      assert_equal "Hello!", response.testString
      assert_equal :something, response.testSymbol
      assert_equal true, response.testBool
      o = response.testObject
      assert_equal KObject, o.class
      assert_equal "Randomness", o.first_attr(42).to_s
      assert_equal [349,3982,27584,nil], response.testArray
      assert_equal({"c"=>"pong", "d"=>56}, response.testHash)
    end
    assert hook_called
    assert_equal "hTestHook called with "+val+"/"+obj_attr, KJSPluginRuntime.current.runtime.host.jsGet__debug_string()
    @hook_call_index += 1
  end

  def _test_non_representative_benchmark
    @hook_call_index = 0
    assert_equal(true, KPlugin.install_plugin("test_plugin"))
    1000.times { tb_check_hook_called }
    number_of_runs = 100000
    ms = Benchmark.ms do
      number_of_runs.times { tb_check_hook_called }
    end
    puts "Each plugin hook call took #{ms.to_f / number_of_runs.to_f}ms"
    KPlugin.uninstall_plugin("test_plugin")
  end

  # -------------------------------------------------------------------------------------------------------------

  def test_chain_stopping
    # Install plugins
    assert_equal(true, KPlugin.install_plugin(["test_plugin", "test_plugin2"]))
    assert KPlugin.get("test_plugin") != nil
    assert KPlugin.get("test_plugin2") != nil

    KJSPluginRuntime.current.runtime.host.jsSet__debug_string("")
    call_hook(:hChainTest1) { |hooks| hooks.run() }
    assert_equal "1 - test_plugin", KJSPluginRuntime.current.runtime.host.jsGet__debug_string()
    call_hook(:hChainTest2) { |hooks| hooks.run() }
    assert_equal "2 - test_plugin2", KJSPluginRuntime.current.runtime.host.jsGet__debug_string()
  end

  # -------------------------------------------------------------------------------------------------------------

  def test_plugin_templates
    restore_store_snapshot("basic")
    assert_equal(true, KPlugin.install_plugin("test_plugin"))
    run_javascript_test(:file, 'unit/javascript/javascript_plugin/test_plugin_templates.js')
  end

  # -------------------------------------------------------------------------------------------------------------

  def test_plugin_features
    begin
      assert_equal(true, KPlugin.install_plugin("test_provide_feature"))
      assert_equal(true, KPlugin.install_plugin("test_use_feature"))
      assert_equal(true, KPlugin.install_plugin("test_use_feature2"))
      run_javascript_test(:file, 'unit/javascript/javascript_plugin/test_plugin_features.js')
    ensure
      KPlugin.uninstall_plugin("test_provide_feature")
      KPlugin.uninstall_plugin("test_use_feature")
      KPlugin.uninstall_plugin("test_use_feature2")
    end
  end

  # -------------------------------------------------------------------------------------------------------------

  def test_plugin_database
    drop_all_javascript_db_tables
    assert_equal(true, KPlugin.install_plugin("test_plugin2"))
    # Check namespace is allocated as expected
    namespaces = YAML::load(KApp.global(:plugin_db_namespaces))
    assert namespaces.has_key?("test_plugin2")
    assert_equal 6, namespaces["test_plugin2"].length
    ns = namespaces["test_plugin2"]
    # Make sure uninstallation and installation works OK
    KPlugin.uninstall_plugin("test_plugin2")
    assert_equal(true, KPlugin.install_plugin("test_plugin2"))
    # Namespace still the same
    assert_equal ns, YAML::load(KApp.global(:plugin_db_namespaces))["test_plugin2"]
    # Do some database work in the plugin
    r = call_hook(:hTestDatabase) { |hooks| hooks.run }
    assert_equal "1 2", r.string
  end

  # -------------------------------------------------------------------------------------------------------------

  def test_plugin_app_globals
    assert_equal(true, KPlugin.install_plugin("test_plugin"))
    KApp.set_global(:_pjson_test_plugin, "") if KApp.global(:_pjson_test_plugin) != nil
    assert_equal "UNDEFINED VALUE", call_hook(:hAppGlobalRead) { |hooks| hooks.run("key1").value }

    about_to_create_an_audit_entry
    call_hook(:hAppGlobalWrite) { |hooks| hooks.run("key1", "value2") }
    assert_no_more_audit_entries_written  # updating plugin data doesn't write an audit trail entry

    values = JSON.parse(KApp.global(:_pjson_test_plugin))
    assert_equal "value2", values["key1"]
    assert_equal "value2", call_hook(:hAppGlobalRead) { |hooks| hooks.run("key1").value }
    KApp.cache_invalidate(KJSPluginRuntime::RUNTIME_CACHE)
    assert_equal "value2", call_hook(:hAppGlobalRead) { |hooks| hooks.run("key1").value }
    call_hook(:hAppGlobalWrite) { |hooks| hooks.run("pants", "essential") }
    assert_equal "essential", call_hook(:hAppGlobalRead) { |hooks| hooks.run("pants").value }
    KApp.cache_invalidate(KJSPluginRuntime::RUNTIME_CACHE)
    assert_equal "value2", call_hook(:hAppGlobalRead) { |hooks| hooks.run("key1").value }
    assert_equal "essential", call_hook(:hAppGlobalRead) { |hooks| hooks.run("pants").value }
    call_hook(:hAppGlobalWrite) { |hooks| hooks.run("pants", "optional") }
    KApp.cache_invalidate(KJSPluginRuntime::RUNTIME_CACHE)
    call_hook(:hAppGlobalWrite) { |hooks| hooks.run("ping", "pong") }
    assert_equal "value2", call_hook(:hAppGlobalRead) { |hooks| hooks.run("key1").value }
    assert_equal "optional", call_hook(:hAppGlobalRead) { |hooks| hooks.run("pants").value }
    KApp.cache_checkin_all_caches
    values = JSON.parse(KApp.global(:_pjson_test_plugin))
    # Simulate a variable being set in another runtime
    values["set_outside"] = "WAS DEFINITELY OUTSIDE"
    KApp.set_global(:_pjson_test_plugin, values.to_json())
    KApp.cache_checkin_all_caches
    assert_equal "value2", call_hook(:hAppGlobalRead) { |hooks| hooks.run("key1").value }
    assert_equal "optional", call_hook(:hAppGlobalRead) { |hooks| hooks.run("pants").value }
    assert_equal "WAS DEFINITELY OUTSIDE", call_hook(:hAppGlobalRead) { |hooks| hooks.run("set_outside").value }
    values = JSON.parse(KApp.global(:_pjson_test_plugin))
    assert_equal "value2", values["key1"]
    assert_equal "optional", values["pants"]
    assert_equal "pong", values["ping"]
    assert_equal "WAS DEFINITELY OUTSIDE", values["set_outside"]
    # Check deleting values
    call_hook(:hAppGlobalDelete) { |hooks| hooks.run("ping") }
    values = JSON.parse(KApp.global(:_pjson_test_plugin))
    assert !(values.has_key?("ping"))
    assert_equal "UNDEFINED VALUE", call_hook(:hAppGlobalRead) { |hooks| hooks.run("ping").value }
    KApp.cache_checkin_all_caches
    assert_equal "UNDEFINED VALUE", call_hook(:hAppGlobalRead) { |hooks| hooks.run("ping").value }
  end

  # -------------------------------------------------------------------------------------------------------------

  def test_privileges
    # Install plugins
    KPlugin.install_plugin(["test_plugin", "test_plugin2", "no_privileges_plugin"])
    test_plugin = KPlugin.get("test_plugin")
    test_plugin2 = KPlugin.get("test_plugin2")
    no_privileges_plugin = KPlugin.get("no_privileges_plugin")
    # Check the privilegesRequired entries are included as expected
    assert test_plugin.plugin_json.has_key?("privilegesRequired")
    assert ! no_privileges_plugin.plugin_json.has_key?("privilegesRequired")
    # Check basic privilege queries
    assert test_plugin.has_privilege?("pTestPriv1")
    assert ! test_plugin2.has_privilege?("pTestPriv1")
    assert test_plugin.has_privilege?("pTestPriv2")
    assert ! test_plugin2.has_privilege?("pTestPriv2")
    assert ! no_privileges_plugin.has_privilege?("pTestPriv2")
    assert ! test_plugin.has_privilege?("pants")
    assert ! test_plugin2.has_privilege?("pants")
    assert ! no_privileges_plugin.has_privilege?("pants")
    # Check Java side query in host object
    ran_callback = 0
    KJSPluginRuntime.current.runtime.host.setTestCallback(proc { |string|
      ran_callback += 1
      assert KJSPluginRuntime.current.runtime.getHost().currentlyExecutingPluginHasPrivilege("pTestPriv1");
      assert KJSPluginRuntime.current.runtime.getHost().currentlyExecutingPluginHasPrivilege("pTestPriv2");
      assert ! KJSPluginRuntime.current.runtime.getHost().currentlyExecutingPluginHasPrivilege("pants");
    })
    call_hook(:hTestNullOperation1) { |hooks| hooks.run() } # responded to by test_plugin

    KJSPluginRuntime.current.runtime.host.setTestCallback(proc { |string|
      ran_callback += 1
      assert ! KJSPluginRuntime.current.runtime.getHost().currentlyExecutingPluginHasPrivilege("pTestPriv1");
      assert ! KJSPluginRuntime.current.runtime.getHost().currentlyExecutingPluginHasPrivilege("pTestPriv2");
      assert ! KJSPluginRuntime.current.runtime.getHost().currentlyExecutingPluginHasPrivilege("pants");
    })
    call_hook(:hTestNullOperation2) { |hooks| hooks.run() } # responded to by test_plugin2

    assert_equal 2, ran_callback
  end

  # -------------------------------------------------------------------------------------------------------------

  def test_jobs
    KApp.set_global(:_pjson_test_plugin, "{}") # Clean up any data stored before running the test
    KPlugin.install_plugin("test_plugin")
    KApp.cache_checkin_all_caches
    assert_equal nil, JSON.parse(KApp.global(:_pjson_test_plugin))["hello"]
    call_hook(:hTestScheduleBackgroundTask) { |hooks| hooks.run("Hello there!"); }
    run_all_jobs :expected_job_count => 1
    KApp.cache_checkin_all_caches
    assert_equal "Hello there!", JSON.parse(KApp.global(:_pjson_test_plugin))["hello"]
  end

  # -------------------------------------------------------------------------------------------------------------

  def test_plugin_defined_text
    restore_store_snapshot("basic")
    KPlugin.install_plugin("test_plugin")

    response = nil
    call_hook(:hObjectTextValueDiscover) { |hooks| response = hooks.run() }
    assert_equal([
      ["test:testtype", "First test type"],
      ["test_plugin:testtype2", "Test type Two"]
    ], response.types)

    run_javascript_test(:file, 'unit/javascript/javascript_plugin/test_plugin_defined_text.js')

    plugin_text = KTextPluginDefined.new({:type => "test:testtype", :value => JSON.dump({"text"=>"abc\ndef"})})
    assert_equal "abc\ndef", plugin_text.to_s
    assert_equal "abc\ndef", plugin_text.to_sortas_form
    assert_equal "XTEXTTYPEX abc\ndef", plugin_text.to_indexable
    assert_equal Encoding::UTF_8, plugin_text.to_indexable.encoding
    assert_equal "<div><p>TEST DATA TYPE</p><p>abc</p><p>def</p></div>", plugin_text.to_html
    assert_equal nil, plugin_text.to_identifier_index_str

    plugin_text2 = KTextPluginDefined.new({:type => "test_plugin:testtype2", :value => '{"v":"Y123<p>456"}'})
    assert_equal 'XY123<p>456', plugin_text2.to_s
    assert_equal 'XY123&lt;p&gt;456', plugin_text2.to_html # checks HTML escaping for default text rendering
    assert_equal "test_plugin:testtype2~ID-Y123<p>456", plugin_text2.to_identifier_index_str

    # Test validation failure
    assert_raise Java::OrgMozillaJavascript::JavaScriptException do
      plugin_text2 = KTextPluginDefined.new({:type => "test_plugin:testtype2", :value => '{"X":"Y123<p>456"}'})
    end

    # Check it's stored in the object store identifier index as expected
    obj = KObject.new
    obj.add_attr(O_TYPE_BOOK, A_TYPE)
    obj.add_attr("Hello", A_TITLE)
    KObjectStore.create(obj)
    get_idx = Proc.new do
      KApp.get_pg_database.exec("SELECT value FROM os_index_identifier WHERE id=#{obj.objref.obj_id} AND identifier_type=#{T_TEXT_PLUGIN_DEFINED}").result.map { |r| r.first}
    end
    get_query_result = Proc.new do
      KObjectStore.query_and.identifier(plugin_text2).execute(:all,:any).map { |o| o.objref }
    end
    assert_equal [], get_idx.call()
    assert_equal [], get_query_result.call()
    obj = obj.dup
    obj.add_attr(plugin_text2, 120)
    KObjectStore.update(obj)
    assert_equal ["test_plugin:testtype2~ID-Y123<p>456"], get_idx.call()
    assert_equal [obj.objref], get_query_result.call()
  end

  # -------------------------------------------------------------------------------------------------------------

  def test_inter_plugin_services
    KPlugin.install_plugin("test_plugin")
    KPlugin.install_plugin("test_plugin2")
    response = nil
    call_hook(:hTestInterPluginService) { |hooks| response = hooks.run() }
    assert_equal "service test_plugin2 Hello", response.value
  end



  def test_session_not_available_outside_request
    KPlugin.install_plugin("test_plugin")
    assert_raise(JavaScriptAPIError) do
      call_hook(:hTestSessionOutsideRequest) { |hooks| hooks.run() }
    end
  end

  # -------------------------------------------------------------------------------------------------------------

  def test_plugin_tests
    KPlugin.install_plugin("test_plugin")
    tester = JSPluginTests.new(KApp.current_application, "test_plugin", nil)
    tester.run # in another thread
    results = tester.results
    assert_equal 2, results[:tests]
    assert_equal 5, results[:asserts]
    assert_equal 1, results[:assert_fails]
    assert_equal false, results[:pass]
    expected_output = <<__E
** Running test_plugin/test/test1.js ...
  OK

** Running test_plugin/test/test2.js ...
ASSERT FAILED: test2 fail msg
  test_plugin/test/test2.js (line 5)
  test_plugin/test/test2.js (line 2)
  test_plugin/test/test2.js (line 1)

__E
    assert_equal expected_output, results[:output]
  end

  # -------------------------------------------------------------------------------------------------------------

  def test_hlabelobject_hook
    restore_store_snapshot("basic")
    KPlugin.install_plugin("test_plugin")

    new_ob = thlh_new_book nil
    assert_equal [O_LABEL_COMMON], new_ob.labels.to_a

    new_ob = thlh_new_book "remove_common_label"
    assert_equal [O_LABEL_UNLABELLED], new_ob.labels.to_a

    new_ob = thlh_new_book "self_label"
    assert_equal [O_LABEL_COMMON, new_ob.objref], new_ob.labels.to_a

    new_ob = thlh_new_book "add_remove_self_label"
    assert_equal [O_LABEL_COMMON], new_ob.labels.to_a

    new_ob = thlh_new_book "add_many"
    assert_equal [KObjRef.new(4), O_LABEL_COMMON, new_ob.objref], new_ob.labels.to_a

    new_ob = thlh_new_book "remove_not_existing"
    assert_equal [O_LABEL_COMMON], new_ob.labels.to_a

    new_ob = thlh_new_book "invalid_labels"
    assert_equal [O_LABEL_COMMON, KObjRef.new(9999)], new_ob.labels.to_a

    # And the update version of the hook
    updating_ob = thlh_new_book "something"
    assert_equal [O_LABEL_COMMON], updating_ob.labels.to_a
    updating_ob = updating_ob.dup
    updating_ob.delete_attrs!(A_TITLE)
    updating_ob.add_attr("update_object", A_TITLE)
    KObjectStore.update(updating_ob)
    assert_equal [KObjRef.new(1234),O_LABEL_COMMON], updating_ob.labels.to_a
  end

  def thlh_new_book(title)
    obj = KObject.new()
    obj.add_attr(O_TYPE_BOOK, A_TYPE)
    obj.add_attr(title, A_TITLE) unless title.nil?
    KObjectStore.create(obj)
    obj
  end

end

# Define the test hook
module KHooks
  define_hook :hTestNullOperation1 do |h|
    h.description "Null 1"
  end
  define_hook :hTestNullOperation2 do |h|
    h.description "Null 2"
  end
  define_hook :hTestHook do |h|
    h.description "Test hook"
    h.argument :inputValue1, String, "Some input value"
    h.argument :object, KObject, "Input object"
    h.result :testDefaultValue, String, "'ping'", "Test default value"
    h.result :testString, String, nil, "Test string"
    h.result :testSymbol, Symbol, nil, "Test symbol"
    h.result :testObject, KObject, nil, "Test object"
    h.result :testBool, "bool", nil, "Test bool"
    h.result :testArray, Array, nil, "Test array"
    h.result :testHash, Hash, nil, "Test hash"
  end
  define_hook :hChainTest1 do |h|
    h.description "Chain test 1"
  end
  define_hook :hChainTest2 do |h|
    h.description "Chain test 2"
  end
  define_hook :hTestDatabase do |h|
    h.description "Test database"
    h.result :string, String, nil, "Results"
  end
  define_hook :hTestOnLoadAndOnInstall do |h|
    h.description "Checking onLoad and onInstall called in this runtime?"
    h.result :onInstallCallCount, Fixnum, "0", "onInstall was called"
    h.result :onLoadCallCount, Fixnum, "0", "onLoad was called"
  end
  define_hook :hAppGlobalWrite do |h|
    h.description "Check app global storing"
    h.argument :key, String, "key"
    h.argument :value, String, "value"
  end
  define_hook :hAppGlobalDelete do |h|
    h.description "Check app global deleting"
    h.argument :key, String, "key"
  end
  define_hook :hAppGlobalRead do |h|
    h.description "Check app global storing"
    h.argument :key, String, "key"
    h.result :value, String, nil, "value"
  end
  define_hook :hTestInterPluginService do |h|
    h.description "Check inter-plugin services"
    h.result :value, String, nil, "value"
  end
  define_hook :hTestSessionOutsideRequest do |h|
    h.description "Check session access fails outside request"
    h.result :called, String, nil, "Test called flag"
  end
  define_hook :hTestScheduleBackgroundTask do |h|
    h.description "Set a background task for the jobs test"
    h.argument :value, String, "value"
  end
  define_hook :hTestMultipleHookDefinitionsInOnePlugin do |h|
    h.description "Using plugin.hook(), check that all functions are called"
    h.result :passedThrough, String, "''", "list"
  end
  define_hook :hTestPlugin3OnLoadOK do |h|
    h.description "Check onLoad was successful for test_plugin3"
    h.result :ok, "bool", nil, "In request?"
  end
  define_hook :hTotallyUnimplementedHook do |h|
    h.description "Do not implement this hook anywhere"
  end
end

