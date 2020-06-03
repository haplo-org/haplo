# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class HardwareOtpToken < MiniORM::Record

  # Parameters for Feitian OTP tokens:
  #   Event based: '6:0:-1:0:0:30'
  #   Time based:  '6:0:-1:60:1:2'

  # -------------------------------------------------------------------------------------------------

  table :hardware_otp_tokens do |t|
    t.column :timestamp,  :updated_at
    t.column :text,       :identifier
    t.column :text,       :algorithm
    t.column :text,       :parameters
    t.column :text,       :secret
    t.column :int,        :counter

    t.order 'identifier', :identifier
  end

  def initialize
    # Set defaults matching SQL table definition
    @counter = 0
  end

  def before_save
    self.updated_at = Time.now
  end

  # -------------------------------------------------------------------------------------------------

  def self.find_by_identifier(identifier)
    self.where(:identifier => identifier).first()
  end

  # -------------------------------------------------------------------------------------------------

  def check_and_update(otp)
    algorithm = ALGORITHMS[self.algorithm]
    raise "Bad OTP algorithm #{self.algorithm}" unless algorithm != nil
    algorithm.new(self).check_and_update(otp)
  end

  # -------------------------------------------------------------------------------------------------

  class HOTP
    OTPGen = Java::OrgOpenauthenticationOtp::OneTimePasswordAlgorithm
    def initialize(token)
      @token = token
      parameters = token.parameters.split(':') # digits, checksum?, truncation offset, time period, allowance before, allowance after
      @digits = parameters[0].to_i
      raise "Bad digits" unless @digits > 4
      @checksum = (parameters[1] == '1')
      @truncation_offset = parameters[2].to_i
      @time_period = parameters[3].to_i
      @allowance_before = parameters[4].to_i
      @allowance_before = 2 if @allowance_before < 2 # to find reused codes
      @allowance_after = parameters[5].to_i
      check_parameters
    end
    def check_and_update(otp)
      raise "Bad otp" unless otp.class == String
      s = expected_counter
      (s - @allowance_before).upto(s + @allowance_after) do |c|
        gen = OTPGen.generateOTP(@token.secret.unpack('m').first.to_java_bytes, c, @digits, @checksum, @truncation_offset)
        # Compare hashes of strings instead of the actual strings to resist timing attacks
        if (Digest::SHA1.hexdigest(gen) == Digest::SHA1.hexdigest(otp))
          if @token.counter >= c
            # The OTP has been used before, or is an old OTP. Don't allow it to be used again.
            return :reuse
          else
            # Update the counter value in the database
            @token.counter = c
            @token.save
            # Tell the caller it matched
            return :pass
          end
        end
      end
      :fail
    end
  end

  # -------------------------------------------------------------------------------------------------

  class TimeHOTP < HOTP
    def check_parameters
      raise "Bad time period" unless @time_period > 10
    end
    def expected_counter
      (Time.new.to_i / @time_period)
    end
  end

  class EventHOTP < HOTP
    def check_parameters
    end
    def expected_counter
      @token.counter + 1
    end
  end

  # -------------------------------------------------------------------------------------------------

  ALGORITHMS = {
    'HOTP:time' => TimeHOTP,
    'HOTP:event' => EventHOTP
  }

end

