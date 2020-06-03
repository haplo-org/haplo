# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# ------------------------
class TestJob1 < KJob
  def self.run_count
    Thread.current[:_tj1_run_count] || 0
  end
  def self.reset_run_count
    Thread.current[:_tj1_run_count] = 0
  end
  def self.found_uid
    Thread.current[:_tj1_found_uid]
  end
  def self.store_uid
    Thread.current[:_tj1_store_uid]
  end
  def run(context)
    Thread.current[:_tj1_run_count] += 1
    Thread.current[:_tj1_found_uid] = AuthContext.user.id
    Thread.current[:_tj1_store_uid] = KObjectStore.external_user_id
  end
end

# ------------------------
class TestJob2 < KJob
  def self.run_count
    Thread.current[:_tj2_run_count] || 0
  end
  def self.reset_run_count
    Thread.current[:_tj2_run_count] = 0
  end
  def initialize(pretend_job_status)
    @pretend_job_status = pretend_job_status
    ls = Thread.current[:_tj2_last_serial] || -1
    @serial = ls + 1
  end
  def run(context)
    # Make sure the object got serialised and deserialised
    raise "Didn't have expected serial increment" if @serial == Thread.current[:_tj2_last_serial]
    Thread.current[:_tj2_last_serial] = @serial   # save the serial that was there when the object was deserialized
    @serial += 1              # inc, so it's different if it got serialised and deserialised
    # Inc run count
    Thread.current[:_tj2_run_count] += 1
    # Exception?
    raise "Expected exception" if @pretend_job_status == :throw_exception
    # Set the result in the context
    (code,delay,log_message) = @pretend_job_status
    case code
    when :complete
      # do nothing
    when :failure
      context.job_failed_and_retry(log_message, delay)
    when :fatal
      context.job_failed(log_message)
    when :defer
      context.defer_job(delay)
    end
  end
end

# ------------------------
class KJobTest < Test::Unit::TestCase

  def setup
    db_reset_test_data
    KApp.with_pg_database { |db| db.perform("DELETE FROM public.jobs WHERE application_id=#{_TEST_APP_ID}") }
  end

  def test_trivial_jobs
    # Reset state
    TestJob1.reset_run_count
    TestJob2.reset_run_count

    # Make a runner
    runner = KJob::Runner.new(KJob::QUEUE_DEFAULT)
    adjust_kjob_runner_for_tests(runner)

    # Set a user -- KJob picks it up from AuthContext
    old_auth_state = AuthContext.set_user(User.cache[42], User.cache[42])

    # Create a job
    TestJob1.new.submit
    assert_equal 0, TestJob1.run_count

    AuthContext.restore_state old_auth_state

    without_application do

      # Run it
      assert_equal true, runner.run_next_job

      # Check it did something
      assert_equal 1, TestJob1.run_count

      # Check the user id was passed through properly
      assert_equal 42, TestJob1.found_uid
      assert_equal 42, TestJob1.store_uid

      # Check that it won't run again
      assert_equal false, runner.run_next_job

    end

    # Check a job which retries
    TestJob2.reset_run_count
    TestJob2.new([:failure,0,'Test failure message']).submit

    without_application do
      watchdog = 1000
      while watchdog > 0 && runner.run_next_job
        watchdog -= 1
      end
      assert_equal KJob::DEFAULT_RETRIES_ALLOWED, TestJob2.run_count
    end

    # Check a job with a fatal error
    TestJob2.reset_run_count
    TestJob2.new([:fatal,nil,'Fatal message']).submit

    without_application do
      watchdog = 1000
      while watchdog > 0 && runner.run_next_job
        watchdog -= 1
      end
      assert_equal 1, TestJob2.run_count
    end

    # Check defers happen an unlimited number of times
    TestJob2.reset_run_count
    TestJob2.new([:defer,0]).submit

    without_application do
      watchdog = KJob::DEFAULT_RETRIES_ALLOWED + 20
      while watchdog > 0 && runner.run_next_job
        watchdog -= 1
      end
      assert_equal true, runner.run_next_job
      assert KJob::DEFAULT_RETRIES_ALLOWED < TestJob2.run_count
    end

    # Clear the queue
    setup

    # Check multiple jobs
    TestJob1.reset_run_count
    TestJob1.new.submit
    TestJob2.reset_run_count
    TestJob2.new([:complete]).submit
    without_application do
      assert_equal true, runner.run_next_job
      assert_equal true, runner.run_next_job
      assert_equal false, runner.run_next_job
      assert_equal 1, TestJob1.run_count
      assert_equal 1, TestJob2.run_count
    end

    # Check exceptions happen and clean up the job
    TestJob2.reset_run_count
    TestJob2.new(:throw_exception).submit
    without_application do
      assert_equal true, runner.run_next_job
      assert_equal 1, TestJob2.run_count
      assert_equal false, runner.run_next_job
      assert_equal 1, TestJob2.run_count
    end

    # Test that jobs only run in their specified queue
    runner2 = KJob::Runner.new(KJob::QUEUE_DEFAULT + 1)
    adjust_kjob_runner_for_tests(runner)
    TestJob1.reset_run_count
    TestJob1.new.submit
    without_application do
      assert_equal false, runner2.run_next_job
      assert_equal 0, TestJob1.run_count
      assert_equal true, runner.run_next_job
      assert_equal false, runner.run_next_job
      assert_equal 1, TestJob1.run_count
    end

  end
end

