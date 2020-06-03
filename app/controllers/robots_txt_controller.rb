# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class RobotsTxtController < ApplicationController

  DEFAULT_ROBOTS_TXT = "User-agent: *\nDisallow: /\n"

  def handle(exchange, path_elements)
    if exchange.request.path != "/robots.txt"
      raise KFramework::RequestPathNotFound.new("Request for path below /robots.txt")
    end

    robots_txt = DEFAULT_ROBOTS_TXT

    # Web publisher will generate a robots.txt file
    unless KPlugin.get("std_web_publisher").nil?
      # Generate robots.txt files as ANONYMOUS
      anonymous = User.cache[User::USER_ANONYMOUS]
      AuthContext.set_user(anonymous, anonymous)
      # Delegate generation of robots.txt to std_web_publisher plugin
      runtime = KJSPluginRuntime.current
      runtime.using_runtime do
        web_publisher = runtime.runtime.host.getWebPublisher()
        robots_txt = (web_publisher.callPublisher("$generateRobotsTxt", exchange.request.host) || DEFAULT_ROBOTS_TXT).to_s
      end
    end

    exchange.response = KFramework::DataResponse.new(robots_txt, 'text/plain; charset=utf-8', 200)
  end

  # pre & post handle shouldn't be called.
  def pre_handle;  raise "Should never be called"; end
  def post_handle; raise "Should never be called"; end
end
