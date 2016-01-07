# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KTempDataStoreTest < Test::Unit::TestCase

  TEST_DATA_1 = "some random data \0\n\r\1 ping"
  TEST_DATA_2 = 'dfdsfi890823rkwdjfwdf'
  TEST_DATA_3 = 'fs098ds90fsd9f((((@@(@((($$"))))))))'
  TEST_DATA_4 = '-'
  TEST_DATA_5 = ''

  # Data is stored in the public database schema, so only one test can be running at once to avoid collisions
  TEST_LOCK = Mutex.new

  def test_temp_data_store
    TEST_LOCK.synchronize do
      KApp.get_pg_database.perform('DELETE FROM public.temp_data_store')

      # Check basic storing and retrieving
      key = KTempDataStore.set('testing', TEST_DATA_1)
      assert key.kind_of?(String)
      assert key.length > 20

      assert_equal nil, KTempDataStore.get(key, 'not_testing')

      retrieved_data = KTempDataStore.get(key, :testing)
      assert_equal retrieved_data, TEST_DATA_1
      assert_equal nil, KTempDataStore.get(key, :testing)

      key1 = KTempDataStore.set('ping', TEST_DATA_4)
      key2 = KTempDataStore.set('pong', TEST_DATA_2)
      key3 = KTempDataStore.set(:pong, TEST_DATA_3)
      key4 = KTempDataStore.set('hello', TEST_DATA_4)
      key5 = KTempDataStore.set('hello', TEST_DATA_5)
      all_keys = [key1, key2, key3, key4, key5].sort
      assert_equal all_keys.uniq, all_keys

      assert_equal nil, KTempDataStore.get(key3, 'ping')
      assert_equal TEST_DATA_3, KTempDataStore.get(key3, :pong)
      assert_equal nil, KTempDataStore.get(key3, :pong)
      assert_equal TEST_DATA_2, KTempDataStore.get(key2, :pong)
      assert_equal TEST_DATA_4, KTempDataStore.get(key1, :ping)
      assert_equal nil, KTempDataStore.get(key1, :pong)
      assert_equal nil, KTempDataStore.get(key2, :pong)
      assert_equal nil, KTempDataStore.get(key3, :pong)
      assert_equal TEST_DATA_4, KTempDataStore.get(key4, 'hello')
      assert_equal TEST_DATA_5, KTempDataStore.get(key5, 'hello')
      ['ping',:pong,'hello'].each do |purpose|
        [key,key1,key2,key3,key4,key5].each { |k| assert_equal nil, KTempDataStore.get(k, purpose) }
      end

      # Checking deleting old data -- first create some data
      key10 = KTempDataStore.set(:p1, TEST_DATA_1)
      key11 = KTempDataStore.set(:p2, TEST_DATA_2)
      key12 = KTempDataStore.set(:p3, TEST_DATA_4)
      key13 = KTempDataStore.set('p4', TEST_DATA_5)
      all_1 = [
          [key10, 'p1', TEST_DATA_1],
          [key11, 'p2', TEST_DATA_2],
          [key12, 'p3', TEST_DATA_4],
          [key13, 'p4', TEST_DATA_5],
        ]
      assert_equal all_1, get_all_temp_data

      # Check nothing's deleted for a clean up of fresh data
      KTempDataStore.delete_old_data
      assert_equal all_1, get_all_temp_data

      # Move a key back an hour and check it's still not deleted
      key11_id = get_id_for_key(key11)
      KApp.get_pg_database.perform("UPDATE public.temp_data_store SET created_at = (NOW() - interval '1 hour') WHERE id=#{key11_id}")
      KTempDataStore.delete_old_data
      assert_equal all_1, get_all_temp_data

      # Move a key back a day, and see if it's deleted
      key12_id = get_id_for_key(key12)
      KApp.get_pg_database.perform("UPDATE public.temp_data_store SET created_at = (NOW() - interval '24 hours') WHERE id=#{key12_id}")
      KTempDataStore.delete_old_data
      all_2 = [
          [key10, 'p1', TEST_DATA_1],
          [key11, 'p2', TEST_DATA_2],
          [key13, 'p4', TEST_DATA_5],
        ]
      assert_equal all_2, get_all_temp_data

      assert_equal TEST_DATA_1, KTempDataStore.get(key10, :p1)
      assert_equal TEST_DATA_2, KTempDataStore.get(key11, :p2)
      assert_equal nil, KTempDataStore.get(key12, :p3)
      assert_equal TEST_DATA_5, KTempDataStore.get(key13, 'p4')

    end
  end

  def get_all_temp_data
    o = Array.new
    KApp.get_pg_database.exec('SELECT key,purpose,data FROM public.temp_data_store ORDER BY id').each do |key,purpose,data|
      o << [key,purpose,PGconn.unescape_bytea(data)]
    end
    o
  end

  def get_id_for_key(key)
    KApp.get_pg_database.exec('SELECT id FROM public.temp_data_store WHERE key=$1',key).first.first.to_i
  end

end

