# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# TODO: Proper test for authorisation based on policy, along with testing for verification correct policy application

#
# Principal related class variables
# ---------------------------------
# @request_user => a User::Info object, from the user cache.
#    (Always set to something, but it could be an anonymous user)
#
#
# Policy enforcement
# ------------------
# Controllers statements to set the required policy:
#    policies_required                (specify policies required by all actions)
#    _PoliciesRequired                (annotation of specific method)
# Use one or the other - they can't be mixed
#
#
# Permissions enforcement
# -----------------------
#
# Call
#    permission_denied
# to stop processing the current action and redirect to the unauthorized page.
#
# Use
#    @request_user.policy.has_permission?(:operation, object)
# to check permissions without aborting if the user doesn't have them.
#


class ApplicationController
  API_KEY_AUTHORIZATION_HEADER_NAME = KFramework::Headers::AUTHORIZATION
  API_KEY_AUTHORIZATION_BASIC = /\ABasic aGFwbG86([A-Za-z0-9\+\/]+=*)\z/ # aGFwbG86 -> 'haplo:'
  API_KEY_HEADER_NAME = 'X-Oneis-Key' # has been normalised to lower case 'IS'
  API_KEY_PARAM_NAME = '_ak'

  # NOTE: _ak parameter filtered with KFRAMEWORK_LOGGING_PARAM_FILTER in environment.rb

  # Use to deny permission to do something
  def permission_denied
    raise KNoPermissionException
  end

  # -----------------------------------------------------------------------------------
  #  Set policy on controller
  # -----------------------------------------------------------------------------------

  # Use to set which policies are required for a controller
  def self.policies_required(*policies)
    # Check the array has at least one member, then annotate CLASS with the array with nil's removed
    raise "No policies specified (use at least nil)" if policies.empty?
    self.annotate_class(:_policies_required, KPolicyRegistry.to_bitmask(policies))
  end

  # An annotation to describe the policies required for this method
  def self._PoliciesRequired(*policies)
    # Check that the class hasn't been annotated
    raise "Can't use _PoliciesRequired method annotations if policies_required has been declared" if self.annotation_get_class(:_policies_required)
    # Check the array has at least one member, then annotate METHOD with the array with nil's removed
    raise "No policies specified (use at least nil)" if policies.empty?
    self.annotate_method(:_policies_required, KPolicyRegistry.to_bitmask(policies))
  end

  # -----------------------------------------------------------------------------------
  #  Policy authorisation filter method
  # -----------------------------------------------------------------------------------
  # called by prepare_for_request
  def check_authorisation
    user_object = nil
    authenticating_user = nil # when impersonation is active

    # Is there an API key?
    api_key = nil
    authorization_header = request.headers[API_KEY_AUTHORIZATION_HEADER_NAME]
    if authorization_header
      authorization_header_m = API_KEY_AUTHORIZATION_BASIC.match(authorization_header)
      api_key = authorization_header_m[1].unpack('m*').first if authorization_header_m
    else
      api_key = params[:_ak] || request.headers[API_KEY_HEADER_NAME] # X-ONEIS-Key HTTP header
    end
    if api_key != nil
      # ================ API Key authentication ================
      device = nil
      if api_key.length >= 16
        begin
          KLoginAttemptThrottle.with_bad_login_throttling(request.remote_ip) do |outcome|
            device = ApiKey.cache[api_key]
            outcome.was_success = !!(device)
          end
        rescue KLoginAttemptThrottle::LoginThrottled => e
          render :text => 'Too many failed API authentication attempts, API usage suspended. Pause requests to wait until restriction lifted.', :status => 403
          return false
        end
      end
      # bad API keys stop all processing -- the key must exist, no auto-anonymous access with APIs
      if device == nil || !(device.valid_for_request?(request, params))
        render :text => 'Bad API Key', :status => 403
        return false
      end
      # Get the user record from the cache, and check it's a non-blocked user or the special support user
      user_object = User.cache[device.user_id]
      unless user_valid_for_request(user_object)
        render :text => 'Not authorised', :status => 403
        return false
      end
      @request_uses_api_key = true
      @current_api_key = device

    else
      # ================ Normal interactive authentication ================
      # Determine the user ID, defaulting to the anonymous user if one isn't set in the session
      # or the authenticating user is no longer authorised with impersonated users.
      user_uid = User::USER_ANONYMOUS
      if session.has_key?(:impersonate_uid)
        authenticating_user = User.cache[session[:uid] || User::USER_ANONYMOUS]
        # Check that the authenticating user is still active and has permission to impersonate
        # before using the impersonated uid.
        if user_valid_for_request(authenticating_user) && authenticating_user.policy.can_impersonate_user?
          # Only user_uid if all checks out, so default to ANONYMOUS otherwise.
          user_uid = session[:impersonate_uid]
        end
      elsif session.has_key?(:uid)
        user_uid = session[:uid]
      end
      user_object = User.cache[user_uid]
      user_object = User.cache[User::USER_ANONYMOUS] unless user_valid_for_request(user_object)
    end

    # Find the policy requirements for this request
    # Try class declaration first
    policies_required = self.class.annotation_get_class(:_policies_required)
    if policies_required == nil
      # Try for method annotations if nothing specified on the class
      method_name = requested_method_to_method_name(exchange.annotations[:requested_method])
      policies_required = self.class.annotation_get(method_name, :_policies_required)
    end

    KApp.logger.info("  uid: #{user_object.id} (anon=#{user_object.policy.is_anonymous?},api=#{@request_uses_api_key})")

    # Make sure there are some policy requirements specified - ensures it hasn't been forgotten
    raise "No policy requirements specified for '#{exchange.annotations[:requested_method]}' in #{self.class.name}" if policies_required == nil

    AuthContext.set_user(user_object, authenticating_user || user_object)
    @request_user = user_object

    unless user_object.policy.check_policy_bitmask(policies_required)
      respond_to_unauthorised_request()
      return false
    end

    true
  end

  # Check that a User object is valid for authenticating a request
  def user_valid_for_request(user_object)
    case user_object.kind
    when User::KIND_USER, User::KIND_SERVICE_USER, User::KIND_SUPER_USER
      true
    else
      false
    end
  end

private

  def respond_to_unauthorised_request
    if !(@request_user) || @request_uses_api_key || exchange.annotations[:api_url]
      # Non-interactive request -- use mini-response without all the usual chrome
      render :template => "authentication/unauthorised_api", :layout => false, :status => 403
    elsif @request_user.policy.is_anonymous?
      # Anonymous users are asked to log in and will be redirected
      # request.request_uri includes the full URI including parameters -- although the docs say it's
      # server specific on what it includes. Mongrel is fine.
      # Use :logged_in so that the login page has uses the same SSL state as logged in users
      redirect_to "#{KApp.url_base(:logged_in)}/do/authentication/login?rdr=#{ERB::Util.url_encode(request.request_uri)}"
    else
      # Logged in users are told they're unauthorised (leaving the SSL status alone)
      render :template => "authentication/unauthorised", :status => 403
    end
    true
  end

end


class KNoPermissionException < RuntimeError
end

