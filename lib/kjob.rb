# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KJob
  QUEUE_DEFAULT   = 0
  QUEUE_PLUGINS   = 1
  QUEUE_FILE_TRANSFORM_PIPELINE = 2
  QUEUE_HTTP_CLIENT = 3
  QUEUE__COUNT    = 4

  # How many worker threads to start
  BACKGROUND_TASK_COUNTS = {
    QUEUE_DEFAULT => 3,
    QUEUE_FILE_TRANSFORM_PIPELINE => 2,
    QUEUE_PLUGINS => 1, # DO NOT CHANGE THIS
    # Plugins need some way to be able to control concurrency of their jobs, and
    # by default, not run any concurrently. Setting only one background task for
    # plugins is an easy way to ensure no concurrency, even if it does introduce
    # other problems around efficiency and ability of apps to block other apps.
    QUEUE_HTTP_CLIENT => 2
  }

  DEFAULT_RETRY_DELAY = 60
  DEFAULT_RETRIES_ALLOWED = 8

  # For signalling to job runner threads
  @@run_flags = Array.new
  0.upto(QUEUE__COUNT-1) do
    flag = Java::OrgHaploCommonUtils::WaitingFlag.new
    @@run_flags << flag
    flag.setFlag()  # make sure the job queues are examined when starting up
  end

  JOB_HEALTH_EVENTS = KFramework::HealthEventReporter.new('JOB')

  # ---------------------------------------------------------------------------------------------------------------------
  #   Job implementation
  # ---------------------------------------------------------------------------------------------------------------------
  #
  # To implement a job...
  #
  #   Derive from KJob
  #   Implement initialize to take parameters for job (everything to be serialisable)
  #   Implement run(), which does the work.
  #     - Just return without doing anything special on success
  #     - On fatal error, call context.job_failed(msg) or let an exception propagate
  #     - For a temporary error, call context.job_failed_and_retry(msg, delay) to reshedule a limited number of times
  #     - To defer the job, call context.defer_job(delay)
  #   For temporary failures and deferments, the object is reserialised to update state in the queue.
  #
  #   Use context.user_id to get the (integer) user which initiated the job.
  #
  def run(context)
  end

  # When a job has run out of retries, this is called to notify the job that it's not
  # going to be run again.
  def giving_up()
  end

  def description_for_log
    self.class.to_s
  end

  def default_queue
    QUEUE_DEFAULT
  end

  def default_retries_allowed
    DEFAULT_RETRIES_ALLOWED
  end

  # Call to queue the job for execution later
  # Will be run within the current pg transaction; if the transaction fails the job won't be run.
  def submit(delay_for = nil, queue = nil, retries_allowed = nil)
    pg = KApp.get_pg_database
    serialised = Marshal.dump(self)
    job_queue = queue || self.default_queue
    state = AuthContext.state
    raise "Cannot submit job without AuthContext" unless state
    pg.update("INSERT INTO public.jobs (application_id,user_id,auth_user_id,queue,retries_left,run_after,object) VALUES (#{KApp.current_application},#{state.user.id.to_i},#{state.auth_user.id.to_i},#{job_queue},#{retries_allowed || default_retries_allowed},NOW()+interval '#{delay_for || 0} seconds',E'#{PGconn.escape_bytea(serialised)}')")

    # Send a notification about an entry in the job queue, which causes the queue to be
    # triggered later at the end request checkpoint, or the end of the in_application block.
    KNotificationCentre.notify(:kjob, :queued, job_queue)
  end

  # ---------------------------------------------------------------------------------------------------------------------
  #   Context class for job running
  # ---------------------------------------------------------------------------------------------------------------------

  class Context
    # For reading information back by the runner
    attr_reader :status
    attr_reader :log_message
    attr_reader :delay
    def initialize
      @status = :complete
    end
    def job_failed_and_retry(log_message = nil, delay = nil)
      @status = :failure
      @log_message = log_message
      @delay = delay
    end
    def job_failed(log_message = nil)
      @status = :fatal
      @log_message = log_message
    end
    def defer_job(delay = nil)
      @status = :defer
      @delay = delay
    end
  end

  # ---------------------------------------------------------------------------------------------------------------------
  #   Trigger jobs in the worker process
  # ---------------------------------------------------------------------------------------------------------------------

  # Compatibility method for other parts of the system to trigger jobs
  def self.trigger_jobs_in_worker_processes
    @@run_flags.each { |flag| flag.setFlag() }
  end

  # Trigger jobs when all the processing for this operation is done, so failed transactions aren't a problem.
  KNotificationCentre.when(:kjob, :queued, {:start_buffering => true, :deduplicate => true}) do |name, detail, job_queue|
    @@run_flags[job_queue].setFlag()
  end

  # ---------------------------------------------------------------------------------------------------------------------
  #   Runner interface
  # ---------------------------------------------------------------------------------------------------------------------

  def self.get_run_flag(queue)
    @@run_flags[queue]
  end

  # ---------------------------------------------------------------------------------------------------------------------
  #   Runner class
  # ---------------------------------------------------------------------------------------------------------------------

  class Runner
    def initialize(queue)
      @queue = queue.to_i
      @should_process_jobs = true
      # Generate the SQL for the next job process -- uses a serialisable transcation so simulatious reads
      # don't get the same job. UPDATE ... RETURNING isn't atomic.
      @next_job_sql = "UPDATE public.jobs SET runner_pid=#{Thread.current.object_id} WHERE id=(SELECT id FROM public.jobs WHERE queue=#{@queue} AND run_after <= NOW() AND runner_pid=0 ORDER BY id LIMIT 1) RETURNING id,application_id,user_id,auth_user_id,retries_left,object"
    end

    # Returns true if a job was processed (even if it errored)
    def run_next_job
      job_info = nil
      KApp.in_application(:no_app) do
        pg = KApp.get_pg_database

        db_retries = 10
        res = nil
        while res == nil && db_retries > 0
          begin
            # Need to use a separate command to start the transaction; underlying JDBC interface won't allow it to be wrapped into the UPDATE stmt
            pg.perform("BEGIN ISOLATION LEVEL SERIALIZABLE")
            res = pg.exec(@next_job_sql)
            if res.length == 0
              res.clear
              pg.perform('ROLLBACK')
              return false  # nothing happened
            end
            pg.perform('COMMIT')
          rescue
            # Exceptions are resonably likely as two job runners querying for a new job at the same time would
            # update the same row and conflict.
            pg.perform('ROLLBACK')
            db_retries -= 1
            res.clear if res != nil
            res = nil
            sleep((db_retries == 0) ? 100 : 1)  # throttle
          end
        end
        # If an exception is returned every time, return saying that nothing happened.
        return false if res == nil

        job_info = res.result.first
        res.clear
      end

      job_id,application_id,user_id,auth_user_id,retries_left,serialised = job_info
      application_id = application_id.to_i

      begin
        job = Marshal.load(PGconn.unescape_bytea(serialised))
      rescue => e
        # If we can't deserialize the object, just delete it (lost cause)
        JOB_HEALTH_EVENTS.log_and_report_exception(e, 'deserialisation failed')
        KApp.logger.error("Deserialisation of job failed")
        KApp.in_application(:no_app) do
          delete_job(job_id, KApp.get_pg_database)
        end
        return true   # did something
      end

      # Log the start of a job run and flush the logs, so that something is in
      # the logs while the job is running. Otherwise all the logging information
      # only appears after the job has completed.
      log_info = "id=#{job_id}, app=#{application_id}, retries_left=#{retries_left}, job=#{job.description_for_log}, queue=#{@queue}"
      KApp.logger.info "Running job: #{log_info} (full logs later)"
      KApp.logger.flush_buffered
      KApp.logger.info "Run job: #{log_info}"

      context = Context.new
      job_result = nil
      begin
        KApp.in_application(application_id) do
          ms = AuthContext.with_user(User.cache[user_id.to_i], User.cache[auth_user_id.to_i]) do
            Benchmark.ms do
              job.run(context)
            end
          end
          KApp.logger.info "Job run took #{ms.to_i}ms with status #{context.status} (#{log_info})"
        end
      rescue => e
        context.job_failed('Exception '+e.inspect)
        JOB_HEALTH_EVENTS.log_and_report_exception(e)
      end

      gave_up_on_job = false

      KApp.in_application(:no_app) do
        pg = KApp.get_pg_database

        case context.status
        when :complete
          delete_job(job_id, pg)

        when :failure
          JOB_HEALTH_EVENTS.log_and_report_exception(nil, 'job failed')
          KApp.logger.error "Job failure: #{log_info}, message=\"#{context.log_message || '?'}\""
          if retries_left.to_i <= 1
            # Can't do anything more
            gave_up_on_job = true
            delete_job(job_id, pg)
          else
            # Mark it for retrying, and re-serialize the job so it can have updated state
            d = context.delay || DEFAULT_RETRY_DELAY
            @last_delay = d
            pg.update("UPDATE public.jobs SET runner_pid=0,retries_left=(retries_left-1),run_after=NOW()+interval '#{d} seconds',object=E'#{PGconn.escape_bytea(Marshal.dump(job))}' WHERE id=#{job_id}")
          end

        when :fatal
          KApp.logger.error "Job fatal error: #{log_info}, message=\"#{context.log_message || '?'}\""
          delete_job(job_id, pg)

        when :defer
          # Reserialise the job so it can update it's state
          d = context.delay || DEFAULT_RETRY_DELAY
          @last_delay = d
          pg.update("UPDATE public.jobs SET runner_pid=0,run_after=NOW()+interval '#{d} seconds',object=E'#{PGconn.escape_bytea(Marshal.dump(job))}' WHERE id=#{job_id}")

        else
          # If it returns anything, just delete it
          delete_job(job_id, pg)
        end
      end

      if gave_up_on_job
        KApp.in_application(application_id) do
          begin
            job.giving_up()
          rescue => e
            KApp.logger.log_exception e
          end
        end
      end

      # If this created any jobs in other queues, set them off now
      KJob.trigger_jobs_in_worker_processes

      true
    ensure
      # Make sure logs get flushed
      KApp.logger.flush_buffered
    end

    def delete_job(job_id, pg)
      pg.perform("DELETE FROM public.jobs WHERE id=#{job_id}")
    end

    # -----------------------------------------------------------------------------------------------------------------
    # Worker process which waits for jobs and runs them
    def run_as_worker
      run_flag = KJob.get_run_flag(@queue)

      # Keep going round the loop processing jobs, waiting on the semaphore for the queue
      while @should_process_jobs

        while run_next_job()
          # (empty loop)
        end

        timeout = 600
        if @last_delay != nil && @last_delay > 0
          # If a previous job had a delay, wait for around that time instead of the main timeout
          timeout = @last_delay + 1
          @last_delay = nil
        end
        timeout = 4 if timeout < 4  # Don't wait tiny short times
        timeout += rand(8).to_i     # Make it wait a random time to avoid things happening all at the same time

        run_flag.waitForFlag(timeout * 1000)  # convert to ms
      end
    end

    # Shutdown is done in two phases so to avoid a race condition with thread being signalled
    # too early for their stop flags to be set.
    def set_to_stop
      @should_process_jobs = false
    end
    def flag_to_stop
      KJob.get_run_flag(@queue).wakeAllWaiting()
    end
  end

  # --------------------------------------------------------------------------------------------------------------------

  # Background tasks

  class BackgroundTask < KFramework::BackgroundTask
    def initialize(queue_number, worker_index)
      @queue_number = queue_number
      @worker_index = worker_index
    end
    def description
      "KJob::BackgroundTask (q#{@queue_number}/n#{@worker_index})"
    end
    def start
      @worker = Runner.new(@queue_number)
      @worker.run_as_worker
    end
    def prepare_to_stop
      @worker.set_to_stop
    end
    def stop
      @worker.flag_to_stop
    end
  end

  # Register the background tasks
  0.upto(QUEUE__COUNT-1) do |q|
    0.upto(BACKGROUND_TASK_COUNTS[q]-1) do |i|
      KFramework.register_background_task(BackgroundTask.new(q,i))
    end
  end

end

# Implement a console command

class Console

  _Description "Examine job queue"
  _Help <<-__E
    With no arguments, list the current size of job queue split by application.
    With a single integer argument, list the jobs for a particular application.
  __E
  def jobs(app_id = nil)
    KApp.in_application(:no_app) do
      db = KApp.get_pg_database
      if app_id == nil
        # List counts of jobs
        r = db.exec("SELECT application_id,COUNT(id) FROM public.jobs GROUP BY application_id ORDER BY application_id")
        puts "  APP_ID   COUNT"
        total = 0
        r.each do |application_id,count_s|
          count = count_s.to_i
          total += count
          puts sprintf("  %-8d %-8d", application_id, count)
        end
        puts "(#{total} jobs queued)"
      else
        # List jobs for a particular application
        r = db.exec("SELECT id,user_id,queue,retries_left,run_after,runner_pid,object FROM public.jobs WHERE application_id=$1 ORDER BY id", app_id)
        puts "  JOBID  UID Q  RTL TID    RUNAFTER"
        r.each do |id,user_id,queue,retries_left,run_after,runner_pid,object|
          puts sprintf("  %-6d %-3d %-2d %-3d %-6d %s", id.to_i, user_id.to_i, queue.to_i, retries_left.to_i, runner_pid.to_i, run_after)
          begin
            job = Marshal.load(PGconn.unescape_bytea(object))
            puts "    #{job.inspect}"
          rescue => e
            puts "  ** couldn't deserialise job"
          end
        end
      end
    end
  end

end
