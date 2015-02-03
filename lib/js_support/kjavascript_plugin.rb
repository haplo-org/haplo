# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Exception for throwing errors which may be reported to the developer
class JavaScriptAPIError < RuntimeError
end

class KJavaScriptPlugin < KPlugin

  def initialize(factory)
    super(factory)
  end

  def plugin_path
    self.factory.js_info.path
  end

  def is_javascript_plugin?
    true
  end

  def has_privilege?(privilege)
    # Plugin has all the privileges requested in the plugin.json file, checks done on install.
    (self.factory.js_info.description["privilegesRequired"] || []).include?(privilege)
  end

  def on_install
    js_runtime = KJSPluginRuntime.current
    js_runtime.using_runtime do
      js_runtime.runtime.host.onPluginInstall(self.factory.name, self.factory.js_info.uses_database)
    end
  end

  def implements_hook?(hook)
    KJSPluginRuntime.current.runtime.host.pluginImplementsHook(self.factory.name, hook)
  end

  def controller_for(path_element_name, other_path_elements, annotations)
    is_api = !!(annotations[:api_url])
    self.factory.js_info.controller_factories.each do |controller_factory|
      return controller_factory if controller_factory.is_api == is_api && controller_factory.path_element == path_element_name
    end
    nil
  end

  def load_template(name)
    kind = self.factory.js_info.templates[name]
    return nil if kind == nil
    # name is now trusted, as it has been checked against the list of templates found when registering the plugin
    File.open("#{self.factory.js_info.path}/template/#{name}.#{kind}") do |f|
      [f.read.strip, kind]
    end
  end

  # -----------------------------------------------------------------------------------------------------------------

  # Helper function for wrapping and reporting errors nicely for plugin development
  # Returns the result of the block
  PluginErrorInfo = Struct.new(:plugin_name)
  def self.reporting_errors(plugin_name = nil)
    # Do the block, and wrap any exceptions it raises
    begin
      yield
    rescue => e
      # If an exception is raised, mark it as something which should be reported as a plugin error
      runtime = KJSPluginRuntime.current_if_active
      pname = (runtime != nil) ? runtime.last_used_plugin_name : nil
      KFramework.mark_exception_as_reportable(e, PluginErrorInfo.new(pname || plugin_name))
      raise
    end
  end

  # -----------------------------------------------------------------------------------------------------------------

  PLUGINS_LOCK = Mutex.new  # lock PLUGINS because registration can happen at any time
  PLUGINS = Hash.new
  class PluginInfo < Struct.new(:name, :path, :description, :controller_factories, :templates, :uses_database, :version)
    # Load full plugin.json file when required - only needed for actions like installation
    def plugin_json
      @plugin_json ||= begin
        File.open("#{self.path}/plugin.json") { |f| JSON.parse(f.read) }
      end
    end
  end

  def self.read_plugin_description_and_version(path)
    # Read the description from the plugin.json file
    description = File.open("#{path}/plugin.json") { |f| JSON.parse(f.read) }
    # Read version file from disc, if it exists
    version = 'UNKNOWN'
    version_pathname = "#{path}/version"
    if File.exists?(version_pathname)
      File.open(version_pathname) { |f| version = f.read.chomp }
    end
    # Append version info from description
    version = "#{version}-#{description["pluginVersion"]}" if description.has_key?("pluginVersion")
    # Return both bits of info
    [description, version]
  end

  # Get plugin info from a directory on disc. Will exception if it's not a valid plugin.
  def self.make_plugin_info(path)
    description, version = self.read_plugin_description_and_version(path)
    # Verify the description is as expected
    KJavaScriptPlugin.reporting_errors do
      KJavaScriptPlugin.verify_plugin_description(description)
    end
    name = description["pluginName"]
    # Build controller factory info
    controller_factories = []
    if description.has_key?("respond")
      description["respond"].each do |url_path|
        raise "Bad plugin respond path #{url_path}" unless url_path =~ /\A\/(do|api)\/([^\s\/]+)\z/
        controller_factories << JavaScriptPluginControllerFactory.new($1 == 'api', $2, !!(description['allowAnonymousRequests']), name)
      end
    end
    # Make a hash of template name -> template kind from files on disc. Names from the JS side will be checked against this before trusting.
    templates = Hash.new
    template_root = "#{path}/template/"
    Dir.glob("#{template_root}**/*.*") do |filename|
      if filename[template_root.length,filename.length] =~ /\A(.+?)\.([a-z0-9A-Z]+)\z/
        templates[$1] = $2
      end
    end
    # Uses a database?
    uses_database = (description.has_key?("privilegesRequired") && description["privilegesRequired"].include?("pDatabase"))
    # Return info to caller
    PluginInfo.new(name, path, description, controller_factories, templates, uses_database, version)
  end

  # Register a global javascript plugin - available to all apps
  def self.register_javascript_plugin(path, prevent_reregistration = true)
    plugin_info = make_plugin_info(path)
    name = plugin_info.name
    # Store plugin info
    PLUGINS_LOCK.synchronize do
      raise "JavaScript plugin #{name} already registered" if prevent_reregistration && PLUGINS.has_key?(name)
      PLUGINS[name] = plugin_info
    end
  end

  # This plugin registration option will silently replace a plugin already registered under the same name
  # Returns the name of the plugin
  def self.register_private_javascript_plugin_in_current_app(path)
    plugin_info = make_plugin_info(path)
    app_info = KApp.current_app_info
    app_info.lock.synchronize do
      app_info.private_js_plugins[plugin_info.name] = plugin_info
    end
    plugin_info.name
  end

  BUILT_IN_JAVASCRIPT_PLUGINS_DIR = "#{KFRAMEWORK_ROOT}/app/plugins"

  def self.register_built_in_javascript_plugins
    Dir.glob("#{BUILT_IN_JAVASCRIPT_PLUGINS_DIR}/*/plugin.json") do |filename|
      begin
        self.register_javascript_plugin(File.dirname(filename))
      rescue => e
        # Too early in the application boot process for logging
        puts "\n\n*******\nWhile registering built-in JavaScript plugin #{filename}, got exception #{e}"; puts
      end
    end
  end

  def self.each_third_party_javascript_plugin
    # Find all the top level directories which may contain plugins
    top_level_dirs = Dir.entries(PLUGINS_LOCAL_DIRECTORY).select do |entry|
      # Only select actual directories, and not the ones ending with .dev which are used by development extensions
      entry !~ /\.dev\z/ && entry !~ /\A\./ && File.directory?("#{PLUGINS_LOCAL_DIRECTORY}/#{entry}")
    end
    # Then search for plugins in those directories, and yield the pathname of the directory
    top_level_dirs.each do |dir|
      Dir.glob("#{PLUGINS_LOCAL_DIRECTORY}/#{dir}/*/plugin.json") do |filename|
        yield File.dirname(filename)
      end
    end
  end

  def self.register_third_party_javascript_plugins
    each_third_party_javascript_plugin do |pathname|
      begin
        self.register_javascript_plugin(pathname)
      rescue => e
        # Too early in the application boot process for logging
        puts "\n\n*******\nWhile registering third-party JavaScript plugin #{pathname}, got exception #{e}"; puts
      end
    end
    self.save_javascript_plugin_version_info
  end

  def self.reload_third_party_plugins(log_destination = :logger)
    before_scan = collect_plugin_version_info
    reload_required = []
    self.each_third_party_javascript_plugin do |pathname|
      # Read the version number
      description, version = self.read_plugin_description_and_version(pathname)
      name = description["pluginName"]
      if name != nil && before_scan[name] != version
        # Re-register (or register) the plugin
        self.register_javascript_plugin(pathname, false) # allow re-registration
        # Does it require flushing the runtimes and caches in the running applications?
        if before_scan.has_key?(name)
          reload_required << name
        end
      end
    end
    # Stop now if nothing happened
    if reload_required.empty?
      KApp.logger.info("Reloaded third party plugins, no changes requiring application runtime flushing detected.")
    else
      # Go through each application, and see if has
      KApp.logger.info("Reloaded third party plugins, scanning for applications needing flushing for plugins: #{reload_required.join(', ')}")
      KApp.in_every_application do |app_id|
        installed_plugins = KPlugin.get_plugin_names_for_current_app
        log_lines = []
        reload_required.each do |name|
          if installed_plugins.include?(name)
            log_lines << "Application #{app_id} #{KApp.global(:url_hostname)}" if log_lines.empty?
            log_lines << "  Changed plugin: #{name}"
            # Reinstall the plugin: Trigger a JS runtime flush and call plugin's onInstall()
            KPlugin.install_plugin(name, :reload)
          end
        end
        case log_destination
        when :logger; log_lines.each { |line| KApp.logger.info(line) }
        when :stdout; log_lines.each { |line| puts(line) }
        else raise "Bad log destination #{log_destination}"
        end
      end
    end
    # Finish by dumping the new version info and flushing the logs
    self.save_javascript_plugin_version_info
    KApp.logger.flush_buffered
  end

  def self.collect_plugin_version_info
    versions = {}
    PLUGINS_LOCK.synchronize do
      PLUGINS.each do |name, info|
        versions[name] = info.version
      end
    end
    versions
  end

  def self.save_javascript_plugin_version_info
    plugin_version_info = collect_plugin_version_info()
    File.open("#{PLUGINS_LOCAL_DIRECTORY}/versions.yaml", 'w') { |f| f.write YAML::dump(plugin_version_info) }
  end

  def self.get_plugin_info(name)
    plugin_info = nil
    # Try the app's private plugin list
    app_info = KApp.current_app_info
    app_info.lock.synchronize do
      plugin_info = app_info.private_js_plugins[name]
    end
    # Try the global plugin list
    if plugin_info == nil
      PLUGINS_LOCK.synchronize do
        plugin_info = PLUGINS[name]
      end
    end
    plugin_info
  end

  def self.plugin_registered?(name)
    (get_plugin_info(name) != nil)
  end

  def self.make_factory(name, path_component)
    js_info = get_plugin_info(name)
    return nil unless js_info
    plugin_load_priority = (js_info.description["loadPriority"] || KPlugin::DEFAULT_PLUGIN_LOAD_PRIORITY).to_i
    JavaScriptPluginFactory.new(name, plugin_load_priority, path_component, js_info)
  end

  class JavaScriptPluginFactory < Struct.new(:name, :plugin_load_priority, :path_component, :js_info)
    def klass
      :javascript_plugin  # for compatibility with KPlugin::PluginFactory
    end
    def is_javascript_factory?
      true
    end
    def begin_request
      raise "JavaScriptPluginFactory in wrong state" unless @plugin_object == nil
      @plugin_object = KJavaScriptPlugin.new(self)
    end
    def reset_plugin_object
      @plugin_object = nil
    end
    attr_reader :plugin_object
    def plugin_name
      self.js_info.description["displayName"]
    end
    def plugin_description
      self.js_info.description["displayDescription"]
    end

    # How to load the plugin into the JavaScript runtime
    def javascript_load(runtime)
      # Load global.js file, if appropraite, set up prefix and suffix for wrapping loaded scripts.
      name = self.name
      generated_javascript = ''
      global_js = "#{js_info.path}/global.js"
      if File.exist?(global_js)
        runtime.loadScript(global_js, "p/#{name}/global.js", nil, nil)
      else
        generated_javascript << "var #{name} = O.plugin('#{name}');\n"
      end
      use_features = self.js_info.description['use']
      if use_features && !(use_features.empty?)
        generated_javascript << "#{JSON.generate(use_features)}.forEach(function(f) { #{name}.use(f); });\n"
      end
      runtime.evaluateString(generated_javascript, "p/#{name}/auto-generated-global.js") if generated_javascript.length > 0
      prefix = "(function(P"
      suffix = "\n})(#{name}"
      (self.js_info.description["locals"] || {}).each do |k,v|
        # these values are checked, so can be trusted to be OK
        prefix << ", #{k}"
        suffix << ", #{name}.#{v}"
      end
      prefix << "){"
      suffix << ");\n"
      # Load the JavaScript files
      js_info.description["load"].each do |filename|
        raise "Bad plugin script filename" if filename =~ /\.\./ || filename =~ /\A\//
        runtime.loadScript("#{js_info.path}/#{filename}", "p/#{name}/#{filename}", prefix, suffix)
      end
    end
  end

  class JavaScriptPluginControllerFactory < Struct.new(:is_api, :path_element, :allow_anonymous, :plugin_name)
    def make_controller
      JavaScriptPluginController.new(self)
    end
  end

  # -----------------------------------------------------------------------------------------------------------------

  # Verification of plugin.json

  def self.verify_plugin_description(description)
    raise PluginDescriptionError, "plugin.json: Top level isn't a Hash" unless description.class == Hash
    description.each_key do |key|
      raise PluginDescriptionError, "plugin.json: Unknown key #{key}" unless PLUGIN_VALID_KEYS.has_key?(key)
    end
    PLUGIN_DESCRIPTION_VERIFY.each do |v|
      v.verify(description)
    end
    api_version = description["apiVersion"]
    raise PluginDescriptionError, "plugin.json: Plugin requires a past apiVersion not implemented by this platform version" unless
          api_version >= MINIMUM_JAVASCRIPT_API_VERSION
    raise PluginDescriptionError, "plugin.json: Plugin requires a future apiVersion not implemented by this platform version" unless
          api_version <= CURRENT_JAVASCRIPT_API_VERSION
  end

  class PluginDescriptionError < RuntimeError
  end

  class PluginDescriptionVerify < Struct.new(:name, :required, :type)
    # Returns true if the key exists
    def verify(description)
      if description.has_key?(self.name)
        value = description[self.name]
        raise PluginDescriptionError, "plugin.json: #{self.name} should be a #{self.type.name}, but was a #{value.class.name}" unless
                value.kind_of?(self.type)
        true
      else
        raise PluginDescriptionError, "plugin.json: #{self.name} is not present" if self.required
        false
      end
    end
  end

  class PluginDescriptionVerifyBool < PluginDescriptionVerify
    def initialize(name, required)
      super(name, required, Object)
    end
    def verify(description)
      return unless super
      value = description[self.name]
      raise PluginDescriptionError, "plugin.json: #{self.name} should be true or false" unless value.class == TrueClass || value.class == FalseClass
    end
  end

  class PluginDescriptionVerifyHash < PluginDescriptionVerify
    def initialize(name, required, key_type, value_type)
      super(name, required, Hash)
      @key_type = key_type
      @value_type = value_type
    end
    def verify(description)
      return unless super
      description[self.name].each do |k, v|
        raise PluginDescriptionError, "plugin.json: in #{self.name}, key #{k} is not a #{self.key_type.name}" unless k.class == @key_type
        raise PluginDescriptionError, "plugin.json: in #{self.name}, value #{v} is not a #{self.value_type.name}" unless v.class == @value_type
      end
    end
  end

  class PluginDescriptionVerifyArray < PluginDescriptionVerify
    def initialize(name, required, value_type)
      super(name, required, Array)
      @value_type = value_type
    end
    def verify(description)
      return unless super
      description[self.name].each do |a|
        raise PluginDescriptionError, "plugin.json: in #{self.name}, value #{a} is not a #{@value_type.name}" unless a.class == @value_type
      end
    end
  end

  class PluginDescriptionVerifyArrayOfFilenames < PluginDescriptionVerifyArray
    def initialize(name, required)
      super(name, required, String)
    end
    def verify(description)
      return unless super
      description[self.name].each do |f|
        raise PluginDescriptionError, "plugin.json: in #{self.name}, filename #{f} is not valid" unless
                f =~ /\A([a-zA-Z0-9_-]+\/)*[a-zA-Z0-9_-]+\.[a-zA-Z0-9]+\z/ && f !~ /\/\./ && f !~ /\/\//
      end
    end
  end

  class PluginDescriptionVerifyLocals <PluginDescriptionVerify
    def initialize(name, required)
      super(name, required, Hash)
    end
    def verify(description)
      return unless super
      description[self.name].each do |k,v|
        # Important checks!
        unless k.kind_of?(String) && v.kind_of?(String) && k =~ /\A[a-zA-Z][a-zA-Z0-9_]*\z/ && v =~ /\A[a-zA-Z][a-zA-Z0-9_\.]*\z/
          raise PluginDescriptionError, "plugin.json: in #{self.name}, invalid entry #{k}"
        end
      end
    end
  end

  PLUGIN_DESCRIPTION_VERIFY = [
      PluginDescriptionVerify.new("pluginName", true, String),
      PluginDescriptionVerify.new("pluginAuthor", true, String),
      PluginDescriptionVerify.new("pluginVersion", true, Fixnum),
      PluginDescriptionVerify.new("displayName", true, String),
      PluginDescriptionVerify.new("displayDescription", true, String),
      PluginDescriptionVerify.new("apiVersion", true, Fixnum),
      PluginDescriptionVerify.new("loadPriority", false, Fixnum),
      PluginDescriptionVerify.new("installSecret", false, String),
      PluginDescriptionVerifyLocals.new("locals", false),
      PluginDescriptionVerifyArrayOfFilenames.new("load", true),
      PluginDescriptionVerifyArray.new("use", false, String),
      PluginDescriptionVerifyArray.new("respond", false, String),
      PluginDescriptionVerifyArray.new("privilegesRequired", false, String),
      PluginDescriptionVerifyBool.new("allowAnonymousRequests", false)
    ]
  PLUGIN_DESCRIPTION_VERIFY.freeze
  PLUGIN_VALID_KEYS = Hash.new
  PLUGIN_DESCRIPTION_VERIFY.each { |v| PLUGIN_VALID_KEYS[v.name] = true }
  PLUGIN_VALID_KEYS.freeze

end
