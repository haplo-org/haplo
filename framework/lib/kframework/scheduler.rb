# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class KFramework

  SECONDS_IN_DAY = 86400

  # Register a scheduled task.
  # The hour, minute is a reference point to start, then period is given in seconds.
  # procedure is a proc to call to perform the task.
  def self.scheduled_task_register(name, description, hour, minute, period, procedure)
    if @@scheduled_tasks.has_key?(name)
      if KFRAMEWORK_ENV == 'development'
        puts "Ignoring duplicate scheduled task registration: #{name}"
        return
      else
        raise "Duplicate scheduled task registration: #{name}"
      end
    end
    @@scheduled_tasks[name] = ScheduledTask.new(name, description, procedure, "Every #{period}s starting #{hour}:#{minute}")
    @@scheduled_tasks_delayed_registration << [hour, minute, period, name]
  end

  # -------------------------------------------------------------------------------------------

  @@scheduled_tasks = Hash.new
  @@scheduled_tasks_delayed_registration = Array.new
  SCHEDULED_TASK_HEALTH_EVENTS = HealthEventReporter.new('SCHEDULED_TASK')

  class ScheduledTask
    attr_accessor :name, :description, :procedure, :scheduled_time, :_run_count, :_last_run, :_last_exception
    def initialize(name, description, procedure, scheduled_time)
      @name = name
      @description = description
      @procedure = procedure
      @scheduled_time = scheduled_time
      @_run_count = 0
    end
  end

  # Hook called from the Java Scheduler class.
  def scheduled_task_perform(name)
    task = @@scheduled_tasks[name]
    raise "No such task #{name}" unless task != nil
    task._run_count += 1
    task._last_run = Time.now
    begin
      KApp.logger.info("Running scheduled task #{name}")
      task.procedure.call
    rescue => e
      task._last_exception = e
      SCHEDULED_TASK_HEALTH_EVENTS.log_and_report_exception(e)
    ensure
      KApp.logger.flush_buffered
    end
  end

  # Called by framework start
  def scheduled_tasks_start
    @@scheduled_tasks_delayed_registration.each do |args|
      Java::OrgHaploAppserver::Scheduler.add(*args)
    end
  end

  # For console
  def dump_scheduled_tasks
    puts "  NAME                   DESCRIPTION              RUN COUNT  E?  LAST RUN AT"
    @@scheduled_tasks.keys.sort.each do |task_name|
      task = @@scheduled_tasks[task_name]
      last_run = ((task._last_run == nil) ? 'NEVER' : task._last_run.to_iso8601_s)
      puts sprintf('  %-22s %-30.30s %3d  %-2s  %s',
        task_name, task.description, task._run_count, ((task._last_exception == nil) ? '' : '!'), last_run)
    end
  end

  # For console
  def dump_scheduled_task_info(name)
    task = @@scheduled_tasks[name]
    if task == nil
      puts "No such task: #{name}"
    else
      puts "       Name: #{task.name}"
      puts "Description: #{task.description}"
      puts "        Run: #{task.scheduled_time}"
      puts "  Run count: #{task._run_count}"
      puts "   Last run: #{((task._last_run == nil) ? 'NEVER' : task._last_run.to_iso8601_s)}"
      if task._last_exception == nil
        puts "No exceptions thrown"
      else
        puts "*** LAST EXCEPTION"
        puts task._last_exception.inspect
        puts "  #{task._last_exception.backtrace.join("\n  ")}"
      end
    end
  end

end

# Define a console command to inspect what's happening with the scheduled tasks
class Console
  _Description "List scheduled tasks"
  _Help <<-__E
    List all the scheduled tasks, with their status.

    Use task name as an argument to list more info about a particular task,
    including any exception it threw on a previous run.
  __E
  def scheduled_tasks(name = nil)
    if name == nil
      KFRAMEWORK__BOOT_OBJECT.dump_scheduled_tasks
    else
      KFRAMEWORK__BOOT_OBJECT.dump_scheduled_task_info(name)
    end
    nil
  end
end
