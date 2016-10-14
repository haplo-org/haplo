# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Provide platform support to std_reporting plugin

module JSStdReportingSupport

  PLUGIN_NAME = "std_reporting".freeze
  DB_TABLE_NAME = "rebuilds".freeze
  UPDATE_JOB_NAME = "#{PLUGIN_NAME}:update".freeze

  WAIT_FOR_UPDATE_REQUESTS = 60*60 # one hour

  StdReporting = Java::OrgHaploJsinterfaceStdplugin::StdReporting

  # -------------------------------------------------------------------------

  def self.getCurrentApplicationId()
    KApp.current_application
  end

  # -------------------------------------------------------------------------

  class BackgroundTask < KFramework::BackgroundTask
    include KPlugin::HookSite
    def initialize()
    end
    def description
      "#{PLUGIN_NAME} background updates"
    end
    def prepare_to_stop;  StdReporting.setShouldStopUpdating(); end
    def stop;             StdReporting.setShouldStopUpdating(); end

    def start
      # First, wait a little, then check for updates in all apps in case
      # updates where interrupted by an application restart
      sleep(1.5)
      KApp.in_every_application { _do_updates_in_current_app() }
      # Now wait for requests to run updates from other threads
      while StdReporting.shouldRunUpdates()
        StdReporting.getApplicationsWithUpdatesAndReset().each do |app_id|
          KApp.in_application(app_id) { _do_updates_in_current_app() }
        end
        StdReporting.waitForUpdates(WAIT_FOR_UPDATE_REQUESTS)
      end
    end
    def _do_updates_in_current_app
      # Application might not use std_reporting
      std_reporting = KPlugin.get(PLUGIN_NAME)
      if std_reporting
        # Check there's something in the rebuilds
        db_namespace = KJSPluginRuntime::DatabaseNamespaces.new()[PLUGIN_NAME]
        raise "Unexpected namespace" unless db_namespace =~ /\A[a-z0-9]{6,}\z/
        has_rebuilds = KApp.get_pg_database.exec("SELECT 1 FROM j_#{db_namespace}_rebuilds LIMIT 1").length
        if has_rebuilds != 0
          sleep(0.5) # hopefully the triggering runtime will no longer be in use and can be reused here
          KApp.logger.info("Starting #{PLUGIN_NAME} updates for application #{KApp.current_application}")
          # TODO: Use a proper JS callback when implemented instead of :hPlatformInternalJobRun (and update comment in js_job_support.rb)
          call_hook(:hPlatformInternalJobRun) do |hooks|
            hooks.run(UPDATE_JOB_NAME, '{}')
          end
          KApp.logger.info("Finished #{PLUGIN_NAME} updates for application #{KApp.current_application}")
          KApp.logger.flush_buffered
        end
      end
    end
  end

  KFramework.register_background_task(BackgroundTask.new())

end

Java::OrgHaploJsinterfaceStdplugin::StdReporting.setRubyInterface(JSStdReportingSupport)
