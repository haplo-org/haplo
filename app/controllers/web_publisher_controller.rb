# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class WebPublisherController < ApplicationController

  KStoredFile = Java::OrgHaploJsinterface::KStoredFile
  KBinaryDataStaticFile = Java::OrgHaploJsinterface::KBinaryDataStaticFile
  KBinaryData = Java::OrgHaploJsinterface::KBinaryData
  KZipFile    = Java::OrgHaploJsinterface::KZipFile
  XmlDocument = Java::OrgHaploJsinterfaceXml::XmlDocument

  CONTENT_TYPES = Hash.new
  Ingredient::Rendering::RENDER_KIND_CONTENT_TYPES.each { |k,v| CONTENT_TYPES[k.to_s] = v}
  HEADER_CONTENT_TYPE = KFramework::Headers::CONTENT_TYPE

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

    # Set headers first, so anything is copied into one of the special responses
    content_type = CONTENT_TYPES[kind] || 'text/plain; charset=utf-8'
    if headersJSON != nil
      headers = JSON.parse(headersJSON)
      headers.each do |name, value|
        if name == HEADER_CONTENT_TYPE
          # Content-Type header needs to be moved to avoid getting overwritten or ignored
          content_type = value
        else
          response.headers[name] = value
        end
      end
    end

    # Support a limited set of binary data types as body
    # TODO: Refactor this to use the implemetation in JavascriptPluginController
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
    elsif body.kind_of?(KBinaryData)
      if body.isAvailableInMemoryForResponse()
        r = JavaScriptPluginController::BinaryDataResponse.new(body)
        r.content_type = body.jsGet_mimeType()
        filename = body.jsGet_filename()
        unless filename == nil or filename == ""
          filename = filename.gsub(/[^a-zA-Z0-9\._-]/,'_')
          r.headers[KFramework::Headers::CONTENT_DISPOSITION] = %Q!attachment; filename="#{filename}"!
        end
        exchange.response = r
      else
        disk_pathname = body.getDiskPathnameForResponse()
        raise JavaScriptAPIError, "File not available" unless disk_pathname && File.exist?(disk_pathname)
        render_send_file disk_pathname,
          :type => body.jsGet_mimeType() || 'application/octet-stream',
          :filename => body.jsGet_filename() || 'data.bin',
          :disposition => 'attachment'
      end
      return
    elsif body.kind_of?(KZipFile)
      r = JavaScriptPluginController::ZipFileResponse.new(body)
      r.content_type = "application/zip"
      filename = body.jsGet_filename().gsub(/[^a-zA-Z0-9\._-]/,'_')
      r.headers[KFramework::Headers::CONTENT_DISPOSITION] = %Q!attachment; filename="#{filename}"!
      exchange.response = r
      return
    end

    # Build & return response
    response = KFramework::DataResponse.new(body,
      content_type,
      (status_code || 200).to_i)
    exchange.response = response
  end

  # pre & post handle shouldn't be called.
  def pre_handle;  raise "Should never be called"; end
  def post_handle; raise "Should never be called"; end
end
