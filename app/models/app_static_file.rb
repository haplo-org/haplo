# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class AppStaticFile < ActiveRecord::Base
  def self.find_all_without_data
    find(:all, :order => 'id', :select => 'id,filename,mime_type')
  end

  def uploaded_file=(field)
    self.filename = field.getFilename().gsub(/[^\w._-]/,'')
    self.mime_type = field.getMIMEType() || 'application/octet-stream'
    self.data = File.open(field.getSavedPathname()) { |f| f.read }
  end
end
