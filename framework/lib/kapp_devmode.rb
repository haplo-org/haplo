# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



# Additional behaviours for KApp in development mode
if KFRAMEWORK_ENV == 'development'

  module KApp
    # Output logs to the console
    class BufferingLogger
      alias original_flush_buffered flush_buffered
      def flush_buffered
        buffer = Thread.current[:_frm_logger_buffer]
        STDOUT.puts buffer if buffer != nil
        original_flush_buffered
      end
    end
  end
end

