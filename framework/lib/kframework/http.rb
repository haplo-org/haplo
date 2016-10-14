# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Bits and pieces for dealing with the HTTP exchange

class KFramework

  # Represents a request and response exchange between server and client
  class Exchange
    attr_accessor :application_id, :request, :params, :annotations
    attr_reader :response
    def initialize(application_id, request)
      @application_id = application_id
      @request = request
      @params = {}
      @annotations = {}
      # Create a null response to collect headers, cookies, etc, and set the default headers
      @response = NullResponse.new
      @response.headers[Headers::CACHE_CONTROL] = Headers::V_DEFAULT_CACHE_CONTROL
    end
    def has_response?
      @response != nil && !(@response.kind_of? NullResponse)
    end
    def response=(r)
      # Merge in relevant headers etc from the old response into the new one
      r.merge_headers!(@response)
      @response = r
    end
  end

  # -------------------------------------------------------------------------------------------------------------------------

  # Store of headers, which can hold multiple values for each header
  class Headers
    CONTENT_TYPE = 'Content-Type'
    COOKIE = 'Cookie'
    SET_COOKIE = 'Set-Cookie'
    EXPIRES = 'Expires'
    CACHE_CONTROL = 'Cache-Control'
    V_DEFAULT_CACHE_CONTROL = 'private, no-cache'
    USER_AGENT = 'User-Agent'
    HOST = 'Host'
    LOCATION = 'Location'
    CONTENT_DISPOSITION = 'Content-Disposition'
    IF_NONE_MATCH = 'If-None-Match'
    IF_MODIFIED_SINCE = 'If-Modified-Since'
    AUTHORIZATION = 'Authorization'

    def initialize
      @headers = Hash.new
    end

    # Set a header, overwriting old value
    def []=(k, v)
      @headers[k] = [v]
    end

    # Add a header
    def add(k, v)
      @headers[k] ||= []
      @headers[k] << v
    end

    # Only returns the last header
    def [](k)
      e = @headers[k]
      (e == nil) ? nil : e.last
    end

    # Get all the headers for a given key
    def values(k)
      @headers[k] || []
    end

    def has_header?(k)
      @headers.has_key?(k) && !(@headers[k].empty?)
    end

    # Iterate over headers
    def each(k = nil)
      if k != nil
        e = @headers[k]
        e.each { |v| yield k,v } if e != nil
      else
        @headers.each do |k,e|
          e.each { |v| yield k,v }
        end
      end
    end

    # Merge in headers
    def merge!(other)
      other.each do |k,e|
        t = self[k]
        self[k] = ((t == nil) ? e : e + t)
      end
    end

    # All the headers - mainly for the JavaScript API
    def all_headers
      @headers
    end
  end

  # -------------------------------------------------------------------------------------------------------------------------

  # Generic request methods
  module RequestMixin

    METHOD_POST = 'POST'
    def post?
      self.method == METHOD_POST
    end

    def cookies
      @cookies ||= begin
        c = Hash.new
        h = self.headers[Headers::COOKIE]
        if h != nil
          Cookie::parse(h).each do |name,cookie|
            c[name] = cookie.value.first || ''
          end
        end
        c
      end
    end

    def host
      # Host header without the port
      (self.headers[Headers::HOST] || '').split(':').first
    end

    def user_agent
      self.headers[Headers::USER_AGENT] || ''
    end
  end

end
