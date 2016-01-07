# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module Ingredient
  module Rendering

    # Any class which includes this module must implement a render_template(data_for_template) method.

    class DoubleRenderException < StandardError
    end

    RENDER_KIND_CONTENT_TYPES = {
      :text => 'text/plain; charset=utf-8',
      :txt => 'text/plain; charset=utf-8',
      :html => 'text/html; charset=utf-8',
      :xml => 'text/xml; charset=utf-8',
      :atom => 'application/atom+xml; charset=utf-8',
      :xls => 'application/vnd.ms-excel',
      :csv => 'text/csv; charset=utf-8',
      :tsv => 'text/tab-separated-values; charset=utf-8',
      :css => 'text/css; charset=utf-8',
      :yaml => 'application/x-yaml; charset=utf-8',
      :json => 'application/json; charset=utf-8',
      :js => 'text/javascript; charset=utf-8',
      :javascript => 'text/javascript; charset=utf-8'
    }

    # Perform the render - Rails style
    def render(args = {})
      if args.has_key?(:partial)
        nm = args[:partial]
        nm = "#{render_controller_basename}/#{nm}" unless nm =~ /\//
        nm = nm.gsub(/(\w+)\z/, '_\1')  # use rails convention
        return render_template(nm, args[:data_for_template])
      end

      # Check for double render
      raise DoubleRenderException if @_render_result != nil

      # Get content type from args (maybe be nil)
      # The actual given/template content type strings are compared, not the symbols.
      content_type = (args[:content_type] || RENDER_KIND_CONTENT_TYPES[args[:kind]])
      template_content_type = nil

      output = nil
      if args.has_key? :text
        output = args[:text]
        content_type ||= RENDER_KIND_CONTENT_TYPES[:html]
      else
        template_name, layout_name = render_templates(args)
        template_content_type = RENDER_KIND_CONTENT_TYPES[render_template_kind(template_name)]
        raise "Bad template content kind for #{template_name}" if template_content_type == nil
        output = render_template(template_name, nil)
        # Render a layout?
        if layout_name != nil && args[:layout] != false
          # Check the content type of the layout matches that of the template
          if RENDER_KIND_CONTENT_TYPES[render_template_kind(template_name)] != template_content_type
            raise "Incompatible content-type for layout #{layout_name} and template #{template_name}"
          end
          @content_for_layout = output
          output = render_template(layout_name, nil)
          @content_for_layout = nil
        end

        if content_type == nil
          # No content-type given by caller, use the template's type
          content_type = template_content_type
        else
          # Check that the given content type matches the template
          unless content_type == template_content_type
            raise "Template #{template_name} ('#{content_type}') didn't match expected content type '#{template_content_type}'"
          end
        end
      end

      @_render_result = KFramework::DataResponse.new(output, content_type, args[:status])
    end

    # Redirection
    def redirect_to(url)
      raise DoubleRenderException if @_render_result != nil
      raise "redirect_to argument must be a String" unless url.kind_of?(String)
      @_render_result = KFramework::RedirectResponse.new(url)
    end

    # Clear a response
    def render_clear_response
      @_render_result = nil
    end

    # Has the render been completed?
    def render_performed?
      @_render_result != nil
    end

    # Get the result of the render
    def render_result
      @_render_result
    end

    # Send a file
    def render_send_file(pathname, options = {})
      raise DoubleRenderException if @_render_result != nil
      @_render_result = KFramework::FileResponse.new(pathname, options)
    end

    # For determinging which directory the templates live in - cached as a class variable
    def render_controller_basename
      name = self.class.instance_variable_get(:@_frm_controller_basename)
      if name == nil
        name = self.class.name.gsub('Controller','').gsub('_','/').gsub(/([a-z])([A-Z])/,'\1_\2').downcase
        self.class.instance_variable_set(:@_frm_controller_basename, name)
      end
      name
    end

    # Get the render parameters
    # Returns [template path, layout path]
    def render_templates(args)
      basename = render_controller_basename
      layout_name = (args[:layout] || render_layout)
      layout_path = (layout_name == nil) ? nil : "layouts/#{layout_name}"
      [args[:template] || "#{basename}/#{args[:action] || self.params[:action]}", layout_path]
    end

    # Name of layout - override to specify layout
    def render_layout
      nil
    end

    # Minimal Jetty continuation support
    def render_continuation_suspended
      raise DoubleRenderException if @_render_result != nil
      @_render_result = KFramework::ContinuationSuspendedResponse.new
      KApp.logger.info("REQUEST SUSPENDED")
    end

  end
end
