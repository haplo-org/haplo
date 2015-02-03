# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class OtpControlllerTest < IntegrationTest

  # TODO: Tests without OTP implementation available
  HAVE_OTP_IMPLEMENTATION = KFRAMEWORK_LOADED_COMPONENTS.include?('management')

  def setup
    db_reset_test_data
    KApp.get_pg_database.exec("SELECT setval('users_id_seq', 300);")
    @user = User.new(
      :kind => User::KIND_USER,
      :name_first => 'first',
      :name_last => "last",
      :email => 'authtest@example.com')
    @user.password = 'pass1234'
    @user.save!
  end

  def teardown
    @user.destroy
  end

  # ===================================================================================================================

  def test_trust_control
    return unless HAVE_OTP_IMPLEMENTATION
    AUTHENTICATION_LOGIN_TEST_FAILURE_LOCK.synchronize do
      # Reset state
      KHardwareOTP.clear_temporary_code
      KApp._thread_context.app_globals = nil

      # Log in
      assert_login_as('authtest@example.com', 'pass1234')
      assert_equal @user.id, session[:uid]

      # Get CSRF token
      get_a_page_to_refresh_csrf_token

      # Make sure you can't do OTP stuff without :control_trust
      assert_equal false, User.find(@user.id).policy.can_control_trust?
      get_403 '/do/admin/otp'

      # Try again, this time with :control_trust policy
      policy = Policy.new(:user_id => @user.id, :perms_allow => KPolicyRegistry.to_bitmask(:control_trust), :perms_deny => 0)
      policy.save!
      assert_equal true, User.find(@user.id).policy.can_control_trust?
      get '/do/admin/otp'
      assert_select '#z__page_name h1', 'Manage OTP tokens'

      # Reset counter on first token
      time1_token = HardwareOtpToken.find_by_identifier('test-1-time')
      time1_token.counter = 12345
      time1_token.save! # reset counter

      about_to_create_an_audit_entry

      # Assign a token after a few bad attempts
      assert_equal nil, User.find(41).otp_identifier
      post '/do/admin/otp/set/41', {:identifier => "no-such-token", :password => '0000000'}
      assert_select '.z__general_alert', 'Incorrect OTP or unknown token serial number. Please try again.'
      post '/do/admin/otp/set/41', {:identifier => "test-1-time", :password => ''}
      assert_select '.z__general_alert', 'Incorrect OTP or unknown token serial number. Please try again.'
      post '/do/admin/otp/set/41', {:identifier => "test-1-time", :password => '000'}
      assert_select '.z__general_alert', 'Incorrect OTP or unknown token serial number. Please try again.'
      post '/do/admin/otp/set/41', {:identifier => "test-1-time", :password => '0000000'}
      assert_select '.z__general_alert', 'Incorrect OTP or unknown token serial number. Please try again.'
      set_otp = TestHardwareOTP.next_otp_for("test-1-time")
      post_302 '/do/admin/otp/set/41', {:identifier => "test-1-time", :password => set_otp}
      assert_redirected_to '/do/admin/otp'
      assert_equal 'test-1-time', User.find(41).otp_identifier
      assert_audit_entry(:kind => 'USER-OTP-TOKEN', :entity_id => 41, :user_id => @user.id, :data => {"identifier" => "test-1-time"})
      # Check reuse
      post '/do/admin/otp/set/41', {:identifier => "test-1-time", :password => set_otp}
      assert_select '.z__general_alert', 'The code you entered has already been used. Please wait until your token generates another code, and try again.'

      # Check you need a token yourself to set a temporary code
      get '/do/admin/otp/temp_code'
      assert_select '#z__ws_content p:nth-child(1)', 'You cannot create temporary codes for colleagues because you do not have a token assigned to your account.'

      # Reset counter on second token
      time2_token = HardwareOtpToken.find_by_identifier('test-2-time')
      time2_token.counter = 22345
      time2_token.save! # reset counter

      # Set a temporary code, after a bad attempt
      @user.otp_identifier = 'test-2-time'
      @user.save!
      assert_audit_entry(:kind => 'USER-OTP-TOKEN')
      post '/do/admin/otp/temp_code3/41', {:password => '0000000'}
      assert_select('p.z__general_alert', 'Incorrect code, please try again.')
      KApp._thread_context.app_globals = nil
      assert_equal nil, KHardwareOTP.get_temporary_code_user_id
      temp_code_otp = TestHardwareOTP.next_otp_for("test-2-time")
      post '/do/admin/otp/temp_code3/41', {:password => temp_code_otp}
      KApp._thread_context.app_globals = nil
      assert_equal 41, KHardwareOTP.get_temporary_code_user_id
      # Check reuse is reported correctly
      post '/do/admin/otp/temp_code3/41', {:password => temp_code_otp}
      assert_select '.z__general_alert', 'The code you entered has already been used. Please wait until your token generates another code, and try again.'

      # Withdraw the token
      post_302 '/do/admin/otp/withdraw/41'
      assert_equal nil, User.find(41).otp_identifier
      assert_audit_entry(:kind => 'USER-OTP-TOKEN', :entity_id => 41, :user_id => @user.id, :data => {"identifier" => nil})

      # Clean up
      KHardwareOTP.clear_temporary_code
    end
  end

end

