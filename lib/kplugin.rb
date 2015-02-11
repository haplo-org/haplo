# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Trusted plugins live in app/plugins/<name>
# Class for the example_stuff plugin is named as ExampleStuffPlugin
# A new KPlugin derived object is created for every request which needs it.

class KPlugin

  # Plugins are loaded in priority then name order. If a priority is not specified, the default is
  # a large number to load those plugins last.
  DEFAULT_PLUGIN_LOAD_PRIORITY = 9999999

  # -----------------------------------------------------------------------------------------------------------------
  # Plugin information via annotations

  extend Ingredient::Annotations
  class << self
    def _PluginName(name)
      annotate_class(:plugin_name, name)
    end
    def _PluginDescription(desc)
      annotate_class(:plugin_description, desc)
    end
  end

  def self.plugin_name
    annotation_get_class(:plugin_name)
  end
  def self.plugin_description
    annotation_get_class(:plugin_description)
  end

  # -----------------------------------------------------------------------------------------------------------------
  # Plugin implementation

  # Initialized with a reference to the factory
  def initialize(factory)
    @_factory = factory
  end

  def factory
    @_factory
  end

  # Find the path on disc where this plugin lives -- use for finding resources
  def plugin_path
    "#{KFRAMEWORK_ROOT}/app/plugins/#{PLUGIN_CLASS_TO_NAME[self.class]}"
  end

  # Return a PluginController derived class if the plugin would like to handle this request.
  # Called whenever a URL is requested which is not handled by the core controllers.
  def controller_for(path_element_name, other_path_elements, annotations)
    nil
  end

  alias implements_hook? respond_to?

  def is_javascript_plugin?
    false
  end

  # Get the current controller
  def controller
    @_controller ||= begin
      rc = KFramework.request_context
      (rc == nil) ? nil : rc.controller
    end
  end

  # -----------------------------------------------------------------------------------------------------------------
  # Installation

  # Called when the plug is installed (or reinstalled)
  # Plugin should cope with it being called multiple times.
  def on_install
  end

  # -----------------------------------------------------------------------------------------------------------------
  # Plugin file handling
  # Plugin files are non-private files served through the dynamic file interface, like app CSS files.
  # Served as /~<serial>/<plugin path_component>/<plugin filename>
  # IMPORTANT: Use a controller for generating anything which might change regularly, be per-user, or need authentication.

  PLUGIN_STATIC_FILENAME_ALLOWED_REGEX = /\A([a-zA-Z0-9_-]+)\.([a-zA-Z0-9]+)\z/

  # Get an array of plugin files
  def get_allowed_plugin_filenames
    static_files_dir = "#{plugin_path}/static"
    return nil unless File.directory?(static_files_dir)
    Dir.entries(static_files_dir).select do |n|
      n =~ PLUGIN_STATIC_FILENAME_ALLOWED_REGEX && n !~ /\A\./ # extra paranoid check to avoid starting with .
    end
  end

  # Return a plugin file from the static dir - override this for more interesting functionality.
  # Return [:file, pathname] for a file on disc, [:data, string] for static data, or nil for not found.
  # MIME type is automatically generated from the file extension
  def get_plugin_file(filename)
    # Security check, to make sure it's a filename without any traversal attempts
    # TODO: Test for plugin files security check to avoid traversal of filesystem (low risk as there's a filter on allowed filenames)
    return nil unless filename =~ PLUGIN_STATIC_FILENAME_ALLOWED_REGEX
    extension = $2
    # Make the pathname within the static files directory
    pathname = "#{plugin_path}/static/#{filename}"
    return nil unless File.exists?(pathname)
    if extension == 'css'
      [:data, plugin_rewrite_css(File.open(pathname) { |f| f.read })]
    else
      [:file, pathname]
    end
  end

  # The url path where the static files appear to the client
  def static_files_urlpath
    "/~#{KApp.global(:appearance_update_serial)}/#{@_factory.path_component}"
  end

  # Rewrite CSS
  ALLOWED_COLOUR_NAMES = {
    "MAIN" => :main,
    "SECONDARY" => :secondary,
    "HIGHLIGHT" => :highlight
  }
  def plugin_rewrite_css(css)
    css.
      gsub('PLUGIN_STATIC_PATH', static_files_urlpath).
      gsub(/APPLICATION_COLOUR_([A-Z]+)/) do
        name = ALLOWED_COLOUR_NAMES[$1]
        name ? "##{KApplicationColours.get_colour(name)}" : "#f0f"
      end
  end

  # -----------------------------------------------------------------------------------------------------------------

  # Method to call hooks
  # Will yield the runner only if necessary. Do all data collection inside the block as most times it won't be called.
  module HookSite
    class HookRunner
      def initialize(plugin_factories)
        @plugin_factories = plugin_factories
        # Make a response object
        @response = self.class.instance_variable_get(:@_RESPONSE).new
      end
      attr_reader :response # so it can be modified before the hook is run in case a default can't be set sensibly
      def run2(args)
        hook_name = self.class.instance_variable_get(:@_NAME)
        # Run through each plugin, calling the hook function
        call_javascript = false
        @plugin_factories.each do |factory|
          plugin = factory.plugin_object
          if plugin.is_javascript_plugin?
            call_javascript = true
          else
            plugin.send(hook_name, @response, *args)
            return @response if @response.stopChain     # a plugin can stop the chain
          end
        end
        if call_javascript
          KJavaScriptPlugin.reporting_errors do
            jsplugins = KJSPluginRuntime.current
            jsresponse = jsplugins.make_response(@response, self)
            jsplugins.call_all_hooks(jsargs(hook_name, jsresponse, args))
            jsplugins.retrieve_response(@response, jsresponse, self)
          end
        end
        @response
      end
    end
    class HookResponse
      attr_accessor :stopChain  # Set to true if the plug wants to stop other plugins in the chain being called
    end

    def call_hook(hook_name)
      runner_class = KHooks::HOOKS[hook_name]
      raise "Hook not defined: #{hook_name}" if runner_class == nil
      responding_plugins = KPlugin.get_plugins_for_current_app.get_plugins_for_hook(hook_name)
      # Optimise the most likely case where there aren't any plugins
      return if responding_plugins.empty?
      # There are some plugins, so instantiate a runner
      runner = runner_class.new(responding_plugins)
      # And yield so the caller can use the hooks
      yield runner
    end
  end

  # -----------------------------------------------------------------------------------------------------------------

  # Manages plugins, used as the object in the KApp cache
  class PluginsForApp
    def initialize
      @hooks_cache = Hash.new
    end

    def plugin_factories
      @plugin_factories ||= begin
        # Load the list of plugins
        factories = Array.new
        ip = YAML::load(KApp.global(:installed_plugins) || '')
        if ip.class == Array
          ip.each do |installed_plugin|
            # Load the plugin?
            if installed_plugin[:state] == :active
              plugin_factory = KPlugin.new_plugin_factory(installed_plugin[:name], installed_plugin[:path])
              if plugin_factory != nil
                factories << plugin_factory
              else
                KApp.logger.warn "Failed to load plugin factory #{installed_plugin[:name]}"
              end
            end
          end
        end
        # Sort by plugin factories by priority, then by name
        factories.sort do |a,b|
          pri_a = a.plugin_load_priority
          pri_b = b.plugin_load_priority
          (pri_a == pri_b) ? (a.name <=> b.name) : (pri_a <=> pri_b)
        end
      end
    end

    def kapp_cache_checkout
      # Ask the factories to create the plugin objects
      plugin_factories.each { |factory| factory.begin_request }
    end

    def kapp_cache_checkin
      # Make sure any plugin objects are't kept around using memory after a request - especially if they have references to controller objects!
      plugin_factories.each { |factory| factory.reset_plugin_object }
    end
    alias kapp_cache_invalidated kapp_cache_checkin

    def get_plugin_by_name(name)
      factory = plugin_factories.find { |factory| factory.name == name }
      return nil if factory == nil
      factory.plugin_object
    end

    def get_plugin_by_path_component(path_component)
      factory = plugin_factories.find { |factory| factory.path_component == path_component }
      return nil if factory == nil
      factory.plugin_object
    end

    def get_plugins_for_hook(hook_name)
      @hooks_cache[hook_name] ||= plugin_factories.select { |factory| factory.plugin_object.implements_hook?(hook_name) }
    end

    # Ask all the plugins if they'd like to handle this request, returning a controller class or nil
    def controller_for(path_element_name, other_path_elements, annotations)
      controller = nil
      plugin_factories.find do |factory|
        controller = factory.plugin_object.controller_for(path_element_name, other_path_elements, annotations)
        controller != nil
      end
      controller
    end
  end

  # The PluginsForApp stores a list of PluginFactory objects. These:
  #   * Create a plugin object on demand
  #   * Discard any previous plugin object at the beginning of each request
  #   * Keep track of the plugin files path component
  # For the same plugin, each app will have it's own factory object for isolation.
  class PluginFactory < Struct.new(:klass, :name, :path_component)
    def is_javascript_factory?
      false
    end
    def begin_request
      raise "PluginFactory in wrong state" unless @plugin_object == nil
      @plugin_object = self.klass.new(self)
    end
    def reset_plugin_object
      @plugin_object = nil
    end
    attr_reader :plugin_object
    def plugin_name
      self.klass.plugin_name
    end
    def plugin_load_priority
      DEFAULT_PLUGIN_LOAD_PRIORITY
    end
    def plugin_description
      self.klass.plugin_description
    end
    def javascript_load(runtime)
      # Do nothing for non-JavaScript plugins
    end
  end

  # Given a name, instantiate a plugin factory object
  def self.new_plugin_factory(name, path_component)
    klass = PLUGIN_NAME_TO_CLASS[name]
    if klass != nil
      PluginFactory.new(klass, name, path_component)
    else
      KJavaScriptPlugin.make_factory(name, path_component)
    end
  end

  # Installs one or more plugins
  # Returns true on success, otherwise an exception will be raised
  def self.install_plugin(names, reason = :install)
    success = true
    names = [names] unless names.kind_of?(Enumerable)
    installable_names = names.select do |name|
      KJavaScriptPlugin.plugin_registered?(name) || PLUGIN_NAME_TO_CLASS.has_key?(name)
    end
    return false unless installable_names.length == names.length
    self._add_plugins_to_installed_list(installable_names)
    # Send notification about plugin changes (flushes lots of caches, including the JS runtime again)
    KNotificationCentre.notify(:plugin, :install, installable_names, reason)
    # Tell each plugin it was installed
    installable_names.each do |name|
      begin
        AuthContext.with_system_user do
          self.get(name).on_install
        end
      rescue => e
        # Log the exception raised during installation, then raise it again to pass it on
        KApp.logger.error("While running plugin installation for #{name}, got exception #{e}")
        raise
      end
    end
    true
  end

  # This is in a seperate method for ease of testing
  def self._add_plugins_to_installed_list(names)
    updating_installed_plugins_list do |plugins|
      names.each do |name|
        plugins.delete_if { |e| e[:name] == name }
        # Find an unused plugin path component
        used_path_components = {}
        path_component = 'a'
        plugins.each do |plugin|
          path_component = plugin[:path]
          used_path_components[path_component] = true
        end
        while used_path_components[path_component]
          path_component = path_component.succ
        end
        plugins.push({:name => name, :state => :active, :path => path_component})
      end
      plugins
    end
  end

  # Uninstall a plugin
  def self.uninstall_plugin(name)
    updating_installed_plugins_list do |plugins|
      plugins.delete_if { |e| e[:name] == name }
    end
    KNotificationCentre.notify(:plugin, :uninstall, [name.to_s])
    true
  end

  # -----------------------------------------------------------------------------------------------------------------

  # Build the map of plugin name -> plugin class as the code is loaded
  # Assumes all trusted plugin code is loaded the app server starts - not threadsafe otherwise
  PLUGIN_NAME_TO_CLASS = Hash.new
  PLUGIN_CLASS_TO_NAME = Hash.new
  class << self
    def inherited(plugin_class)
      name = plugin_class.name.gsub(/Plugin\z/,'').underscore
      PLUGIN_NAME_TO_CLASS[name] = plugin_class
      PLUGIN_CLASS_TO_NAME[plugin_class] = name
    end
  end

  # -----------------------------------------------------------------------------------------------------------------

  # Get all the possible plugin file pathnames
  def self.get_all_plugin_file_pathnames
    pathnames = Java::ComOneisFramework::Application::PluginFilePathnames.new
    get_plugins_for_current_app.plugin_factories.each do |plugin_factory|
      plugin = plugin_factory.plugin_object
      allowed_pathnames = plugin.get_allowed_plugin_filenames
      if allowed_pathnames != nil
        allowed_pathnames.each { |n| pathnames.addAllowedPathname("#{plugin_factory.path_component}/#{n}") }
      end
    end
    pathnames
  end

  # Generate a response given a plugin filename
  def self.generate_plugin_file_response(pathname)
    return nil unless pathname =~ /\A([a-z]+)\/(.+)\.(\w+?)\z/
    plugin_path_component = $1
    plugin_file_pathname = $2
    plugin_file_extension = $3
    # Find the plugin
    plugin_factory = get_plugins_for_current_app.plugin_factories.find { |f| f.path_component == plugin_path_component }
    return nil unless plugin_factory != nil
    plugin = plugin_factory.plugin_object
    # MIME type
    mime_type = (KFramework::STATIC_MIME_TYPES[plugin_file_extension] || 'application/octet-stream')
    # Get the file and generate a response
    kind, info = plugin.get_plugin_file("#{plugin_file_pathname}.#{plugin_file_extension}")
    if kind == :file
      Java::ComOneisAppserver::StaticFileResponse.new(info, mime_type, mime_type !~ /\Aimage/i)
    elsif kind == :data
      Java::ComOneisAppserver::StaticFileResponse.new(info.to_java_bytes, mime_type, mime_type !~ /\Aimage/i)
    else
      nil
    end
  end

  # -----------------------------------------------------------------------------------------------------------------

  PLUGINS_CACHE = KApp.cache_register(PluginsForApp, "Plugins cache")

  # Helper to get the list of plugins (cached)
  def self.get_plugins_for_current_app
    KApp.cache(PLUGINS_CACHE)
  end

  # Get the names of all plugins installed in the current app
  def self.get_plugin_names_for_current_app
    self.get_plugins_for_current_app.plugin_factories.map { |factory| factory.name }
  end

  # Helper to get a specific plugin for the app, given a class for the plugin. Handy in plugin controllers.
  def self.get(name)
    factory = if name.instance_of? Class
      get_plugins_for_current_app.plugin_factories.find { |factory| factory.klass == name }
    else
      get_plugins_for_current_app.plugin_factories.find { |factory| factory.name == name }
    end
    (factory == nil) ? nil : factory.plugin_object
  end

  # Modify the list of installed plugins
  def self.updating_installed_plugins_list
    installed_plugins = YAML::load(KApp.global(:installed_plugins) || '')
    installed_plugins = Array.new unless installed_plugins.class == Array
    installed_plugins = yield installed_plugins
    if installed_plugins != nil
      KApp.set_global(:installed_plugins, YAML::dump(installed_plugins))
    end
  end

  # Listen for notification which require the cached list of plugins to be invalidated
  KNotificationCentre.when_each([
    [:plugin]                         # installations and reconfigurations
  ]) do
    KApp.cache_invalidate(PLUGINS_CACHE)
  end

end
