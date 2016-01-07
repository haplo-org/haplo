# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class FileCacheEntry < ActiveRecord::Base
  after_destroy :delete_files_on_disk

  def self.for(stored_file, output_mime_type = nil, output_options = nil)
    e = find(:first,
      :conditions => ['stored_file_id=? AND output_mime_type=? AND output_options=?',
        stored_file.id, output_mime_type || '', output_options || '']
      )
    # Check the file exists -- might be in the process of being created
    return nil unless e != nil && File.exists?(e.disk_pathname)
    e
  end

  def update_usage_info!
    raise "Not saved" if self.id == nil
    KApp.get_pg_database.perform("BEGIN; SET LOCAL synchronous_commit TO OFF; UPDATE file_cache_entries SET last_access=NOW(), access_count=access_count+1 WHERE id=#{self.id.to_i}; COMMIT")
  end

  # Get the name of the file on disk
  def disk_pathname
    "#{KFILESTORE_PATH}/#{KApp.current_application}/cache/#{FileCacheEntry.short_path_component(self.id)}"
  end

  def ensure_target_directory_exists
    cache_pathname = self.disk_pathname

    dirname = File.dirname(cache_pathname)
    unless File.exists?(dirname)
      FileUtils.mkdir_p(dirname, :mode => StoredFile::DIRECTORY_CREATION_MODE)
    end
    raise "Unexpected file where a directory was expected for #{dirname}" unless File.directory?(dirname)
  end

  # Clean up when deleting objects
  # after_destroy
  def delete_files_on_disk
    pathname = self.disk_pathname
    if File.exists?(pathname)
      File.unlink(pathname)
    end
  end

  def self.short_path_component(id)
    raise "negative int for short_path_component" if id < 0
    leaf = id & 0xff
    e = id >> 8
    p = ''
    while e > 0
      p << sprintf("%02x/", e & 0xff)
      e >>= 8
    end
    p + sprintf("%02x.o", leaf)
  end
end

