# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



# Implements the application server side of script/runner

# NOTE: boot.rb defines KFRAMEWORK_RUNNER_BINDING so that the code can be run in the context of main, giving the expected results.

class KFramework

  def self.run_arbitary_code(what)
    success = false
    begin
      KApp.logger.info("Running code from console\n----\n#{what}\n----")
      if File.exist?(what)
        eval("begin\n#{File.open(what) { |f| f.read }}\nend", KFRAMEWORK_RUNNER_BINDING, what, -1)
      else
        eval("begin\n#{what}\nend", KFRAMEWORK_RUNNER_BINDING, 'runner_eval', -1)
      end
      success = true
    rescue => e
      KApp.logger.log_exception(e)
      puts "EXCEPTION IN RUNNER: #{e.inspect} (see server logs for more details)"
      raise
    ensure
      KApp.logger.flush_buffered
    end
    success
  end

end

class Console
  # runner() isn't declared as a command, because it's intended for use with the script/runner script
  def runner(code)
    KFramework.run_arbitary_code(code)
  end
end
