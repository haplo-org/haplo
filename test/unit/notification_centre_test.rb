# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Load devmode version of notification centre, renamed for separate testing.
['framework/lib/notification_centre.rb','framework/lib/notification_centre_devmode.rb'].each do |filename|
  eval(File.open(filename) { |f| f.read } .gsub('NotificationCentre', 'NotificationCentreDevMode'))
end


class NotificationCentreTest < Test::Unit::TestCase

  def test_api_checks
    centre = KFramework::NotificationCentre.new
    centre.when(:x3) { }
    buffer1 = centre.when(:x10, nil, {:start_buffering => true}) { }
    centre.finish_setup
    assert_raises(RuntimeError) { centre.when_each([]) { } }
    assert_raises(RuntimeError) { centre.when(:x9) { } } # can't set up new targets after finishing setup
    centre.start_on_thread
    assert_equal 1, buffer1.buffering_depth
    # Can send notification with existing target, and one which has hasn't been set up
    centre.notify(:x10, :hello)
    centre.notify(:unknown_target, :world)
    # End buffering must be matched by begins
    buffer1.end_buffering # use count was 1, now 0
    assert_equal 0, buffer1.buffering_depth
    assert_raises(RuntimeError) { buffer1.end_buffering }
    centre.send_buffered_then_end_on_thread
    # Calling it again has no effect
    centre.send_buffered_then_end_on_thread

    # Check devmode extras haven't been applied
    assert ! centre.respond_to?(:begin_reload)
  end

  BASICS_TEST_RUNS = 100
  BASICS_THREADS = 3

  def test_notification_basics
    centre = KFramework::NotificationCentre.new

    barrier1 = java.util.concurrent.CyclicBarrier.new(BASICS_THREADS + 1)
    barrier2 = java.util.concurrent.CyclicBarrier.new(BASICS_THREADS + 1)
    setup_mutex = Mutex.new

    # Create testers and run them on threads, which set up the various notifications
    testers = []
    0.upto(BASICS_THREADS - 1) { |index| testers << NotificationTester.new(centre, index, barrier1, barrier2, setup_mutex) }
    threads = testers.map do |tester|
      Thread.new do
        begin
          tester.run_tests
        rescue => e
          puts "\nEXCEPTION IN NOTIFICATION CENTRE TEST\n#{e.inspect}\n#{e.backtrace.join("\n")}"
        end
      end
    end

    # Wait for the barrier for the threads to set up their interesting notifications
    barrier1.await

    # Set up a global notification receiver, which tells the active tester
    centre.when(:global) do |name, detail, x|
      Thread.current[:__nc_tester].global_notify(detail, x)
    end
    # And a buffered version to make sure that buffers are thread safe
    centre.when(:global, nil, {:start_buffering => true}) do |name, detail, x|
      Thread.current[:__nc_tester].global_notify(detail, x)
    end

    # Finish the setup, which can only be done in one thread
    centre.finish_setup

    # Set the tests going in their threads
    barrier2.await

    # Wait for the threads, and check the results
    threads.each { |thread| thread.join }
    testers.each do |tester|
      assert_equal BASICS_TEST_RUNS, tester.successful_runs
    end

  end

  class NotificationTester
    def initialize(centre, index, barrier1, barrier2, setup_mutex)
      @index = index
      @centre = centre
      @barrier1 = barrier1
      @barrier2 = barrier2
      @setup_mutex = setup_mutex
      @successful_runs = 0
    end
    attr_reader :successful_runs
    def run_tests
      # Do the setup (but only one thread at a time)
      @setup_mutex.synchronize do

        # NOTE: All the targets set up here must use tsym() for at least one of name or details.
        # Otherwise they'll be called from different threads.
        # There's a global notification handler set up to make sure that notifications are delievered
        # to the right place.
        @centre.when(:carrots, tsym(:hello)) do |name, detail, value|
          @results << [1, name, detail, value]
        end
        @buffer1 = @centre.when(:carrots, tsym(:hello), {:start_buffering => true, :deduplicate => true}) do |name, detail, value|
          @results << [2, name, detail, value]
        end
        raise "No buffer returned" unless @buffer1 != nil
        @centre.call_when(self, :lovely_notify, tsym(:thingy))
        @centre.call_when(self, :lovely_notify, tsym(:thingy2), nil, {:max_arguments => 2}) # and with a buffer
        @centre.when_each([
          [:ping, tsym(:pong)],
          [tsym(:something)]
        ]) do |name, detail, value1, value2|
          @results << [4, name, detail, value1, value2]
        end
        @buffer2 = @centre.when(:carrots, tsym(:hello2),
            {:start_buffering => true, :deduplicate => true}) do |name, detail, value|
          @results << [5, name, detail, value]
        end
        @buffer3 = @centre.when_each([[:ping, tsym(:pong)]], {:start_buffering => true}) do |name, detail, value1, value2|
          @results << [6, name, detail, value1, value2]
        end
        @centre.when(tsym(:truncate), nil, {:max_arguments => 1}) { |*args| @results << [10, args] }
        @buffer4 = @centre.when(tsym(:buffering), nil, {:deduplicate => true}) { |name, detail, value| @results << [11, value] }

      end

      # Wait for the barriers
      @barrier1.await
      @barrier2.await
      Thread.current[:__nc_tester] = self

      # Expected results
      expected = [
        [0, :global, :ping1, self.object_id],
        [1, :carrots, tsym(:hello), "Fish"],
        [1, :carrots, tsym(:hello), "Fish2"],
        [1, :carrots, tsym(:hello), "Fish"], # sent twice
        :check2,
        [2, :carrots, tsym(:hello), "Fish"], # but the buffered version is deduplicated
        [2, :carrots, tsym(:hello), "Fish2"],
        :check2b,
        [5, :carrots, tsym(:hello2), "Fish3"],
        [3, tsym(:thingy), nil],
        [3, tsym(:thingy2), :hello],
        [4, tsym(:something), :else, 3, 9],
        [4, tsym(:something), nil, 88, 12],
        [4, :ping, tsym(:pong), 2, 1],
        [4, :ping, tsym(:pong), 2, 2],
        [10, [tsym(:truncate)]], # only one argument
        :buffering_checking,
        [11, "Hello2"],
        :buffering_checking2,
        [11, "Hello3"],
        :buffering_checking3,
        :buffering_checking4,
        [11, "Hello4"], # deduplicated
        :buffering_checking5,
        [11, "Hello5"],
        :buffering_checking6,
        :buffering_checking7,
        [11, "Hello6"],
        [11, "Hello7"],
        :finish,
        [6, :ping, tsym(:pong), 2, 1], # uses a buffer which is never explicitly sent and doesn't deduplicate
        [6, :ping, tsym(:pong), 2, 2],
        [0, :global, :ping1, self.object_id] # the buffered notification from the beginning to test buffer thread safety
      ]

      # Do the test runs
      BASICS_TEST_RUNS.times do
        @results = []
        @centre.start_on_thread

        @centre.notify(:global, :ping1, self.object_id)
        @centre.notify(:carrots, tsym(:hello), "Fish")
        @centre.notify(:carrots, tsym(:hello), "Fish2")
        @centre.notify(:carrots, tsym(:hello), "Fish")
        @centre.notify(:carrots, tsym(:hello2), "Fish3")
        @results << :check2
        @buffer1.send_buffered
        @results << :check2b
        @buffer2.send_buffered
        @centre.notify(tsym(:thingy))
        @centre.notify(tsym(:thingy2), :hello, "X") # argument removed
        @centre.notify(tsym(:something), :else, 3, 9)
        @centre.notify(tsym(:something), nil, 88, 12)
        @centre.notify(:ping, tsym(:pong), 2, 1)
        @centre.notify(:ping, tsym(:pong), 2, 2)
        @centre.notify(tsym(:truncate), :subthingy, 1, 45, 23, 9)
        @results << :buffering_checking
        @centre.notify(tsym(:buffering), :hhh, "Hello2")
        @buffer4.begin_buffering
        @centre.notify(tsym(:buffering), :hhh, "Hello3")
        @results << :buffering_checking2
        @buffer4.end_buffering
        @results << :buffering_checking3
        @buffer4.begin_buffering
        @centre.notify(tsym(:buffering), :hhh, "Hello4")
        @buffer4.begin_buffering
        @centre.notify(tsym(:buffering), :hhh, "Hello4") # duplicate
        @buffer4.end_buffering
        @results << :buffering_checking4
        @buffer4.end_buffering
        @results << :buffering_checking5
        @centre.notify(tsym(:buffering), :hhh, "Hello5")
        @results << :buffering_checking6
        raise "Bad depth" unless 0 == @buffer4.buffering_depth
        @buffer4.while_buffering do
          raise "Bad depth" unless 1 == @buffer4.buffering_depth
          @centre.notify(tsym(:buffering), :hhh, "Hello6")
          @buffer4.while_buffering do
            raise "Bad depth" unless 2 == @buffer4.buffering_depth
            @centre.notify(tsym(:buffering), :hhh, "Hello7")
          end
          raise "Bad depth" unless 1 == @buffer4.buffering_depth
          @results << :buffering_checking7
        end
        raise "Bad depth" unless 0 == @buffer4.buffering_depth
        @results << :finish
        @centre.send_buffered_then_end_on_thread

        if expected == @results
          @successful_runs += 1
        end
      end
    end
    def global_notify(detail, x)
      @results << [0, :global, detail, x]
    end
    def lovely_notify(name, detail)
      @results << [3, name, detail]
    end
    def tsym(x)
      "testersym_#{@index.to_s}_#{x}".to_sym
    end
  end

  # --------------------------------------------------------------------------------------------------------------

  def test_exceptions_with_buffers
    # Exceptions in notification centres are gathered then re-thrown after buffer cleanup
    centre = KFramework::NotificationCentre.new
    buffer1 = centre.when(:a, nil, {:start_buffering => true, :deduplicate => true, :max_arguments => 0}) do
      raise "Exception One"
    end
    buffer2 = centre.when(:a, :b, {:start_buffering => true, :deduplicate => true, :max_arguments => 0}) do
      raise "Exception Two"
    end
    centre.finish_setup

    # Throw one exception, and make sure the buffers are cleared even though an exception was thrown
    centre.start_on_thread
    centre.notify(:a, :not_b)
    assert nil != Thread.current[buffer1.instance_variable_get(:@thread_key)]
    assert_equal nil, Thread.current[buffer2.instance_variable_get(:@thread_key)]
    assert_raises(RuntimeError) { centre.send_buffered_then_end_on_thread }
    assert_equal nil, Thread.current[buffer1.instance_variable_get(:@thread_key)]

    # Throw two exceptions, test it has a special exception thrown, again checking buffers
    centre.start_on_thread
    centre.notify(:a, :b)
    assert nil != Thread.current[buffer1.instance_variable_get(:@thread_key)]
    assert nil != Thread.current[buffer2.instance_variable_get(:@thread_key)]
    assert_raises(KFramework::NotificationCentre::TooManyExceptionsException) { centre.send_buffered_then_end_on_thread }
    assert_equal nil, Thread.current[buffer1.instance_variable_get(:@thread_key)]
    assert_equal nil, Thread.current[buffer2.instance_variable_get(:@thread_key)]
  end

  # --------------------------------------------------------------------------------------------------------------

  def test_notification_centre_devmode
    # Initial setup, from three files
    centre = KFramework::NotificationCentreDevMode.new
    assert centre.respond_to?(:begin_reload)
    centre.when(:n1) { @tncd_results << 1 }
    centre.when_each([[:n2]]) { @tncd_results << 2 }
    centre.call_when(self, :tncd_method, :n3)
    tncd_set_from_file1(centre, :n1, 42)
    original_buffer = tncd_set_from_file1(centre, :n2, 43, {:start_buffering => true})
    tncd_set_from_file2(centre, :n3, 100)
    centre.finish_setup
    assert_equal 1, centre.instance_variable_get(:@buffers).length
    assert centre.instance_variable_get(:@buffers).first == original_buffer

    # First run
    @tncd_results = []
    centre.start_on_thread
    centre.notify(:n1)
    assert_equal [1, 42], @tncd_results
    centre.notify(:n2)
    centre.notify(:n3)
    centre.send_buffered_then_end_on_thread
    assert_equal [1, 42, 2, 3, 100, 43], @tncd_results

    # Simulate a reload
    centre.begin_reload
    tncd_set_from_file1(centre, :n1, 82) # only one for file1
    tncd_set_from_file2(centre, :n2, 99)
    replaced_buffer = tncd_set_from_file2(centre, :n2, 199, {:start_buffering => true})
    assert replaced_buffer != original_buffer
    centre.end_reload

    # Check number of buffers is still 1
    assert_equal 1, centre.instance_variable_get(:@buffers).length
    assert centre.instance_variable_get(:@buffers).first == replaced_buffer
    assert centre.instance_variable_get(:@buffers).first != original_buffer

    # Run again
    @tncd_results = []
    centre.start_on_thread
    [:n1, :n2, :n3].each { |n| centre.notify(n) }
    centre.send_buffered_then_end_on_thread
    assert_equal [1, 82, 2, 99, 3, 199], @tncd_results
  end

  def tncd_method(a, b)
    @tncd_results << 3
  end

  # Define some functions in fake other files
  module_eval(<<-__E, "notification_centre_test_extras_file1.rb")
    def tncd_set_from_file1(centre, name, n, options = nil)
      centre.when(name, nil, options) { @tncd_results << n }
    end
  __E
  module_eval(<<-__E, "notification_centre_test_extras_file2.rb")
    def tncd_set_from_file2(centre, name, n, options = nil)
      centre.when(name, nil, options) { @tncd_results << n }
    end
  __E

end

