# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class KFramework

  CONSOLE_URI = "druby://localhost:7777"

  class ConsoleServer < BackgroundTask
    def start
      begin
        @console = Console.new
        @server = DRb::DRbServer.new(KFramework::CONSOLE_URI, @console)
        @server.thread.join
      rescue IOError => e
        # Ignore IO exceptions, thrown when stop_service is called from another thread
      end
    end
    def stop
      # Calling @server.stop_service makes assumptions about which thread it's called from
      # and tries to join the server thread itself. Use a hack to to be compatible with
      # background tasks.
      @server.instance_variable_get(:@protocol).shutdown
    end
    def description
      "Application Console"
    end
  end

  @@console = ConsoleServer.new
  register_background_task(@@console)

end

