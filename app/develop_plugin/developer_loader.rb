# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


unless PLUGIN_DEBUGGING_SUPPORT_LOADED
  raise "DeveloperLoader should only be loaded if plugin debugging support is explicitly required"
end

class DeveloperLoader

  GENERIC_FAILURE_MESSAGE = "Failed to load plugin - possible syntax error in JavaScript file or incorrect plugin.json file."

  # TODO: Clean up developer_loader loaded plugins when they haven't been used for a while.
  # TODO: Stop too much data being uploaded, and other potential abuses
  # TODO: Better error reporting for errors in plugins and for handling authorisation problems

  # -------------------------------------------------------------------------------------------------------------------

  # Security: Don't allow the loader's info file to be uploaded
  BANNED_FILENAMES = /\A(__loader\.json)\z/

  # -------------------------------------------------------------------------------------------------------------------

  # Keep track of the plugins loaded in memory
  LOADED_PLUGINS = Hash.new { |hash, key| hash[key] = Hash.new }
  LOADED_PLUGINS_MUTEX = Mutex.new

  # -------------------------------------------------------------------------------------------------------------------

  # Where the plugins will be stored
  LOADER_PLUGIN_DIR = "#{PLUGINS_LOCAL_DIRECTORY}/loader.dev"

  begin
    # Make sure the uploaded plugins directory exists
    FileUtils.mkdir(LOADER_PLUGIN_DIR) unless File.exists?(LOADER_PLUGIN_DIR)
    # Reregister any uploaded plugins on start
    KNotificationCentre.when(:server, :starting) do
      Dir.glob("#{LOADER_PLUGIN_DIR}/*/__loader.json").each do |loader_info_filename|
        plugin_dir = File.dirname(loader_info_filename)
        begin
          loader_info = File.open(loader_info_filename) { |f| JSON.parse(f.read) }
          # Attempt to register it
          plugin = KJavaScriptPlugin.new(plugin_dir)
          KPlugin.register_plugin(plugin, loader_info["applicationId"])
          KApp.logger.info("DeveloperLoader: Re-registered #{plugin.name} from #{plugin_dir}")
          # Store the name and ID for tracking
          LOADED_PLUGINS_MUTEX.synchronize do
            LOADED_PLUGINS[loader_info["applicationId"]][plugin.name] = loader_info["id"]
          end
        rescue => e
          KApp.logger.error("DeveloperLoader: Failed to re-register plugin #{plugin_dir}\n#{e.inspect}")
        end
      end
    end
  end

  # -------------------------------------------------------------------------------------------------------------------

  # Notifications support
  NOTIFICATION_QUEUES = Hash.new { |hash, key| hash[key] = Hash.new }
  NOTIFICATION_QUEUES_MUTEX = Mutex.new
  ATTR_NOTIFICATION_QUEUE_NAME = 'com.oneis.devloader.queuename'

  class NotificationQueue
    include JRuby::Synchronized
    def initialize()
      @name = KRandom.random_api_key
      @last_use = Time.now.to_i
      @queue = ''
    end
    attr_reader :name
    attr_reader :last_use
    attr_writer :continuation
    def empty?
      @queue.empty?
    end
    def make_response_and_flush
      @last_use = Time.now.to_i
      response = @queue; @queue = ''; response
    end
    def push_notification(data)
      @queue << data
      if @continuation && @continuation.isSuspended()
        @continuation.resume()
        @continuation = nil
      end
    end
  end

  def self.get_notification_queue(name)
    NOTIFICATION_QUEUES_MUTEX.synchronize do
      app_queues = NOTIFICATION_QUEUES[KApp.current_application]
      if name
        app_queues[name]
      else
        queue = NotificationQueue.new
        app_queues[queue.name] = queue
      end
    end
  end

  def self.broadcast_notification(type, notification)
    # Assemble into data to send
    data = sprintf('%4s%08x', type, notification.bytesize)
    data << notification
    expire_older_than = Time.now.to_i - 120
    NOTIFICATION_QUEUES_MUTEX.synchronize do
      app_queues = NOTIFICATION_QUEUES[KApp.current_application]
      app_queues.delete_if do |name,queue|
        if queue.last_use < expire_older_than
          # expire anything older than a couple of minutes
          KApp.logger.info("Expiring plugin tool notification queue #{queue.name}")
          true
        else
          queue.push_notification(data)
          false
        end
      end
    end
  end

  # Send notifications to plugin tool
  begin
    # Listen for console.log() events
    KNotificationCentre.when(:javascript_console_log) do |name, detail, text, currently_executing_plugin_name|
      broadcast_notification('log ', "#{currently_executing_plugin_name}:#{detail}: #{text}")
    end
    # Listen for audit trail entries being written
    KNotificationCentre.when(:audit_trail, :write) do |name, detail, entry|
      fields = [["id", entry.id], ["auditEntryType", entry.kind]]
      ref = entry.objref
      fields << ["ref", ref.to_presentation] if ref
      PLUGIN_TOOL_AUDIT_ENTRY_FIELDS.each do |attr, name|
        value = entry.read_attribute(attr)
        if value
          fields << [name, value]
        end
      end
      broadcast_notification('audt', fields.to_json)
    end
    # Listen for schema changes and output the list of changed codes on the plugin console
    KNotificationCentre.when(:schema_requirements, :applied) do |name, details, applier|
      unless applier.changes.empty?
        changed_codes = applier.changes.map { |object_applier| object_applier.code }
        broadcast_notification('log ', "requirements.schema:CHANGED: #{changed_codes.join(', ')}")
      end
    end
    # Send pipeline results to the console so developers can see error messages without having to write their own code
    KNotificationCentre.when(:jsfiletransformpipeline, :pipeline_result) do |name, details, result|
      broadcast_notification('log ', "FILE-PIPELINE:#{result.name}:#{result.success ? 'SUCCESS' : 'ERROR'}:#{result.error_message}")
    end
  end

  # Which fields should be sent to the plugin tool from audit entries
  PLUGIN_TOOL_AUDIT_ENTRY_FIELDS = [
      ["created_at", "creationDate"],
      ["remote_addr", "remoteAddress"],
      ["user_id", "userId"],
      ["auth_user_id", "authenticatedUserId"],
      ["data", "data"]
    ]

  # -------------------------------------------------------------------------------------------------------------------

  class Controller < ApplicationController
    REQUIRED_POLICY = KPolicyRegistry.to_bitmask(:not_anonymous, :setup_system)

    ALLOWED_PLUGIN_DIRECTORIES = ['js', 'template', 'static', 'test', 'data']

    # Implement very minimal pre- and post-handle checks. These avoid anything implemented by a plugin,
    # so even if the plugin uplaoded breaks everything, the loader will still work so the corrected version
    # can be uploaded to fix everything.
    # The authorisation check is very minimal, and carefully choses paths which avoid plugin code.
    def pre_handle
      if KApp.global(:status) == KApp::STATUS_ACTIVE
        api_key = request.headers[ApplicationController::API_KEY_HEADER_NAME]
        if api_key && api_key.length >= 16
          device = ApiKey.cache[api_key]
          if device && device.path == '/api/development-plugin-loader/'
            user_object = User.cache[device.user_id]
            if user_object && user_valid_for_request(user_object)
              user_allowed = false
              if user_object.kind == User::KIND_SUPER_USER
                user_allowed = true
              else
                user_policy = user_object.user_groups.calculate_policy_bitmask()
                if (user_policy & REQUIRED_POLICY) == REQUIRED_POLICY
                  user_allowed = true
                end
              end
              if user_allowed
                # User is authenticated sufficiently to be allowed to use the plugin loader
                # Don't set AuthContext, as it'll call plugins, and if they're broken, that's going break the loader too
                @request_user = user_object
                init_standard_controller_class_variables()
                return true
              end
            end
          end
        end
      end
      render :status => 403, :text => JSON.generate(:result => "error",
        :message => "Not authorised: Must provide a valid API key from a user with the setup system policy.")
      false
    end
    def csrf_check(exchange)
      # It's always API key authenticated POSTs, so CSRF is ignored.
    end
    def post_handle
      # Only set the response, skip everything else
      exchange.response = render_result
    end

    def handle_application_info_api
      info = {
        "name" => KApp.global(:system_name),
        "config" => JSON.parse(KApp.global(:javascript_config_data) || '{}'),
        "installedPlugins" => KPlugin.get_plugins_for_current_app.map { |f| f.name }
      }
      render :text => JSON.generate(info), :kind => :json
    end

    # See if a plugin is already registered, and if so, get the ID and manifest
    _PostOnly
    def handle_find_registration_api
      return unless params.has_key?(:name) && params[:name] =~ /\A[A-Za-z0-9_-]+\z/
      found_id = nil
      DeveloperLoader::LOADED_PLUGINS_MUTEX.synchronize do
        found_id = DeveloperLoader::LOADED_PLUGINS[KApp.current_application][params[:name]]
      end
      unless found_id
        render :text => JSON.generate(:result => "success", :found => false)
        return
      end
      return unless setup_plugin_id_info(found_id)
      render :text => JSON.generate(:result => "success", :found => true, :plugin_id => @loaded_plugin_id, :manifest => load_info["files"])
    end

    # Create a new plugin
    _PostOnly
    def handle_create_api
      # Generate new ID
      @loaded_plugin_id = KRandom.random_api_key
      @loaded_plugin_pathname = "#{LOADER_PLUGIN_DIR}/#{@loaded_plugin_id}"
      raise "Already exists!" if File.exists?(@loaded_plugin_pathname)
      # Create directory
      FileUtils.mkdir(@loaded_plugin_pathname)
      # Write blank loader information
      File.open("#{@loaded_plugin_pathname}/__loader.json", 'w') do |f|
        f.write JSON.generate({
          "id" => @loaded_plugin_id,
          "updated" => 0,
          "applicationId" => KApp.current_application,
          "files" => {}
        })
      end
      # Return the ID of the plugin
      render :text => JSON.generate(:result => "success", :plugin_id => @loaded_plugin_id)
    end

    # Get information about an existing plugin
    def handle_manifest_api
      return unless setup_plugin_id_info
      render :text => JSON.generate(:result => "success", :manifest => load_info["files"])
    end

    # Store a file
    _PostOnly
    def handle_put_file_api
      return unless setup_plugin_id_info
      uploads = exchange.annotations[:uploads]
      raise "Upload expected" unless request.post? && uploads != nil
      if uploads.getInstructionsRequired()
        uploads.addFileInstruction("file", @loaded_plugin_pathname, "SHA-256", nil)
        render :text => ''
      else
        setup_file_path_info
        file = uploads.getFile("file")
        # Load the info first, so it's known to be good before we do anything else
        load_info
        # Make sure the directory exists
        if @directory != nil
          dir_pathname = "#{@loaded_plugin_pathname}/#{@directory}"
          FileUtils.mkdir_p(dir_pathname) unless File.directory?(dir_pathname)
        end
        # If it's the plugin.json file, check it now to avoid errors later
        if @plugin_pathname == 'plugin.json'
          contents = File.open(file.getSavedPathname()) { |f| f.read }
          message = nil
          begin
            parsed_new_plugin_json = JSON.parse(contents)
            KJavaScriptPlugin.verify_plugin_json(parsed_new_plugin_json)
            # Check plugin name hasn't changed, as this would really mess things up
            if File.exist?(@pathname)
              unless parsed_new_plugin_json["pluginName"] == get_plugin_name()
                message = "Changing pluginName in plugin.json is not allowed. Restart the plugin tool."
              end
            end
          rescue KJavaScriptPlugin::PluginJSONError => e
            message = e.message
          rescue => e
            message = "Could not parse plugin.json file - check syntax."
          end
          # Ignore file and report error if it failed to validate
          if message != nil
            render :text => JSON.generate(:result => "error", :message => message)
            return
          end
        end
        # Move uploaded file into place
        FileUtils.mv file.getSavedPathname(), @pathname
        # Update manifest
        @loader_info["files"][@plugin_pathname] = file.getDigest()
        save_info
        # Return the hash
        render :text => JSON.generate(:result => "success", :hash => file.getDigest())
      end
    end

    # Delete a file
    _PostOnly
    def handle_delete_file_api
      return unless setup_plugin_id_info
      setup_file_path_info
      raise "No file" unless File.exists? @pathname
      raise "Error" if @pathname.include?('..') # paranoia
      # Deleting plugin.json is not helpful
      if @plugin_pathname == "plugin.json"
        render :text => JSON.generate(:result => "error", :message => "plugin.json cannot be deleted")
        return
      end
      File.unlink @pathname # safe because all info is checked
      # Update manifest
      load_info
      @loader_info["files"].delete @plugin_pathname
      save_info
      render :text => JSON.generate(:result => "success")
    end

    # Apply changes
    _PostOnly
    def handle_apply_api
      plugin_loaded_ids = (params[:plugins] || '').split(' ')
      apply_plugin_names = []
      error_messages = []
      name_to_id_update = {}
      plugin_loaded_ids.each do |loaded_plugin|
        return unless setup_plugin_id_info(loaded_plugin)
        load_info
        # Check all the files mentioned in plugin.json exist
        missing_files = find_missing_plugin_js_files()
        if missing_files.empty?
          # (Re-)register the plugin, mark it for installation
          plugin = KJavaScriptPlugin.new(@loaded_plugin_pathname)
          KPlugin.register_plugin(plugin, KApp.current_application)
          apply_plugin_names << plugin.name
          # Store ID for update
          name_to_id_update[plugin.name] = @loaded_plugin_id
        else
          KJSPluginRuntime.invalidate_all_runtimes  # Although we're going to avoid a broken install, the plugin should still break
          error_messages << "Some of the files required to be loaded in plugin.json are missing: #{missing_files.join(', ')}"
        end
      end
      # Install the plugins which passed the tests
      unless apply_plugin_names.empty?
        begin
          # :developer_loader_apply reason avoids lots of audit entries
          installation = KPlugin.install_plugin_returning_checks(apply_plugin_names, :developer_loader_apply)
          # Report failures and warnings
          [installation.failure, installation.warnings].compact.each { |m| error_messages << m }
        rescue => e
          error_messages << (KFramework.reportable_exception_error_text(e, :text) || GENERIC_FAILURE_MESSAGE)
        end
      end
      # Update registered plugin tracking
      DeveloperLoader::LOADED_PLUGINS_MUTEX.synchronize do
        DeveloperLoader::LOADED_PLUGINS[KApp.current_application].merge!(name_to_id_update)
      end
      if error_messages.empty?
        render :text => JSON.generate(:result => "success")
      else
        render :text => JSON.generate(:result => "error", :message => error_messages.join("\n\n"))
      end
    end

    # Run tests
    _PostOnly
    def handle_run_tests_api
      # Collect information necessary to run the tests
      return unless setup_plugin_id_info
      plugin_name = get_plugin_name()
      # Run the tests in a new thread, to keep everything isolated from the main application.
      # Repeated runs of the tests may reuse the underlying JS runtime.
      tester = JSPluginTests.new(KApp.current_application, plugin_name, params[:test])
      tester.run # in another thread
      # Report the result back to the plugin tool
      results = tester.results
      response = {:result => "success"}
      [:tests, :asserts, :errors, :assert_fails, :output].each do |key|
        response[key] = results[key]
      end
      response[:summary] = "#{results[:pass] ? 'PASSED' : 'FAILED'}: #{results[:asserts]} asserts in #{results[:tests]} tests, #{results[:errors]} errors, #{results[:assert_fails]} failures"
      render :text => JSON.generate(response)
    end

    # Reset relational database
    _PostOnly
    def handle_resetdb_api
      return unless setup_plugin_id_info
      # Get plugin name
      plugin_name = get_plugin_name()
      # Get database namespace
      dbnamespaces = KApp.global(:plugin_db_namespaces) || ''
      dbnamespaces = YAML::load(dbnamespaces) || {}
      dbname = dbnamespaces[plugin_name]
      if dbname != nil
        raise "bad database mapping" unless dbname =~ /\A[a-zA-Z0-9]+\z/
        # A mapping exists - find all the tables for this plugin and delete them
        db = KApp.get_pg_database
        sql = "SELECT table_schema,table_name FROM information_schema.tables WHERE table_schema='a#{KApp.current_application}' AND table_name LIKE 'j_#{dbname}_%' ORDER BY table_name"
        drop = "BEGIN; SET CONSTRAINTS ALL DEFERRED; "
        r = db.exec(sql)
        r.each do |table_schema,table_name|
          drop << "DROP TABLE IF EXISTS #{table_name} CASCADE; " # IF EXISTS required because of CASCADE
        end
        r.clear
        drop << "COMMIT"
        db.perform(drop) if drop.include?('TABLE')
      end
      render :text => JSON.generate(:result => "success")
    end

    # Uninstall plugin
    _PostOnly
    def handle_uninstall_api
      return unless setup_plugin_id_info
      plugin_name = nil
      begin
        plugin_name = get_plugin_name()
      rescue => e
        # Fall back to trying the information about loaded plugins
        DeveloperLoader::LOADED_PLUGINS_MUTEX.synchronize do
          plugin_name = DeveloperLoader::LOADED_PLUGINS[KApp.current_application].key(params[:id])
        end
      end
      if plugin_name == nil
        render :text => JSON.generate(:result => "error", :message => "Couldn't find plugin name for uninstallation.")
      else
        KPlugin.uninstall_plugin(plugin_name)
        if KPlugin.get(plugin_name) == nil
          render :text => JSON.generate(:result => "success")
        else
          render :text => JSON.generate(:result => "error", :message => "Failed to uninstall plugin.")
        end
      end
    end

    # -----------------------------------------------------------------------------------------------------------------------------
    # Notifications API

    def handle_get_notifications_api
      # Get a continuation for this request
      continuation = request.continuation
      # Get or create a queue, using a queue name from the continuation or the parameter passing in by the plugin tool
      queue = DeveloperLoader.get_notification_queue(continuation.getAttribute(ATTR_NOTIFICATION_QUEUE_NAME) || params[:queue])
      queue ||= DeveloperLoader.get_notification_queue(nil)
      # Suspend this request if there aren't any entries to send and it's a fresh request
      if queue.empty? && continuation.isInitial()
        continuation.setTimeout(55000) # just under a minute
        continuation.suspend()
        continuation.setAttribute(ATTR_NOTIFICATION_QUEUE_NAME, queue.name)
        queue.continuation = continuation
        render_continuation_suspended
        return
      else
        # Wait a little while for more notifications to appear if the queue isn't empty
        sleep(0.1) unless queue.empty?
      end
      # Return a response
      response.headers['X-Queue-Name'] = queue.name
      render :text => queue.make_response_and_flush
    end

    # -----------------------------------------------------------------------------------------------------------------------------

  private

    def setup_plugin_id_info(given_id = nil)
      # Get a checked version of the plugin ID
      i = (given_id || params[:id] || '').gsub(/[^a-zA-Z0-9_-]/,'') # cleaned version of the ID
      raise "Bad plugin id" unless i.length > 40
      raise "Bad plugin id" if i =~ /\./ || i =~ /\//
      # Setup info
      @loaded_plugin_id = i
      @loaded_plugin_pathname = "#{LOADER_PLUGIN_DIR}/#{@loaded_plugin_id}"
      # Check dir exists
      unless File.directory? @loaded_plugin_pathname
        render :text => JSON.generate(:result => "error", :message => "No such plugin")
        return false
      end
      true
    end

    def report_plugin_install_error(e)
      # Probably a syntax error, try and report it
      reportable_error = KFramework.reportable_exception_error_text(e, :text)
      if reportable_error != nil
        render :text => JSON.generate(:result => "error", :message => reportable_error)
      else
        render :text => JSON.generate(:result => "error", :message => GENERIC_FAILURE_MESSAGE)
      end
      nil
    end

    def get_plugin_name
      (File.open("#{@loaded_plugin_pathname}/plugin.json") { |f| JSON.parse(f.read) })['pluginName']
    end

    def find_missing_plugin_js_files
      missing_files = []
      load = (File.open("#{@loaded_plugin_pathname}/plugin.json") { |f| JSON.parse(f.read) })['load']
      if load
        load.each do |filename|
          raise "Bad filename" if filename.include?("..")
          missing_files.push(filename) unless File.exist?("#{@loaded_plugin_pathname}/#{filename}")
        end
      end
      missing_files
    end

    def setup_file_path_info
      # Checked directory
      @directory = params[:directory]
      if @directory != nil
        raise "Bad directory" unless @directory =~ /\A([a-zA-Z0-9_\-]+)[a-zA-Z0-9_\/\-]*\z/  # no '.' for filesystem traversal
        raise "Bad root directory" unless ALLOWED_PLUGIN_DIRECTORIES.include?($1)
        raise "Bad directory" if @directory =~ /\/\z/ # prevents double // getting into manifests
        raise "Directory name contains dot" if @directory.include?('.') # paranoid extra check
      end
      # Checked filename
      @filename = params[:filename]
      raise "Bad filename" if @filename =~ BANNED_FILENAMES
      raise "Bad filename" unless @filename =~ /\A[a-zA-Z0-9_-]+\.[a-zA-Z0-9]+\z/
      # Plugin path
      @plugin_pathname = (@directory == nil) ? @filename : "#{@directory}/#{@filename}"
      # Generate pathname
      @pathname = "#{@loaded_plugin_pathname}/#{@plugin_pathname}"
    end

    def load_info
      @loader_info ||= File.open("#{@loaded_plugin_pathname}/__loader.json") { |f| JSON.parse(f.read) }
    end

    def save_info
      raise "Not loaded" if @loader_info == nil
      info = @loader_info.dup
      info["updated"] = Time.now.to_i
      File.open("#{@loaded_plugin_pathname}/__loader.json", 'w') { |f| f.write JSON.generate(info) }
    end

  end

  # Add this controller to the server's URL namespace
  KNotificationCentre.when(:server, :starting) do
    KFRAMEWORK__BOOT_OBJECT.instance_variable_get(:@namespace).class.const_get(:MAIN_MAP)['api'].last['development-plugin-loader'] = [:controller, {}, Controller]
  end

end
