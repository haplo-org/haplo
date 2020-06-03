# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class Console
  extend Ingredient::Annotations
  class << self
    def _Description(desc)
      annotate_method(:description, desc)
    end
    def _Help(help)
      annotate_method(:help, help)
    end
  end

  def framework_start_time
    KFRAMEWORK__BOOT_OBJECT.get_start_time.to_i
  end

  def ping?
    :console_is_active
  end

  def all_methods
    out = Array.new
    self.class.public_instance_methods(false).each do |name|
      s = name.to_sym
      if self.class.annotation_get(s, :description) != nil
        out << s
      end
    end
    out
  end

  def call_console_method(remote_io, method_name, remote_console_client, args)
    begin
      if remote_console_client # only passed to runner by console client
        raise "Unexpected PID match" unless Process.pid != remote_console_client.test_remote_client(Dir.getwd)
        Thread.current[:_remote_console_client] = remote_console_client
      end
      $stdout.with_alternative_write_proc_in_thread(proc { |d| remote_io.write(d) }) do
        self.__send__(method_name, *args)
      end
    ensure
      Thread.current[:_remote_console_client] = nil
    end
    nil
  end

  def self.remote_console_client
    console_client = Thread.current[:_remote_console_client]
    raise "No console client connected for this thread" unless console_client
    console_client
  end

  # ---------------------------------------------------------------------------------------------------

  _Description "Get help on the commands available"
  _Help <<-__E
    Show help on a given command.
  __E
  def help(command = nil)
    if command != nil
      help = self.class.annotation_get(command.to_sym, :help)
      if help == nil
        puts "Command not known or no help available"
      else
        puts "COMMAND: #{command}\n#{help.gsub(/\A\s+/,'  ')}"
      end
    else
      puts "Type command <args> to run a command."
      puts
      puts "Commands available:"
      self.class.public_instance_methods(false).sort.each do |method|
        desc = self.class.annotation_get(method.to_sym, :description)
        if desc != nil
          puts sprintf("  %20s  %s", method, desc)
        end
      end
      puts
      puts "Type 'help :command' to get help on a command."
      puts "WARNING: help command without the : will run the command."
      nil
    end
  end

  # ---------------------------------------------------------------------------------------------------

  _Description "List all hostnames"
  _Help <<-__E
    Lists all the hostnames, along with their application ID. An application may have
    more than one hostname associated with it.

    If a Regexp is passed as an argument, only hostnames matching it are listed.
  __E
  def hostnames(regexp = nil)
    puts "  APP_ID  HOSTNAME"
    KApp.all_hostnames.each do |app_id,hostname|
      if regexp == nil || hostname =~ regexp
        puts sprintf("%8d  %s", app_id,hostname)
      end
    end
    nil
  end

  # ---------------------------------------------------------------------------------------------------

  _Description "List cache statistics for an application"
  _Help <<-__E
    Specific the application as the argument.
  __E
  def caches(app_id = nil)
    unless app_id.kind_of? Integer
      puts "Must specify an application ID"
      return
    end
    KApp.dump_cache_info_for(app_id)
    nil
  end

end
