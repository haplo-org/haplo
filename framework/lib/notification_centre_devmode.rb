# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



# Assumption:
#   Reloading will happen in one thread only.
#   Only one notification centre can be reloaded at once.

class KFramework

  class NotificationCentre

    def begin_reload
      raise "Can't reload until setup is complete" unless @done_setup
      raise "Reload in progress" if @doing_reload
      @doing_reload = true
      @done_setup = false # allow notifications to be added
      @reloading_from = Hash.new
    end

    def end_reload
      raise "No reload in progress" unless @doing_reload
      @doing_reload = false
      @done_setup = true
      @reloading_from = nil
    end

    # Log notifications
    alias :i_notify :notify
    def notify(name, detail = nil, *args)
      KApp.logger.info("NOTIFY #{name.inspect} #{detail.inspect} with #{args.length} args")
      i_notify(name, detail, *args)
    end

    # Surround definition functions with methods to check the file defining this target
    alias :i_when :when
    def when(name, detail = nil, buffer_options = nil, &block)
      _devmode_handle_file
      _checking_buffer i_when(name, detail, buffer_options, &block)
    end
    alias :i_when_each :when_each
    def when_each(notifications, buffer_options = nil, &block)
      _devmode_handle_file
      _checking_buffer i_when_each(notifications, buffer_options, &block)
    end
    alias :i_call_when :call_when
    def call_when(object, method, name, detail = nil, buffer_options = nil)
      _devmode_handle_file
      _checking_buffer i_call_when(object, method, name, detail, buffer_options)
    end

    # Determine the file which called the original method, and if reloading, wipe any targets it created before
    def _devmode_handle_file
      (caller.detect { |l| l !~ /devmode\.rb/ && l =~ /\.rb/ }) =~ /\A(.+?)\:\d/
      @@devmode_last_file = $1
      if @doing_reload
        unless @reloading_from[@@devmode_last_file]
          @reloading_from[@@devmode_last_file] = true
          # Create copies of frozen structures
          new_names = Hash.new
          @names.each { |k,v| new_names[k] = v.dup }
          new_buffers = @buffers.dup
          # Wipe all the targets for this file so they can be replaced
          new_names.each do |key, value|
            value.delete_if { |target| target.devmode_file == @@devmode_last_file}
          end
          # Remove all the buffers for this file
          new_buffers.delete_if { |buffer| buffer.devmode_file == @@devmode_last_file }
          # Replace with new structures -- but don't freeze them, none of this is really thread safe anyway
          @names = new_names
          @buffers = new_buffers
        end
      end
    end

    # Make sure buffers are annotated with the file they were created in
    def _checking_buffer(value)
      if value != nil
        value.devmode_file = @@devmode_last_file
      end
      value
    end

  private

    class Target
      alias :i_initialize :initialize
      def initialize(*args)
        i_initialize(*args)
        @devmode_file = KFramework::NotificationCentre.__send__(:class_variable_get, :@@devmode_last_file)
      end
      attr_reader :devmode_file
    end

    class Buffer
      attr_accessor :devmode_file
    end

  end

end
