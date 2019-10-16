# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class AuthenticationController < ApplicationController
  include AuthenticationHelper
  include Application_HstsHelper
  include HardwareOTPHelper
  include KPlugin::HookSite

  # NOTE: password, old, pw1, pw2 parameters filtered with KFRAMEWORK_LOGGING_PARAM_FILTER in environment.rb to keep passwords out of logs

  CSRF_NOT_REQUIRED_FOR_URLS = ['/do/authentication/support_login']

  SAFE_REDIRECT_URL_PATH = /\A\/[^\/]\S*\z/ # match regexp in framework.js

  # Don't do CSRF checks for some special URLs.
  def csrf_check(exchange)
    if CSRF_NOT_REQUIRED_FOR_URLS.include?(exchange.request.path)
      # Allow this request through without a token.
      #   Support login URL: a much better check is done with the callback to the management server
      #   Mobile app registration: Username and password is provided instead of a token for this request.
      true
    else
      # Normal implementation
      super
    end
  end

  def post_handle
    send_hsts_header
    super
  end

  _GetAndPost
  _PoliciesRequired nil
  def handle_login
    # Check SSL status (belts and braces over the automatic stuff -- makes sure stray sessions don't cause problems)
    if KApp.use_ssl_for(:logged_in) && !(request.ssl?)
      redirect_to "#{KApp.url_base(:logged_in)}#{request.request_uri}"
      return
    end

    # Check that the user isn't already logged in. This stops redirections from non-SSL pages
    # unnecessarily showing the login page, and redirects to the home page if someone goes
    # back to the login URL (which happens a suprisingly large number of times and can be
    # a little confusing for the user).
    if @request_user.policy.is_not_anonymous? && !(request.post?)
      rdr = params[:rdr]
      redirect_to((rdr != nil && rdr =~ SAFE_REDIRECT_URL_PATH) ? rdr : '/')
      return
    end

    # Would a plugin like to change the user interface?
    unless request.post?
      redirect_path = nil
      call_hook(:hLoginUserInterface) do |hooks|
        rdr = params[:rdr]
        redirect_path = hooks.run((rdr != nil && rdr =~ SAFE_REDIRECT_URL_PATH) ? rdr : nil, params[:auth]).redirectPath
      end
      if redirect_path
        redirect_to redirect_path
        return
      end
    end

    @authentication_provider = 'localhost'
    do_local_login

    # If a login happened OK, log the user in
    if @logged_in_user != nil

      # Paranoia - abort if the user is the "all access" support user (just in case)
      if @logged_in_user.kind == User::KIND_SUPER_USER
        raise "Attempt to login as super user"
      end

      # Create a new session -- generating a new session ID, and throwing away any old session
      session_reset
      session_create

      # Does the user have an OTP token?
      if nil != @logged_in_user.otp_identifier
        # Redirect to request an OTP, storing the ID of the user for the pending login
        session[:pending_uid] = @logged_in_user.id
        session[:pending_was_autologin] = @was_autologin
        redirect_to(if params[:rdr] != nil && params[:rdr] =~ SAFE_REDIRECT_URL_PATH
          "/do/authentication/otp?rdr=#{ERB::Util.url_encode(params[:rdr])}"
        else
          '/do/authentication/otp'
        end)
        return
      else
        # Does the user require a token?
        if @logged_in_user.policy.is_otp_token_required?
          redirect_to '/do/authentication/otp_required'
          return
        else
          # Set session for logged in user
          session[:uid] = @logged_in_user.id
          # Send notification of login
          KNotificationCentre.notify(:authentication, :login, @logged_in_user, {:autologin => @was_autologin, :provider => @authentication_provider})
        end
      end

      # Got a page to redirect to?
      do_redirect_to_destination
    end
  end

  def do_local_login
    @autologin_allowed = false

    @login_attempted = false
    @logged_in_user = nil

    # Try auto-login
    @was_autologin = false

    if request.post? && !(params.has_key?(:no_login))
      if @logged_in_user == nil
        # Make the login attempt
        @login_attempted = true
        begin
          @logged_in_user = User.login(params[:email], params[:password], request.remote_ip)
          unless @logged_in_user
            KNotificationCentre.notify(:authentication, :interactive_failure, {:email => params[:email].strip, :provider => 'localhost'})
          end
        rescue KLoginAttemptThrottle::LoginThrottled => e
          # Nice message for throttled login attempts
          render :action => 'login_throttled'
          return
        end
      end
    end
  end

  # Handle the OAuth return for OAuthClient, then ask plugins to do something with the returned data
  _PoliciesRequired nil
  def handle_oauth_rtx
    if params.has_key? :state
      oauth_client = nil
      begin
        (oauth_client = OAuthClient.new).setup(session, params)
        auth_info = oauth_client.authenticate(params)
        redirect_path = nil
        if auth_info
          call_hook(:hOAuthSuccess) do |hooks|
            redirect_path = hooks.run(JSON.generate(auth_info)).redirectPath
          end
        end
        if redirect_path
          redirect_to redirect_path
          return
        end
      rescue OAuthClient::OAuthError => error
        data = (error.detail || {}).merge({ 'error' => error.error_code, :provider => oauth_client.issuer })
        KNotificationCentre.notify(:authentication, :oauth_failure, data)
        session_reset
        error.maybe_report
        @error = error
        render :action => "oauth_failed"
        return
      end
    end
    render :action => "oauth_unhandled"
  end

  _PoliciesRequired nil
  def handle_otp_required
  end

  _GetAndPost
  _PoliciesRequired nil
  def handle_otp
    # Make sure there's a pending login
    if nil == session[:pending_uid]
      redirect_to '/do/authentication/login'
      return
    end
    if request.post?
      @login_attempted = true
      otp = params[:password].gsub(/\D/,'') # remove all non-digit letters
      if otp.length > 5
        user = nil
        begin
          # Attempt to validate the given password against the OTP server
          user = User.cache[session[:pending_uid]]
          @otp_result = KHardwareOTP.check_otp(user.otp_identifier, otp, request.remote_ip, user.id)
        rescue KLoginAttemptThrottle::LoginThrottled => e
          # Nice message for throttled login attempts
          render :action => 'login_throttled'
          return
        end
        if nil != @otp_result && @otp_result.ok
          # OTP was correct, log in user
          session[:uid] = session[:pending_uid]
          session[:last_otp] = Time.now.to_i
          @was_autologin = session[:pending_was_autologin]
          session.delete(:pending_uid)
          session.delete(:pending_was_autologin)
          do_redirect_to_destination
          # Send notification of login
          KNotificationCentre.notify(:authentication, :login, user, {:autologin => @was_autologin, :otp => user.otp_identifier})
        else
          KNotificationCentre.notify(:authentication, :interactive_failure, {:otp => user.otp_identifier, :uid => session[:pending_uid]})
        end
      end
    end
  end

  # Support login
  _PostOnly
  _PoliciesRequired nil
  def handle_support_login
    if request.post? && params.has_key?(:secret) && params.has_key?(:reference) && params.has_key?(:user_id)
      # See if there's an active support request outstanding with this secret
      secret1, secret2 = params[:secret].split(':', 2)
      info = nil
      encoded = KTempDataStore.get(secret1, 'superuser_auth')
      if encoded != nil && encoded.class == String && (info = YAML::load(encoded)) != nil && secret1.length > 16 && secret2.length > 32 &&
            info[:secret2] == secret2 && info[:app_id] == KApp.current_application && info[:uid] == params[:user_id].to_i
        # Reset current session, create a new session
        session_reset
        session_create
        # Get the requested user, and set the session accordingly
        user_to_login_as = User.find(info[:uid].to_i)
        raise "Bad user from support request" if user_to_login_as == nil
        session[:uid] = user_to_login_as.id.to_i
        # Redirect to home page
        redirect_to('/')
      else
        render :text => 'SUPPORT LOGIN FAILED'
      end
    end
  end

  _PoliciesRequired :not_anonymous
  _GetAndPost
  def handle_logout
    # If not a POST request, display the logout page which makes the POST via JavaScript
    # The POST requirement means you can't log people out by including the logout link in an <img> on any web page,
    # and browsers won't cache it. (Safari has been spotted caching the result of the redirect.)
    return unless request.post?

    # A redirect after logout is necessary so UI is displayed as a logged out user.
    # Default redirect which may be altered by plugins.
    rdr = '/do/authentication/logged-out'

    # Plugins might want to alter the redirect to send to a different page or a different site entirely
    # Called before actual logout, so the plugin has access to session and authenticated user.
    call_hook(:hLogoutUserInterface) do |hooks|
      plugin_rdr = hooks.run().redirectURL
      rdr = plugin_rdr if plugin_rdr && (plugin_rdr =~ SAFE_REDIRECT_URL_PATH || plugin_rdr.start_with?('https://'))
    end

    session[:uid] = nil

    # Reset the session to make sure
    session_reset

    # Finally once complete, make an audit entry
    KNotificationCentre.notify(:authentication, :logout, @request_user, {})

    redirect_to rdr
  end

  _GetAndPost
  _PoliciesRequired :not_anonymous
  def handle_impersonate
    # Allowed if the user has the impersonate policy, or if the original
    # logged-in user has the impersonate user policy. This enables the
    # impersonate history UI to swap users.
    authenticated_user = session[:uid] ? User.cache[session[:uid].to_i] : nil
    permission_denied unless @request_user.policy.can_impersonate_user? ||
        (authenticated_user && authenticated_user.policy.can_impersonate_user?)
    raise "Impersonate not allowed for API keys" if @request_uses_api_key # TODO: Test to make sure impersonation isn't allowed for API keys
    if request.post?
      impersonate_uid = params[:uid].to_i
      if impersonate_uid == 0
        # Nothing selected
        redirect_to '/do/authentication/impersonate'
      else
        KNotificationCentre.notify(:authentication, :impersonate, authenticated_user, impersonate_uid)
        session[:impersonate_uid] = impersonate_uid
        history = (session[:impersonate_history] ||= [])
        history.push(impersonate_uid) unless history.include?(impersonate_uid)
        session[:locale] = nil
        rdr = params[:rdr]
        redirect_to((rdr != nil && rdr =~ SAFE_REDIRECT_URL_PATH) ? rdr : '/')
      end
    else
      @users = User.find_all_by_kind(User::KIND_USER)
    end
  end

  _GetAndPost
  _PoliciesRequired :not_anonymous
  def handle_end_impersonation
    if request.post?
      session.delete(:impersonate_uid)
      session[:locale] = nil
      redirect_to '/' # as good as anywhere
    end
  end

  _PoliciesRequired nil
  def handle_logged_out
    # When you log out, all the windows open will go to the logged out URL immediately.
    # This avoids lots of requests being made, which could do things like creating lots
    # of JavaScript runtimes.
    set_response_validity_time(3600)
  end

  # Display a message
  # DO NOT DELETE THIS ACTION -- some older plugins redirect to this page
  _PoliciesRequired nil
  def handle_unauthorised
  end

  # Display a message about objects not being visible
  _PoliciesRequired nil
  def handle_hidden_object
  end

  # Password management
  _GetAndPost
  _PoliciesRequired :not_anonymous
  def handle_change_password
    if @request_user.kind == User::KIND_SUPER_USER
      @change_msg = T(:Authentication_Can_t_change_super_user_password_)
      return render :action => 'change_password_disabled'
    end

    # Is this enabled for this email address?
    change_enabled, @change_msg = is_password_feature_enabled?(:change_password, @request_user.email)
    unless change_enabled
      return render :action => 'change_password_disabled'
    end

    if @request_user.password_is_invalid?
      return render :action => 'change_password_managed_elsewhere'
    end

    if request.post? && session[:uid] != nil
      @failed_change = true

      @bad_old = ! (@request_user.password_check(params[:old]))
      @not_match = (params[:pw1] != params[:pw2])
      @bad_new = ! (User.is_password_secure_enough?(params[:pw1]))

      @failed_change = false unless @bad_old || @not_match || @bad_new

      unless @failed_change
        @request_user.password = params[:pw1]
        @request_user.save!
        render :action => 'password_changed'
      end
    end
  end

  # Lost password handling
  _GetAndPost
  _PoliciesRequired nil
  def handle_recovery
    if request.post? && params.has_key?(:email)
      email = params[:email].gsub(/\s/,'')
      if email =~ K_EMAIL_VALIDATION_REGEX

        # Is this enabled for this email address?
        forgotten_enabled, @forgotten_msg = is_password_feature_enabled?(:forgotten_password, email)
        unless forgotten_enabled
          render :action => 'recovery_disabled'
          return
        end

        user_record = User.find_first_by_email(email)

        template = EmailTemplate.find(EmailTemplate::ID_PASSWORD_RECOVERY)

        if user_record == nil
          # Send an email explaining there isn't something at that address
          template.deliver(
            :to => email,
            :subject => @locale.text_format(:Authentication_Recovery_Email_Subject_Change_password, KApp.global(:product_name)),
            :message => render(:partial => 'email_recovery_no_account')
          )
        else
          # Generate the recovery URL - use a logged in URL to use SSL if at all possible (not :visible)
          @url = "#{KApp.url_base(:logged_in)}#{user_record.generate_recovery_urlpath()}"
          @name = user_record.name

          template.deliver(
            :to => user_record,
            :subject => @locale.text_format(:Authentication_Recovery_Email_Subject_Change_password, KApp.global(:product_name)),
            :message => render(:partial => 'email_recovery')
          )
        end

        render(:action => 'recovery2')
      else
        @invalid_email_address = true
      end
    end
  end

  _GetAndPost
  _PoliciesRequired nil
  def handle_r # short link for recovery
    user_record = User.get_user_for_recovery_token(params[:id])
    unless user_record
      render(:action => ((params[:action] == 'welcome') ? 'bad_welcome' : 'bad_recovery'))
    else
      @user_first_name = user_record.name_first
      @user_id = user_record.id
      if request.post?
        # Check passwords
        @failed_change = true
        @not_match = (params[:pw1] != params[:pw2])
        @bad_new = ! (User.is_password_secure_enough?(params[:pw1]))
        @failed_change = false unless @not_match || @bad_new
        # Change it?
        unless @failed_change
          user_record.password = params[:pw1]
          user_record.recovery_token = nil    # stop the link from working again
          user_record.save!
          if params[:action] == 'welcome'
            # Welcome email gets a special page
            @email = user_record.email
            render(:action => 'welcome_done')
          else
            render(:action => 'recovery4')
          end
        end
      end
    end
  end

  _GetAndPost
  _PoliciesRequired nil
  def handle_welcome
    handle_r
  end

  # ----------------------------------------------------------------------------------------------------------------------------

private
  def do_redirect_to_destination
    rdr = params[:rdr]
    destination_url = if rdr != nil && rdr =~ SAFE_REDIRECT_URL_PATH   # must begin with a / to avoid being able to trick people
      rdr
    else
      # Redirect to the home page by default
      '/'
    end
    redirect_to destination_url
  end
end
