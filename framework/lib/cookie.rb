# frozen_string_literal: true

# Modified implementation of CGI::Cookie to support HttpOnly

class KFramework

  # Class representing an HTTP cookie.
  #
  # In addition to its specific fields and methods, a Cookie instance
  # is a delegator to the array of its values.
  #
  # See RFC 2965.
  #
  # == Examples of use
  #   cookie1 = CGI::Cookie::new("name", "value1", "value2", ...)
  #   cookie1 = CGI::Cookie::new("name" => "name", "value" => "value")
  #   cookie1 = CGI::Cookie::new('name'    => 'name',
  #                              'value'   => ['value1', 'value2', ...],
  #                              'path'    => 'path',   # optional
  #                              'domain'  => 'domain', # optional
  #                              'expires' => Time.now, # optional
  #                              'secure'  => true      # optional
  #                              'http_only' => true      # optional
  #                             )
  #
  #   cgi.out("cookie" => [cookie1, cookie2]) { "string" }
  #
  #   name    = cookie1.name
  #   values  = cookie1.value
  #   path    = cookie1.path
  #   domain  = cookie1.domain
  #   expires = cookie1.expires
  #   secure  = cookie1.secure
  #
  #   cookie1.name    = 'name'
  #   cookie1.value   = ['value1', 'value2', ...]
  #   cookie1.path    = 'path'
  #   cookie1.domain  = 'domain'
  #   cookie1.expires = Time.now + 30
  #   cookie1.secure  = true
  class Cookie

    # Create a new CGI::Cookie object.
    #
    # The contents of the cookie can be specified as a +name+ and one
    # or more +value+ arguments.  Alternatively, the contents can
    # be specified as a single hash argument.  The possible keywords of
    # this hash are as follows:
    #
    # name:: the name of the cookie.  Required.
    # value:: the cookie's value or list of values.
    # path:: the path for which this cookie applies.  Defaults to the
    #        base directory of the CGI script.
    # domain:: the domain for which this cookie applies.
    # expires:: the time at which this cookie expires, as a +Time+ object.
    # secure:: whether this cookie is a secure cookie or not (default to
    #          false).  Secure cookies are only transmitted to HTTPS
    #          servers.
    #
    # These keywords correspond to attributes of the cookie object.
    def initialize(name = "", *value)
      options = if name.kind_of?(String)
                  { "name" => name, "value" => value }
                else
                  name
                end
      unless options.has_key?("name")
        raise ArgumentError, "`name' required"
      end

      @name = options["name"]
      @value = Array(options["value"])
      # simple support for IE
      if options["path"]
        @path = options["path"]
      else
        %r|^(.*/)|.match(ENV["SCRIPT_NAME"])
        @path = ($1 or "")
      end
      @domain = options["domain"]
      @expires = options["expires"]
      @secure = options["secure"] == true ? true : false
      @http_only = options["http_only"] == true ? true : false
    end

    attr_accessor("name", "value", "path", "domain", "expires")
    attr_reader("secure", "http_only")

    # Set whether the Cookie is a secure cookie or not.
    #
    # +val+ must be a boolean.
    def secure=(val)
      @secure = val if val == true or val == false
      @secure
    end

    # Set whether the Cookie is an HTTP only cookie or not.
    #
    # +val+ must be a boolean.
    def http_only=(val)
      @http_only = val if val == true or val == false
      @http_only
    end

    # Convert the Cookie to its string representation.
    def to_s
      buf = ""
      buf += @name + '='

      if @value.kind_of?(String)
        buf += Utils::escape(@value)
      else
        buf += @value.collect{|v| Utils::escape(v) }.join("&")
      end

      if @domain
        buf += '; domain=' + @domain
      end

      if @path
        buf += '; path=' + @path
      end

      if @expires
        buf += '; expires=' + Utils::rfc1123_date(@expires)
      end

      if @http_only
        buf << '; HttpOnly'
      end

      if @secure == true
        buf += '; secure'
      end

      buf
    end

  end # class Cookie


  # Parse a raw cookie string into a hash of cookie-name=>Cookie
  # pairs.
  #
  #   cookies = CGI::Cookie::parse("raw_cookie_string")
  #     # { "name1" => cookie1, "name2" => cookie2, ... }
  #
  def Cookie::parse(raw_cookie)
    cookies = Hash.new([])
    return cookies unless raw_cookie

    raw_cookie.split(/[;,]\s?/).each do |pairs|
      name, values = pairs.split('=',2)
      next unless name and values
      name = Utils::unescape(name)
      values ||= ""
      values = values.split('&').collect{|v| Utils::unescape(v) }
      if cookies.has_key?(name)
        values = cookies[name].value + values
      end
      cookies[name] = Cookie::new({ "name" => name, "value" => values })
    end

    cookies
  end

end
