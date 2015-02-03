# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Test::Unit::TestCase

  DEFAULT_TEST_USER_ID = 21

  def start_test_request(request = nil, user = nil, auth_user = nil)
    request = MockRequest.new(request || {})
    user = user ? user : User.cache[DEFAULT_TEST_USER_ID]
    exchange = KFramework::Exchange.new(_TEST_APP_ID, request)
    params = request.query_string.empty? ? Hash.new : Utils.parse_nested_query(request.query_string)
    if request.post?
      body = request.body
      params.merge!(Utils.parse_nested_query(body)) unless body.empty?
    end
    exchange.params = HashWithIndifferentAccess.new(params)
    @_controller = ApplicationController.make_background_controller(user, exchange)
    context = KFramework::RequestHandlingContext.new(@_controller, exchange)
    Thread.current[:_frm_request_context] = context
    @_old_auth_state = AuthContext.set_user(user, auth_user || user)
  end

  def end_test_request
    Thread.current[:_frm_request_context] = nil
    AuthContext.restore_state(@_old_auth_state) if @_old_auth_state
    @_old_auth_state = @_controller = nil
  end

  def with_request(*args)
    start_test_request(*args)
    begin
      yield @_controller
    ensure
      end_test_request
    end
  end

  # ---------------------------------------------------------------------------------------------------

  class MockRequest
    include KFramework::RequestMixin
    def initialize(request)
      @request = request
    end
    def method;       @request[:method] || 'GET'; end
    def path;         @request[:path] || '/'; end
    def query_string; @request[:query_string] || ''; end
    def body;         @request[:body] || ''; end
    def headers;      @request[:headers] || {}; end
    def ssl?;         !!@request[:is_ssl]; end
    def remote_ip;    @request[:remote_ip] || '127.0.0.1'; end
    def request_uri
      (query_string != nil && query_string != '') ? "#{path}?#{query_string}" : path
    end
    def continuation
      raise "No request continuation support for testing"
    end
  end

end

