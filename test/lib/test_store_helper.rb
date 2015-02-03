# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module TestStoreHelper
  include KConstants

  def without_application
    KApp.__send__(:clear_app)
    yield
  ensure
    KApp.__send__(:switch_by_id, _TEST_APP_ID)
  end

  TEXTIDX_SNAPSHOTS = {}

  SCHEMA_TABLES = ['db/objectstore.sql', 'db/objectstore_global.sql'].map {|n| File.open("#{KFRAMEWORK_ROOT}/#{n}") { |f| f.read }} .join(";\n")
  # If REFERENCES added, use this to make them deferrable
  # .gsub(/REFERENCES([^,]+),/) { "REFERENCES#{$1} DEFERRABLE,"}"

  def snapshot_store(snapshot_name, app_id)
    clone_name = "#{snapshot_name}_#{app_id}"
    close_store_text_writers(app_id)
    pg = KObjectStore.get_pgdb
    pg.exec("BEGIN; SET CONSTRAINTS ALL DEFERRED; CREATE SCHEMA #{clone_name}; SET search_path=#{clone_name},public; #{SCHEMA_TABLES}; SELECT khq_copy_objectstore_contents('a#{app_id}','#{clone_name}'); COMMIT; SET search_path=a#{app_id},public")
    files = Dir.glob("#{KOBJECTSTORE_TEXTIDX_BASE}/#{app_id}/**/*")
    weightings = "#{KOBJECTSTORE_WEIGHTING_BASE}/#{app_id}.yaml"
    files << weightings if File.exist?(weightings)
    snap = {}
    files.each do |filename|
      unless File.directory?(filename)
        snap[filename] = File.open(filename, "rb") { |f| f.read }
      end
    end
    TEXTIDX_SNAPSHOTS[clone_name] = snap
    puts "Took snapshot: #{app_id}@#{snapshot_name}"
  end

  def self.save_snapshots
    File.open("#{TEST_ENV_TEST_DATA}/store_snapshots", "wb") { |f| f.write Marshal.dump(TEXTIDX_SNAPSHOTS) }
  end

  def self.load_snapshots
    File.open("#{TEST_ENV_TEST_DATA}/store_snapshots", "rb") { |f| TEXTIDX_SNAPSHOTS.merge!(Marshal.load(f.read)) }
    puts "#{TEXTIDX_SNAPSHOTS.length} store snapshots loaded"
  end

  def restore_store_snapshot(snapshot_name, app_id = nil)
    app_id ||= _TEST_APP_ID
    clone_name = "#{snapshot_name}_#{app_id}"
    close_store_text_writers(app_id)
    KObjectStore._test_reset_currently_selected_store
    pg = KObjectStore.get_pgdb
    pg.exec("SELECT oxp_reset_all(); SET search_path=a#{app_id},public; BEGIN; SET CONSTRAINTS ALL DEFERRED; SELECT khq_clear_os_tables('a#{app_id}'); SELECT khq_copy_objectstore_contents('#{clone_name}','a#{app_id}'); COMMIT")
    weightings = "#{KOBJECTSTORE_WEIGHTING_BASE}/#{app_id}.yaml"
    File.unlink(weightings) if File.exist?(weightings)
    TEXTIDX_SNAPSHOTS[clone_name].each do |filename,contents|
      File.open(filename,"wb") { |f| f.write(contents) }
    end
    KObjectStore::TEXTIDX_FLAG_GENERAL.clearFlag()
    KObjectStore::TEXTIDX_FLAG_REINDEX.clearFlag()
  end

  # Taken by anything involving the indexer
  TEST_INDEXING_LOCK = Mutex.new

  def close_store_text_writers(app_id)
    TEST_INDEXING_LOCK.synchronize do
      KObjectStore.textidx_close_writer_for(app_id)
    end
  end

  def reset_objectstore_to_minimal
    # Reset store (not done automatically)
    pg = KObjectStore.get_pgdb
    %w(os_objects os_objects_old os_index_int os_index_link os_index_link_pending os_index_datetime os_index_identifier).each do |table|
      pg.perform('DELETE FROM '+table)
    end
    # Clear the dirty text objects table for this store, clear the reindexing table, close all the Xapian indexes
    pg.perform("DELETE FROM os_dirty_text WHERE app_id=#{_TEST_APP_ID}; DELETE FROM os_store_reindex WHERE app_id=#{_TEST_APP_ID}; SELECT oxp_reset_all()")
    # Delete the weightings file
    weightings_file = KObjectStore.get_current_weightings_file_pathname
    File.unlink weightings_file if File.exist? weightings_file
    # Delete and reinit empty text indexes
    close_store_text_writers(_TEST_APP_ID)  # so the underlying databases can be deleted
    KObjectStore::TEXT_INDEX_FOR_INIT.each do |name|
      pathname = KObjectStore.get_text_index_path(name)
      # Delete and rebuild the index.
      FileUtils.rm_r(pathname) if File.exist?(pathname)
      pg.exec("SELECT oxp_w_init_empty_index($1)", pathname)
    end
    # Reset the store object, to remove anything it's cached
    KObjectStore._test_reset_currently_selected_store
    # Unset flags
    KObjectStore::TEXTIDX_FLAG_GENERAL.clearFlag()
    KObjectStore::TEXTIDX_FLAG_REINDEX.clearFlag()
    # Initialise the store
    KObjectLoader.load_store_initialisation
    # Do any text indexing required
    run_outstanding_text_indexing :expected_reindex => false, :expected_work => true
  end

  class NoVaccumingObjHandler < KObjectLoader::DefaultObjectHandler
    def on_finish
    end
  end
  def load_basic_schema_objects
    handler = NoVaccumingObjHandler.new
    KObjectLoader.load_from_file(File.dirname(__FILE__) + '/../../db/dublincore.objects', handler)
    KObjectLoader.load_from_file(File.dirname(__FILE__) + '/../../db/app.objects', handler)
    KObjectLoader.load_from_file(File.dirname(__FILE__) + '/../../db/app_attrs.objects', handler)
    KObjectLoader.load_from_file(File.dirname(__FILE__) + '/../../db/app_types.objects', handler)
    run_outstanding_text_indexing :expected_reindex => true
  end

  def run_outstanding_text_indexing(opts = {})
    # Switch out of the current app
    without_application do
      # Parse options
      if opts == true || opts == {}
        opts = {:expected_work => true}
      elsif opts == false
        opts = {}
      end
      # Expecting a reindex means it must be expecting to do something
      opts[:expected_work] = true if opts[:expected_reindex]
      # Check to see if the sempahore state looks right
      raise "Bad state" unless (opts[:expected_work] ? true : false) == KObjectStore::TEXTIDX_FLAG_GENERAL.isFlagged()
      raise "Bad state" unless (opts[:expected_reindex] ? true : false) == KObjectStore::TEXTIDX_FLAG_REINDEX.isFlagged()
      # in a locked block because it doesn't expect to be multi-threaded
      TEST_INDEXING_LOCK.synchronize do
        # Make sure the database connection created and set to this app, so the additional indexing tables are visible
        $indexing_database_connection ||= KApp.make_unassigned_pg_database
        $indexing_database_connection.perform("SET search_path TO a#{_TEST_APP_ID},public")
        # See if there's a reindex required
        KObjectStore.update_reindex_states($indexing_database_connection)
        reindex_states = KObjectStore.send(:class_variable_get, :@@reindex_states)
        raise "Bad state" unless (opts[:expected_reindex] ? 1 : 0) == (reindex_states.select {|s| s.app_id == _TEST_APP_ID} .length)
        # Call the text indexing until it returns
        runs = 0
        while KObjectStore.do_text_indexing($indexing_database_connection)
          runs += 1
        end
        if opts[:expected_work]
          # Check that something happened
          raise "Bad state" unless runs > 0
        else
          # Make sure the first and only call returned false, as nothing to do
          raise "Bad state" unless 0 == runs
        end
        # Reset the general flag, because the way it's being called doesn't unset it
        KObjectStore::TEXTIDX_FLAG_GENERAL.clearFlag()
        # Check reindex semaphore is unset
        raise "Bad state" unless (false == KObjectStore::TEXTIDX_FLAG_REINDEX.isFlagged())
        # Check reindexing is all done
        raise "Bad state" unless (0 == (reindex_states.select {|s| s.app_id == _TEST_APP_ID} .length))
      end
    end
    nil
  end

end
