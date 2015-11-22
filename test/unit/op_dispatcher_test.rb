# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class OpDispatcherTest < Test::Unit::TestCase

  RuntimeException = Java::JavaLang::RuntimeException

  OpDispatcher = Java::ComOneisOp::OpDispatcher
  OpWorkerSupervisor = Java::ComOneisOp::OpWorkerSupervisor
  WorkerState = OpDispatcher::WorkerState
  Operation = Java::ComOneisOp::Operation
  OpNotifyTarget = Java::ComOneisOp::OpNotifyTarget
  TestOperation = Java::ComOneisOpTest::TestOperation

  # ------------------------------------------------------------------------------------

  class TestNotifyTarget
    include OpNotifyTarget
    def initialize(notify_list)
      @notify_list = notify_list
    end
    def notifyOperationComplete(operation)
      @notify_list << [:notifyOperationComplete, operation.string]
    end
    def notifyOperationException(operation, exception)
      @notify_list << [:notifyOperationException, operation.string, exception.message]
    end
  end

  # ------------------------------------------------------------------------------------

  class TestOpWorkerSupervisor
    include OpWorkerSupervisor
    def initialize
      @started_with_workers = -1
      @last_failure = -1
    end
    attr_reader :started_with_workers
    attr_reader :last_failure
    def startSupervision(policy)
      @started_with_workers = policy.numberOfWorkers
    end
    def workerFailed(workerNumber)
      @last_failure = workerNumber
    end
  end

  # ------------------------------------------------------------------------------------

  class TestWorkerWaker
    def initialize
      @signaled = false
    end
    def wakeup
      @signaled = true
    end
    def unsetWakeFlag
    end
    def get_signaled
      r = @signaled; @signaled = false; r
    end
  end

  # ------------------------------------------------------------------------------------

  def test_op_dispatcher

    # Set up dispatcher and get worker interfaces
    default_policy = OpDispatcher::Policy.new()
    dispatcher = OpDispatcher.new(default_policy)

    supervisor = TestOpWorkerSupervisor.new
    assert supervisor.started_with_workers < 0
    dispatcher.useSupervisor(supervisor)
    assert_equal default_policy.numberOfWorkers, supervisor.started_with_workers

    worker0 = dispatcher.workerConnected(0)
    worker0_waker = TestWorkerWaker.new
    worker0.setWaker(worker0_waker)
    worker1 = dispatcher.workerConnected(1)
    worker2 = dispatcher.workerConnected(2)
    worker3 = dispatcher.workerConnected(3)
    assert_raises(RuntimeException) { dispatcher.workerConnected(-1) }
    assert_raises(Java::JavaLang::RuntimeException) { dispatcher.workerConnected(4) }
    assert_raises(Java::JavaLang::RuntimeException) { dispatcher.workerConnected(5) }

    # Can't connect a worker twice
    assert_raises(RuntimeException) { dispatcher.workerConnected(0) }

    # Test queue, dispatch, completion notifications, and that only 2 ops from a single app can be in flight at any time.
    notifications = []
    assert_equal false, worker0_waker.get_signaled() # not flagged before work is added
    test_ops = [
      ["ABC", 1234],
      ["DEF", 1234],
      ["XYZ", 1234],
      ["012", 2354],
      ["872", 2354],
      ["YYY", 1234]
    ].each do |str, app_id|
      dispatcher.queueOperation(TestOperation.new(str), app_id, TestNotifyTarget.new(notifications))
    end
    op0 = worker0.getNextWork()
    assert_equal true, worker0_waker.get_signaled() # make sure the waker has been signalled
    op1 = worker1.getNextWork()
    op2 = worker2.getNextWork()
    assert_equal "ABC", op0.string # 1234
    assert_equal "DEF", op1.string # 1234
    assert_equal "012", op2.string  # 2354 NOT "XYZ" because of two app rule
    assert notifications.empty?
    worker0.finishedWork(op0, TestOperation.new("PING"), nil, WorkerState::OK) # app 1234
    check_notification(notifications, :notifyOperationComplete, "PING") # string value comes from completed op
    op0 = worker0.getNextWork() # 1234
    assert_equal "XYZ", op0.string  # as 1234 had a task finish
    op3 = worker3.getNextWork() # 2354
    assert_equal "872", op3.string # 2354
    worker2.finishedWork(op2, TestOperation.new("HELLO"), nil, WorkerState::OK) # app 2354
    check_notification(notifications, :notifyOperationComplete, "HELLO")
    op2 = worker2.getNextWork()
    assert_equal nil, op2 # because two 1234 tasks still in flight, and all 2354 task are returned or in flight
    worker0.finishedWork(op0, TestOperation.new("HELLO3"), nil, WorkerState::OK) # 1234
    check_notification(notifications, :notifyOperationComplete, "HELLO3")
    op2 = worker2.getNextWork()
    assert_equal "YYY", op2.string
    worker2.finishedWork(op2, TestOperation.new("HELLO2"), nil, WorkerState::OK)
    check_notification(notifications, :notifyOperationComplete, "HELLO2")
    assert_equal nil, worker2.getNextWork()
    assert_equal false, worker1.isFailed()
    assert_equal -1, supervisor.last_failure
    worker1.finishedWork(op1, TestOperation.new("HELLO5"), nil, WorkerState::FAILED) # mark worker as failed, can be done for an exception or on success
    assert_equal 1, supervisor.last_failure
    assert_equal true, worker1.isFailed();
    worker1 = dispatcher.workerConnected(1) # reconnect worker
    check_notification(notifications, :notifyOperationComplete, "HELLO5")
    worker3.finishedWork(op3, TestOperation.new("HELLO6"), nil, WorkerState::OK)
    check_notification(notifications, :notifyOperationComplete, "HELLO6")
    assert_equal nil, worker0.getNextWork()
    assert_equal nil, worker1.getNextWork()
    assert_equal nil, worker2.getNextWork()
    assert_equal nil, worker3.getNextWork()

    # Test exception notifications
    dispatcher.queueOperation(TestOperation.new("Exceptional"), 1234, TestNotifyTarget.new(notifications))
    op0 = worker0.getNextWork()
    worker0.finishedWork(op0, nil, java.lang.RuntimeException.new("Exception message"), WorkerState::OK)
    check_notification(notifications, :notifyOperationException, "Exceptional", "Exception message")

    # Test worker reconnections
    old_worker1 = worker1
    dispatcher.workerDisconnected(worker1)
    worker1 = dispatcher.workerConnected(1)
    assert_raises(RuntimeException) { old_worker1.getNextWork() }
    assert_equal nil, worker1.getNextWork()
    dispatcher.queueOperation(TestOperation.new("AHT"), 1234, TestNotifyTarget.new(notifications))
    op1 = worker1.getNextWork()
    assert_equal "AHT", op1.string
    assert_raises(RuntimeException) { dispatcher.workerDisconnected(worker1) } # because it's running something
    worker1.finishedWork(op1, TestOperation.new("HELLO6"), nil, WorkerState::OK)

    # Check worker returning work
    dispatcher.queueOperation(TestOperation.new("RETURNED"), 1234, TestNotifyTarget.new(notifications))
    dispatcher.queueOperation(TestOperation.new("ABC"), 1234, TestNotifyTarget.new(notifications))
    dispatcher.queueOperation(TestOperation.new("DEF"), 1234, TestNotifyTarget.new(notifications))
    op2 = worker2.getNextWork()
    assert_equal "RETURNED", op2.string
    assert_equal true, worker2.isConnected()
    worker2.returnWork(op2, WorkerState::FAILED)
    assert_equal 2, supervisor.last_failure
    assert_equal false, worker2.isConnected()
    assert_raises(RuntimeException) { worker2.getNextWork() } # because it's been disconnected
    worker2 = dispatcher.workerConnected(2)
    # Make sure the returned op goes to the front of the queue
    op3 = worker3.getNextWork()
    assert_equal "RETURNED", op3.string
    op2 = worker2.getNextWork()
    assert_equal "ABC", op2.string
    op0 = worker0.getNextWork()
    assert_equal nil, op0 # per-app limit
    worker3.finishedWork(op3, TestOperation.new("HELLO6"), nil, WorkerState::OK)
    worker2.finishedWork(op2, TestOperation.new("HELLO6"), nil, WorkerState::OK)
    op0 = worker0.getNextWork()
    assert_equal "DEF", op0.string
    worker0.finishedWork(op0, TestOperation.new("HELLO6"), nil, WorkerState::OK)

    # Test member vars of returned operation gets copied across to originally queued operation
    original_op = TestOperation.new("LOVELY OP")
    dispatcher.queueOperation(original_op, 1234, TestNotifyTarget.new(notifications))
    op1 = worker1.getNextWork()
    worker1.finishedWork(op1, TestOperation.new("REPLACED MEMBER VAR"), nil, WorkerState::OK)
    assert_equal "REPLACED MEMBER VAR", original_op.string

    # Fill up the queue, then add a final op to check it won't take an unlimited number of ops in the queue for safety
    assert_equal 512, default_policy.maxQueueLength
    512.times do
      dispatcher.queueOperation(TestOperation.new("DEF"), 1234, TestNotifyTarget.new(notifications))
    end
    assert_raises(RuntimeException) { dispatcher.queueOperation(TestOperation.new("DEF"), 1234, TestNotifyTarget.new(notifications)) }
  end

  def check_notification(notifications, *info)
    assert_equal 1, notifications.length
    assert_equal info, notifications.pop
  end

end

