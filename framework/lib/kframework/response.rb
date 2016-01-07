# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KFramework

  # Base of the response objects
  class Response
    attr_accessor :headers

    def initialize
      @headers = Headers.new
    end

    # Helper function for useful things
    def content_type=(mime_type)
      @headers[Headers::CONTENT_TYPE] = mime_type
    end

    def merge_headers!(other_response)
      @headers.merge!(other_response.headers)
      self.cookies.merge!(other_response.cookies) if other_response.has_cookies?
    end

    def has_cookies?
      @cookies != nil
    end
    def cookies
      @cookies ||= Hash.new
    end
    def set_cookie(name, value = nil)
      self.cookies[name] = Cookie.new(name, value)
    end

    def set_cookie_headers
      if has_cookies?
        @cookies.each do |name,cookie|
          @headers.add(Headers::SET_COOKIE, cookie.to_s)
        end
        # Clear the cookies so they won't be applied again
        @cookies = nil
      end
    end

    # Java object
    def to_java_object
      # Turn the cookies into headers
      set_cookie_headers
      # Get the subclass to create the java object
      java_obj = make_java_object
      # Apply headers and return
      java_apply_headers_to(java_obj)
      java_obj
    end

    def make_java_object
      raise "Can't use KFramework::Response base class"
    end

  protected
    def java_apply_headers_to(java_obj)
      @headers.each { |k,v| java_obj.addHeader(k,v) }
    end
  end

  # -------------------------------------------------------------------------------------------------------------------------

  # Used for collecting stuff like headers and cookies before the real response is set
  class NullResponse < Response
  end

  # -------------------------------------------------------------------------------------------------------------------------

  # Data response
  class DataResponse < Response
    def initialize(body, content_type = nil, response_code = nil)
      super()
      self.content_type = content_type if content_type != nil
      @response_code = (response_code || 200)
      @body = body
    end

    def make_java_object
      Java::ComOneisAppserver::DataResponse.new(@body.to_java_bytes, @response_code)
    end
  end

  # -------------------------------------------------------------------------------------------------------------------------

  # Redirect response
  class RedirectResponse < Response
    def initialize(url)
      super()
      @url = url
    end

    def make_java_object
      headers[Headers::LOCATION] = @url
      headers[Headers::CONTENT_TYPE] = 'text/html; charset=utf-8'
      body = %Q!<html><body><p><a href="#{@url}">Redirect</a></p></body></html>!
      Java::ComOneisAppserver::DataResponse.new(body.to_java_bytes, 302) # use temporary redirect
    end
  end

  # -------------------------------------------------------------------------------------------------------------------------

  # File response
  class FileResponse < Response
    #
    # Options: (all optional)
    #   :filename => Name of file
    #   :disposition => :attachment, :inline, 'attachment', 'inline'
    #   :type => MIME type of file
    #
    def initialize(pathname, options)
      super()
      @pathname = pathname
      @options = options
    end

    def make_java_object
      disposition = (@options[:disposition] || :inline).to_s
      if @options.has_key?(:filename)
        disposition = %Q!#{disposition}; filename="#{@options[:filename]}"!
      end
      headers[Headers::CONTENT_DISPOSITION] = disposition
      headers[Headers::CONTENT_TYPE] = @options[:type] || 'application/octet-stream'
      Java::ComOneisAppserver::FileResponse.new(@pathname)
    end
  end

  # -------------------------------------------------------------------------------------------------------------------------

  # Jetty continuation support response
  class ContinuationSuspendedResponse < Response
    def make_java_object
      Java::ComOneisAppserver::ContinuationSuspendedResponse.new
    end
  end

end
