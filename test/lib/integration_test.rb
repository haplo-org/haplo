# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class IntegrationTest < Test::Unit::TestCase
  include IntegrationTestUtils

  # Only one thread can try login failures at any one time.
  AUTHENTICATION_LOGIN_TEST_FAILURE_LOCK = Mutex.new

  # Implementation of a test session which makes requests from the application
  module TestingSession
    def _testing_host
      "www#{_TEST_APP_ID}.example.com"
    end

    def set_ignore_cookies(ignore = true)
      @_ignore_cookies = ignore
      if ignore
        @_cookies = {}
      end
    end

    def get_cookies
      @_cookies || {}
    end
    def replace_cookies(replace_with)
      @_cookies = replace_with.dup
    end

    # ------------- ASSERTIONS

    def assert_request(truth)
      if not truth
        puts "Assertion error with request.  First 1k of response: <<<"
        puts @_last_response.body[0..1024]
        puts ">>>"
      end
      assert truth
    end

    def assert_response(is)
      case is
      when :success
        assert_request @_last_response.kind_of? Net::HTTPSuccess
      when :failure
        assert_request (@_last_response.kind_of? Net::HTTPServerError) || (@_last_response.kind_of? Net::HTTPClientError)
      when :redirect
        assert_request @_last_response.kind_of? Net::HTTPRedirection
      else
        raise "Bad assert_response code #{is}"
      end
    end

    def html_document
      xml = response.content_type =~ /xml$/
      @_html_document ||= HTML::Document.new(response.body, false, xml)
    end

    def find_tag(conditions)
      html_document.find(conditions)
    end

    def select_tags(selector)
      HTML::Selector.new(selector).select(@_assert_select_context || html_document.root)
    end

    # comparison is String or hash of:
    #   :text => text it must contain
    #   :count => count of elements to match (must match 1 otherwise)
    #   :cookies => Hash of String => String of additional cookies to add
    # If block_given?, yields in a context where the child elements are tested if assert_select is called again
    def assert_select(selector, comparison = nil)
      # Allow shortcut
      if comparison.kind_of?(String) || comparison.kind_of?(Regexp)
         comparison = {:text => comparison}
      end
      # Find the bit of document
      n = HTML::Selector.new(selector).select(@_assert_select_context || html_document.root)
      # Check number of elements, defaulting to checking against 1
      if comparison != nil
        # Count of elements
        if comparison.has_key?(:count)
          assert_equal comparison[:count], n.length
        end
        if comparison.has_key?(:present)
          assert comparison[:present] ? (n.length > 0) : (n.length == 0)
        end
        # Text of elements
        if comparison.has_key?(:text)
          # Must have something to test against!
          assert n.length > 0
          # Check each is equal
          n.each do |x|
            text = x.children.map { |e| e.to_s } .join('').gsub(/\<[^\>]+?\>/,'').strip
            if comparison[:text].kind_of? Regexp
              assert text =~ comparison[:text]
            else
              assert_equal comparison[:text], text
            end
          end
        end
        # Attribute checks
        if comparison.has_key?(:attributes)
          # Must have something to test against!
          assert n.length > 0
          # Check attributes on each one
          n.each do |x|
            comparison[:attributes].each do |name,value|
              assert x.attributes.has_key?(name.to_s)
              assert_equal value, x.attributes[name.to_s]
            end
          end
        end
      end
      # Continue checks inside block
      if block_given?
        # Must have something to test against!
        assert n.length > 0
        # Yield each block
        n.each do |context|
          old_context = @_assert_select_context
          begin
            @_assert_select_context = context
            yield
          ensure
            @_assert_select_context = old_context
          end
        end
      end
    end

    def assert_redirected_to(uri)
      assert response.kind_of? Net::HTTPRedirection
      location = response['location'].gsub(/\Ahttps?:\/\/([^\/]+)/,'')
      assert_equal uri, location
      # Check content-type is as expected and body looks roughly right
      assert_equal "text/html; charset=utf-8", response['content-type']
      assert response.body.include?(uri)
    end

    # ------------- REQUESTING

    # opts with key.kind_of? String are set as HTTP headers in request
    #   :redirects => (override default_redirects argument)
    #   :no_automatic_csrf_token => true to stop the automatic CSRF addition to POST params
    #   :no_check_for_csrf_failure => true to stop checking for the CSRF message with a special failure
    #   :no_check_for_wrong_http_method => true to stop checking for the wrong HTTP method failure
    #   :expected_response_codes => a list of HTTP status codes that the server is allowed to return,
    #                               any HTTP response not in this list will cause an assertion error. Default: [200]
    #
    def make_request(path, params, opts = nil, method = :get, default_redirects = :follow_redirects)
      raise "Bad path" unless path =~ /\A\//
      params ||= {}
      opts ||= {}
      # Reset state
      @_html_document = nil
      @_last_request = nil
      @_last_response = nil
      # Create a request
      req = case method
      when :get
        Net::HTTP::Get.new(params.empty? ? path : %Q!#{path}?#{URI.encode_www_form(params)}!)
      when :options
        Net::HTTP::Options.new(params.empty? ? path : %Q!#{path}?#{URI.encode_www_form(params)}!)
      when :post
        r = Net::HTTP::Post.new(path)
        if params.kind_of? Hash
          # CSRF handling?
          unless @_csrf_token == nil || opts[:no_automatic_csrf_token] || params.has_key?(:__)
            params = params.dup
            params[:__] = @_csrf_token
          end
          # Set the form data, automatically encoding it
          r.set_form_data(params)
        elsif params.kind_of? String
          r.body = params
        else
          raise "Bad kind of params / body for make_request (#{params.class.name})"
        end
        r
      else
        raise "Bad request method #{method}"
      end
      # If it's requesting an authentication URL, need to lock it to ensure tests don't clash
      # Doing authentication actions affects the global state of the login throttling code
      taking_auth_lock = !!((method == :post) && (path =~ /\A\/do\/authentication\/(login|otp)/))
      if taking_auth_lock
        begin
          AUTHENTICATION_LOGIN_TEST_FAILURE_LOCK.lock
        rescue ThreadError => e
          # Lock already held by this thread
          taking_auth_lock = false
        end
      end
      # Make the request
      _setup_request(req, opts)
      res = Net::HTTP.new('127.0.0.1', KApp::SERVER_PORT_INTERNAL_CLEAR).start { |http| http.request(req) }
      _capture_testing_info_from(res)
      # Undo auth lock?
      AUTHENTICATION_LOGIN_TEST_FAILURE_LOCK.unlock if taking_auth_lock
      # Check CSRF failure?
      if method == :post && !(opts[:no_check_for_csrf_failure]) && res.body =~ /attempt to circumvent security measures/
        flunk "CSRF protection triggered in server -- make sure CSRF token is obtained and sent in request"
      end
      # Check for wrong method handling
      if !(opts[:no_check_for_wrong_http_method]) && res.body != nil && res.body =~ /Wrong HTTP method used, ?([^\<]+)/
        flunk "Wrong HTTP method used for this request: #{$1}"
      end

      # Redirect handling?
      if res.kind_of? Net::HTTPRedirection
        case opts[:redirects] || default_redirects
        when :do_not_follow_redirects
          # Do nothing
        when :follow_redirects
          # Follow the redirect!
          failsafe = 10
          while failsafe > 0
            failsafe -= 1
            next_path = res['location']
            next_path = next_path.gsub(/\Ahttps?:\/\/([^\/]+)\//) do
              raise "Bad redirect to non-local host" unless $1 == _testing_host
              '/' # replace http.../ with /
            end
            if next_path !~ /\A\//
              raise "Bad path from redirect #{next_path}"
            end
            res = Net::HTTP.new('127.0.0.1', KApp::SERVER_PORT_INTERNAL_CLEAR).start { |http| http.request(_setup_request(Net::HTTP::Get.new(next_path), opts)) }
            _capture_testing_info_from(res)
            if res.kind_of? Net::HTTPInternalServerError
              flunk "Server returned a 500 Internal Server Error response for path #{next_path} (redirected from #{path})."
            end
            break unless res === Net::HTTPRedirection
          end
          raise "Redirection recursed too many times" if failsafe <= 0
        else
          raise "Bad redirects value #{no_redirects}"
        end
      end

      expected_response_codes = opts[:expected_response_codes] || [200]
      if not expected_response_codes.include?(res.code.to_i)
        # Special case for redirects, because it's really useful to see where you're being sent..
        flunk "Server unexpectedly redirected(#{res.code}) to: #{res['location']}." if res.kind_of? Net::HTTPRedirection
        flunk "Server returned an unexpected #{res.code} response for path #{path}."
      end
      # Set data for asserts
      @_last_request = req
      @_last_response = res
    end

    def _setup_request(req, opts)
      # Cookies
      cookies = opts[:cookies] || {}
      if @_cookies != nil && !@_ignore_cookies
        cookies = cookies.dup.merge(@_cookies)
      end
      c = cookies.map { |k,v| %Q!#{k}=#{v}! }
      unless c.empty?
        req['Cookie'] = %Q!$Version="1"; #{c.join('; ')}!
      end
      # Host (set first so headers can override)
      req['host'] = _testing_host
      # Headers
      opts.each { |k,v| req[k] = v if k.kind_of? String }
      # Return request
      req
    end

    def _capture_testing_info_from(res)
      return if res == nil
      # Capture the cookies from the response, if required
      unless @_ignore_cookies
        @_cookies ||= Hash.new
        set_cookie = res.get_fields('set-cookie')
        if set_cookie != nil
          set_cookie.each do |value|
            if value =~ /\A([^=]+)=([^;]+)\;?/
              @_cookies[$1] = $2
            end
          end
        end
      end
      # CSRF token
      if (res.kind_of? Net::HTTPSuccess) && (res.body != nil) && (res.body =~ /<input type="hidden" name="__" value="([^"]+)">/)
        @_csrf_token = $1
      end
    end

    def request
      @_last_request
    end

    def response
      @_last_response
    end

    def session
      return "No session" if @_cookies == nil || !(@_cookies.has_key?('s'))
      session_id = @_cookies['s']
      # Rummage around in the internals to find the session data
      app_info = Java::OrgHaploFramework::Application.fromHostname(_testing_host).getRubyObject
      sessions = app_info.all_sessions
      # It's possible a session doesn't exist, in which case, return an empty session with marker
      session = (sessions[session_id] || {:_no_session_found => true})
      session
    end

    def session_cookie_value
      return nil if @_cookies == nil
      @_cookies['s']
    end

    def session_cookie_value_set(value)
      @_cookies ||= {}
      if value.nil?
        @_cookies.delete('s')
      else
        @_cookies['s'] = value
      end
      @_csrf_token = nil  # because session info has been reset
    end

    def cookies
      @_cookies
    end

    def current_discovered_csrf_token
      @_csrf_token
    end

    def get(path, params = nil, opts = nil)
      make_request(path, params, opts, :get, :do_not_follow_redirects)
    end

    def post(path, params = nil, opts = nil)
      make_request(path, params, opts, :post, :do_not_follow_redirects)
    end

    def get_via_redirect(path, params = nil, opts = nil)
      make_request(path, params, opts, :get, :follow_redirects)
    end

    def post_via_redirect(path, params = nil, opts = nil)
      make_request(path, params, opts, :post, :follow_redirects)
    end

    # ------------- Some magic to make calling GETs and POSTs easier:

    def method_missing(meth, *args, &block)
      if meth.to_s =~ /^(get|post|get_via_redirect|post_via_redirect|multipart_post)_(\d+)$/
        args[2] = args[2] || {}
        args[2][:expected_response_codes] =[$2.to_i]
        send $1.to_sym, *args
      else
        super
      end
    end

    # ------------- MULTIPART POSTING

    def multipart_post(url, params, opts = {})
      # CSRF handling?
      unless @_csrf_token == nil || opts[:no_automatic_csrf_token] || params.has_key?(:__)
        params = params.dup
        params[:__] = @_csrf_token
      end
      # Make POST request
      boundary = "----------XnJLe9ZIbbGUYtzPQJ16u1"
      post url, multipart_body(params, boundary), opts.merge({"Content-Type" => "multipart/form-data; boundary=#{boundary}"})
    ensure
      # Make sure everythign is tidied up
      params.each do |k,value|
        if value.respond_to?(:getSavedPathname)
          p = value.getSavedPathname
          File.unlink(p) if File.exist?(p)
        end
      end
    end

    def multipart_requestify(params, first=true)
      p = {}
      params.each do |key, value|
        k = first ? key.to_s : "[#{key.to_s}]"
        if Hash === value
          multipart_requestify(value, false).each do |subkey, subvalue|
            p[k + subkey] = subvalue
          end
        else
          p[k] = value
        end
      end
      p
    end

    def multipart_body(params, boundary)
      multipart_requestify(params).map do |key, value|
        if value.respond_to?(:getSavedPathname)
          File.open(value.getSavedPathname) do |f|
            <<-EOF
--#{boundary}\r
Content-Disposition: form-data; name="#{key}"; filename="#{KFramework::Utils::escape(value.getFilename)}"\r
Content-Type: #{value.getMIMEType}\r
Content-Length: #{File.stat(value.getSavedPathname).size}\r
\r
#{File.open(value.getSavedPathname) { |f| f.read }}\r
EOF
          end
        else
          <<-EOF
--#{boundary}\r
Content-Disposition: form-data; name="#{key}"\r
\r
#{value}\r
EOF
        end
      end.join("")+"--#{boundary}--\r"
    end

  end

  # Have a default session in the tests, but allow a standalone session to be created
  include TestingSession
  class StandaloneSession
    def initialize(host)
      @_host = host
    end
    def _testing_host
      @_host
    end
    include Test::Unit::Assertions
    include TestingSession
  end

  # Get a standalone session
  def open_session(host = _testing_host)
    session = StandaloneSession.new(host)
    yield session if block_given?
    session
  end
end

