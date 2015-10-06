# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Load other support modules
require 'js_support/js_schema'
require 'js_support/js_plugin_runtime'
require 'js_support/kjavascript_plugin'
require 'js_support/javascript_api_version'
require 'js_support/js_template'
require 'js_support/js_ruby_templates'
# Interfaces to Ruby code for JavaScript
require 'js_support/js_interface_support'
require 'js_support/js_datetime_support'
require 'js_support/js_label_support'
require 'js_support/js_kobject_support'
require 'js_support/js_query_support'
require 'js_support/js_text_support'
require 'js_support/js_file_support'
require 'js_support/kjsfiletransformpipeline'
require 'js_support/js_user_support'
require 'js_support/js_audit_entry_support'
require 'js_support/js_work_unit_support'
require 'js_support/js_email_template_support'
require 'js_support/js_uploaded_file_support'
require 'js_support/js_job_support'
require 'js_support/js_remote_collaboration_service_support'
require 'js_support/js_remote_authentication_service_support'
require 'js_support/js_inter_runtime_signal_support'


# Root class for interacting with a JavaScript runtime.
# Expects a new object to be created every time the runtime is checked out.
class JSSupportRoot
  include Java::ComOneisJsinterfaceApp::AppRoot

  def initialize
    @controller = nil
  end

  def clear
    @controller = nil
  end

  # For plugin test scripts support
  def _test_set_fake_controller(c)
    @controller = c
  end

  # Application information
  def currentApplicationId
    KApp.current_application || -1
  end

  def getApplicationInformation(item)
    case item
    when "id"
      KApp.current_application.to_s
    when "name"
      KApp.global(:system_name)
    when "hostname"
      KApp.global(:ssl_hostname)
    when "url"
      KApp.url_base(:logged_in)
    else
      raise JavaScriptAPIError, "Unknown application information requested"
    end
  end

  def getApplicationConfigurationDataJSON
    KApp.global(:javascript_config_data) || '{}'
  end

  # For working out which plugin is to blame for an error
  def getCurrentlyExecutingPluginName()
    com.oneis.javascript.Runtime.findCurrentlyExecutingPluginFromStack()
  end

  # Does the last used plugin have the requested privilege?
  def currentlyExecutingPluginHasPrivilege(privilegeName)
    found_name = com.oneis.javascript.Runtime.findCurrentlyExecutingPluginFromStack()
    return false unless found_name != nil
    plugin = KPlugin.get(found_name)
    return false unless plugin != nil
    plugin.has_privilege?(privilegeName)
  end

  def javascriptWarningsAreErrors()
    # In test mode, any JavaScript warning is treated as an error.
    (KFRAMEWORK_ENV == 'test')
  end

  def getPostgresSchemaName()
    app_id = KApp.current_application
    if app_id == nil || !(app_id.kind_of?(Integer)) || app_id < 0
      raise "Not within a valid KApp.current_application"
    end
    "a#{app_id}"
  end

  def getJdbcConnection()
    KApp.get_jdbc_database
  end

  def generateSchemaQueryFunction(queryName)
    KSchemaToJavaScript.generate_schema_query_function(KObjectStore.schema, queryName)
  end

  def impersonating(user, runnable)
    user ||= User.cache[User::USER_SYSTEM]
    old_state = AuthContext.set_impersonation(user)
    begin
      runnable.run()
    ensure
      AuthContext.restore_state old_state
    end
  end

  def withoutPermissionEnforcement(runnable)
    old_state = AuthContext.set_enforce_permissions(false)
    begin
      runnable.run()
    ensure
      AuthContext.restore_state old_state
    end
  end

  def isHandlingRequest()
    !!(controller())
  end

  def fetchRequestInformation(infoName)
    c = controller
    raise "Cannot fetch request information - bad state or not in request context" unless c
    case infoName
    when 'parametersJSON'
      c.params.to_json
    when 'headersJSON'
      c.request.headers.all_headers.to_json
    when 'body'
      c.request.body
    when "remoteIPv4"
      c.request.remote_ip
    else
      raise "Bad infoName"
    end
  end

  def fetchRequestUploads()
    c = controller
    raise "Cannot fetch request information - bad state or not in request context" unless c
    c.exchange.annotations[:uploads]
  end

  def getSessionJSON()
    c = controller
    raise JavaScriptAPIError, "Session information not available outside request context" unless c
    c.session[:_jsplugin_store]
  end

  def setSessionJSON(json)
    c = controller
    raise JavaScriptAPIError, "Session information not available outside request context" unless c
    # Make sure there's a session, then store the value.
    c.session_create if c.session.discarded_after_request?
    c.session[:_jsplugin_store] = json
  end

  def getSessionTray()
    c = controller
    raise JavaScriptAPIError, "Tray contents not available outside request context" unless c
    c.tray_contents
  end

  # Object rendering is performed in app root so it can efficiently use a cached controller (although might be worth benchmarking this properly)
  def renderObject(object, style)
    c = controller_or_background_controller
    c.render_obj(object, style)
  end

  def loadTemplateForPlugin(pluginName, templateName)
    plugin = KPlugin.get(pluginName)
    return nil if plugin == nil
    plugin.load_template(templateName)
  end

  def renderRubyTemplate(templateName, args)
    c = controller_or_background_controller
    template_info = JSRubyTemplates::LOOKUP[templateName]
    return "STANDARD TEMPLATE std:#{templateName} NOT FOUND" if template_info == nil
    template_kind, template_ruby_name, arg_info = template_info
    # Build arguments
    call_args = JSRubyTemplates.make_args_container(template_kind)
    0.upto(arg_info.length - 1) do |i|
      k, type, is_required, has_default, default_value = arg_info[i]
      if args[i] == nil
        if has_default
          call_args[k] = default_value
        end
        raise JavaScriptAPIError, "Standard template #{templateName} argument #{k} was not provided." if is_required
        next
      end
      call_args[k] = case type
      when :kobject, :kobjref, :ktext
        args[i].toRubyObject
      when :symbol
        args[i].to_s.to_sym
      when :string
        args[i].to_s
      when :integer
        args[i].to_i
      when :boolean
        !!(args[i])
      when :array
        args[i].to_a
      else
        nil
      end
    end
    # Call the template
    case template_kind
    when :partial
      c.render :partial => template_ruby_name, :data_for_template => call_args
    when :method
      c.send(template_ruby_name, *call_args)
    else
      raise "Unknown JS -> Ruby template kind #{template_kind}"
    end
  end

  def addRightContent(html)
    c = controller
    raise JavaScriptAPIError, "Can only use renderIntoSidebar() when a request is being processed" unless c
    c.in_right_column(html)
  end

  def pluginStaticDirectoryUrl(pluginName)
    plugin = KPlugin.get(pluginName)
    return nil if plugin == nil
    plugin.static_files_urlpath
  end

  def pluginRewriteCSS(pluginName, css)
    plugin = KPlugin.get(pluginName)
    return nil if plugin == nil
    plugin.plugin_rewrite_css(css)
  end

  def readPluginAppGlobal(pluginName)
    KApp.global("_pjson_#{pluginName}".to_sym)
  end
  def savePluginAppGlobal(pluginName, global)
    KApp.set_global("_pjson_#{pluginName}".to_sym, global)
  end

  LOG_LEVEL = {
    "info" => Logger::Severity::INFO, "debug" => Logger::Severity::DEBUG, "warn" => Logger::Severity::WARN, "error" => Logger::Severity::ERROR
  }
  def writeLog(level, text)
    l = LOG_LEVEL[level]
    raise "Bad log level '#{level}'" if l == nil
    # Log into application logs - but only a limited amount to stop plugins being able to fill up the log too much
    KApp.logger.add(l, "JS: #{(text.length > 128) ? text[0,128] : text}")
    # Notify everything else interested in the logs
    KNotificationCentre.notify(:javascript_console_log, level.to_sym, text, getCurrentlyExecutingPluginName())
  end

  # -------------------------------------------------------------------------------------------------------

  PLUGIN_REPORTED_HEALTH_EVENTS = KFramework::HealthEventReporter.new('PLUGIN_REPORT')

  def reportHealthEvent(pluginEventTitle, pluginEventText)
    event_title = "Plugin reported health event: #{pluginEventTitle || '????'}"
    event_text = "#{pluginEventText}\n\n\n"
    caller.each { |line| event_text << "  #{line}\n"}
    PLUGIN_REPORTED_HEALTH_EVENTS.log_and_report_event(event_title, event_text)
  end

  # -------------------------------------------------------------------------------------------------------
  # Cache invalidation

  def reloadUserPermissions
    User.invalidate_cached
  end

  def reloadNavigation
    KNotificationCentre.notify(:javascript_plugin_reload_navigation)
  end

  def reloadJavaScriptRuntimes
    KJSPluginRuntime.invalidate_all_runtimes
  end

  # -------------------------------------------------------------------------------------------------------

private
  def controller
    @controller ||= begin
      rc = KFramework.request_context
      (rc == nil) ? nil : rc.controller
    end
  end

  def controller_or_background_controller
    controller() || ApplicationController.make_background_controller(AuthContext.user)
  end
end
