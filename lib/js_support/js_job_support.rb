# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Provide utility functions to KJob JavaScript objects

module JSKJobSupport

  def self.runJob(name, data)
    # Check job name is sensible
    unless name =~ /\A[a-zA-Z0-9_]+\:[a-zA-Z0-9_]+\z/
      raise JavaScriptAPIError, "Bad background task name"
    end
    # Queue the job for processing later
    KPluginJob.new(name, data).submit
  end

  class KPluginJob < KJob
    include KPlugin::HookSite

    def initialize(name, data)
      @name = name
      @data = data
    end

    def default_queue
      KJob::QUEUE_PLUGINS
    end

    def description_for_log
      "Plugin Job: #{@name}"
    end

    def run(context)
      # NOTE: std_reporting support also uses this interface (until replaced by callback)
      call_hook(:hPlatformInternalJobRun) do |hooks|
        hooks.run(@name, @data)
      end
    end
  end

end

Java::OrgHaploJsinterface::KJob.setRubyInterface(JSKJobSupport)
