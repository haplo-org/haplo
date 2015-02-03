# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# This has been written with the possibility of optimising delivery by generating a method which
# calls the objects from the Targets directly. The objects themselves would be stored as member
# variables in the NotificationCentre object.

class KFramework

  class NotificationCentre

    def initialize
      @names = Hash.new # must not have block
      @buffers = Array.new
      @done_setup = false
    end

    # buffer_options argument is an optional hash, which if given, creates a buffer for the
    # notification handler. If a buffer is created, it is returned from the method.
    # The hash contains options:
    #   :start_buffering - if true, the buffer should start buffering without an explicit start
    #   :deduplicate - if true, deduplicate notifications while buffering.
    #   :max_arguments - use to truncate the arguments to the block or method. Useful comhined with deduplication.

    # Request that the block is called to receive the matching notification. The arguments are
    #    name, detail, *arguments
    # where arguments are the arguments from the notify() call.
    def when(name, detail = nil, buffer_options = nil, &block)
      raise "NotificationCentre has already been set up" if @done_setup
      if buffer_options
        buffer = Buffer.new(block, :call, buffer_options)
        @buffers << buffer
        _add_target Target.new(name, detail, buffer, :call)
        buffer
      else
        _add_target Target.new(name, detail, block, :call)
        nil
      end
    end

    # Request that the block is called to receive each of the matching notifications, arguments as when()
    # notifications is array of [name, detail]
    def when_each(notifications, buffer_options = nil, &block)
      raise "NotificationCentre has already been set up" if @done_setup
      notifications.each { |e| raise "Must be array of arrays" unless e.kind_of?(Array) }
      buffer = nil
      object = block
      if buffer_options
        buffer = Buffer.new(block, :call, buffer_options)
        @buffers << buffer
        object = buffer
      end
      notifications.each do |name, detail|
        _add_target Target.new(name, detail, object, :call)
      end
      buffer # may be nil
    end

    # Request that the method is called on the object to receive the matching notification, arguments as when()
    def call_when(object, method, name, detail = nil, buffer_options = nil)
      raise "NotificationCentre has already been set up" if @done_setup
      if buffer_options
        buffer = Buffer.new(object, method, buffer_options)
        @buffers << buffer
        _add_target Target.new(name, detail, buffer, :call)
        buffer
      else
        _add_target Target.new(name, detail, object, method)
        nil
      end
    end

    # Finish setting up the NotificationCentre, so it can be used for sending notifications
    def finish_setup
      raise "Already set up NotificationCentre" if @done_setup
      @names.each_value { |l| l.freeze }
      @names.freeze
      @buffers.freeze
      @done_setup = true
    end

    # Initialise the NotificationCentre for use on this thread.
    def start_on_thread
      raise "NotificationCentre hasn't been set up" unless @done_setup
    end

    # Send a notification to the registered targets.
    # The args are passed as parameters to the target blocks or methods.
    def notify(name, detail = nil, *args)
      targets = @names[name]
      return unless targets
      targets.each do |target|
        if target.detail == nil || target.detail == detail
          target.call(name, detail, args)
        end
      end
    end

    # Call when the block of operations are complete. Sends all buffered notifiations.
    def send_buffered_then_end_on_thread
      @buffers.each { |buffer| buffer.finish_on_thread }
    end

    # Dump out the targets for debugging
    def dump
      puts "NotificationCentre id#{self.object_id}"
      puts
      @names.each do |key, targets|
        puts "#{key.inspect} (#{targets.length} targets)"
        targets.each do |target|
          puts "  #{target.dump_info}"
        end
        puts
      end
    end

  private

    class Target < Struct.new(:name, :detail, :object, :method)
      def call(name, detail, args)
        object.__send__(self.method, name, detail, *args)
      end
      def dump_info
        "#{self.name.inspect} #{self.detail.inspect} -> #{_obj_to_dump_info(self.object, self.method)}"
      end
    private
      def _obj_to_dump_info(object, method)
        if object.kind_of?(Class)
          "#{object.name}.#{method}"
        elsif object.kind_of?(Proc) && method == :call
          object.to_s
        elsif object.kind_of?(Buffer)
          "buffer:#{object.dump_options} -> #{_obj_to_dump_info(object.object, object.method)}"
        else
          "#{object.class.name}/id#{object.object_id} #{method.inspect}"
        end
      end
    end

    def _add_target(target)
      # While it might be tempting to just use a block on the Hash.new to simply this, it makes it too easy to be mutated,
      # the code needs to be thread safe.
      (@names[target.name] ||= []) << target
    end

    class Buffer
      attr_reader :object
      attr_reader :method
      def initialize(object, method, buffer_options)
        @object = object
        @method = method
        @start_buffering = !!(buffer_options[:start_buffering])
        @deduplicate = !!(buffer_options[:deduplicate])
        @max_arguments = buffer_options[:max_arguments] if buffer_options[:max_arguments].kind_of?(Integer)
        @thread_key = "__notification_centre_buffer_#{self.__id__}".to_sym
      end

      def dump_options
        opts = ""
        opts << 'S' if @start_buffering
        opts << 'D' if @deduplicate
        opts << @max_arguments.to_s if @max_arguments != nil
        opts
      end

      def call(*args)
        # Reduce the number of arguments?
        if @max_arguments != nil && args.length > @max_arguments
          args = args.slice(0, @max_arguments)
        end
        # Currently buffering?
        info = _get_or_create_info()
        if info.buffering?
          unless @deduplicate && info.buffered.include?(args)
            info.buffered << args
          end
        else
          @object.__send__(@method, *args)
        end
        nil
      end

      # Increment the buffering use count by 1, beginning buffering if it wasn't before.
      def begin_buffering
        info = _get_or_create_info()
        info.buffer_count += 1
        nil
      end

      # Decrement the buffering use count by 1, ending buffering and sending buffered nofications
      # if it reaches zero.
      def end_buffering
        info = _get_or_create_info()
        raise "end_buffering called too many times on notification buffer" if info.buffer_count <= 0
        info.buffer_count -= 1
        send_buffered if info.buffer_count == 0
        nil
      end

      # Yield to the given block surrounded by begin_buffering and end_buffering.
      def while_buffering
        begin_buffering
        v = nil
        begin
          v = yield
        ensure
          end_buffering
        end
        v
      end

      def buffering_depth
        _get_or_create_info().buffer_count
      end

      # Send all the buffered notifications without changing the use count.
      def send_buffered
        info = Thread.current[@thread_key]
        if info
          info.buffered.each do |args|
            @object.__send__(@method, args)
          end
          info.buffered.clear
        end
        nil
      end

      # Internal call for the notification centre to send all remaining buffered notifications.
      def finish_on_thread
        send_buffered
        Thread.current[@thread_key] = nil
      end

    private

      def _get_or_create_info
        Thread.current[@thread_key] ||= ThreadInfo.new(@start_buffering ? 1 : 0)
      end

      class ThreadInfo
        attr_accessor :buffer_count
        attr_accessor :buffered
        def initialize(buffer_count)
          @buffer_count = buffer_count
          @buffered = Array.new
        end
        def buffering?
          @buffer_count > 0
        end
      end
    end

  end

end
