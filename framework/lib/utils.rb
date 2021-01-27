# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



# TODO: Is this the best place for this regex?
K_EMAIL_VALIDATION_REGEX = /\A[a-zA-Z0-9!\#$%*\/?\|\^{}`~&'+=_\.-]+\@[a-zA-Z0-9-]+\.[a-zA-Z0-9\.-]+\z/

K_LINKABLE_URL_WHITELIST = /\Ahttps?:\/\//i


class KFramework
  # Copied from Rack, most deleted, choice bits retained
  # contains a grab-bag of useful methods for writing web
  # applications adopted from all kinds of Ruby libraries.

  module Utils
    # Performs URI escaping so that you can construct proper
    # query strings faster.  Use this rather than the cgi.rb
    # version since it's faster.  (Stolen from Camping).
    def escape(s)
      s.to_s.gsub(/([^ a-zA-Z0-9_.-]+)/n) {
        '%'+$1.unpack('H2'*$1.size).join('%').upcase
      }.tr(' ', '+')
    end
    module_function :escape

    # Escapes a string for URIs. (Stolen from CGI)
    def escape(string)
      string.gsub(/([^ a-zA-Z0-9_.-]+)/n) do
        '%' + $1.unpack('H2' * $1.size).join('%').upcase
      end.tr(' ', '+')
    end
    module_function :escape

    # Unescapes a URI escaped string. (Stolen from Camping).
    def unescape(s)
      s.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/n){
        [$1.delete('%')].pack('H*')
      }
    end
    module_function :unescape

    # Abbreviated day-of-week names specified by RFC 822
    RFC822_DAYS = %w[ Sun Mon Tue Wed Thu Fri Sat ]
    # Abbreviated month names specified by RFC 822
    RFC822_MONTHS = %w[ Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec ]

    # Converts a time to RFC1123.
    def rfc1123_date(time)
      t = time.clone.gmtime
      return format("%s, %.2d %s %.4d %.2d:%.2d:%.2d GMT",
          RFC822_DAYS[t.wday], t.day, RFC822_MONTHS[t.month-1], t.year,
          t.hour, t.min, t.sec)
    end
    module_function :rfc1123_date


    def parse_nested_query(qs, d = '&;')
      params = {}
      decoded = nil
      begin
        decoded = URI.decode_www_form((qs || ''), Encoding::UTF_8)
      rescue ArgumentError => e
        # Ignore incorrectly formatted application/x-www-form-urlencoded data, but log error for troubleshooting
        KApp.logger.info("Ignored incorrectly formatted query string: #{qs}")
      end
      unless decoded.nil?
        decoded.each do |k,v|
          normalize_params(params, k, v)
        end
      end
      return params
    end
    module_function :parse_nested_query

    def normalize_params(params, name, v = nil)
      name =~ %r([\[\]]*([^\[\]]+)\]*)
      k = $1 || ''
      after = $' || ''

      return if k.empty?

      if after == ""
        params[k] = v
      elsif after == "[]"
        params[k] ||= []
        raise TypeError, "expected Array (got #{params[k].class.name}) for param `#{k}'" unless params[k].is_a?(Array)
        params[k] << v
      elsif after =~ %r(^\[\]\[([^\[\]]+)\]$) || after =~ %r(^\[\](.+)$)
        child_key = $1
        params[k] ||= []
        raise TypeError, "expected Array (got #{params[k].class.name}) for param `#{k}'" unless params[k].is_a?(Array)
        if params[k].last.is_a?(Hash) && !params[k].last.key?(child_key)
          normalize_params(params[k].last, child_key, v)
        else
          params[k] << normalize_params({}, child_key, v)
        end
      else
        params[k] ||= {}
        raise TypeError, "expected Hash (got #{params[k].class.name}) for param `#{k}'" unless params[k].is_a?(Hash)
        params[k] = normalize_params(params[k], after, v)
      end

      return params
    end
    module_function :normalize_params

    def build_query(params)
      params.map { |k, v|
        if v.class == Array
          build_query(v.map { |x| [k, x] })
        else
          escape(k) + "=" + escape(v)
        end
      }.join("&")
    end
    module_function :build_query

    # Escape ampersands, brackets and quotes to their HTML/XML entities.
    def escape_html(string)
      string.to_s.gsub("&", "&amp;").
        gsub("<", "&lt;").
        gsub(">", "&gt;").
        gsub("'", "&#39;").
        gsub('"', "&quot;")
    end
    module_function :escape_html

  end
end
