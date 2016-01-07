# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module PluginDebugging
  class ErrorReporter

    SIMPLE_EXCEPTION_MAPPING_TYPES = [
      # A plugin had a dodgy plugin.json file
      KJavaScriptPlugin::PluginJSONError,
      # A plugin misused a JavaScript API (Ruby)
      JavaScriptAPIError,
      # A plugin misused a JavaScript API (Java)
      com.oneis.javascript.OAPIException,
      # A javascript exception (Syntax errors etc. see ECMA v3, section 15.11.6)
      org.mozilla.javascript.EcmaError,
      org.mozilla.javascript.EvaluatorException,
      # Object store permissions restriction
      KObjectStore::PermissionDenied,
    ]

    FIXED_EXCEPTION_MESSAGES = [
      [java.lang.NullPointerException, "Bad argument. undefined or null passed to an API function which expected a valid object."],
      [java.lang.StackOverflowError, "Stack overflow. Check for recursive calls of functions in the stack trace."],
      [SystemStackError, "Stack overflow. Check for recursive calls of functions in the stack trace."],
      [ActiveRecord::RecordNotFound, "Attempt to read something which doesn't exist."],
    ]

    def self.javascript_message_from_exception(exception)
      SIMPLE_EXCEPTION_MAPPING_TYPES.each do |exception_type|
        return exception.message if exception.is_a? exception_type
      end
      FIXED_EXCEPTION_MESSAGES.each do |exception_type, fixed_message|
        return fixed_message if exception.is_a? exception_type
      end
      if exception.is_a? org.mozilla.javascript.JavaScriptException
        if exception.message =~ /\Aorg\.mozilla\.javascript\.JavaScriptException: (.+)\s*\([^\)]+\#\d+\)\s*\z/
          return $1
        else
          return exception.details()
        end
      end
      # Ruby exception
      if exception.is_a?(Exception)
        return exception.message
      end
      # Java exception
      if exception.is_a?(java.lang.Throwable)
        return exception.getMessage()
      end
      # Couldn't decode, log then just use inspect as message
      KApp.logger.error("Unknown exception type for javascript_message_from_exception() - #{exception.inspect}")
      KApp.logger.log_exception(exception)
      return exception.inspect
    end

    def self.presentable_exception(exception)
      # Unwrap exceptions which have passed through one or more intepreters
      original_exception = exception
      if exception.kind_of?(org.mozilla.javascript.WrappedException)
        exception = exception.getWrappedException()
      end
      if exception.kind_of?(org.jruby.exceptions.RaiseException)
        exception = exception.getException()
      end

      # Decode the exception into a presentable message
      message = javascript_message_from_exception(exception)
      raise "Couldn't decode exception" if message == nil
      message = message.dup

      # Build a santized backtrace (from the wrapped exception)
      backtrace = []
      original_exception.backtrace.each do |line|
        if line =~ /\Aorg[\/\.]mozilla[\/\.]javascript[\/\.]gen[\/\.].+?\(p\/(.+?\.js)\:([0-9-]+)\)/i
          file = $1
          line = $2.to_i
          backtrace << "#{file} (line #{line})" if line > 0
        end
      end

      # In development mode, prefer the full stace trace rather than the truncated plugin version if it's not
      # completely obvious that it came from a plugin.
      if (KFRAMEWORK_ENV == 'development') && backtrace.empty?
        return nil
      end

      # Clean up filename in message?
      message.gsub!(/\(p\/([^\)]+\.js)\#([0-9-]+)\)\s*\z/i) do
        loc = "#{$1} (line #{$2})"
        backtrace.unshift loc unless backtrace.first == loc
        ''
      end
      message.gsub!(/\(lib\/javascript\/lib\/.+?\)\s*\z/i, '')

      # Remove leading and trailing whitespace from message, then return the results
      message.strip!
      [message, backtrace]
    end

    # -----------------------------------------------------------------------------------------------------

    def call(exception, format)
      message, backtrace = ErrorReporter.presentable_exception(exception)
      return nil unless message

      # Return some HTML
      # TODO: Make reported error HTML a bit more pretty
      result = if format == :html
        <<__E
<html>
<head><title>Plugin error</title></head>
<body>
  <h1>Plugin error</h1>
  <h2>#{message}</h2>
  <hr>
  <h3>Error location</h3>
  <pre>
#{backtrace.join("\n")}
  </pre>
</body>
</html>
__E
      elsif format == :text
        <<__E
#{message}

Location: #{backtrace.join("\n    ")}
__E
      else
        raise "Bad format for PluginDebugging::ErrorReporter#call"
      end
      result
    end
  end
end
