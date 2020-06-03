# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
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

  SCHEMA_TABLES = File.open("#{KFRAMEWORK_ROOT}/db/objectstore.sql") { |f| f.read }
  # If REFERENCES added, use this to make them deferrable
  # .gsub(/REFERENCES([^,]+),/) { "REFERENCES#{$1} DEFERRABLE,"}"

  def snapshot_store(snapshot_name, app_id)
    clone_name = "#{snapshot_name}_#{app_id}"
    KApp.with_pg_database do |pg|
      pg.exec("BEGIN; SET CONSTRAINTS ALL DEFERRED; CREATE SCHEMA #{clone_name}; SET search_path=#{clone_name},public; #{SCHEMA_TABLES}; SET search_path=public; SELECT khq_copy_objectstore_contents('a#{app_id}','#{clone_name}'); COMMIT;")
    end
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
    KObjectStore._test_reset_currently_selected_store
    KApp.with_pg_database do |pg|
      pg.exec("SELECT oxp_reset_all(); BEGIN; SET CONSTRAINTS ALL DEFERRED; SELECT khq_clear_os_tables('a#{app_id}'); SELECT khq_copy_objectstore_contents('#{clone_name}','a#{app_id}'); DELETE FROM public.os_dirty_text WHERE app_id=#{app_id}; DELETE FROM public.os_store_reindex WHERE app_id=#{app_id}; COMMIT;")
    end
    weightings = "#{KOBJECTSTORE_WEIGHTING_BASE}/#{app_id}.yaml"
    File.unlink(weightings) if File.exist?(weightings)
    TEXTIDX_SNAPSHOTS[clone_name].each do |filename,contents|
      File.open(filename,"wb") { |f| f.write(contents) }
    end
    KObjectStore::TEXTIDX_FLAG.clearFlag()
  end

  def reset_objectstore_to_minimal
    # Reset store (not done automatically)
    KApp.with_pg_database do |pg|
      %w(os_objects os_objects_old os_index_int os_index_link os_index_datetime os_index_identifier).each do |table|
        pg.perform("DELETE FROM #{KApp.db_schema_name}.#{table}")
      end
      # Clear the dirty text objects table for this store, clear the reindexing table, close all the Xapian indexes
      pg.perform("DELETE FROM public.os_dirty_text WHERE app_id=#{_TEST_APP_ID}; DELETE FROM public.os_store_reindex WHERE app_id=#{_TEST_APP_ID}; SELECT oxp_reset_all()")
    end
    # Delete the weightings file
    weightings_file = KObjectStore.get_current_weightings_file_pathname
    File.unlink weightings_file if File.exist? weightings_file
    # Delete and reinit empty text indexes
    KObjectStore::TEXT_INDEX_FOR_INIT.each do |name|
      pathname = KObjectStore.get_text_index_path(name)
      # Delete and rebuild the index.
      FileUtils.rm_r(pathname) if File.exist?(pathname)
      KApp.with_pg_database do |pg|
        pg.exec("SELECT oxp_w_init_empty_index($1)", pathname)
      end
    end
    # Reset the store object, to remove anything it's cached
    KObjectStore._test_reset_currently_selected_store
    # Unset flags
    KObjectStore::TEXTIDX_FLAG.clearFlag()
    # Initialise the store
    KObjectLoader.load_store_initialisation
    # Do text indexing
    KObjectStore.reindex_all_objects
    run_outstanding_text_indexing :expected_reindex => true, :expected_work => true
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
      raise "Bad state" unless (opts[:expected_work] ? true : false) == KObjectStore::TEXTIDX_FLAG.isFlagged()

      work = KObjectStore::StoreReindexWork.new(_TEST_APP_ID)
      has_work = work.prepare
      raise "Bad state" unless opts[:expected_work] == has_work

      # Check for pending reindex
      reindex_id = work.__send__(:instance_variable_get, :@reindex_id)
      raise "Bad state" unless ((opts[:expected_reindex] ? false : true) == reindex_id.nil?)

      # Do the text indexing until complete
      while has_work
        work.perform
        work = KObjectStore::StoreReindexWork.new(_TEST_APP_ID)
        has_work = work.prepare
      end

      # Reset the general flag, because the way it's being called doesn't unset it
      KObjectStore::TEXTIDX_FLAG.clearFlag()
      # Check reindexing is all done
      if opts[:expected_reindex]
        KApp.with_pg_database do |db|
          reindex_count = db.perform("SELECT count(id) FROM public.os_store_reindex WHERE app_id=#{_TEST_APP_ID}").first.first.to_i
          raise "Bad state" unless reindex_count == 0
        end
      end
    end
    nil
  end

end
