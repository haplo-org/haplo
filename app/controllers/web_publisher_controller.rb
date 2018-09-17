# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class WebPublisherController < ApplicationController

  KStoredFile = Java::OrgHaploJsinterface::KStoredFile
  KBinaryDataStaticFile = Java::OrgHaploJsinterface::KBinaryDataStaticFile
  XmlDocument = Java::OrgHaploJsinterfaceXml::XmlDocument

  def self.hostname_has_publication_at_root?(host)
    r = false
    unless KPlugin.get("std_web_publisher").nil?
      runtime = KJSPluginRuntime.current
      runtime.using_runtime do
        web_publisher = runtime.runtime.host.getWebPublisher()
        r = !!(web_publisher.callPublisher("$isPublicationOnRootForHostname", host))
      end
    end
    r
  end

  # Send requests to std_web_publisher plugin (if installed)
  # NOTE: CSRF protection is disabled for publisher
  def handle(exchange, path_elements)
    @exchange = exchange

    web_publisher = KPlugin.get("std_web_publisher")
    raise KFramework::RequestPathNotFound.new("std_web_publisher plugin is not installed") unless web_publisher

    # Call into web publisher as ANONYMOUS
    anonymous = User.cache[User::USER_ANONYMOUS]
    AuthContext.set_user(anonymous, anonymous)
    @request_user = anonymous

    request = exchange.request
    unless (request.method == "GET") || (request.method == "POST")
      raise KFramework::RequestPathNotFound.new("Only GET & POST supported by web publisher");
    end

    r = KJSPluginRuntime.current.call_web_publisher_handler(request.host, request.method, request.path)
    raise KFramework::RequestPathNotFound.new("Web publisher didn't render anything") unless r

    # Split out response infomation (shares Java response decoding with JavaScriptPluginController)
    status_code, headersJSON, body, kind = r.to_a
    raise KFramework::RequestPathNotFound.new("Web publisher didn't render a body") if body.nil?

    # Support a limited set of binary data types as body
    if body.kind_of?(KStoredFile)
      # Stored file - probably from built-in /download handler
      stored_file = body.toRubyObject()
      exchange.response = KFramework::FileResponse.new(stored_file.disk_pathname, {
        :type => stored_file.mime_type,
        :filename => stored_file.upload_filename,
        :disposition => 'attachment'
      })
      return
    elsif body.kind_of?(KBinaryDataStaticFile)
      # Static file - probably thumbnail from built-in /thumbnail handler
      exchange.response = KFramework::FileResponse.new(body.getDiskPathnameForResponse(), {
        :type => body.jsGet_mimeType(),
        :filename => body.jsGet_filename()
      })
      return
    elsif body.kind_of?(XmlDocument)
      r = KFramework::JavaByteArrayResponse.new(body.toByteArray())
      r.content_type = "application/xml"
      exchange.response = r
      return
    end

    # Otherwise only support Text and HTML responses
    unless (kind == 'html' || kind == 'text') && body.kind_of?(String)
      raise JavaScriptAPIError, "Web publisher response wasn't HTML or text"
    end

    # Build & return response
    response = KFramework::DataResponse.new(body,
      (kind == 'text') ? 'text/plain; charset=utf-8' : 'text/html; charset=utf-8',
      (status_code || 200).to_i)
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
