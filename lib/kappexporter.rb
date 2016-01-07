# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KAppExporter
  include KConstants

  def self.export(app_id, filename_base, options)
    KApp.in_application(app_id) do
      self.do_export(filename_base, options.split(/,/))
    end
  end

  def self.do_export(filename_base, options)
    raise 'No export filename specified' unless filename_base != nil && filename_base.length > 0
    pg = KApp.get_pg_database

    # Get the remote console process for running commands so main server process doesn't have to fork
    remote_process = Console.remote_console_client

    # ---------------------------------------------------------------------------------------------

    files_export = true
    if options.include?('nofiles')
      files_export = false
      puts "Application files will not be exported."
    end

    # ---------------------------------------------------------------------------------------------

    # Basic details of the app are stored in a JSON file
    data = Hash.new

    app_id = KApp.current_application
    data["applicationId"] = app_id

    hostnames = Array.new
    data["hostnames"] = hostnames
    begin
      s = pg.exec("SELECT hostname FROM public.applications WHERE application_id=#{app_id}")
      s.each do |row|
        hostnames << row.first
      end
      s.clear
    end

    File.open("#{filename_base}.json",'w') do |file|
      file.write JSON.pretty_generate(data)
    end

    # ---------------------------------------------------------------------------------------------

    # Dump the application's schema from the database
    dump_cmd = "pg_dump --schema=a#{app_id} --no-owner #{KFRAMEWORK_DATABASE_NAME} | gzip -9 - > #{filename_base}.sql.gz"
    remote_process.remote_system dump_cmd

    # ---------------------------------------------------------------------------------------------

    # Tar up the files
    tgz_file = "#{File.expand_path(filename_base)}.tgz"
    if files_export
      remote_process.remote_system "cd #{StoredFile.disk_root}; tar cf - . | gzip -9 - > #{tgz_file}"
    else
      # Make an empty .tgz file to make import easier
      empty_dirname = "/tmp/k_export_blank_dir_#{Process.pid}_#{Thread.current.__id__}"
      FileUtils.mkdir(empty_dirname)
      remote_process.remote_system "cd #{empty_dirname}; tar cf - . | gzip - > #{tgz_file}"
      FileUtils.rmdir(empty_dirname)
    end
  end

end

