# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
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

  def call_console_method(remote_io, method_name, args)
    $stdout.with_alternative_write_proc_in_thread(proc { |d| remote_io.write(d) }) do
      self.__send__(method_name, *args)
    end
    nil
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
      puts "Commands available:\n"
      self.class.public_instance_methods(false).sort.each do |method|
        desc = self.class.annotation_get(method.to_sym, :description)
        if desc != nil
          puts sprintf("  %20s  %s\n", method, desc)
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

  _Description "Show database connections"
  _Help <<-__E
    List the current database connection, with some diagnostic information.
    Note that this is not a consistent snapshot, so errors shown might be due
    to changes during the time the checks are running.
  __E
  def db_conns
    ActiveRecord::Base.connection_pool.dump_info
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
