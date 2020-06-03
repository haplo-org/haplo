# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Test::Unit::TestCase
  include KConstants
  include TestStoreHelper

  def should_test_plugin_debugging_features?
    if ENV['DISABLE_TEST_PLUGIN_DEBUGGING']
      puts "NOTE: Skipping plugging debugging test"
      false
    else
      true
    end
  end

  TEST_JOBS_LOCK = Mutex.new
  def run_all_jobs(options)
    TEST_JOBS_LOCK.synchronize do
      # Find which queues are in use
      r = KApp.with_pg_database { |db| db.exec("SELECT queue FROM jobs WHERE application_id=#{_TEST_APP_ID}") }
      njobs = 0
      queues = Hash.new
      r.each do |r|
        queues[r.first] = true
        njobs += 1
      end
      if options != nil && options.has_key?(:expected_job_count)
        assert_equal options[:expected_job_count], njobs
      end
      without_application do
        queues.keys.each do |queue|
          runner = KJob::Runner.new(queue)
          adjust_kjob_runner_for_tests(runner)
          # Run the jobs
          while runner.run_next_job
            # nothing
          end
        end
      end
    end
    nil
  end

  def delete_all_jobs
    TEST_JOBS_LOCK.synchronize do
      KApp.with_pg_database do |db|
        db.exec("DELETE FROM jobs WHERE application_id=#{_TEST_APP_ID}")
      end
    end
  end

  def adjust_kjob_runner_for_tests(runner)
    # Hack the select next job SQL in the runner so it only finds jobs for the app being tested in this thread
    sql = runner.instance_variable_get(:@next_job_sql)
    runner.instance_variable_set(:@next_job_sql, sql.gsub('WHERE queue', "WHERE application_id=#{_TEST_APP_ID} AND queue"))
  end

  # Helpers for checking audit entries
  def about_to_create_an_audit_entry
    @_audit_entry_current_id = audit_entries_last_id(true)
  end

  def reset_audit_trail
    delete_all AuditEntry
    about_to_create_an_audit_entry
  end

  def assert_audit_entry(*attributes_list)
    currval = audit_entries_last_id
    assert_equal(@_audit_entry_current_id + attributes_list.length, currval,
                 "Audit id does not match expected value")
    audit_entry_id = currval - attributes_list.length + 1
    last_entry = nil
    attributes_list.each do |attributes|
      entry = last_entry = AuditEntry.read(audit_entry_id)
      audit_entry_id += 1
      assert nil != entry
      attributes.each do |key, value|
        if key == :objref
          assert_equal value, entry.objref
        elsif key == :data
          data = entry.data
          if data == nil
            assert_equal data, value
          else
            value.each do |test_key, test_value|
              assert_equal test_value, data[test_key]
            end
          end
        else
          assert_equal value, entry.__send__(key)
        end
      end
    end
    @_audit_entry_current_id = currval
    last_entry
  end

  def assert_no_more_audit_entries_written
    assert_equal @_audit_entry_current_id, audit_entries_last_id
  end

  def audit_entries_last_id(starting = false)
    if starting
      # Write a dummy entry so there's always an ID
      AuditEntry.write(:kind => '*TEST*', :displayable => false)
    end
    KApp.with_pg_database { |db| db.exec("SELECT MAX(id) FROM #{KApp.db_schema_name}.audit_entries").first.first.to_i }
  end

  def fixture_file_upload(filename, mime_type)
    # Copy the file
    outfilename = nil
    full_pathname = "#{File.dirname(__FILE__)}/../fixtures/#{filename}"
    File.open(full_pathname,"r") do |source|
      n = 0
      while File.exist?(outfilename = "#{FILE_UPLOADS_TEMPORARY_DIR}/fixture_file_upload.#{Thread.current.object_id}.#{n}")
        n += 1
      end
      File.open(outfilename, "w") { |dest| File.copy_stream(source, dest) }
    end

    # Calculate digest
    digest = Digest::SHA256.file(outfilename).hexdigest
    # Get leafname
    leafname = (filename =~ /\/([^\/]+)\z/) ? $1 : filename
    # Make a java upload object and return it
    upload = Java::OrgHaploAppserver::FileUploads::Upload.new("file", FILE_UPLOADS_TEMPORARY_DIR, "SHA-1", nil)
    upload.setUploadDetails(outfilename, digest, mime_type, leafname, File.size(full_pathname))
    upload
  end

  FIXTURE_TABLES = [:users, :user_memberships, :user_datas, :policies, :permission_rules, :latest_requests, :api_keys]

  def db_reset_test_data
    KApp.with_pg_database do |pg|
      FIXTURE_TABLES.reverse_each do |fixture_name|
        pg.perform("DELETE FROM #{KApp.db_schema_name}.#{fixture_name}")
      end
      db_load_table_fixtures(pg, FIXTURE_TABLES)
    end
  end

  def db_load_table_fixtures(pg, *fixtures)
    fixtures.flatten.each do |fixture_name|
      csv_name = "#{File.dirname(__FILE__)}/../fixtures/#{fixture_name}.csv"
      if File.exist?(csv_name)
        attr_names = nil
        File.open(csv_name) do |csv|
          csv.each do |line|
            elements = line.strip.split(/\s*,\s*/)
            if attr_names == nil
              attr_names = elements
            elsif elements.length > 0
              values = attr_names.zip(elements).delete_if { |k, v| !v || v=="" }
              pg.perform("INSERT INTO #{KApp.db_schema_name}.#{fixture_name} (#{values.map { |k,v| k }.join(",")}) VALUES ('#{values.map { |k,v| v }.join("','")}')")
            end
          end
        end
      end
    end
  end

  def self.disable_test_unless_file_conversion_supported(method, from_mime_type, to_mime_type)
    unless KFileTransform.can_transform?(from_mime_type, to_mime_type)
      define_method(method) { }
      puts "Disabling test #{method} because conversion from #{from_mime_type} to #{to_mime_type} is not supported"
    end
  end

  def read_zip_file(pathname)
    contents = {}
    java_zip_file = Java::JavaUtilZip::ZipFile.new(pathname)
    begin
      filenames_seen = []
      java_zip_file.entries.each do |entry|
        filenames_seen << entry.getName()
        data = Java::byte[entry.getSize()].new
        to_read = entry.getSize()
        offset = 0
        entry_stream = java_zip_file.getInputStream(entry)
        while(to_read > 0)
          bytes_read = entry_stream.read(data, offset, to_read)
          to_read -= bytes_read
          offset += bytes_read
        end
        contents[entry.getName()] = String.from_java_bytes(data)
      end
    ensure
      java_zip_file.finalize()
    end
    contents
  end

  class ObjectStorePermissionsTestUser
    def initialize(user_id, permissions)
      @id = user_id
      @permissions = permissions
    end
    attr_reader :id, :permissions
    def policy
      @policy ||= UserPolicy.new(self)
    end
    def policy_bitmask; 0xffffff; end
    def attribute_restriction_labels
      []
    end
  end
  def set_mock_objectstore_user(id, permissions = nil)
    mock_user = ObjectStorePermissionsTestUser.new(id, (permissions || KLabelStatements.super_user).freeze)
    AuthContext.set_user(mock_user, mock_user)
  end

  # MiniORM test helper functions
  # delete everything in the table, calling the after_delete() callback to clean up 
  def destroy_all(miniorm_class)
    miniorm_class.where().each do |row|
      row.delete
    end
  end
  def delete_all(miniorm_class)
    miniorm_class.where().delete()
  end

  def keychain_credential_create(k)
    kc = KeychainCredential.new
    kc.name = k[:name]
    kc.kind = k[:kind]
    kc.instance_kind = k[:instance_kind]
    kc.account_json = k[:account_json] if k.has_key?(:account_json)
    kc.account = k[:account] if k.has_key?(:account)
    kc.secret_json = k[:secret_json] if k.has_key?(:secret_json)
    kc.secret = k[:secret] if k.has_key?(:secret)
    kc.save
  end

end

