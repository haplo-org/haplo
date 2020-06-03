# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KLoginAttemptThrottle

  # Init login failure tracking (use global variable so it doesn't get reset in dev mode, and the tests can easily get at it)
  $khq_login_failures_lock ||= Mutex.new
  $khq_login_failures ||= Hash.new

  # How long a failure should be counted against a client
  FAILURE_ATTEMPT_TIMEOUT = 300
  # How many failures allowed in a period
  FAILURE_ATTEMPT_MAX = 50

  # Exception thrown if logins are throttled for this IP address
  class LoginThrottled < KFramework::SecurityAbort
  end

  Outcome = Struct.new(:was_success)

  # Wrap a authentication attempt.
  # Will return the return value of the yield.
  def self.with_bad_login_throttling(client_ip)
    ##raise "Bad IP address for throttling" unless client_ip =~ /\A\d+\.\d+\.\d+\.\d+\z/  # to check this is called correctly
    client_failures = nil
    $khq_login_failures_lock.synchronize do
      client_failures = $khq_login_failures[client_ip]
      if client_failures != nil
        last_fail, number_failures = client_failures
        if last_fail < (Time.now.to_i - FAILURE_ATTEMPT_TIMEOUT)
          # Last failure was too long ago to count
          $khq_login_failures.delete(client_ip)
          client_failures = nil
        else
          # Too many failures in this period?
          if number_failures >= FAILURE_ATTEMPT_MAX
            raise LoginThrottled
          end
        end
      end
    end

    outcome = Outcome.new
    result = yield(outcome)
    raise "Outcome not set when using with_bad_login_throttling()" if outcome.was_success == nil

    $khq_login_failures_lock.synchronize do
      if outcome.was_success
        # Clear failures, as someone has logged in - saves a little memory on this app server plus a little less harsh throttling
        $khq_login_failures.delete(client_ip)
      else
        # Add to failures info
        $khq_login_failures[client_ip] = [Time.now.to_i, (client_failures == nil) ? 1 : (client_failures[1] + 1)]
      end
    end

    result
  end

end

