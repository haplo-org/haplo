# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavaScriptPluginController < ApplicationController
  policies_required nil

  def initialize(factory)
    @factory = factory
  end

  KBinaryData = Java::OrgHaploJsinterface::KBinaryData
  KStoredFile = Java::OrgHaploJsinterface::KStoredFile

  CONTENT_TYPES = Hash.new
  Ingredient::Rendering::RENDER_KIND_CONTENT_TYPES.each_key { |k| CONTENT_TYPES[k.to_s] = k}

  ALLOWED_LAYOUTS = {"std:standard" => true, "std:wide" => true, "std:minimal" => true}

  # -----------------------------------------------------------------------------------------------------------

  # Don't want the action and id params polluting the params sent to the JavaScript request handlers
  def use_rails_compatible_action_and_id_params?
    false
  end

  def perform_handle(exchange, path_elements, requested_method)
    # Unless anonymous requests are allowed, check the user is not anonymous
    unless @factory.allow_anonymous
      permission_denied unless @request_user.policy.is_not_anonymous?
    end
    # Handle any request by the framework for file upload instructions
    uploads = exchange.annotations[:uploads]
    if nil != uploads && uploads.getInstructionsRequired()
      # Request for file upload instructions
      inst = KJSPluginRuntime.current.get_file_upload_instructions(@factory.plugin_name, exchange.request.path)
      if inst == nil
        raise JavaScriptAPIError, "File upload received, but no arguments for the handler function are files."
      end
      inst.split(',').each do |name|
        raise JavaScriptAPIError, "Bad file argument name" unless name =~ /\A[a-zA-Z0-9_-]+\z/ # duplicates test in untrusted JS code
        uploads.addFileInstruction(name, FILE_UPLOADS_TEMPORARY_DIR, StoredFile::FILE_DIGEST_ALGORITHM, nil)
      end
      render :text => ''
      return
    end
    # Call the plugin
    r = KJSPluginRuntime.current.call_request_handler(@factory.plugin_name, exchange.request.method, exchange.request.path)
    if r == nil
      raise KFramework::RequestPathNotFound.new("Plugin #{@factory.plugin_name} didn't handle request")
    end
    # Split out the array returned by the plugin handler
    status_code, headersJSON, body, kind, layout_name, page_title, staticResourcesJSON, back_link, back_link_text = r.to_a
    if body == nil
      raise KFramework::RequestPathNotFound.new("Plugin #{@factory.plugin_name} returned a null response body")
    end
    # Send headers (decoding them from the JSON value)
    if headersJSON != nil
      headers = JSON.parse(headersJSON)
      headers.each do |name, value|
        response.headers[name] = value
      end
    end
    # If E.response.body was set to a stored or generated file, respond without any further response processing.
    return respond_with_binary_data(body) if body.kind_of?(KBinaryData)
    return respond_with_stored_file(body) if body.kind_of?(KStoredFile)
    # Handle response
    render_opts = Hash.new
    render_opts[:status] = status_code if status_code != nil
    if layout_name == nil
      render_opts[:text] = body
      if kind != nil && CONTENT_TYPES.has_key?(kind)
        render_opts[:kind] = CONTENT_TYPES[kind]
      end
    else
      raise JavaScriptAPIError, "Unknown standard layout '#{layout_name}'" unless ALLOWED_LAYOUTS.has_key?(layout_name)
      @minimal_layout_no_cancel = true  # always use this option on the minimal layout
      @page_title = h(page_title) if page_title != nil  # @page_title is NOT escaped by the layout, so must be escaped here
      if back_link != nil && back_link_text != nil
        raise "Bad back link" if back_link =~ /[<>]/    # don't want to get into escaping issues
        @breadcrumbs = [[back_link, back_link_text]]    # NOTE: back_link_text will be escaped by the layout (checked in tests)
      end
      if staticResourcesJSON != nil
        plugin = KPlugin.get(@factory.plugin_name)
        JSON.parse(staticResourcesJSON).each do |resourceName|
          # TODO: Check static resource exists when requested by a plugin
          kind = (resourceName =~ /\.js\z/i) ? :javascript : :css
          client_side_plugin_resource(plugin, kind, resourceName)
        end
      end
      @content_for_layout = body
      raise "Logic error" unless layout_name =~ /\Astd:(.+)\z/
      ruby_layout_name = $1
      if ruby_layout_name == "wide"
        # Use standard layout with extra class to trigger wide size of main element
        ruby_layout_name = "standard"
        @standard_layout_page_element_classes = 'z__page_wide_layout'
      end
      render_opts[:text] = render_template("layouts/#{ruby_layout_name}", nil)
      @content_for_layout = nil
      render_opts[:kind] = :html
    end
    render(render_opts)
  end

  # -----------------------------------------------------------------------------------------------------------

  # Special response which sends files generated by the JavaScript side
  class BinaryDataResponse < KFramework::Response
    def initialize(binary_data)
      super()
      @binary_data = binary_data
    end
    def make_java_object
      Java::OrgHaploAppserver::DataResponse.new(@binary_data.getInMemoryByteArrayForResponse())
    end
  end

  def respond_with_binary_data(binary_data)
    # TODO: Implement a mechanism to allow attachment disposition to be turned off
    if binary_data.isAvailableInMemoryForResponse()
      r = BinaryDataResponse.new(binary_data)
      r.content_type = binary_data.jsGet_mimeType()
      filename = binary_data.jsGet_filename()
      unless filename == nil or filename == ""
        filename = filename.gsub(/[^a-zA-Z0-9\._-]/,'_')
        r.headers[KFramework::Headers::CONTENT_DISPOSITION] = %Q!attachment; filename="#{filename}"!
      end
      exchange.response = r
    else
      disk_pathname = binary_data.getDiskPathnameForResponse()
      raise JavaScriptAPIError, "File not available" unless disk_pathname && File.exist?(disk_pathname)
      render_send_file disk_pathname,
        :type => binary_data.jsGet_mimeType() || 'application/octet-stream',
        :filename => binary_data.jsGet_filename() || 'data.bin',
        :disposition => 'attachment'
    end
    true
  end

  def respond_with_stored_file(java_stored_file)
    stored_file = java_stored_file.toRubyObject()
    raise "Didn't have expected Ruby stored file object" unless stored_file
    render_send_file stored_file.disk_pathname, :type => stored_file.mime_type,
      :filename => stored_file.upload_filename,
      :disposition => 'attachment'
  end

end
