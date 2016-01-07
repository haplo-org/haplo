# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module JavaScriptTestHelper

  Runtime = Java::ComOneisJavascript::Runtime

  # Make a runtime which also loads in the testing framework
  def make_javascript_runtime
    runtime = Runtime.new
    runtime.useOnThisThread(JSSupportRoot.new)
    runtime.loadScript(KFRAMEWORK_ROOT+'/test/lib/javascript/testing.js', 'test/lib/javascript/testing.js', nil, nil)
    runtime.stopUsingOnThisThread()
    runtime
  end

  # Run a JavaScript test in a framework managed runtime
  def run_javascript_test(kind, input, predefines = nil, with_plugin_name = "UNSPECIFIED_TEST_PLUGIN", keep_runtime = :invalidate)
    predefines ||= {}
    # Add line numbers into the javascript, because it appears to be impossible to get a stack trace out of Rhino
    debug_filename = nil
    line_number = 1
    javascript = if kind == :file
      input =~ /([^\/]+)\z/
      debug_filename = $1
      File.open("#{File.dirname(__FILE__)}/../#{input}") { |f| f.read }
    else
      # NOTE: JRuby 1.5.3 contains a bug where the line number if Kernel.caller is the line number of the last insert in the heredoc
      Kernel.caller.first =~ /([^\/]+):(\d+)/
      debug_filename = $1
      line_number = $2.to_i + 1
      input
    end
    javascript = javascript.split(/\n/).map do |line|
      line = line.gsub(/TEST.(assert|assert_equal|assert_exceptions)\(/) do
        "TEST.#{$1}('#{debug_filename}:#{line_number}', "
      end
      line_number += 1
      line
    end .join("\n")
    # Run the test
    runtime = KJSPluginRuntime.current.runtime
    # Load the test framework code
    runtime.loadScript(KFRAMEWORK_ROOT+'/test/lib/javascript/testing.js', 'test/lib/javascript/testing.js', nil, nil)
    # Set the predefined variables in the runtime
    runtime.evaluateString("_.extend(this,#{predefines.to_json});\n", "<test-predefines>")
    yield runtime if block_given?
    begin
      KJSPluginRuntime.current.using_runtime do
        runtime.evaluateString(javascript, "p/#{with_plugin_name}/#{debug_filename}")
      end
    ensure
      unless keep_runtime == :preserve_js_runtime
        KApp.cache_invalidate(KJSPluginRuntime::RUNTIME_CACHE)
      end
    end
    result = runtime.host.jsGet__debug_string()
    if result == 'OK'
      assert true # passed
    else
      flunk(result) # failed
    end
    # Return the runtime used
    runtime
  end

  def run_javascript_test_with_file_pipeline_callback(*args)
    run_javascript_test(*args) do |runtime|
      runtime.host.setTestCallback(proc { |string|
        if string == "Check temp files exist"
          assert have_file_pipeline_temp_files?
        else
          # Implement just enough of the job runner to run the pipeline jobs in this thread and runtime
          pg = KApp.get_pg_database
          jobs = pg.exec("SELECT id,object FROM jobs WHERE queue=#{KJob::QUEUE_FILE_TRANSFORM_PIPELINE} AND application_id=#{_TEST_APP_ID}").result
          assert_equal string.to_i, jobs.length
          jobs.each do |id,serialised|
            job = Marshal.load(PGconn.unescape_bytea(serialised))
            context = KJob::Context.new
            job.run(context)
            pg.exec("DELETE FROM jobs WHERE id=#{id}")
          end
        end
      })
    end
  end

  def have_file_pipeline_temp_files?
    Dir.glob("#{FILE_UPLOADS_TEMPORARY_DIR}/tmp.pipeline.#{Thread.current.object_id}.*").length > 0
  end

  def drop_all_javascript_db_tables
    db = KApp.get_pg_database
    sql = "SELECT table_schema,table_name FROM information_schema.tables WHERE table_schema='a#{KApp.current_application}' AND table_name LIKE 'j_%' ORDER BY table_name"
    drop = "BEGIN; SET CONSTRAINTS ALL DEFERRED; "
    r = db.exec(sql)
    r.each do |table_schema,table_name|
      drop << "DROP TABLE IF EXISTS #{table_name} CASCADE; " # IF EXISTS required because of CASCADE
    end
    r.clear
    drop << "COMMIT"
    db.perform(drop) if drop.include?('TABLE')
  end

  # -----------------------------------------------------------------------------------------------------------------

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/test_plugins/no_privileges_plugin")

  USER_FIXTURES = [:users, :user_memberships, :user_datas, :policies, :permission_rules, :latest_requests]

  REGISTERED_GRANT_PRIVS_LOCK = Mutex.new
  REGISTERED_GRANT_PRIVS = {}

  def install_grant_privileges_plugin_with_privileges(*privs)
    # Create a new plugin object, then hack in the privileges required by the test
    grant_privileges_plugin = KJavaScriptPlugin.new("#{File.dirname(__FILE__)}/javascript/test_plugins/grant_privileges_plugin")
    grant_privileges_plugin.plugin_json["privilegesRequired"].clear.push(*(privs || []))
    # Register the plugin as a private plugin for the application under test to avoid a race conditions with multiple threads sharing the same one
    KPlugin.register_plugin(grant_privileges_plugin, KApp.current_application)
    # Also install the no_privileges_plugin, which has a hook which is called at inoppourtune times
    # and makes sure that the last used plugin tracking works correctly.
    KPlugin.install_plugin(["grant_privileges_plugin", "no_privileges_plugin"])
  end

  def uninstall_grant_privileges_plugin
    KPlugin.uninstall_plugin("grant_privileges_plugin")
    KPlugin.uninstall_plugin("no_privileges_plugin")
  end

end
