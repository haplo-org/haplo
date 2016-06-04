# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KJSPluginRuntime
  RUNTIME_CACHE = KApp.cache_register(KJSPluginRuntime, "JavaScript runtimes")
  Runtime = Java::OrgHaploJavascript::Runtime

  JS_PLUGIN_RUNTIME_HEALTH_REPORTER = KFramework::HealthEventReporter.new("JS_PLUGIN_RUNTIME")

  # Listen for notifications which require invalidation of the runtime.
  # Use buffering so that when something requiring an invalidation happens when the runtime is in use,
  # the notification is delayed until the nested stack of runtime invocations has exited.
  @@invalidate_notification_buffer = KNotificationCentre.when_each([
    [:jspluginruntime_internal, :invalidation_requested],
    [:os_schema_change],
    [:app_global_change, :javascript_config_data],
    [:plugin,            :install],
    [:plugin,            :uninstall],
    [:user_modified,     :group]
  ], {:deduplicate => true, :max_arguments => 0}) do # max arguments set to zero so every notification counts the same
    KApp.cache_invalidate(RUNTIME_CACHE)
  end

  def self.invalidate_all_runtimes
    # Delay the invalidation until the runtime has exited -- this is called from the JS API
    KNotificationCentre.notify(:jspluginruntime_internal, :invalidation_requested)
  end

  def self.current
    KApp.cache(RUNTIME_CACHE)
  end

  def self.current_if_active
    KApp.cache_if_already_checked_out(RUNTIME_CACHE)
  end

  def initialize
    # This is repeated in the rescue for kapp_cache_checkout to recover
    @runtime = Runtime.new
  end

  def runtime
    @runtime
  end

  # Keep track of nested calls into the JavaScript runtime, using the notification buffer to track the depth
  # Returns the value of the yielded block.
  def using_runtime
    @@invalidate_notification_buffer.while_buffering do
      yield
    end
  end

  # For plugin test scripts support
  def _test_get_support_root
    @support_root
  end

  def currently_executing_plugin_name
    @support_root ? @support_root.getCurrentlyExecutingPluginName() : nil
  end

  def make_json_parser
    @runtime.makeJsonParser()
  end

  def kapp_cache_checkout
    raise "Bad state for KJSPluginRuntime" if @support_root != nil
    # Set the SYSTEM user as active during code loading (which could do things like making queries),
    # and when the the onLoad() function is called. Otherwise it's not predictable which user is active,
    # and the plugin may not have sufficient permissions, or schema loading may not be able to see
    # all the objects it needs.
    AuthContext.with_system_user do
      AuthContext.lock_current_state
      # JSSupportRoot implementation requires that a new object is created every time the runtime is checked out
      @support_root = JSSupportRoot.new
      @runtime.useOnThisThread(@support_root)
      begin
        unless @plugins_loaded
          ms = Benchmark.ms do
            # Quick check that nothing has been loaded into this runtime yet
            unless 0 == @runtime.host.getNumberOfPluginsRegistered()
              raise "Runtime in bad state - already has plugins registered."
            end
            # Load basic schema information into runtime
            @runtime.evaluateString(KSchemaToJavaScript.schema_to_js(KObjectStore.schema), "<schema>")
            # Parse the plugin schema requirements so it can be passed to the plugins when loading
            schema_for_js_runtime = SchemaRequirements::SchemaForJavaScriptRuntime.new()
            db_namespaces = DatabaseNamespaces.new
            using_runtime do
              # Go through each plugin, and ask it to load the JavaScript code
              KPlugin.get_plugins_for_current_app.each do |plugin|
                database_namespace = plugin.uses_database ? db_namespaces[plugin.name] : nil
                # This check prevents unexpected registrations by plugin code, and sets the database namespace for the plugin.
                @runtime.host.setNextPluginToBeRegistered(plugin.name, database_namespace)
                plugin.javascript_load(@runtime, schema_for_js_runtime)
                @runtime.host.setNextPluginToBeRegistered(nil, nil)
              end
              @runtime.host.callAllPluginOnLoad()
            end
            @plugins_loaded = true
          end
          KApp.logger.info("Initialised application JavaScript runtime, took #{ms.to_i}ms\n")
        end
      rescue
        # If there's an exception when loading, reset the state of the runtime so the Java side doesn't think there's a Runtime on this thread
        clear_runtime_run_state
        # and then replace the runtime itself so everything is nice and clean for the next run
        @runtime = Runtime.new
        # then re-raise the error
        raise
      end
    end
  end

  class DatabaseNamespaces
    def initialize
      @namespaces = YAML::load(KApp.global(:plugin_db_namespaces) || '') || {}
    end
    def [](plugin_name)
      namespace = @namespaces[plugin_name]
      return namespace if namespace
      safety = 256
      while safety > 0
        safety -= 1
        r = KRandom.random_hex(3)
        unless @namespaces.has_value?(r)
          @namespaces[plugin_name] = r
          KApp.set_global(:plugin_db_namespaces, YAML::dump(@namespaces))
          return r
        end
      end
      raise "Couldn't allocate database namespace"
    end
  end

  def clear_runtime_run_state
    use_depth = @@invalidate_notification_buffer.buffering_depth
    if use_depth != 0
      JS_PLUGIN_RUNTIME_HEALTH_REPORTER.log_and_report_exception(nil, "Probable logic error: Clearing JavaScript runtime state when use depth = #{use_depth}")
      if KFRAMEWORK_ENV != 'production'
        raise "Invalid use depth when clearing JS runtime state"
      end
    end
    @runtime.stopUsingOnThisThread()
    @support_root.clear
    @support_root = nil
  end

  def kapp_cache_checkin
    clear_runtime_run_state
  end
  alias kapp_cache_invalidated kapp_cache_checkin

  def call_all_hooks(args)
    using_runtime do
      @runtime.host.callHookInAllPlugins(args)
    end
  end

  def make_response(ruby_response, runner)
    js_response = Java::OrgHaploJsinterface::KPluginResponse.make(runner.class.instance_variable_get(:@_RESPONSE_FIELDS))
    runner.response_r_to_j(ruby_response, js_response)
    js_response.prepareForUse()
    js_response
  end

  def retrieve_response(ruby_response, js_response, runner)
    runner.response_j_to_r(ruby_response, js_response)
  end

  def get_file_upload_instructions(plugin_name, path)
    using_runtime do
      @runtime.host.getFileUploadInstructions(plugin_name, path)
    end
  end

  def call_request_handler(plugin_name, method, path)
    using_runtime do
      @runtime.host.callRequestHandler(plugin_name, method, path)
    end
  end

  def call_search_result_render(object)
    host = @runtime.host
    return nil unless host.doesAnyPluginRenderSearchResults()
    using_runtime { host.callRenderSearchResult(object) }
  end

  def call_fast_work_unit_render(work_unit, context)
    using_runtime do
      Java::OrgHaploJsinterface::KWorkUnit.fastWorkUnitRender(work_unit, context)
    end
  end
  def call_work_unit_render_for_event(event_name, work_unit)
    using_runtime do
      Java::OrgHaploJsinterface::KWorkUnit.workUnitRenderForEvent(event_name, work_unit)
    end
  end

  KNotificationCentre.when(:jsfiletransformpipeline, :pipeline_result) do |name, operation, result|
    # Changing this mechanism will break the test which checks the notifications
    # happen in the right order.
    KJSPluginRuntime.current._call_file_transform_pipeline_callback(result)
  end
  def _call_file_transform_pipeline_callback(pipeline_result)
    using_runtime do
      Java::OrgHaploJsinterface::KFilePipelineResult.callback(pipeline_result)
    end
  end

end

