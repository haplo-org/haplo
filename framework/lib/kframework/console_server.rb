# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
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
      @server.stop_service
    end
    def description
      "Application Console"
    end
  end

  @@console = ConsoleServer.new
  register_background_task(@@console)

end

