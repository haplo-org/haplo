# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Setup_PluginsController < ApplicationController
  policies_required :setup_system
  include SystemManagementHelper

  JAVASCRIPT_LOG = Hash.new { |hash,key| hash[key] = [] }
  JAVASCRIPT_LOG_MUTEX = Mutex.new

  # Store JavaScript console.log() output here for the diagnostics page
  KNotificationCentre.when(:javascript_console_log) do |name, detail, text, last_used_plugin_name|
    text = text[0,2047] if text.length >= 2048 # Make sure the text isn't too long
    JAVASCRIPT_LOG_MUTEX.synchronize do
      log = JAVASCRIPT_LOG[KApp.current_application]
      log << "#{Time.now.to_iso8601_s}\t#{detail}\t#{last_used_plugin_name || '?'}\t#{text}"
      log.shift if log.length > 16
    end
  end

  def render_layout
    'management'
  end

  def handle_index
    @plugins = KPlugin.get_plugins_for_current_app
  end

  def handle_show
    @plugin_factory = KPlugin.get_plugins_for_current_app.plugin_factories.find { |factory| factory.name == params[:id] }
  end

  _GetAndPost
  def handle_install
    if request.post?
      if params[:plugin].length > 0 && params[:plugin] =~ /\A[a-zA-Z0-9_]+\z/
        # Determine installation secret
        plugin_info = KJavaScriptPlugin.get_plugin_info(params[:plugin])
        install_secret = (plugin_info == nil) ? nil : plugin_info.plugin_json["installSecret"]
        # If there's an installation secret, make sure it matches
        if install_secret != nil
          license_key = HMAC::SHA1.sign(install_secret, "application:#{KApp.current_application}")
          if params.has_key?(:license)
            if params[:license] != license_key
              @bad_license_key = true
              return
            end
          else
            @need_license_key = true
            return
          end
        end
        # License key checked, install plugin?
        install_success = false
        begin
          install_success = KPlugin.install_plugin(params[:plugin])
          if install_success
            redirect_to "/do/setup/plugins/show/#{params[:plugin]}?update=1"
            return
          end
        rescue => e
          if PLUGIN_DEBUGGING_SUPPORT_LOADED
            # Just use normal reporting, which should give the user a nice backtrace for their JavaScript plugin
            raise
          end
        end
        # In normal mode, show a nice error as the plugin install failed
        render :action => 'plugin_install_error'
      end
    end
  end

  _GetAndPost
  def handle_uninstall
    @plugin_factory = KPlugin.get_plugins_for_current_app.plugin_factories.find { |factory| factory.name == params[:id] }
    if request.post?
      if params[:uninstall] != 'confirm'
        @should_confirm = true
      else
        KPlugin.uninstall_plugin(params[:id])
        render :action => 'refresh_list'
      end
    end
  end

  def handle_diagnostics
    # Make a copy of the current log to avoid concurrency problems
    JAVASCRIPT_LOG_MUTEX.synchronize do
      @log = JAVASCRIPT_LOG[KApp.current_application].dup
    end
  end

  def handle_elements
  end

end