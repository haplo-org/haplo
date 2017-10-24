# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# There is a single KPlugin derived object shared between every application, and every thread.
# Plugin objects are frozen to prevent accidentally using state.

class KPlugin

  # Plugins are loaded in priority then name order. If a priority is not specified, the default is
  # a large number to load those plugins last.
  DEFAULT_PLUGIN_LOAD_PRIORITY = 9999999

  # -----------------------------------------------------------------------------------------------------------------
  # Plugin implementation

  def name
    raise "Not implemented in base class"
  end

  # Find the path on disc where this plugin lives -- use for finding resources
  def plugin_path
    raise "Not implemented in base class"
  end

  def plugin_display_name
    raise "Not implemented in base class"
  end

  def plugin_description
    raise "Not implemented in base class"
  end

  def plugin_install_secret
    nil
  end

  def plugin_load_priority
    DEFAULT_PLUGIN_LOAD_PRIORITY
  end

  def plugin_depend
    []
  end

  def uses_database
    false
  end

  def parse_schema_requirements(parser)
    requirements_pathname = "#{self.plugin_path}/requirements.schema"
    if File.exist?(requirements_pathname)
      File.open(requirements_pathname) do |io|
        parser.parse(self.name, io)
      end
    end
  end

  def javascript_load(runtime, schema_for_js_runtime)
    # Do nothing for non-JavaScript plugins
  end

  # Return a PluginController derived class if the plugin would like to handle this request.
  # Called whenever a URL is requested which is not handled by the core controllers.
  def controller_for(path_element_name, other_path_elements, annotations)
    nil
  end

  def has_privilege?(privilege)
    false # JavaScript runtime concept
  end

  def implements_hook?(hook)
    false
  end

  def hook_needs_javascript_dispatch?(hook)
    false
  end

  # -----------------------------------------------------------------------------------------------------------------
  # Installation

  # Called when the plug is installed (or reinstalled)
  # Plugin should cope with it being called multiple times.
  def on_install
  end

  # -----------------------------------------------------------------------------------------------------------------
  # Plugin bundled file support

  PLUGIN_BUNDLED_PATHNAME_ALLOWED_REGEX = /\A([a-zA-Z0-9_-]+\/)*([a-zA-Z0-9_-]+)\.([a-zA-Z0-9]+)\z/

  def get_bundled_file_pathname(directory, pathname, restricted_mime_type_choice = true)
    # Security check, to make sure it's a filename without any traversal attempts
    unless pathname =~ PLUGIN_BUNDLED_PATHNAME_ALLOWED_REGEX
      KApp.logger.error("Possible attempted file traversal attack when reading plugin bundled file in #{directory}: #{pathname}")
      return nil
    end
    extension = $3
    # Make the pathname within the directory
    full_pathname = "#{plugin_path}/#{directory}/#{pathname}"
    return nil unless File.exists?(full_pathname)
    mime_type = KFramework::STATIC_MIME_TYPES[extension] # includes charset, because plugins must use UTF-8
    mime_type = KMIMETypes.type_from_extension(extension) unless mime_type || restricted_mime_type_choice
    mime_type ||= 'application/octet-stream'
    [full_pathname, extension,  mime_type]
  end

  # -----------------------------------------------------------------------------------------------------------------
  # Plugin data files -- files which are available to the JS runtime

  def get_plugin_data_file(pathname)
    pathname, extension, mime_type = get_bundled_file_pathname(:file, pathname, false)
    return nil if pathname == nil
    [pathname, File.basename(pathname), mime_type]
  end

  # -----------------------------------------------------------------------------------------------------------------
  # Plugin static file handling
  # Plugin static files are non-private files served through the dynamic file interface, like app CSS files.
  # Served as /~<serial>/<plugin path_component>/<plugin filename>
  # IMPORTANT: Use a controller for generating anything which might change regularly, be per-user, or need authentication.

  # Get an array of plugin static filenames
  def get_allowed_plugin_static_filenames
    static_files_dir = "#{plugin_path}/static"
    return nil unless File.directory?(static_files_dir)
    allowed = []
    without_dir = (static_files_dir.length+1) .. -1
    Dir.glob("#{static_files_dir}/**/*.*").each do |fullpath|
      n = fullpath[without_dir]
      allowed << n if n =~ PLUGIN_BUNDLED_PATHNAME_ALLOWED_REGEX && n !~ /(\A|\/)\./ # extra paranoid check to avoid starting with .
    end
    allowed
  end

  # Return a plugin file from the static dir - override this for more interesting functionality.
  # Return [:file, pathname] for a file on disc, [:data, string] for static data, or nil for not found.
  # MIME type is automatically generated from the file extension
  def get_plugin_static_file(filename)
    pathname, extension, mime_type = get_bundled_file_pathname(:static, filename)
    return nil unless pathname
    if extension == 'css'
      [:data, plugin_rewrite_css(File.open(pathname) { |f| f.read }), mime_type]
    else
      [:file, pathname, mime_type]
    end
  end

  # The url path where the static files appear to the client
  def static_files_urlpath
    # TODO: Move this somewhere else?
    plugins_for_app = KApp.cache(PLUGINS_CACHE)
    "/~#{KApp.global(:appearance_update_serial)}/#{plugins_for_app.get_path_component_by_name(self.name)}"
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
      def initialize(plugins, needs_javascript_dispatch)
        @plugins = plugins
        @needs_javascript_dispatch = needs_javascript_dispatch
        # Make a response object
        @response = self.class.instance_variable_get(:@_RESPONSE).new
      end
      attr_reader :response # so it can be modified before the hook is run in case a default can't be set sensibly
      def run2(args)
        hook_name = self.class.instance_variable_get(:@_NAME)
        # Run through each directly implementing plugin, calling the hook function
        @plugins.each do |plugin|
          plugin.__send__(hook_name, @response, *args)
          return @response if @response.stopChain     # a plugin can stop the chain
        end
        # Special case JavaScript as runtime handles calling the individual plugins
        if @needs_javascript_dispatch
          KJavaScriptPlugin.call_javascript_hooks(hook_name, self, @response, args)
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
      responding_plugins, needs_javascript_dispatch = KApp.cache(PLUGINS_CACHE).get_plugins_for_hook(hook_name)
      # Optimise the most likely case where there aren't any plugins
      return if responding_plugins.empty? && !(needs_javascript_dispatch)
      # There are some plugins, so instantiate a runner
      runner = runner_class.new(responding_plugins, needs_javascript_dispatch)
      # And yield so the caller can use the hooks
      yield runner
    end
  end

  # -----------------------------------------------------------------------------------------------------------------

  # Manages plugins, used as the object in the KApp cache
  class PluginList
    def initialize
      @plugins = []
      @plugins_by_name = Hash.new
    end

    def with_plugins(plugin_names)
      current_app = KApp.current_application
      PLUGINS_LOCK.synchronize do
        private_plugins = PRIVATE_PLUGINS[current_app]
        plugin_names.each do |name|
          plugin = private_plugins[name] || PLUGINS[name]
          if plugin != nil
            @plugins << plugin
            @plugins_by_name[name] = plugin
          else
            KApp.logger.warn "Plugin #{name} is not registered"
          end
        end
      end
      # Sort by plugins by priority, then by name
      @plugins.sort! do |a,b|
        pri_a = a.plugin_load_priority
        pri_b = b.plugin_load_priority
        (pri_a == pri_b) ? (a.name <=> b.name) : (pri_a <=> pri_b)
      end
      @plugins.freeze
      self
    end

    attr_reader :plugins

    def have_loaded_plugins?
      @plugins.frozen?
    end

    def get(name)
      @plugins_by_name[name]
    end
  end

  # -----------------------------------------------------------------------------------------------------------------

  class PluginsForApp < PluginList
    def initialize
      super
      @hooks_cache = Hash.new
      @plugin_paths = Hash.new
      @path_to_name = Hash.new
    end

    def kapp_cache_checkout
      return if have_loaded_plugins?
      # Can't read an app global in initialize, so delay loading plugin list until checkout
      plugin_names = []
      ip = YAML::load(KApp.global(:installed_plugins) || '')
      if ip.class == Array
        ip.each do |installed_plugin|
          if installed_plugin[:state] == :active
            name = installed_plugin[:name]
            plugin_names << name
            path = installed_plugin[:path]
            @plugin_paths[name] = path
            @path_to_name[path] = name
          end
        end
      end
      self.with_plugins(plugin_names)
    end

    def get_path_component_by_name(name)
      @plugin_paths[name]
    end

    def get_plugin_by_path_component(path_component)
      self.get(@path_to_name[path_component])
    end

    def get_plugins_for_hook(hook_name)
      @hooks_cache[hook_name] ||= begin
        javascript_disatch = false
        direct_implementation = @plugins.select do |plugin|
          javascript_disatch = true if plugin.hook_needs_javascript_dispatch?(hook_name)
          plugin.implements_hook?(hook_name)
        end
        [direct_implementation, javascript_disatch]
      end
    end

    # Ask all the plugins if they'd like to handle this request, returning a controller class or nil
    def controller_for(path_element_name, other_path_elements, annotations)
      @plugins.each do |plugin|
        controller = plugin.controller_for(path_element_name, other_path_elements, annotations)
        return controller if controller
      end
      nil
    end
  end

  # -----------------------------------------------------------------------------------------------------------------

  def self.controller_for(path_element_name, other_path_elements, annotations)
    KApp.cache(PLUGINS_CACHE).controller_for(path_element_name, other_path_elements, annotations)
  end

  # -----------------------------------------------------------------------------------------------------------------

  class InstallChecks
    def initialize
      @warnings = []
    end
    attr_accessor :failure
    def success?
      @warnings.empty? && @failure.nil?
    end
    def append_warnings(w)
      @warnings << w
    end
    def warnings
      @warnings.empty? ? nil : @warnings.join("\n\n")
    end
    def warnings_array
      @warnings
    end
  end

  # Installs one or more plugins
  # Returns true on success, otherwise an exception will be raised
  def self.install_plugin(names, reason = :install)
    nil == self.install_plugin_returning_checks(names, reason).failure
  end
  
  def self.install_plugin_returning_checks(names, reason = :install)
    install_check = InstallChecks.new
    names = names.kind_of?(Enumerable) ? names.to_a.dup : [names]
    # Expand names to include dependents
    dependent_check_start = 0
    while true
      start_check_length = names.length
      dependent_check_start.upto(names.length-1) do |i|
        proposed_plugin = get_plugin_without_installation(names[i])
        if proposed_plugin
          proposed_plugin.plugin_depend.each do |depend|
            names.push(depend) unless names.include?(depend)              
          end
        else
          KApp.logger.info("Plugin not registered during dependency resolution: #{names[i]}")
        end
      end
      break if names.length == dependent_check_start # no additions made
      dependent_check_start = start_check_length
    end
    # Generate a new list of plugins, checking that all requestred plugins can be installed
    new_plugin_names = KApp.cache(PLUGINS_CACHE).plugins.map { |plugin| plugin.name }
    new_plugin_names.concat(names).uniq!
    new_plugin_list = PluginList.new.with_plugins(new_plugin_names)
    names.each do |name|
      unless new_plugin_list.get(name)
        install_check.failure = "Plugin not registered: #{name}"
        return install_check
      end
    end
    # Pre-installation allocations
    KNotificationCentre.notify(:plugin_pre_install, :allocations, names, new_plugin_list.plugins)
    # Check that it's OK to install these plugins
    KNotificationCentre.notify(:plugin_pre_install, :check, names, new_plugin_list.plugins, install_check)
    if install_check.failure != nil
      KApp.logger.error("Plugin pre-installation checks failed: #{install_check.failure} for #{names.inspect}")
      return install_check
    end
    # Update installed plugin list app global
    self._add_plugins_to_installed_list(names)
    # Send notification about plugin changes (flushes lots of caches, including the JS runtime again)
    KNotificationCentre.notify(:plugin, :install, names, reason)
    # Tell _every_ plugin it was installed, as if a plugin uses a feature from another plugin it may
    # need to be updated too if the plugin is updated, and dependences only go in one direction.
    AuthContext.with_system_user do
      self.get_plugins_for_current_app.each { |plugin| plugin.on_install }
      KNotificationCentre.notify(:plugin_post_install, :final)
    end
    install_check
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

  REGISTER_KNOWN_PLUGINS = []
  def self.register_known_plugins
    REGISTER_KNOWN_PLUGINS.each { |p| p.call }
  end

  PLUGINS_LOCK = Mutex.new  # lock PLUGINS because registration can happen at any time
  PLUGINS = Hash.new
  PRIVATE_PLUGINS = Hash.new { |h,k| h[k] = {} }

  def self.register_plugin(plugin, private_for_application = nil)
    PLUGINS_LOCK.synchronize do
      # If private registration
      plugin_lookup = (private_for_application.nil? ? PLUGINS : PRIVATE_PLUGINS[private_for_application])
      plugin_lookup[plugin.name] = plugin.freeze # freeze to prevent accidental storage of state within plugin objects
    end
  end

  def self.get_plugin_without_installation(name)
    current_app = KApp.current_application
    PLUGINS_LOCK.synchronize do
      PRIVATE_PLUGINS[current_app][name] || PLUGINS[name]
    end
  end

  def self.plugin_registered?(name)
    !!(self.get_plugin_without_installation(name))
  end

  # Doesn't yield private plugins
  def self.each_registered_plugin
    PLUGINS_LOCK.synchronize do
      PLUGINS.each { |name,plugin| yield plugin }
    end
  end

  # -----------------------------------------------------------------------------------------------------------------

  # Get all the possible plugin static file pathnames
  def self.get_all_plugin_static_file_pathnames
    pathnames = Java::OrgHaploFramework::Application::PluginFilePathnames.new
    plugins_for_app = KApp.cache(PLUGINS_CACHE)
    plugins_for_app.plugins.each do |plugin|
      allowed_pathnames = plugin.get_allowed_plugin_static_filenames
      path_component = plugins_for_app.get_path_component_by_name(plugin.name)
      if allowed_pathnames != nil
        allowed_pathnames.each { |n| pathnames.addAllowedPathname("#{path_component}/#{n}") }
      end
    end
    pathnames
  end

  # Generate a response given a plugin static filename
  def self.generate_plugin_static_file_response(pathname)
    plugin_path_component, file_pathname = pathname.split('/',2)
    # Find the plugin
    plugin = KApp.cache(PLUGINS_CACHE).get_plugin_by_path_component(plugin_path_component)
    return nil unless plugin
    # Get the file and generate a response
    kind, info, mime_type = plugin.get_plugin_static_file(file_pathname)
    if kind == :file
      Java::OrgHaploAppserver::StaticFileResponse.new(info, mime_type, mime_type !~ /\Aimage/i)
    elsif kind == :data
      Java::OrgHaploAppserver::StaticFileResponse.new(info.to_java_bytes, mime_type, mime_type !~ /\Aimage/i)
    else
      nil
    end
  end

  # -----------------------------------------------------------------------------------------------------------------

  PLUGINS_CACHE = KApp.cache_register(PluginsForApp, "Plugins cache")

  # Helper to get the list of plugins (cached)
  def self.get_plugins_for_current_app
    KApp.cache(PLUGINS_CACHE).plugins
  end

  # Get the names of all plugins installed in the current app
  def self.get_plugin_names_for_current_app
    self.get_plugins_for_current_app.map { |plugin| plugin.name }
  end

  # Helper to get a specific plugin for the app, given a class for the plugin. Handy in plugin controllers.
  def self.get(name)
    KApp.cache(PLUGINS_CACHE).get(name)
  end

  def self.get_by_path_component(path_component)
    KApp.cache(PLUGINS_CACHE).get_plugin_by_path_component(path_component)
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
