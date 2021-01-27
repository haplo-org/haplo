# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2021            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KJavaScriptPluginBuiltin < KJavaScriptPlugin

  BUILT_IN_JAVASCRIPT_PLUGINS_DIR = "#{KFRAMEWORK_ROOT}/app/plugins"
  BUILT_IN_JAVASCRIPT_PLUGINS = []

  # Register built in plugins
  KPlugin::REGISTER_KNOWN_PLUGINS << Proc.new do
    Dir.glob("#{BUILT_IN_JAVASCRIPT_PLUGINS_DIR}/*/plugin.json").sort.each do |filename|
      begin
        plugin = KJavaScriptPluginBuiltin.new(File.dirname(filename))
        KPlugin.register_plugin(plugin)
        BUILT_IN_JAVASCRIPT_PLUGINS << plugin
      rescue => e
        # Too early in the application boot process for logging
        puts "\n\n*******\nWhile registering built-in JavaScript plugin #{filename}, got exception #{e}"; puts
      end
    end
  end

  def self.load_builtins_into_shared_js_scope(loader)
    loader.evaluateString("this.$stdplugin = {};\n", "<$stdplugin>")
    # Fake some schema requirements so the function wrappers around each plugin file can be generated
    # TODO: This is a little bit of a hack, is it necessary to do it more accurately?
    schema_for_plugin = {}
    BUILT_IN_JAVASCRIPT_PLUGINS.each do |plugin|
      requirements_pathname = "#{plugin.plugin_path}/requirements.schema"
      if File.exist?(requirements_pathname)
        req = {"attribute"=>{}} # attribute always exists
        req["group"] = {} if File.read(requirements_pathname) =~ /^group/m
        schema_for_plugin[plugin.name] = req
      end
    end
    schema_for_js_runtime = SchemaRequirements::SchemaForJavaScriptRuntime.new(schema_for_plugin)
    # Load all the plugin code into the shared scope, and whilelist the global variable
    BUILT_IN_JAVASCRIPT_PLUGINS.each do |plugin|
      plugin.javascript_load_for_shared_scope(loader, schema_for_js_runtime)
    end
  end

  # -------------------------------------------------------------------------

  def javascript_loader_symbol
    return "$stdplugin.$#{name}__stdload__"
  end

  alias super_javascript_load javascript_load

  def javascript_load_for_shared_scope(loader, schema_for_js_runtime)
    super_javascript_load(loader, schema_for_js_runtime)
  end

  def javascript_load(loader, schema_for_js_runtime)
    # Do nothing for application runtimes, as the code is already in the shared scope
  end

end
