# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class AuthenticationControllerTest < IntegrationTest

  # TODO: Tests without OTP implementation available
  HAVE_OTP_IMPLEMENTATION = KFRAMEWORK_LOADED_COMPONENTS.include?('management')

  def setup_in_app(app_id)
    @_users ||= Hash.new
    KApp.in_application(app_id) do
      db_reset_test_data
      KApp.get_pg_database.exec("SELECT setval('users_id_seq', 300);")
      @_users[app_id] = User.new(
        :name_first => 'first',
        :name_last => "last#{app_id}",
        :email => 'authtest@example.com')
      @_users[app_id].kind = User::KIND_USER
      @_users[app_id].password = 'pass1234'
      @_users[app_id].save!
    end
  end

  def teardown_in_app(app_id)
    KApp.in_application(app_id) do
      u = @_users[app_id]
      u.destroy if u != nil
    end
  end

  # ===================================================================================================================

  def test_login_failure_throttle
    AUTHENTICATION_LOGIN_TEST_FAILURE_LOCK.synchronize { do_test_login_failure_throttle }
  end
  def do_test_login_failure_throttle
    without_application { setup_in_app(_TEST_APP_ID) }
    # Reset login throttle info
    $khq_login_failures = Hash.new
    # Get a CSRF token
    get "/do/authentication/login"
    assert_select('h1', 'Log in to your account')
    # Make a number of requests from a certain ip address, check it gets locked out after all attempts have been used up
    assert 2 < KLoginAttemptThrottle::FAILURE_ATTEMPT_MAX # check at least a value which does minimal testing
    1.upto(KLoginAttemptThrottle::FAILURE_ATTEMPT_MAX) do |attempt_n|
      post "/do/authentication/login", {:email => 'a@b', :password => 'p'}
      t, attempts = $khq_login_failures['127.0.0.1']
      assert_equal attempt_n, attempts
      assert_select('h1', 'Log in to your account')
      assert_select('p.z__general_alert', 'Incorrect login, please try again.')
    end
    # This one should be locked out
    post "/do/authentication/login", {:email => 'a@b', :password => 'p'}
    assert_select('h1', 'Locked out')
    # But an attempt on another IP shouldn't
    swap_ip_in_failures_hash('127.0.0.1', '192.168.0.1')  # POINT 1
    post "/do/authentication/login", {:email => 'a@b', :password => 'p'}
    assert_select('p.z__general_alert', 'Incorrect login, please try again.')
    swap_ip_in_failures_hash('192.168.0.1', '127.0.0.1')  # reverse POINT 1
    # Check data format
    time_now = Time.now.to_i
    atime, attempts = $khq_login_failures['127.0.0.1'] # now original failures
    assert atime > (time_now - 2) && atime < (time_now + 2)
    assert_equal KLoginAttemptThrottle::FAILURE_ATTEMPT_MAX, attempts
    # Make sure that the lockout times out
    assert 10 < KLoginAttemptThrottle::FAILURE_ATTEMPT_TIMEOUT
    $khq_login_failures['127.0.0.1'] = [time_now - (KLoginAttemptThrottle::FAILURE_ATTEMPT_TIMEOUT + 1), attempts]
    post "/do/authentication/login", {:email => 'a@b', :password => 'p'}
    assert_select('p.z__general_alert', 'Incorrect login, please try again.') # login failure, not lockout

    # Swap out the existing keys
    swap_ip_in_failures_hash('127.0.0.1', '129.268.0.3')  # POINT 2

    # Make sure that a correct login resets the count
    post "/do/authentication/login", {:email => 'a@b', :password => 'p'}
    assert_select('p.z__general_alert', 'Incorrect login, please try again.')
    assert $khq_login_failures.has_key?('127.0.0.1')
    post_302 "/do/authentication/login", {:email => 'authtest@example.com', :password => 'pass1234'}
    assert !($khq_login_failures.has_key?('127.0.0.1'))
    assert_redirected_to('/')

    without_application { teardown_in_app(_TEST_APP_ID) }
  end

  def swap_ip_in_failures_hash(from, to)
    h = Hash.new
    $khq_login_failures.each do |k,v|
      h[(k == from) ? to : ((k == to) ? from : k)] = v
    end
    $khq_login_failures = h
  end

  # ===================================================================================================================

  def test_login_user_interface_hook
    begin
      # No plugin
      get "/do/authentication/login"
      assert_select('h1', 'Log in to your account')
      # Install plugin, gets redirected
      raise "Failed to install plugin" unless KPlugin.install_plugin("authentication_controller_test/login_user_interface_hook_test")
      get_302 "/do/authentication/login"
      assert_redirected_to "/path/to/alternative/ui"
      # Plugin has code not to redirect
      get "/do/authentication/login?auth=internal"
      assert_select('h1', 'Log in to your account')
      # ... and test the two parameters
      get_302 "/do/authentication/login?auth=hello"
      assert_redirected_to "/path/to/alternative/ui?auth=hello"
      get_302 "/do/authentication/login?rdr=hello"
      assert_redirected_to "/path/to/alternative/ui" # ignored as bad
      get_302 "/do/authentication/login?rdr=/hello"
      assert_redirected_to "/path/to/alternative/ui?destination=%2Fhello" # ignored as bad
      get_302 "/do/authentication/login?other=1" # other parameter
      assert_redirected_to "/path/to/alternative/ui"
      get_302 "/do/authentication/login?auth=hello&rdr=/ping" # both
      assert_redirected_to "/path/to/alternative/ui?destination=%2Fping&auth=hello"
      # POST isn't redirected
      get_a_page_to_refresh_csrf_token
      post "/do/authentication/login", {:email => 'a@b', :password => 'p'}
      assert_select('h1', 'Log in to your account')
      assert_select('p.z__general_alert', 'Incorrect login, please try again.')
    ensure
      KPlugin.uninstall_plugin("authentication_controller_test/login_user_interface_hook_test")
    end
  end

  class LoginUserInterfaceHookTestPlugin < KTrustedPlugin
    _PluginName "Authentication UI Hook Test Plugin"
    _PluginDescription "Test"
    def hLoginUserInterface(response, destination, auth)
      return if "internal" == auth
      response.redirectPath = "/path/to/alternative/ui"
      params = {}
      params["destination"] = destination if destination
      params["auth"] = auth if auth
      unless params.empty?
        response.redirectPath += "?"+URI.encode_www_form(params)
      end
    end
  end

  # ===================================================================================================================

  def test_change_password
    AUTHENTICATION_LOGIN_TEST_FAILURE_LOCK.synchronize { do_test_change_password }
  end
  def do_test_change_password
    without_application { setup_in_app(_TEST_APP_ID) }

    about_to_create_an_audit_entry

    # CSRF token
    get "/do/authentication/login"

    # Check it doesn't work if you're not logged in
    post_302 "/do/authentication/change-password", {:old => 'pass1234', :pw1 => 'pants9872', :pw2 => 'pants9872'}
    assert_redirected_to '/do/authentication/login?rdr=%2Fdo%2Fauthentication%2Fchange-password'
    assert_no_more_audit_entries_written

    # Log in
    post_302 "/do/authentication/login", {:email => 'authtest@example.com', :password => 'pass1234'}
    assert_redirected_to '/'
    about_to_create_an_audit_entry # ignore audit entry created

    # Refresh CSRF token by fetching the form again
    get "/do/authentication/change-password"

    # Try a bad old password
    post "/do/authentication/change-password", {:old => 'pass5323', :pw1 => 'pants9872', :pw2 => 'pants9872'}
    assert response.body =~ /Password not changed/
    assert response.body =~ /The old password entered was incorrect/
    assert_no_more_audit_entries_written

    # Try a password not matching
    post "/do/authentication/change-password", {:old => 'pass1234', :pw1 => 'pants9872', :pw2 => 'pants9873'}
    assert response.body =~ /Password not changed/
    assert response.body =~ /The new passwords entered did not match/
    assert_no_more_audit_entries_written

    # Rubbish password
    post "/do/authentication/change-password", {:old => 'pass1234', :pw1 => 'password', :pw2 => 'password'}
    assert response.body =~ /Password not changed/
    assert response.body =~ /The new password did not meet minimum security requirements/
    assert_no_more_audit_entries_written

    # Change password
    post "/do/authentication/change-password", {:old => 'pass1234', :pw1 => 'pants9872', :pw2 => 'pants9872'}
    assert_select 'h1', 'Password changed'
    assert_audit_entry(:kind => 'USER-CHANGE-PASS', :user_id => @_users[_TEST_APP_ID].id, :entity_id => @_users[_TEST_APP_ID].id, :displayable => false)

    # Log out
    get_a_page_to_refresh_csrf_token
    post_302 "/do/authentication/logout"
    get_302 "/"
    assert_redirected_to '/do/authentication/login'

    # Log in with new password
    get "/do/authentication/login"
    post "/do/authentication/login", {:email => 'authtest@example.com', :password => 'pass1234'}
    assert_select('p.z__general_alert', 'Incorrect login, please try again.')
    post_302 "/do/authentication/login", {:email => 'authtest@example.com', :password => 'pants9872'}
    assert_redirected_to '/'
    get "/do/authentication/change-password"
    assert_select 'h1', 'Change password'

    without_application { teardown_in_app(_TEST_APP_ID) }

  end

  # ===================================================================================================================

  def test_password_recovery
    AUTHENTICATION_LOGIN_TEST_FAILURE_LOCK.synchronize do
      without_application { setup_in_app(_TEST_APP_ID) }
      d_before = EmailTemplate.test_deliveries.size

      # CSRF token
      get '/do/authentication/recovery'
      assert response.body.include? '<input type="text" name="email" value="" class="z__focus_candidate">'

      # Ask for an email for an unknown email address
      post "/do/authentication/recovery", {:email => 'noaccount@example.com'}
      assert_equal d_before + 1, EmailTemplate.test_deliveries.size
      sent = EmailTemplate.test_deliveries.last
      assert_equal ['noaccount@example.com'], sent.header.to
      assert sent.multipart?
      assert sent.body.detect { |part| part.header.content_type == 'text/plain' } .body.include? 'There is no user account for the email address entered'

      [false, true].each do |swap_for_welcome|
        # Attempt recovery for the real address
        get '/do/authentication/recovery'
        post "/do/authentication/recovery", {:email => 'authtest@example.com'}
        assert_equal d_before + (swap_for_welcome ? 3 : 2), EmailTemplate.test_deliveries.size
        sent = EmailTemplate.test_deliveries.last
        assert_equal 1, sent.header.to.length
        # When it's a known account, the address is given in full, including the display name
        assert_equal 'authtest', sent.header.to.first.local
        assert_equal 'example.com', sent.header.to.first.domain
        assert_equal "first last#{_TEST_APP_ID}", sent.header.to.first.display_name
        assert sent.multipart?
        plain_body = sent.body.detect { |part| part.header.content_type == 'text/plain' } .body
        plain_body.gsub!("=\n",''); plain_body.gsub!('=3D','=')
        assert plain_body.include? 'Click here to continue the process'
        assert plain_body =~ /http:\/\/[a-z0-9:\.]+(\/do\/authentication\/r\/(\d+-[a-z0-9-]+))\s/m
        urlpath = $1
        token = $2
        assert token =~ /\A(\d+)-(\d+)-(\d+)-([a-f0-9]+)\z/
        uid = $1.to_i
        time = $2.to_i + User::RECOVERY_TOKEN_TIME_OFFSET
        days = $3.to_i
        assert_equal @_users[_TEST_APP_ID].id, uid
        assert (Time.now.to_i - 2) <= time
        assert time <= (Time.now.to_i)
        assert_equal 1, days
        assert token.length > 16

        # User has token
        assert nil != User.find(@_users[_TEST_APP_ID].id).recovery_token

        # Try welcome instead
        urlpath.gsub!('/r/', '/welcome/') if swap_for_welcome

        # Check a bad token
        get urlpath + 'a'
        assert response.body.include?(if swap_for_welcome then
            'password. However, this link as expired'
          else
            'The link you clicked was not a valid link to set a new password'
          end)

        # Check the right token
        get urlpath
        assert response.body.include?(swap_for_welcome ? 'Please choose a password' : 'Please choose a new password')
        post urlpath, {:pw1 => 'pants23897324', :pw2 => 'carrots2387634'}
        assert response.body.include?(swap_for_welcome ? 'Password not set' : 'Password not changed')
        post urlpath, {:pw1 => 'ping1654ss'+swap_for_welcome.to_s, :pw2 => 'ping1654ss'+swap_for_welcome.to_s}
        assert response.body.include?(swap_for_welcome ? 'Your password has been set' : 'Your password has been changed')

        # Check can login with new token
        post "/do/authentication/login", {:email => 'authtest@example.com', :password => 'pass1234'}
        assert_select('p.z__general_alert', 'Incorrect login, please try again.')
        post_302 "/do/authentication/login", {:email => 'authtest@example.com', :password => 'ping1654ss'+swap_for_welcome.to_s}
        assert_redirected_to '/'

        # User doesn't have a recovery token any more
        assert_equal nil, User.find(@_users[_TEST_APP_ID].id).recovery_token
      end

      # Check that tokens in past or future don't work
      [
        [-100, true], # first check a reasonable one does work, to check this test
        [0-(10+(60*60*24)), false], # too long in the past
        [100, false]  # in the future
      ].each do |diff, should_work|
        user = @_users[_TEST_APP_ID]
        urlpath = user.generate_recovery_urlpath(:r, Time.now.to_i + diff)
        get urlpath
        if should_work
          assert response.body.include? 'Please choose a new password'
        else
          assert response.body.include? 'The link you clicked was not a valid link'
        end
      end

      without_application { teardown_in_app(_TEST_APP_ID) }
    end
  end

  # ===================================================================================================================

  def test_logout
    AUTHENTICATION_LOGIN_TEST_FAILURE_LOCK.synchronize do
      without_application { setup_in_app(_TEST_APP_ID) }

      # Login as two different users, collecting cookie values
      assert_login_as(User.find(41), 'password')
      cookie1 = session_cookie_value
      session_cookie_value_set('x') # new session
      assert_login_as(User.find(42), 'password')
      cookie2 = session_cookie_value
      assert cookie2 != 'x'
      assert cookie1 != cookie2
      # Swap cookie values around to check this does have intended effect
      session_cookie_value_set(cookie1)
      get '/do/account/info'
      assert_select '#z__aep_tools_tab a', "User 1"
      session_cookie_value_set(cookie2)
      get '/do/account/info'
      assert_select '#z__aep_tools_tab a', "User 2"
      # Log out of the first session
      session_cookie_value_set(cookie1)
      about_to_create_an_audit_entry
      get '/do/authentication/logout'
      # Check it just shows the page with the logout form
      assert_select '#z__page_name h1', 'Logging out...'
      assert response.body.include?('<form')
      # Check user is still logged in
      get '/do/account/info'
      assert_select '#z__aep_tools_tab a', "User 1"
      # POST to log out
      post_302 '/do/authentication/logout'
      assert_redirected_to '/do/authentication/logged-out'
      assert_audit_entry({:kind => 'USER-LOGOUT', :user_id => 41, :displayable => false, :remote_addr => '127.0.0.1'})
      get_302 '/do/account/info'
      assert_redirected_to '/do/authentication/login?rdr=%2Fdo%2Faccount%2Finfo'
      # Check second session is OK
      session_cookie_value_set(cookie2)
      get '/do/account/info'
      assert_select '#z__aep_tools_tab a', "User 2"
      # Restore cookie from first session and make sure it's still logged out
      session_cookie_value_set(cookie1)
      get_302 '/do/account/info'
      assert_redirected_to '/do/authentication/login?rdr=%2Fdo%2Faccount%2Finfo'

      without_application { teardown_in_app(_TEST_APP_ID) }
    end
  end

  # ===================================================================================================================

  def test_impersonation
    AUTHENTICATION_LOGIN_TEST_FAILURE_LOCK.synchronize do
      without_application { setup_in_app(_TEST_APP_ID) }
      other_user = User.find(41)
      assert_equal "User 1", other_user.name

      assert ! @_users[_TEST_APP_ID].policy.can_impersonate_user?

      # Login
      get "/do/authentication/login"
      post_302 "/do/authentication/login", {:email => 'authtest@example.com', :password => 'pass1234'}

      # Check can't access impersonation
      get_403 "/do/authentication/impersonate"
      get_a_page_to_refresh_csrf_token
      post_403 "/do/authentication/impersonate"

      # Add permission
      policy = Policy.new(:user_id => @_users[_TEST_APP_ID].id,
                          :perms_allow => KPolicyRegistry.to_bitmask(:impersonate_user),
                          :perms_deny => 0)
      policy.save!

      # Will be able to login and impersonate
      impersonation_do_login_and_impersonation

      # And end the impersonation
      post_302 "/do/authentication/end_impersonation"
      assert_redirected_to '/'
      get '/do/account/info'
      assert_select '#z__aep_tools_tab a', "first last#{_TEST_APP_ID}"
      assert_select '#z__ws_content b', 'authtest@example.com'
      assert_equal @_users[_TEST_APP_ID].id, session[:uid]
      assert_equal nil, session[:impersonate_uid]

      # Disable the underlying account, check the impersonated account is logged out
      impersonation_do_login_and_impersonation
      @_users[_TEST_APP_ID].kind = User::KIND_USER_BLOCKED
      @_users[_TEST_APP_ID].save!
      get_302 '/do/account/info'
      assert_redirected_to '/do/authentication/login?rdr=%2Fdo%2Faccount%2Finfo'
      # Enable it again and check it works now
      @_users[_TEST_APP_ID].kind = User::KIND_USER
      @_users[_TEST_APP_ID].save!
      impersonation_do_login_and_impersonation
      get '/do/account/info'
      assert_select '#z__aep_tools_tab a', other_user.name

      # Remove permission from the underlying account, check impersonated account is logged out
      impersonation_do_login_and_impersonation
      policy.destroy
      get_302 '/do/account/info'
      assert_redirected_to '/do/authentication/login?rdr=%2Fdo%2Faccount%2Finfo'
    end
  end

  def impersonation_do_login_and_impersonation
    other_user = User.find(41)
    # Log in, logging out first to be sure
    get_a_page_to_refresh_csrf_token
    post_302 "/do/authentication/logout"
    get "/do/authentication/login"
    post_302 "/do/authentication/login", {:email => 'authtest@example.com', :password => 'pass1234'}
    # Get the impersonate page, and impersonate someone
    get "/do/authentication/impersonate"
    assert_select '#z__page_name h1', 'Impersonate user'
    assert response.body =~ /<a [^>]*data-uid="#{other_user.id}"[^>]*>\s*User 1\s*<\/a>/
    assert_select '#z__aep_tools_tab a', "first last#{_TEST_APP_ID}"
    # Check submitting form without UID just redirects back
    post_302 "/do/authentication/impersonate"
    assert_redirected_to "/do/authentication/impersonate"
    # Post with UID
    about_to_create_an_audit_entry
    post_302 "/do/authentication/impersonate", {:uid => other_user.id.to_s}
    assert_audit_entry({:kind => 'USER-IMPERSONATE', :user_id => other_user.id, :auth_user_id => @_users[_TEST_APP_ID].id, :displayable => false})
    assert_redirected_to '/'
    get '/do/account/info'
    assert_select '#z__aep_tools_tab a', other_user.name
    assert_select '#z__ws_content b', other_user.email
    assert_equal @_users[_TEST_APP_ID].id, session[:uid]
    assert_equal other_user.id, session[:impersonate_uid]
    assert_select 'form[action="/do/authentication/end_impersonation"]', "Impersonating #{other_user.name}"

    # Impersonated user doesn't have permission to impersonate
    get_403 "/do/authentication/impersonate"
  end

  # ===================================================================================================================

  def otpres(result)
    assert result.kind_of?(KHardwareOTP::Result)
    assert result.message.length > 4 unless result.ok
    [result.ok, result.reason]
  end

  def test_hardware_otp_checks
    return unless HAVE_OTP_IMPLEMENTATION
    AUTHENTICATION_LOGIN_TEST_FAILURE_LOCK.synchronize do
      # Check the basic interface
      assert_raises(RuntimeError) { KHardwareOTP.check_otp("a", 123456, "127.0.0.1") }
      ['1','12','123','1234','1234 ',' 1234','a1234','abcde','  12 ','1   2','12b45'].each do |short_otp|
        assert_raises(RuntimeError) { KHardwareOTP.check_otp("a", short_otp, "127.0.0.1") }
      end
      assert_equal [false, :fail], otpres(KHardwareOTP.check_otp("a", "123456", "127.0.0.1"))

      # Temporary code setting
      temporary_code_lifetime = 300 # value of KHardwareOTP::TEMPORARY_CODE_VALIDITY
      KApp.set_global(:otp_override, '')
      assert_equal nil, KHardwareOTP.get_temporary_code_user_id
      KHardwareOTP.set_temporary_code(123, "01234567")
      assert_equal 123, KHardwareOTP.get_temporary_code_user_id
      assert_equal [false, :fail], otpres(KHardwareOTP.check_otp("a", "01234567", "127.0.0.1"))
      assert_equal [false, :fail], otpres(KHardwareOTP.check_otp("a", "01234567", "127.0.0.1", 120))
      assert_equal [false, :fail], otpres(KHardwareOTP.check_otp("a", "01234568", "127.0.0.1", 123)) # different code
      assert_equal [true, :temp_code], otpres(KHardwareOTP.check_otp("a", "01234567", "127.0.0.1", 123))  # correct temporary code
      assert_equal [false, :fail], otpres(KHardwareOTP.check_otp("a", "01234567", "127.0.0.1", 123)) # can't be repeated
      KHardwareOTP.set_temporary_code(124, "01234567")
      assert_equal [true, :temp_code], otpres(KHardwareOTP.check_otp("a", "01234567", "127.0.0.1", 124))
      KHardwareOTP.set_temporary_code(125, "01234567")
      KHardwareOTP.clear_temporary_code
      assert_equal [false, :fail], otpres(KHardwareOTP.check_otp("a", "01234567", "127.0.0.1", 125))
      # Now do behind the scenes setting of codes to check time validity
      KApp.set_global(:otp_override, "150:321765:#{Time.now.to_i}")
      assert_equal [false, :fail], otpres(KHardwareOTP.check_otp("a", "321765", "127.0.0.1", 149))
      assert_equal [true, :temp_code], otpres(KHardwareOTP.check_otp("a", "321765", "127.0.0.1", 150))
      KApp.set_global(:otp_override, "150:321766:#{Time.now.to_i - (temporary_code_lifetime / 2)}")
      assert_equal [false, :fail], otpres(KHardwareOTP.check_otp("a", "321766", "127.0.0.1", 149))
      assert_equal [true, :temp_code], otpres(KHardwareOTP.check_otp("a", "321766", "127.0.0.1", 150))
      KApp.set_global(:otp_override, "150:321767:#{Time.now.to_i - (temporary_code_lifetime + 1)}") # expired code
      assert_equal [false, :fail], otpres(KHardwareOTP.check_otp("a", "321767", "127.0.0.1", 150))
      KApp.set_global(:otp_override, "150:321768:#{Time.now.to_i + 2}") # in future
      assert_equal [false, :fail], otpres(KHardwareOTP.check_otp("a", "321768", "127.0.0.1", 150))

      # Check the values against a sequence of OTPs generated by a real key
      token = HardwareOtpToken.find_by_identifier('test-3-event')
      token.counter = 36  # counter one *before* the beginning of this sequence of OTPs
      token.save!
      assert_equal [false, :fail], otpres(KHardwareOTP.check_otp("test-3-event", "123456", "127.0.0.1"))
      assert_equal [true, :pass], otpres(KHardwareOTP.check_otp("test-3-event", "211172", "127.0.0.1"))
      assert_equal [false, :fail], otpres(KHardwareOTP.check_otp("test-3-event", "264532", "127.0.0.1"))
      assert_equal [true, :pass], otpres(KHardwareOTP.check_otp("test-3-event", "149890", "127.0.0.1"))
      assert_equal [true, :pass], otpres(KHardwareOTP.check_otp("test-3-event", "741402", "127.0.0.1"))
      assert_equal [false, :reuse], otpres(KHardwareOTP.check_otp("test-3-event", "741402", "127.0.0.1"))
      assert_equal [true, :pass], otpres(KHardwareOTP.check_otp("test-3-event", "872069", "127.0.0.1"))
      assert_equal [true, :pass], otpres(KHardwareOTP.check_otp("test-3-event", "178245", "127.0.0.1"))
      assert_equal [false, :reuse], otpres(KHardwareOTP.check_otp("test-3-event", "178245", "127.0.0.1")) # repeat
      # Check the sequence can't be repeated...
      %w(211172 149890 741402).each do |otp|
        assert_equal [false, :fail], otpres(KHardwareOTP.check_otp("test-3-event", otp, "127.0.0.1"))
      end
      # ... and the last two trigger reuse results
      %w(872069 178245).each do |otp|
        assert_equal [false, :reuse], otpres(KHardwareOTP.check_otp("test-3-event", otp, "127.0.0.1"))
      end

      # Check the time based OTP, now we trust the generation of OTP codes
      time_token = HardwareOtpToken.find_by_identifier('test-1-time')
      time_token.counter = 12345
      time_token.save! # reset counter
      time_otp = Java::OrgOpenauthenticationOtp::OneTimePasswordAlgorithm.generateOTP(time_token.secret.unpack('m').first.to_java_bytes, (Time.new.to_i / 60), 6, false, -1)
      assert_equal [false, :fail], otpres(KHardwareOTP.check_otp("test-1-time", "123456", "127.0.0.1")) if time_otp != "123456" # don't fail test by chance
      assert_equal [true, :pass], otpres(KHardwareOTP.check_otp("test-1-time", time_otp, "127.0.0.1"))
      assert_equal [false, :fail], otpres(KHardwareOTP.check_otp("test-1-time", "233482", "127.0.0.1")) if time_otp != "233482" # don't fail test by chance
      # Check reuse doesn't work
      assert_equal [false, :reuse], otpres(KHardwareOTP.check_otp("test-1-time", time_otp, "127.0.0.1"))

      # Check throttling
      $khq_login_failures = Hash.new
      KLoginAttemptThrottle::FAILURE_ATTEMPT_MAX.times do
        assert_equal [false, :fail], otpres(KHardwareOTP.check_otp("test-1-time", "1234567", "127.0.0.1"))  # 7 digits to make sure it always fails
      end
      time_token.counter = 12323
      time_token.save! # reset counter again
      assert_raises(KLoginAttemptThrottle::LoginThrottled) { KHardwareOTP.check_otp("test-1-time", time_otp, "127.0.0.1") }
      assert_equal [true, :pass], otpres(KHardwareOTP.check_otp("test-1-time", time_otp, "127.0.0.2")) # OK for another IP address

      # Reset login failures for other tests
      $khq_login_failures = Hash.new
    end
  end

  # ===================================================================================================================

  def test_login_with_and_without_otp
    return unless HAVE_OTP_IMPLEMENTATION
    AUTHENTICATION_LOGIN_TEST_FAILURE_LOCK.synchronize do
      without_application { setup_in_app(_TEST_APP_ID) }

      # User to test with & permission object
      user_obj = @_users[_TEST_APP_ID]
      policy = Policy.new(:user_id => user_obj.id, :perms_allow => 0, :perms_deny => 0)
      policy.save!

      # Accounting start
      KAccounting.setup_accounting
      KAccounting.set_counters_for_current_app
      accounting_expected_login_count = KAccounting.get(:logins)

      # Check redirection to login page
      assert session == "No session" || session[:uid] == nil
      get_302 "/"
      assert_redirected_to "/do/authentication/login"
      get_302 "/do/account/info"
      assert_redirected_to "/do/authentication/login?rdr=%2Fdo%2Faccount%2Finfo"

      # Wrong password for user, check error message
      get "/do/authentication/login"
      assert_select 'h1', 'Log in to your account'  # login page is shown
      about_to_create_an_audit_entry
      post "/do/authentication/login", {:email => 'authtest@example.com', :password => 'badpass'}
      assert_select('p.z__general_alert', 'Incorrect login, please try again.')
      assert_equal nil, session[:uid]
      assert_equal accounting_expected_login_count, KAccounting.get(:logins)
      assert_audit_entry(:kind => 'USER-AUTH-FAIL', :displayable => false,
          :data => {"email" => 'authtest@example.com', "interactive" => true}, :remote_addr => '127.0.0.1')

      # Login as user, check redirects as expected
      get "/do/authentication/login"
      post_302 "/do/authentication/login", {:email => 'authtest@example.com', :password => 'pass1234'}
      assert_redirected_to('/')
      assert_equal user_obj.id, session[:uid]
      accounting_expected_login_count += 1
      assert_equal accounting_expected_login_count, KAccounting.get(:logins)
      assert_audit_entry(:kind => 'USER-LOGIN', :displayable => false, :user_id => user_obj.id, :data => {"autologin" => false, "provider" => "localhost"})

      # Check that requests for the login page redirect properly
      get_302 "/do/authentication/login?rdr=%2Fdo%2Faccount%2Finfo"
      assert_redirected_to "/do/account/info"
      get_302 "/do/authentication/login"
      assert_redirected_to "/"
      # Security check - make sure rdr's which could go elsewhere are ignored
      get_302 "/do/authentication/login?rdr=does_not%2Fstart%2Fwith%2Fslash"
      assert_redirected_to "/" # rdr ignored

      # Log out
      get_a_page_to_refresh_csrf_token
      post_302 "/do/authentication/logout"
      assert_audit_entry({:kind => 'USER-LOGOUT', :user_id => user_obj.id, :displayable => false})

      # Set token for user, check login sequence, with and without the "requires" policy set on the user
      user_obj.otp_identifier = "test-1-time"
      user_obj.save!
      assert_audit_entry({:kind => 'USER-OTP-TOKEN', :entity_id => user_obj.id})
      otp = nil
      token = HardwareOtpToken.find_by_identifier("test-1-time")
      [
        [false, false], [false, true],
        [true,  false], [true,  true]
      ].each do |require_token_policy, reusing_otp|
        if require_token_policy
          # Set the policy for the user
          policy.perms_allow = KPolicyRegistry.to_bitmask(:require_token)
          policy.save!
        end
        assert_equal require_token_policy, User.find(user_obj.id).policy.is_otp_token_required?
        # Reset the counter on the token?
        unless reusing_otp
          token.counter = 12345 + (require_token_policy ? 1 : 2) # so AR thinks there is a change worth saving
          token.save!
        end
        # Login - wrong password
        get "/do/authentication/login"
        post "/do/authentication/login", {:email => 'authtest@example.com', :password => 'badpass'}
        assert_select('p.z__general_alert', 'Incorrect login, please try again.')
        assert_equal nil, session[:uid]
        assert_equal accounting_expected_login_count, KAccounting.get(:logins)
        assert_audit_entry(:kind => 'USER-AUTH-FAIL', :displayable => false, :data => {"email" => 'authtest@example.com', "interactive" => true})
        # Login - correct password, and check it went to the OTP page
        get "/do/authentication/login"
        post_302 "/do/authentication/login", {:email => 'authtest@example.com', :password => 'pass1234'}
        assert_redirected_to('/do/authentication/otp')
        assert_equal accounting_expected_login_count, KAccounting.get(:logins)
        assert_no_more_audit_entries_written
        # Check not possible to get home page
        get_302 '/'
        assert_redirected_to('/do/authentication/login')
        # Check session details
        assert_equal nil, session[:uid]
        assert_equal user_obj.id, session[:pending_uid]
        # Bad OTP
        get '/do/authentication/otp' # get CSRF token
        post '/do/authentication/otp', {:password => '0000000'}
        assert_equal nil, session[:uid]
        assert_select('p.z__general_alert', 'Incorrect code, please try again.')
        assert_equal accounting_expected_login_count, KAccounting.get(:logins)
        assert_audit_entry(:kind => 'USER-AUTH-FAIL', :displayable => false, :data => {"otp" => 'test-1-time', "uid" => user_obj.id, "interactive" => true})
        # Provide OTP and check it works
        otp = TestHardwareOTP.next_otp_for("test-1-time") unless reusing_otp
        post '/do/authentication/otp', {:password => otp}, {:expected_response_codes => [200, 302]}
        unless reusing_otp
          assert_redirected_to('/')
          assert_equal user_obj.id, session[:uid]
          assert_equal nil, session[:pending_uid]
          accounting_expected_login_count += 1
          assert_equal accounting_expected_login_count, KAccounting.get(:logins)
          assert_audit_entry(:kind => 'USER-LOGIN', :displayable => false, :user_id => user_obj.id, :data => {"autologin" => false, "otp" => "test-1-time"})
        else
          assert_select('p.z__general_alert', 'The code you entered has already been used. Please wait until your token generates another code, and try again.')
          assert_equal nil, session[:uid]
          assert_audit_entry(:kind => 'USER-AUTH-FAIL', :displayable => false, :data => {"otp" => 'test-1-time', "uid" => user_obj.id, "interactive" => true})
        end
        # Log out
        get_a_page_to_refresh_csrf_token
        post_302 "/do/authentication/logout"
        unless reusing_otp # (as when reusing, there's no login to logout)
          assert_audit_entry({:kind => 'USER-LOGOUT', :user_id => user_obj.id, :displayable => false})
        end
      end

      # Check temporary codes work
      KHardwareOTP.set_temporary_code(user_obj.id, '123456789')
      get "/do/authentication/login"
      post_302 "/do/authentication/login", {:email => 'authtest@example.com', :password => 'pass1234'}
      assert_redirected_to('/do/authentication/otp')
      get '/do/authentication/otp' # get CSRF token
      post '/do/authentication/otp', {:password => '0000000'} # bad
      assert_select('p.z__general_alert', 'Incorrect code, please try again.')
      assert_equal nil, session[:uid]
      post_302 '/do/authentication/otp', {:password => '123456789'}
      assert_redirected_to('/')
      assert_equal user_obj.id, session[:uid]
      assert_equal nil, session[:pending_uid]
      get_a_page_to_refresh_csrf_token
      post_302 "/do/authentication/logout"
      # Check it won't work again
      get "/do/authentication/login"
      post_302 "/do/authentication/login", {:email => 'authtest@example.com', :password => 'pass1234'}
      assert_redirected_to('/do/authentication/otp')
      get '/do/authentication/otp' # get CSRF token
      post '/do/authentication/otp', {:password => '123456789'}
      assert_select('p.z__general_alert', 'Incorrect code, please try again.')
      assert_equal nil, session[:uid]

      # Leaving the requires_token policy set on the user, remove token, then check login fails
      user_obj.otp_identifier = nil
      user_obj.save!
      # Check policy is still set
      assert_equal true, User.find(user_obj.id).policy.is_otp_token_required?
      # Log in!
      get "/do/authentication/login"
      post_302 "/do/authentication/login", {:email => 'authtest@example.com', :password => 'pass1234'}
      assert_redirected_to('/do/authentication/otp_required')
      assert_equal nil, session[:pending_uid]
      assert_equal nil, session[:uid]
      # Check the OTP admin message is displayed correctly
      get '/do/authentication/otp_required'
      assert_select('p:nth-child(1)', 'You cannot log on because you are required to use a token, but have not been issued with a token.')
      assert_select('p:nth-child(2)', KDisplayConfig::DEFAULT_OTP_ADMIN_CONTACT)
      # Can't get home page
      get_302 '/'
      assert_redirected_to('/do/authentication/login')

      without_application { teardown_in_app(_TEST_APP_ID) }
    end
  end

  # ===================================================================================================================

  def test_check_only_users_can_make_requests
    AUTHENTICATION_LOGIN_TEST_FAILURE_LOCK.synchronize do

      without_application { setup_in_app(_TEST_APP_ID) }

      # Get all the kind of users from the User object
      user_kinds = User.constants.select { |name| name.to_s =~ /\AKIND_[A-Z]/ }
      assert user_kinds.length > 4

      # The user object we'll use
      user_obj = @_users[_TEST_APP_ID]

      # Log into the application
      get "/do/authentication/login"
      post_302 "/do/authentication/login", {:email => 'authtest@example.com', :password => 'pass1234'}
      assert_redirected_to('/')
      assert_equal user_obj.id, session[:uid]

      # Modify the user object with a different kind and make sure authentication works only with expected kinds
      user_kinds.each do |kind_of_user|
        # Change the kind of user
        k = User.const_get(kind_of_user)
        user_obj.kind = k
        user_obj.save!
        # Get account page to test to see whether it was allowed or not
        get "/do/account/info", nil, {:expected_response_codes => [200, 302]}
        if k == User::KIND_USER || k == User::KIND_SUPER_USER
          # Got the account page OK?
          assert_select 'h1', "first last#{_TEST_APP_ID}'s account information"
        else
          # Was redirected away
          assert_redirected_to "/do/authentication/login?rdr=%2Fdo%2Faccount%2Finfo"
        end
      end

      without_application { teardown_in_app(_TEST_APP_ID) }

    end
  end

  # ===================================================================================================================

  def test_cross_app_sessions
    AUTHENTICATION_LOGIN_TEST_FAILURE_LOCK.synchronize do

      # Use this app id and the extra app created for this cross-app testing (see test/test.rb)
      app_id1 = _TEST_APP_ID
      app_id2 = LAST_TEST_APP_ID + 1  # know this one exists!
      assert app_id1 != app_id2

      # Make sure there's a user in there
      without_application { [app_id1,app_id2].each { |a| setup_in_app(a) } }
      # Just check each user got the same UID
      expected_uid = nil
      @_users.each do |a,u|
        expected_uid ||= u.id
        assert_equal u.id, expected_uid
      end

      # Make testing sessions
      session1 = open_session("www#{app_id1}.example.com"); session1.extend(IntegrationTestUtils)
      session2 = open_session("www#{app_id2}.example.com"); session2.extend(IntegrationTestUtils)

      # And log into the first
      session1.assert_login_as(@_users[app_id1], "pass1234")
      session1.get('/do/account/info')
      session1.assert_select('#z__aep_tools_tab a', "first last#{app_id1}")

      # Then copy the cookies over
      session2.replace_cookies(session1.get_cookies)

      # And make a request with that session ID, checking it doesn't get an account into page so isn't authenticated
      session2.get_302('/do/account/info')
      assert session2.response.body !~ /first last/
      assert_equal nil, session2.session[:uid]  # not logged in and an empty session

      # Teardown data
      without_application { [app_id1,app_id2].each { |a| teardown_in_app(a) } }
    end
  end

end
