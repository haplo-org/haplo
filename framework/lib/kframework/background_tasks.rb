# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class KFramework

  class BackgroundTask
    attr_accessor :_thread
    attr_accessor :_is_running
    attr_accessor :_start_count
    attr_accessor :_last_start_time
    attr_accessor :_last_exception
    def start
      raise "No task implemented for #{self.class.name.to_s}"
    end
    def prepare_to_stop
    end
    def stop
    end
    def description
      self.class.name
    end
    def is_transient?
      false # return true to stop the runner from restarting it when it exits
    end
  end

  @@background_tasks = Array.new
  @@continue_running_background_tasks = true

  def self.register_background_task(task)
    @@background_tasks << task
  end

  def self.should_continue_running_background_tasks
    @@continue_running_background_tasks
  end

  BACKGROUND_TASK_HEALTH_EVENTS = HealthEventReporter.new('BACKGROUND_TASK')

  def start_background_tasks
    @running_tasks = @@background_tasks.dup
    @running_tasks.each do |task|
      task._start_count = 0
      task._last_start_time = nil
      task._thread = Thread.new do
        while KFramework.should_continue_running_background_tasks
          begin
            # Store start info
            task._start_count += 1
            task._last_start_time = Time.now
            # Log start
            logger = KApp.logger
            logger.info "Starting background task #{task.description}"
            logger.flush_buffered
            # Start the task
            begin
              task._is_running = true
              task.start
            ensure
              task._is_running = false
            end
            # Stop now?
            break if task.is_transient?
            # Throttle restart
            sleep 1 if KFramework.should_continue_running_background_tasks
          rescue => e
            # Store the exception for later
            task._last_exception = e
            # Log the error
            logger = KApp.logger
            logger.error "EXCEPTION IN BACKGROUND TASK #{task.description}"
            logger.error "Will restart #{task.description} in 5 seconds..."
            BACKGROUND_TASK_HEALTH_EVENTS.log_and_report_exception(e, "task restarting")
            logger.flush_buffered
            # Throttle retries
            sleep 5
          ensure
            KApp.logger.flush_buffered
          end
        end
        KApp.logger.info("Background task #{task.description} has stopped.")
        KApp.logger.flush_buffered
      end
      # Wait a little while before starting the next task, to avoid rushing all at once
      sleep 0.2
    end
  end

  def stop_background_tasks
    return if @running_tasks == nil
    # Flag to stop
    @@continue_running_background_tasks = false
    # Signal each task to stop
    @running_tasks.each do |task|
      task.prepare_to_stop
    end
    # Ask each task to stop
    @running_tasks.each do |task|
      task.stop
    end
    # Wait for threads to stop
    @running_tasks.each do |task|
      task._thread.join
    end
  end

  # Console command support
  def dump_background_tasks
    if @running_tasks == nil
      puts "No tasks"
    else
      puts '  *  TASK DESCRIPTION                 START COUNT  RUNNING?     LAST START TIME'
      @running_tasks.each_with_index do |task,index|
        puts sprintf('  %-2d %-40.40s %3d %02s  %s',
          index, task.description, task._start_count, task._is_running ? 'y' : 'n', task._last_start_time.to_iso8601_s)
      end
    end
  end

  def dump_background_task_info(command_index)
    task = @running_tasks[command_index]
    if task == nil
      puts "No task #{command_index}"
      return
    end
    puts "Task description: #{task.description}"
    puts "     Start count: #{task._start_count}"
    puts "     Running now: #{task._is_running ? 'YES' : 'NO'}"
    puts " Last start time: #{task._last_start_time.to_iso8601_s}"
    e = task._last_exception
    if e == nil
      puts "Task has not thrown any exceptions."
    else
      puts "*** LAST EXCEPTION"
      puts e.inspect
      puts "  #{e.backtrace.join("\n  ")}"
    end
  end
end

# Define a console command to inspect what's happening with the background tasks
class Console
  _Description "List background tasks"
  _Help <<-__E
    List all the background tasks, with their status.

    Use task number as an argument to list more info about a particular task,
    including any exception it threw on a previous run.
  __E
  def background_tasks(command_index = nil)
    if command_index == nil
      KFRAMEWORK__BOOT_OBJECT.dump_background_tasks
    else
      KFRAMEWORK__BOOT_OBJECT.dump_background_task_info(command_index.to_i)
    end
    nil
  end
end

