# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class AppStaticFile < MiniORM::Record
  table :app_static_files do |t|
    t.column :text, :filename
    t.column :text, :mime_type
    t.column :bytea, :data
  end

  # MiniORM doesn't allow reads of partial columns
  StaticFileNoData = Struct.new(:id, :filename, :mime_type)
  def self.select_all_without_data
    KApp.with_pg_database do |db|
      db.perform("SELECT id,filename,mime_type FROM #{KApp.db_schema_name}.app_static_files ORDER BY id").map do |id,filename,mime_type|
        StaticFileNoData.new(id.to_i, filename, mime_type)
      end
    end
  end

  def uploaded_file=(field)
    self.filename = field.getFilename().gsub(/[^\w._-]/,'')
    self.mime_type = field.getMIMEType() || 'application/octet-stream'
    self.data = File.open(field.getSavedPathname()) { |f| f.read }
  end
end
