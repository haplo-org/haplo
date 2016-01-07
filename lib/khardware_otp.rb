# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KHardwareOTP

  Result = Struct.new(:ok, :reason, :message)
  MESSAGE_INCORRECT = 'Incorrect code, please try again.'
  MESSAGE_REUSE = 'The code you entered has already been used. Please wait until your token generates another code, and try again.'
  MESSAGE_NOT_IMPLEMENTED = "This installation does not support hardware OTP tokens."

  TEMPORARY_CODE_VALIDITY = 300

  # Health reporting for OTP checks
  OTP_HEALTH_REPORTER = KFramework::HealthEventReporter.new("OTP_MESSAGE")

  # Needs IP address of the client to be able to do throttling
  def self.check_otp(identifier, otp, client_ip, user_id = nil)
    result = nil
    KLoginAttemptThrottle.with_bad_login_throttling(client_ip) do |outcome|
      result = check_otp2(identifier, otp, user_id)
      outcome.was_success = (nil != result && result.ok)
    end
    result
  end

  def self.check_otp2(identifier, otp, user_id = nil)
    result = nil
    # Check OTP value
    raise "Bad OTP type" unless otp.class == String
    otp = otp.gsub(/[^0-9]/,'') # remove non-digits
    raise "OTP too short" unless otp.length >= 5
    # Temporary code active for this user?
    if user_id != nil
      temp_code_uid, temp_code = _get_temp_code
      if temp_code_uid != nil && user_id == temp_code_uid && temp_code.length > 5 && otp == temp_code
        # Used the correct temporary code!
        clear_temporary_code # but only once
        return Result.new(true, :temp_code)
      end
    end
    # Check OTP with server
    begin
      if @@check_implementation
        result = @@check_implementation.call(identifier, otp)
      else
        result = Result.new(false, :noimpl, MESSAGE_NOT_IMPLEMENTED)
      end
    rescue => e
      OTP_HEALTH_REPORTER.log_and_report_exception(e)
    end
    result || Result.new(false, :fail, MESSAGE_INCORRECT)
  end

  def self.set_temporary_code(user_id, temporary_code)
    raise "Bad temporary code" unless temporary_code.class == String && temporary_code.gsub(/\s/,'').length > 5
    KApp.set_global(:otp_override, "#{user_id}:#{temporary_code}:#{Time.now.to_i}")
  end

  # Returns user ID if a user has a temporary code, otherwise nil
  def self.get_temporary_code_user_id
    user_id, code = _get_temp_code
    user_id
  end

  def self.clear_temporary_code
    KApp.set_global(:otp_override, '')
  end

  def self._get_temp_code
    override = KApp.global(:otp_override)
    return [nil, nil] if override == nil
    user_id, code, time = override.split(':')
    user_id = user_id.to_i
    time = time.to_i
    time_now = Time.now.to_i
    if (user_id > 0) && (code != nil) && (code.length > 5) && (time_now >= time) && ((time + TEMPORARY_CODE_VALIDITY) > time_now)
      return [user_id, code]
    end
    [nil, nil]
  end

  @@check_implementation = nil
  def self.check_implementation=(impl)
    @@check_implementation = impl
  end

end
