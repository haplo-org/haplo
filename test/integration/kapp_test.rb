# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KAppIntegrationTest < IntegrationTest

  CACHE_TEST1 = KApp.cache_register(Array, "Test cache 1")
  CACHE_TEST2 = KApp.cache_register(SyncedLookupCache.factory(proc { |x| "VALUE #{x}" }), "Test cache 2", :shared)

  def setup
    # To avoid counters getting screwed up
    @assert_lock = Mutex.new
  end

  # =======================================================================================================================

  def test_caches
    run_multiple_threads :tc_thread1, :tc_thread2
  end

  def tc_thread1
    KApp.in_application(@app_id) do
      cache = KApp.cache(CACHE_TEST1)
      assert cache.class == Array
      assert cache.empty?
      cache << 1
    end
    @barrier.await # ---------------------- 1
    @barrier.await # ---------------------- 2
    # Check that the cache is as expected
    KApp.in_application(@app_id) do
      cache = KApp.cache(CACHE_TEST1)
      assert cache.class == Array
      assert_equal [1,2], cache
    end
    @barrier.await # ---------------------- 3
    # Make sure if two apps ask for it, they get different caches
    KApp.in_application(@app_id) do
      @barrier.await # ---------------------- 4
      cache = KApp.cache(CACHE_TEST1)
      @stage4n1 = tc_cache_state_at_stage4(cache)
      @barrier.await # ---------------------- 5
      assert_equal ! @stage4n1, @stage4n2
    end
    @barrier.await # ---------------------- 6
    # Check invalidation
    KApp.in_application(@app_id) { tc_check_invalidation }
    @barrier.await # ---------------------- 7
    KApp.in_application(@app_id) do
      @barrier.await # ---------------------- 8
      cache = KApp.cache(CACHE_TEST1)
      assert_equal [], cache
    end
    @barrier.await # ---------------------- 9
    # Try filling the cache again
    KApp.in_application(@app_id) do
      cache = KApp.cache(CACHE_TEST1)
      cache << 3
    end
    @barrier.await # ---------------------- 10
    @barrier.await # ---------------------- 11
  end

  def tc_thread2
    @barrier.await # ---------------------- 1
    # Check that the cache is as expected
    KApp.in_application(@app_id) do
      cache = KApp.cache(CACHE_TEST1)
      assert cache.class == Array
      assert_equal [1], cache
      cache << 2
    end
    @barrier.await # ---------------------- 2
    @barrier.await # ---------------------- 3
    # Make sure if two apps ask for it, they get different caches
    KApp.in_application(@app_id) do
      @barrier.await # ---------------------- 4
      cache = KApp.cache(CACHE_TEST1)
      @stage4n2 = tc_cache_state_at_stage4(cache)
      @barrier.await # ---------------------- 5
      assert_equal ! @stage4n2, @stage4n1
    end
    @barrier.await # ---------------------- 6
    # Check invalidation
    KApp.in_application(@app_id) { tc_check_invalidation }
    @barrier.await # ---------------------- 7
    KApp.in_application(@app_id) do
      @barrier.await # ---------------------- 8
      cache = KApp.cache(CACHE_TEST1)
      assert_equal [], cache
    end
    @barrier.await # ---------------------- 9
    @barrier.await # ---------------------- 10
    # Final check
    KApp.in_application(@app_id) do
      cache = KApp.cache(CACHE_TEST1)
      assert_equal [3], cache
    end
    @barrier.await # ---------------------- 11
  end

  def tc_cache_state_at_stage4(cache)
    assert cache.empty? || cache == [1,2]
    cache.empty?
  end

  def tc_check_invalidation
    cache = KApp.cache(CACHE_TEST1)
    # Check state is valid as well as getting state
    current_state = tc_cache_state_at_stage4(cache)
    unless current_state
      assert_equal [1,2], cache
      KApp.cache_invalidate(CACHE_TEST1)
      assert_equal [1,2], cache
      cache = KApp.cache(CACHE_TEST1)
      assert_equal [], cache
    end
  end

  # =======================================================================================================================

  def test_shared_cache
    run_multiple_threads :tsc_thread1, :tsc_thread2
  end

  def tsc_thread1
    KApp.in_application(@app_id) do
      o = KApp.cache(CACHE_TEST2)
      @cache_objid = o.object_id
      assert_equal SyncedLookupCache, o.class
      v2 = o[2]
      @v2_objid = v2.object_id
      assert_equal "VALUE 2", v2
      assert_equal v2.object_id, o[2].object_id # make sure it's not recreated each time
      o[3] = 'pants'
    end
    @barrier.await # ---------------------- 1
    @barrier.await # ---------------------- 2
    KApp.in_application(@app_id) do
      o = KApp.cache(CACHE_TEST2)
      @barrier.await # ---------------------- 3
      assert_equal @cache_objid, o.object_id
      assert_equal 'pants', o[3]
    end
    @barrier.await # ---------------------- 4
  end

  def tsc_thread2
    @barrier.await # ---------------------- 1
    KApp.in_application(@app_id) do
      o = KApp.cache(CACHE_TEST2)
      assert_equal @cache_objid, o.object_id
      assert_equal @v2_objid, o[2].object_id # make sure it's not recreated each time
      assert_equal 'pants', o[3]
      assert_equal 'VALUE P', o['P']
    end
    @barrier.await # ---------------------- 2
    KApp.in_application(@app_id) do
      @barrier.await # ---------------------- 3
      o = KApp.cache(CACHE_TEST2)
      assert_equal @cache_objid, o.object_id
      assert_equal 'pants', o[3]
      assert_equal 'VALUE X', o[:X]
    end
    @barrier.await # ---------------------- 4
  end

  # =======================================================================================================================

  def test_app_globals
    run_multiple_threads :tag_thread1, :tag_thread2
  end

  def tag_thread1
    KApp.in_application(@app_id) do
      KApp.set_global(:test1, "value 1")
      KApp.set_global(:test2, 53)
    end
    @barrier.await # ---------------------- 1
    @barrier.await # ---------------------- 2
    # Check that globals set in one appear in the other, but only in the next in_application block so it's consistent thoughtout runs
    KApp.in_application(@app_id) do
      assert_equal "value 1", KApp.global(:test1)
      KApp.set_global(:test1, "value 2")
      @barrier.await # ---------------------- 3
      assert_equal "value 2", KApp.global(:test1)
      @barrier.await # ---------------------- 4
      KApp.set_global(:test1, "value 3")
      @barrier.await # ---------------------- 5
      assert_equal "value 3", KApp.global(:test1)
    end
    @barrier.await # ---------------------- 6
    KApp.in_application(@app_id) do
      assert_equal "value 3", KApp.global(:test1)
      assert_equal 53, KApp.global(:test2)
    end
    @barrier.await # ---------------------- 7
  end

  def tag_thread2
    @barrier.await # ---------------------- 1
    KApp.in_application(@app_id) do
      assert_equal "value 1", KApp.global(:test1)
    end
    @barrier.await # ---------------------- 2
    # Global changed in the other, make sure it's picked up
    @barrier.await # ---------------------- 3
    KApp.in_application(@app_id) do
      assert_equal "value 2", KApp.global(:test1)
      @barrier.await # ---------------------- 4
      @barrier.await # ---------------------- 5
      assert_equal "value 2", KApp.global(:test1)
    end
    @barrier.await # ---------------------- 6
    KApp.in_application(@app_id) do
      assert_equal "value 3", KApp.global(:test1)
      assert_equal 53, KApp.global(:test2)
    end
    @barrier.await # ---------------------- 7
  end

  # =======================================================================================================================

  def run_multiple_threads(*method_names)
    @app_id = _TEST_APP_ID
    @barrier = java.util.concurrent.CyclicBarrier.new(method_names.length) # number of threads
    # Call functions and join threads when done
    without_application do
      method_names.map { |m| Thread.new { self.send(m) } } .each { |thread| thread.join }
    end
  end

  def assert(*args)
    @assert_lock.synchronize { super }
  end
  def assert_equal(*args)
    @assert_lock.synchronize { super }
  end

end


