# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class FileCacheEntry < MiniORM::Record
  table :file_cache_entries do |t|
    t.column :timestamp, :created_at
    t.column :timestamp, :last_access
    t.column :int, :access_count
    t.column :int, :stored_file_id
    t.column :text, :output_mime_type
    t.column :text, :output_options
  end

  def self.for(stored_file, output_mime_type = nil, output_options = nil)
    e = where({
      :stored_file_id => stored_file.id,
      :output_mime_type => output_mime_type || '',
      :output_options => output_options || ''
    }).first
    # Check the file exists -- might be in the process of being created
    return nil unless e != nil && File.exists?(e.disk_pathname)
    e
  end

  def update_usage_info!
    raise "Not saved" if self.id == nil
    KApp.with_pg_database do |db|
      db.perform("BEGIN; SET LOCAL synchronous_commit TO OFF; UPDATE #{KApp.db_schema_name}.file_cache_entries SET last_access=NOW(), access_count=access_count+1 WHERE id=#{self.id.to_i}; COMMIT")
    end
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
  def after_delete
    pathname = self.disk_pathname
    if File.exists?(pathname)
      File.unlink(pathname)
    end
  end

  def self.short_path_component(id)
    raise "negative int for short_path_component" if id < 0
    leaf = id & 0xff
    e = id >> 8
    p = ''.dup
    while e > 0
      p << sprintf("%02x/", e & 0xff)
      e >>= 8
    end
    p + sprintf("%02x.o", leaf)
  end
end

