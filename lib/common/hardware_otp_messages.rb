# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Handle messages asking for Hardware OTP token checks

if KFRAMEWORK_IS_MANAGED_SERVER

module HardwareOTPMessages
  # Message handler
  KMessageQueuing.sync_message_handler(:otp) do |message, sender|
    result = nil
    case message['action']
    when 'check'
      HardwareOTPMessages.using_database do
        # Check a token
        token = HardwareOtpToken.find_by_identifier(message['token'])
        if token != nil
          check_result = token.check_and_update(message['otp'])
          result = {'error' => false, 'result' => check_result, 'token' => message['token']}
        else
          result = {'error' => false, 'result' => 'fail', 'token' => message['token']}
        end
      end

    else
      result = {'error' => true, 'message' => "Unknown action"}
    end

    # Check a reply was generated, then return it
    raise "Internal logic error" if result == nil
    result
  end

  # Application specific support
  if RUNNING_IN_KAPPLICATION == :khq
    # Main application
    def self.using_database
      KApp.in_application(:no_app) do
        yield
      end
    end
  else
    # Normal Rails app
    def self.using_database
      begin
        yield
      ensure
        ActiveRecord::Base.clear_active_connections!
      end
    end
  end
end

end
