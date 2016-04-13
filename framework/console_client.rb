#!/usr/bin/env jruby

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


CONSOLE_URI = "druby://localhost:7777"

require 'drb'
require 'irb'

# Default options
is_runner = (ARGV.length >= 1 && ARGV[0] == 'runner')
ARGV.shift if is_runner # remove first argument
console_command = nil
console_args = nil

# Choose some options, depending on the invoked name
if is_runner
  if ARGV.length != 1
    puts "runner must have exactly one argument: code or script filename to run"
    exit 1
  end
  console_command = :runner
  console_args = [ARGV[0]]
end

# Start a local server for callbacks on a random port on the loopback address.
# This allows writes to $stdout in the server to appear on the console $stdout.
DRb.start_service('druby://localhost:0')

# Get a working connection to the console
console_ok = true
# Connect to console
$console = DRbObject.new_with_uri(CONSOLE_URI)
# Check the console is working
console_ok = true
begin
  if $console.ping? != :console_is_active
    console_ok = false
  end
rescue => e
  console_ok = false
end
unless console_ok
  puts "Could not connect to console"
  if is_runner
    # Use the script/server command instead
    puts "**** Running server not available; cannot execute command ****"
  end
  exit 1
end

# Define an easy method for getting the console object in irb
def c
  $console
end

# Define methods for the console commands
$console.all_methods.each do |name|
  eval <<-__E
    def #{name}(*args)
      $console.call_console_method($stdout, :#{name}, args)
    end
  __E
end

# Objects passed to main process for the runner command
class ConsoleClient
  include DRb::DRbUndumped # prevent marshalling so methods are run in this process
  def test_remote_client(wd)
    raise "Unexpected working directory" unless wd == Dir.getwd
    Process.pid
  end
  # Allow main server process to run system(), without having to fork itself.
  # Forking main server process requires lots of memory, compared to forking this console client.
  def remote_system(*args)
    puts "Running #{args.inspect}"
    system(*args)
  end
end

# Run a command, or start an interactive console?
if console_command == nil
  puts "\n**** Started Haplo console ****\n\nType help for help.\n\n"
  IRB.start
else
  if console_command == :runner
    $console.call_console_method($stdout, :runner, [ConsoleClient.new, *console_args])
  else
    raise "Unsupported command"
  end
end

