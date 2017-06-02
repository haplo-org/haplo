# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class WebPublisherController < ApplicationController

  # Send requests to std_web_publisher plugin (if installed)
  def handle(exchange, path_elements)
    @exchange = exchange

    web_publisher = KPlugin.get("std_web_publisher")
    raise KFramework::RequestPathNotFound.new("std_web_publisher plugin is not installed") unless web_publisher

    # Call into web publisher as ANONYMOUS
    anonymous = User.cache[User::USER_ANONYMOUS]
    AuthContext.set_user(anonymous, anonymous)
    @request_user = anonymous

    request = exchange.request
    if request.method != "GET"
      # If this is changed, then CSRF needs to be considered. (CSRF protection is disabled for publisher)
      raise KFramework::RequestPathNotFound.new("Only GET supported by web publisher");
    end

    r = KJSPluginRuntime.current.call_web_publisher_handler(request.host, "GET", request.path)
    raise KFramework::RequestPathNotFound.new("Web publisher didn't render anything") unless r

    # Split out response infomation (shares Java response decoding with JavaScriptPluginController)
    status_code, headersJSON, body, kind = r.to_a
    raise KFramework::RequestPathNotFound.new("Web publisher didn't render a body") if body.nil?

    # Only support HTML responses
    unless (kind == 'html') && body.kind_of?(String)
      raise JavaScriptAPIError, "Web publisher response wasn't HTML"
    end

    session_commit

    # Build & return response
    response = KFramework::DataResponse.new(body, 'text/html; charset=utf-8', (status_code || 200).to_i)
    if headersJSON != nil
      headers = JSON.parse(headersJSON)
      headers.each do |name, value|
        response.headers[name] = value
      end
    end
    exchange.response = response
  end

  # pre & post handle shouldn't be called.
  def pre_handle;  raise "Should never be called"; end
  def post_handle; raise "Should never be called"; end
end
