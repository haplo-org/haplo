# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



# NOTE: Import/export of entire apps is a bit icky. In particular, the db export is non-optimal and the creation of the schema is assumed.
# TODO: Test app import/export cycles on a multi-app system.

class KAppImporter
  include KConstants

  def self.cmd_import(filename_base, new_hostname = nil, new_application_id = nil)
    raise "Reached app limit on this zone" unless KAccounting.room_for_another_app

    raise "Bad new hostname" unless new_hostname.nil? || (new_hostname.kind_of?(String) && new_hostname.length > 0)
    raise "Bad new app ID" unless new_application_id.nil? || (new_application_id.kind_of?(Integer) && new_application_id > 0)

    # Remove any suffix from filename base, as auto-completion willl leave a '.'
    filename_base = filename_base.gsub(/\.+\z/,'')

    raise "No filename base specified" unless filename_base != nil && filename_base.length > 0
    ['json','tgz'].each do |ext|
      raise "No #{ext} file found" unless File.exist?("#{filename_base}.#{ext}")
    end
    have_uncompressed_sql = File.exist?("#{filename_base}.sql")
    have_compressed_sql = File.exist?("#{filename_base}.sql.gz")
    if have_uncompressed_sql && have_compressed_sql
      raise "Both compressed and uncompressed SQL files present"
    elsif !have_uncompressed_sql && !have_compressed_sql
      raise "No .sql.gz file found"
    end

    # Get the remote console process for running commands so main server process doesn't have to fork
    remote_process = Console.remote_console_client

    data = File.open("#{filename_base}.json",'r') { |f| JSON.parse(f.read) }
    raise "Bad data file" unless data && data.has_key?("applicationId") && data.has_key?("hostnames")

    hostnames = data["hostnames"]
    hostnames = [new_hostname] unless new_hostname.nil?

    # Check policy
    import_policy_class = POLICIES[KInstallProperties.get(:server_import_policy, 'allow-all')]
    raise "Bad import policy configured" unless import_policy_class
    import_policy = import_policy_class.new(data, hostnames)
    unless import_policy.import_allowed?
      puts "\nImport not allowed on this server:\n"
      import_policy.violations.each { |v| puts "  * #{v}" }
      puts "\nIMPORTANT: Delete the application export files from this server immediately.\n\n"
      return false
    end

    source_app_id = data["applicationId"].to_i
    app_id = new_application_id || source_app_id

    # Check the SQL file has the right app_id in it
    sql_check_length = 1024 # assume statements within this number of bytes of file start
    sql_start = if have_compressed_sql
      gstream = java.util.zip.GZIPInputStream.new(java.io.FileInputStream.new("#{filename_base}.sql.gz"))
      bytes = Java::byte[sql_check_length].new
      gstream.read(bytes)
      gstream.close
      String.from_java_bytes(bytes)
    else
      File.read("#{filename_base}.sql", sql_check_length)
    end
    raise "Bad schema create in SQL file" unless sql_start =~ /CREATE SCHEMA a#{source_app_id};/

    KApp.in_application(:no_app) do
      KApp.with_pg_database do |db|

        db.perform('BEGIN')
        # Check the application ID hasn't been used
        [source_app_id,app_id].each do |id|
          r = db.exec("SELECT * FROM public.applications WHERE application_id=#{id.to_i}")
          if r.length > 0
            raise "Application ID #{id} is already in use"
          end
        end
        # Add the rows for each hostname
        hostnames.each do |hostname|
          db.update(%Q!INSERT INTO public.applications (hostname,application_id) VALUES($1,#{app_id})!, hostname)
        end
        db.perform('COMMIT')

        # Create the empty text indicies for the app
        textidx_path = "#{KOBJECTSTORE_TEXTIDX_BASE}/#{app_id}"
        KObjectStore::TEXT_INDEX_FOR_INIT.each do |name|
          db.exec("SELECT oxp_w_init_empty_index($1)", "#{textidx_path}/#{name}")
        end

      end

      StoredFile.init_store_on_disc_for_app(app_id)

    end

    # Import the SQL table data, which creates the schema and includes the object store
    load_cmd = if have_compressed_sql
      "gunzip -c #{filename_base}.sql.gz | psql #{KFRAMEWORK_DATABASE_NAME}"
    else
      "psql #{KFRAMEWORK_DATABASE_NAME} < #{filename_base}.sql"
    end
    remote_process.remote_system load_cmd

    # Rename the schema?
    if source_app_id != app_id
      KApp.in_application(:no_app) do
        KApp.with_pg_database { |db| db.perform("ALTER SCHEMA a#{source_app_id.to_i} RENAME TO a#{app_id.to_i}") }
      end
    end

    # Final initialisation
    KApp.in_application(app_id) do
      # Check hostname set in app_globals -- makes it easier to rename on import just by editing the json file
      [:url_hostname, :ssl_hostname].each do |key|
        KApp.set_global(key, hostnames.first) unless hostnames.include?(KApp.global(key))
      end

      remote_process.remote_system "cd #{StoredFile.disk_root}; gunzip --stdout #{File.expand_path(filename_base)}.tgz | tar xf - "

      FileCacheEntry.where().delete()

      # Change secrets on app import, so values created by clones can't be used in the originals
      KApp.set_global(:file_secret_key, KRandom.random_hex(KRandom::FILE_SECRET_KEY_LENGTH))
      KApp.set_global(:file_static_signature_key, KRandom.random_hex(KRandom::FILE_STATIC_SIGNATURE_KEY_LENGTH)) if KApp.global(:file_static_signature_key) != nil

      KAccounting.set_counters_for_current_app

      KObjectStore.schema_weighting_rebuild

      KObjectStore.reindex_all_objects
    end

    KApp.clear_all_cached_data_for_app(app_id)

    KApp.update_app_server_mappings

    # Trigger any jobs to get any files indexed
    KJob.trigger_jobs_in_worker_processes

    KNotificationCentre.notify(:applications, :changed)
  end

  # -------------------------------------------------------------------------

  class ImportPolicy
    def initialize(export_data, hostnames)
      @export_data = export_data
      @hostnames = hostnames
      @violations = []
    end
    attr_reader :export_data, :hostnames, :violations
    def import_allowed?
      policy()
      @violations.empty?
    end
    def policy
      violation("Policy not implemented")
    end
    def violation(violation)
      @violations << violation
    end
    def violation_if_server_classification_tag(tag)
      tags = @export_data["serverClassificationTags"] || [KInstallProperties::DEFAULT_SERVER_CLASSIFICATION_TAG]
      if tags.include?(tag)
        violation("Source server classification tag '#{tag}' is not permitted.")
      end
    end
  end

  class ImportPolicyAllowAll < ImportPolicy
    def policy
      # no checks
    end
  end

  POLICIES = {
    "allow-all" => ImportPolicyAllowAll
  }

end
