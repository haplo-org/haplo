# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


#
# The ApplicationController includes quite a bit of code which is shared. The strategy is to put
# this in files within
#
#    app/base/application/
#
# and the methods defined within these files have prefixes to identify where they come from
# (this rule is not 100% followed.)
#
#
# Globally useful helpers are similarly split into files by 'subject', and are kept in
#
#    app/helpers/application/
#
# These helpers are explicitly loaded with the include declarations below.
#

#
# Class variables with global significance
# ----------------------------------------
#
# -- set by system for controllers to use:
#
#    @request_user        - User which made this request
#    @current_api_key     - nil, or ApiKey object for the current request
#    @request_uses_api_key - true if the request uses authentication via an api key -- errors returned differently
#    @locale              - KLocale object for the current session
#
# -- set by controllers for layout and other bits of the system to use:
#
#    @page_title          - title for the page in the HTML head and h1 in layout - must have been h()ed
# TODO: Check @page_title assignments -- maybe have automated thing to check non-constants have h()?
#    @page_creation_label_html - HTML for creation label at bottom of page
#    @edit_link           - link for editing the current item, if appropraite (edit button)
#    @represented_objref  - the ref of the object this page represents (add to basket button)
#    @page_selectable_as_search  - true if the page can be used as a search input for spawned subtasks
#    @standard_layout_page_element_classes - extra classes for the z__page div element in the standard library
#
#

# Spinner HTML constants
SPINNER_HTML = '<img src="/images/spinner.gif" width="16" height="15" class="z__spinner">'
SPINNER_HTML_PLAIN = '<img src="/images/spinner.gif" width="16" height="15" align="top">'

class ApplicationController
  # Framework
  extend  Ingredient::Annotations
  include Ingredient::Handling
  extend  Ingredient::Handling::ClassMethods
  include Ingredient::Rendering
  include Ingredient::Sessions

  # Application
  include KConstants
  include KPlugin::HookSite

  # Helpers
  include ApplicationHelper
  include Application_HtmlHelper
  include Application_TextHelper
  include Application_LabelHelper
  include Application_TimeHelper
  include Application_IconHelper
  include Application_RenderHelper
  include Application_ElementHelper
  include Application_DynamicFileHelper
  include Application_TrayHelper
  include Application_WorkflowButtonsHelper
  include Application_ControlsHelper

  include KObjectURLs

  # Support for JavaScript plugin API
  include JSRubyTemplateControllerSupport

  # Standard libraries
  include ERB::Util

  # Function for shortcut to translated text in code
  def T(sym)
    @locale.text(sym)
  end

  # Security headers
  HEADER_X_FRAME_OPTIONS = 'X-Frame-Options'
  HEADER_X_FRAME_OPTIONS_DEFAULT = 'SAMEORIGIN'
  # NOTE: X-Content-Type-Options: nosniff set for IE for all 200 responses by the Java RequestHandler
  HEADER_CONTENT_SECURITY_POLICY = 'Content-Security-Policy'
  CONTENT_SECURITY_POLICIES = {
    '$SECURE' => "default-src 'self'; style-src 'self' 'unsafe-inline'",
    '$ENCRYPTED' => "default-src https: 'unsafe-inline' 'unsafe-eval'",
    '$OFF' => '', # don't send a header
    '$NO-SCRIPT' => "default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'none'"
  }

  # Where to get the templates from
  include Templates::Application

  # Get information (for use by plugins and other parts of the system)
  attr_reader :current_api_key
  attr_reader :request_uses_api_key
  attr_reader :locale

  # Class objects are used as the controller factories
  class << self
    alias make_controller new
  end

  # A "background" controller is one which has been created for the purpose of using the controller
  # infrastructure (eg rendering) outside the usual context of handling a request.
  def self.make_background_controller(*args)
    self.new._setup_background_controller(*args)
  end
  def _setup_background_controller(user, exchange = nil)
    @request_user = user
    @exchange = exchange
    @locale = KLocale::ID_TO_LOCALE[user.get_user_data(UserData::NAME_LOCALE) || KLocale::DEFAULT_LOCALE.locale_id]
    self
  end

  # Default layout
  def render_layout
    'standard'
  end

  def _override_layout_rendering(content, layout)
    output = nil
    call_hook(:hRenderStandardLayout) do |hooks|
      result = hooks.run(
        "std:"+(layout || render_layout()),
        @page_title,
        content,
        @__right_column_chunks.nil? ? nil : @__right_column_chunks.join(''),
        @page_creation_label_html
      )
      output = result.html
    end
    output
  end

  def csrf_get_token
    token = session[:_csrf_tok]
    if token == nil
      # Make sure there's a session
      session_create if session.discarded_after_request?
      # Generate a new token and store
      token = KRandom::random_api_key(12)
      session[:_csrf_tok] = token
    end
    token
  end

  def csrf_check(exchange)
    if @current_api_key != nil
      # If an API key has been used to authenticate, don't check for CSRF
      true
    else
      # Use normal CSRF protection
      super
    end
  end

  # --------------------------------------------------------------------------
  # Caching control
  def set_response_validity_time(seconds)
    response.headers['Cache-Control'] = "private, max-age=#{seconds.to_i}"
    response.headers['Expires'] = (Time.now + seconds).to_formatted_s(:rfc822)
  end

  # --------------------------------------------------------------------------
  # Allow controllers to override default content security policy
  def set_content_security_policy(policy)
    @_content_security_policy = policy
  end


  # --------------------------------------------------------------------------
  # For supporting the spawned window UI scheme
  #
  def redirect_to(a)
    # Normal?
    unless params.has_key?('_sx')
      super(a)
    else
      # In a spawned window
      sx = params['_sx'].to_i  # makes sure it doesn't contain bad characters
      raise "Redirect isn't a string as expected by redirect_to" unless a.class == String
      if a =~ /[\&\?]_sx/
        super(a)
      else
        super(a += ((a =~ /\?/) ? '&' : '?') + "_sx=#{sx}")
      end
    end
  end

  # -----------------------------------------------------------------------------------
  #  Exception catcher
  # -----------------------------------------------------------------------------------
  def exception_during_handle(exception)
    # Clear any response generated
    render_clear_response

    # JavaScript & Ruby interpreters may have wrapped the underlying exception
    if exception.kind_of?(org.mozilla.javascript.WrappedException)
      exception = exception.getWrappedException()
    end
    if exception.kind_of?(org.jruby.exceptions.RaiseException)
      exception = exception.getException()
    end

    case exception
    when KNoPermissionException, KObjectStore::PermissionDenied
      respond_to_unauthorised_request()
      true # handled
    else
      # Use normal exception handling
      super
    end
  end

  # --------------------------------------------------------------------------
  # Client side info
  CLIENT_AJAX_AND_WINDOW_SIZE_COOKIE_NAME = 'w'
  def client_proven_to_support_ajax
    request.cookies.has_key?(CLIENT_AJAX_AND_WINDOW_SIZE_COOKIE_NAME)
  end
  def client_window_dimensions
    dims = request.cookies[CLIENT_AJAX_AND_WINDOW_SIZE_COOKIE_NAME]
    if dims =~ /\A(\d+)-(\d+)\z/
      [$1.to_i,$2.to_i]
    else
      nil
    end
  end


  # --------------------------------------------------------------------------
  #   Get things ready for the application

  def pre_handle
    # Make sure there's always a locale available. It'll be replaced by the user's locale early on in request handling.
    @locale = KLocale::DEFAULT_LOCALE
    # Inherited behaviour
    super
    # Check the application is active
    unless KApp.global(:status) == KApp::STATUS_ACTIVE
      render(:text => IO.read("#{KFRAMEWORK_ROOT}/static/special/404app.html"), :status => 404)
      return false # Don't continue
    end
    # Check authorisation
    unless check_authorisation
      # If the framework is requesting instructions for a file upload, set a special header so the response is returned now
      uploads = exchange.annotations[:uploads]
      if uploads && uploads.getInstructionsRequired()
        response.headers['X-Haplo-Reportable-Error'] = 'yes'
      end
      return false
    end
    # Enforce SSL policy and desired hostnames
    url_type = (@request_user.policy.is_anonymous? ? :anonymous : :logged_in)
    is_currently_ssl = request.ssl? ? true : false
    expected_hostname = KApp.global((KApp.use_ssl_for(url_type) || is_currently_ssl) ? :ssl_hostname : :url_hostname)
    # if SSL is used, stay there -- avoids circular redirects on common SSL policies with different hostnames
    if (! is_currently_ssl && KApp.use_ssl_for(url_type)) || (request.host.downcase != expected_hostname)
      if should_redirect_to_primary_hostname?
        # Redirect to the right URL
        redirect_to "#{KApp.url_base(url_type)}#{request.request_uri}"
        return false
      end
    end
    # Set user's locale. Session contains the locale so it's in memory to avoid database access, and can be
    # changed independently of any user data configuration (eg for ANONYMOUS)
    locale_id = session[:locale]
    unless locale_id
      locale_id = session[:locale] = @request_user.get_user_data(UserData::NAME_LOCALE) || KLocale::DEFAULT_LOCALE.locale_id
    end
    @locale = KLocale::ID_TO_LOCALE[locale_id] || KLocale::DEFAULT_LOCALE
    # Set up important class variables which should always be created, to avoid messy repeated code
    init_standard_controller_class_variables()
    # Send pre-request handling notification
    KNotificationCentre.notify(:http_request, :start, request, @request_user, @current_api_key)
    # Allow the request to continue
    true
  end

  def should_redirect_to_primary_hostname?
    true
  end

  def init_standard_controller_class_variables
    @title_bar_buttons = {}
  end

  # --------------------------------------------------------------------------
  #   Complete the request

  def post_handle

    # Join the handling and rendering together
    unless exchange.has_response?
      # If the controller didn't do an explicit render, perform it now
      unless render_performed?
        # Handle permission denied exceptions during rendering
        begin
          render
        rescue => e
          raise unless exception_during_handle(e)
        end
      end
      # Set the response to the result of the rendering
      exchange.response = render_result
    end

    # Commit any changes to the session
    session_commit

    # Set security headers
    unless exchange.response.headers.has_header?(HEADER_X_FRAME_OPTIONS)
      exchange.response.headers[HEADER_X_FRAME_OPTIONS] = HEADER_X_FRAME_OPTIONS_DEFAULT
    end
    content_security_policy = @_content_security_policy || KApp.global(:content_security_policy)
    # Replace built in policies with actual text, or if not found, just send the header
    content_security_policy = CONTENT_SECURITY_POLICIES[content_security_policy] || content_security_policy
    if content_security_policy != nil && content_security_policy.length != 0
      # Replace any whitespace with spaces to stop newlines getting through
      exchange.response.headers[HEADER_CONTENT_SECURITY_POLICY] = content_security_policy.gsub(/\s+/,' ')
      # Note that use of the single standards compliant header name misses out support in some older
      # browsers, but anyone who cares about security will have upgraded.
    end

    # Post-request notification
    KNotificationCentre.notify(:http_request, :end)
  end

end