# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Test::Unit::TestCase
  include KConstants
  include TestStoreHelper

  TEST_JOBS_LOCK = Mutex.new
  def run_all_jobs(options)
    TEST_JOBS_LOCK.synchronize do
      # Find which queues are in use
      pg = KApp.get_pg_database
      r = pg.exec("SELECT queue FROM jobs WHERE application_id=#{_TEST_APP_ID}")
      njobs = 0
      queues = Hash.new
      r.result.each do |r|
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

  def adjust_kjob_runner_for_tests(runner)
    # Hack the select next job SQL in the runner so it only finds jobs for the app being tested in this thread
    runner.instance_variable_get(:@next_job_sql).gsub!('WHERE queue', "WHERE application_id=#{_TEST_APP_ID} AND queue")
  end

  # Helpers for checking audit entries
  def about_to_create_an_audit_entry
    @_audit_entry_current_id = audit_entries_last_id(true)
  end

  def reset_audit_trail
    AuditEntry.delete_all
    about_to_create_an_audit_entry
  end

  def assert_audit_entry(*attributes_list)
    currval = audit_entries_last_id
    assert_equal(@_audit_entry_current_id + attributes_list.length, currval,
                 "Audit id does not match expected value")
    audit_entry_id = currval - attributes_list.length + 1
    last_entry = nil
    attributes_list.each do |attributes|
      entry = last_entry = AuditEntry.find(audit_entry_id)
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
          assert_equal value, entry[key]
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
    KApp.get_pg_database.exec("SELECT MAX(id) FROM audit_entries").result.first.first.to_i
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
    upload = Java::ComOneisAppserver::FileUploads::Upload.new("file", FILE_UPLOADS_TEMPORARY_DIR, "SHA-1", nil)
    upload.setUploadDetails(outfilename, digest, mime_type, leafname, File.size(full_pathname))
    upload
  end

  FIXTURE_TABLES = [:users, :user_memberships, :user_datas, :policies, :permission_rules, :latest_requests, :api_keys]

  def db_reset_test_data
    pg = KApp.get_pg_database
    FIXTURE_TABLES.reverse_each do |fixture_name|
      pg.perform("DELETE FROM #{fixture_name}")
    end
    db_load_table_fixtures(FIXTURE_TABLES)
  end

  def db_load_table_fixtures(*fixtures)
    pg = KApp.get_pg_database
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
              pg.perform("INSERT INTO #{fixture_name} (#{values.map { |k,v| k }.join(",")}) VALUES ('#{values.map { |k,v| v }.join("','")}')")
            end
          end
        end
      end
    end
  end

  def _delete_fixtures(fixtures)
    pg = KApp.get_pg_database
    # Do them in reverse order
    fixtures.flatten.reverse.each do |fixture_name|
      pg.perform("DELETE FROM #{fixture_name}")
    end
  end

  def self.disable_test_unless_file_conversion_supported(method, from_mime_type, to_mime_type)
    unless KFileTransform.can_transform?(from_mime_type, to_mime_type)
      define_method(method) { }
      puts "Disabling test #{method} because conversion from #{from_mime_type} to #{to_mime_type} is not supported"
    end
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
  end
  def set_mock_objectstore_user(id, permissions = nil)
    mock_user = ObjectStorePermissionsTestUser.new(id, (permissions || KLabelStatements.super_user).freeze)
    AuthContext.set_user(mock_user, mock_user)
  end

end

