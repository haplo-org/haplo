# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class DeveloperJSPluginRuntime < KJSPluginRuntime

  RELOADABLE_RUNTIMES = Hash.new
  RELOADABLE_RUNTIMES_LOCK = Mutex.new

  def ensure_java_js_runtime
    if @runtime == nil
      @runtime = RELOADABLE_RUNTIMES_LOCK.synchronize { RELOADABLE_RUNTIMES.delete(KApp.current_application) }
      is_new_runtime = false
      if @runtime == nil
        @runtime = Runtime.new
        is_new_runtime = true
      end
      KApp.logger.info("JavaScript runtime initialising with developer mode loading. (#{is_new_runtime ? 'New' : 'Reusing'} runtime)")
      cx = Runtime.enterContext()
      begin
        jsscope = @runtime.getJavaScriptScope()
        if is_new_runtime
          cx.evaluateString(jsscope, FASTER_LOAD_JS, "<faster-load>", 1, nil);
          @__loader_plugin_versions = {}
        else
          # Find out which versions of plugins are already parsed
          fn = jsscope.get("$fasterLoadGetVersions", jsscope)
          versions_json = fn.call(cx, jsscope, fn, [])
          @__loader_plugin_versions = JSON.parse(versions_json)
          # Reset the runtime so it can be reused
          @runtime.reinitialiseRuntime()
        end
      ensure
        Java::OrgMozillaJavascript::Context.exit()
      end
      @__loader_plugins_parsed = 0
    end
  end

  def load_plugin_into_runtime(plugin, schema_for_js_runtime, database_namespace)
    return unless plugin.kind_of? KJavaScriptPlugin
    if plugin.__loader_version == @__loader_plugin_versions[plugin.name]
      # Required version of plugin is already parsed in JS runtime, don't need to repeat
      return
    end
    global_js = plugin.javascript_generate_global_js()
    prefix, _, loadargs = plugin.javascript_file_wrappers(schema_for_js_runtime)
    plugin_setup = "$fasterLoad.plugin.#{plugin.name} = #{JSON.generate({
      "global" => global_js,
      "version" => plugin.__loader_version,
      "loadargs" => loadargs
    })}; $fasterLoad.pluginJSFiles.#{plugin.name} = [];\n"
    @runtime.evaluateString(plugin_setup, "<faster-setup-#{plugin.name}>")
    prefix = "$fasterLoad.pluginJSFiles.#{plugin.name}.push#{prefix}"
    suffix = "\n});"
    plugin.javascript_load_all_js(@runtime, prefix, suffix)
    @__loader_plugins_parsed += 1
  end

  def finalise_plugin_load(db_namespaces)
    jsscope = @runtime.getJavaScriptScope()
    jscontext = @runtime.getContext()
    load_fn = jsscope.get("$fasterLoadPlugin", jsscope)
    plugins = KPlugin.get_plugins_for_current_app
    plugins.each do |plugin|
      if plugin.kind_of? KJavaScriptPlugin
        database_namespace = plugin.uses_database ? db_namespaces[plugin.name] : nil
        @runtime.host.setNextPluginToBeRegistered(plugin.name, database_namespace)
        load_fn.call(jscontext, jsscope, load_fn, [plugin.name])
        @runtime.host.setNextPluginToBeRegistered(nil, nil)
      end
    end
    KApp.logger.info("Parsed #{@__loader_plugins_parsed} plugins out of #{plugins.length}")
  end

  def finalise_runtime_checkout()
    jsscope = @runtime.getJavaScriptScope()
    jscontext = @runtime.getContext()
    fn = jsscope.get("$fasterLoadRemoveCachedTemplates", jsscope)
    fn.call(jscontext, jsscope, fn, [nil != KPlugin.get("std_web_publisher")])
  end

  def _store_runtime_for_reloading
    RELOADABLE_RUNTIMES_LOCK.synchronize do
      RELOADABLE_RUNTIMES[KApp.current_application] = @runtime
    end
  end

  def kapp_cache_invalidated
    _store_runtime_for_reloading
    super
  end

  def kapp_cache_invalidated_inactive
    _store_runtime_for_reloading
  end

  FASTER_LOAD_JS = <<__E
    var $fasterLoadPlugin = function(pluginName) {
        var globalEval = eval;
        globalEval($fasterLoad.plugin[pluginName].global);
        var args = globalEval('['+$fasterLoad.plugin[pluginName].loadargs+']');
        $fasterLoad.pluginJSFiles[pluginName].forEach(function(fn) {
            fn.apply(this, args);
        });
    };
    var $fasterLoadGetVersions = function() {
        var versions = {};
        _.each($fasterLoad.plugin, function(i, name) {
            versions[name] = i.version;
        });
        return JSON.stringify(versions);
    };
    var $fasterLoadRemoveCachedTemplates = function(webPublisherInstalled) {
        var root = (function() { return this; })();
        _.each($fasterLoad.plugin, function(i, name) {
            if(root[name]) {
                root[name].$templates = {};
            }
        });
        if(webPublisherInstalled) {
            std_web_publisher.__removeCachedTemplates();
        }
    };
    var $fasterLoad = {
        plugin: {},
        pluginJSFiles: {}
    };
__E
end

class KJavaScriptPlugin
  def __loader_version
    @__loader_version || 0
  end
  def __loader_version=(version)
    @__loader_version = version
  end
end

module DeveloperRuntimeModeSwitch
  def self.new
    klass = Thread.current[:__developer_use_faster_loading] ? DeveloperJSPluginRuntime : KJSPluginRuntime
    klass.new
  end
  def self.faster_loading=(faster)
    Thread.current[:__developer_use_faster_loading] = faster
  end
end

KApp::CACHE_INFO[KJSPluginRuntime::RUNTIME_CACHE].cache_class = DeveloperRuntimeModeSwitch
puts "Installed DeveloperRuntimeModeSwitch as JS runtime cache class"
