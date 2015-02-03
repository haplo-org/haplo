# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KPlugin

  module Schedule
    extend KPlugin::HookSite
    PLUGIN_SCHEDULE_HEALTH_EVENTS = KFramework::HealthEventReporter.new('PLUGIN_SCHEDULE')

    def self.call_scheduled_hooks
      # Prepare arguments for hook
      time = Time.now
      year = time.year
      month = time.month - 1 # use JavaScript Date conventions
      dayOfMonth = time.mday
      hour = time.hour
      dayOfWeek = time.wday
      # Which hooks should be called?
      hooks_to_call = [:hScheduleHourly]
      hooks_to_call << :hScheduleDailyMidnight if hour == 0
      hooks_to_call << :hScheduleDailyEarly if hour == 6
      hooks_to_call << :hScheduleDailyMidday if hour == 12
      hooks_to_call << :hScheduleDailyLate if hour == 18
      # Call the hooks in every application
      KApp.in_every_application do
        run_scheduled_hooks(hooks_to_call, [year, month, dayOfMonth, hour, dayOfWeek])
      end
    end

    def self.run_scheduled_hooks(hooks_to_call, time_args)
      app_id = KApp.current_application
      logger = KApp.logger
      logger.info("Running plugin scheduled hooks [#{hooks_to_call.join(',')}] in app #{app_id}...")
      hooks_to_call.each do |hook_name|
        begin
          call_hook(hook_name) do |hooks|
            logger.info("Calling #{hook_name}...")
            hooks.send(:run, *time_args)
          end
        rescue => e
          logger.error("Caught exception handling hook #{hook_name} in app #{app_id}")
          PLUGIN_SCHEDULE_HEALTH_EVENTS.log_and_report_exception(e)
        end
      end
      logger.info("Finished calling hooks.")
      logger.flush_buffered
    end

    KFramework.scheduled_task_register(
      "plugin_schedule", "Call scheduled hooks in plugins",
      0, 1, 3600, # Every hour at one minute past the hour
      proc { KPlugin::Schedule.call_scheduled_hooks }
    )
  end

end

