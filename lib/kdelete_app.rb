# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



require 'digest/md5'

class KAppDelete
  def self.delete_app(hostname,confirm)
    confirm_val = Digest::MD5.hexdigest(hostname)
    if confirm != confirm_val
      puts "Correct confirmation value not supplied."
      puts "To delete the app, use"
      puts "  db/delete_app.sh #{hostname} #{confirm_val}"
      puts "APP NOT DELETED"
      return
    end

    app_id = nil

    # Find the application_id, and remove the hostnames from the app switcher table
    KApp.in_application(:no_app) do
      KApp.with_pg_database do |db|
        # Find app ID and check
        r = db.exec("SELECT application_id FROM public.applications WHERE hostname=$1", hostname)
        raise "Couldn't find application with hostname #{hostname}" if r.length != 1
        app_id = r.first.first.to_i
        raise "Bad app_id" if app_id == 0
        # Remove hostnames
        db.perform("DELETE FROM public.applications WHERE application_id=#{app_id}")
      end
    end

    KApp.update_app_server_mappings

    KApp.clear_all_cached_data_for_app(app_id)

    Java::OrgHaploFramework::Application.forgetApplication(app_id)

    KObjectStore.forget_store(app_id)

    KApp.in_application(:no_app) do
      KApp.with_pg_database do |db|
        # Destroy the schema - wipes the database
        db.perform("DROP SCHEMA a#{app_id} CASCADE")

        # Remove the text index...
        KObjectStore::TEXT_INDEX_FOR_INIT.each do |name|
          db.exec("SELECT oxp_w_remove_index($1,'t')", KObjectStore.get_text_index_path_for_id(app_id, name))
        end
        # ... and the weighting file
        weighting_file = KObjectStore.get_current_weightings_file_pathname_for_id(app_id)
        File.unlink(weighting_file) if File.exist?(weighting_file)
      end
    end

    # Remove all the files
    filestore_path = "#{KFILESTORE_PATH}/#{app_id}"
    FileUtils.rm_r(filestore_path)
  end
end
