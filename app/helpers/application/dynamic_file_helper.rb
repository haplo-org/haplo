# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module Application_DynamicFileHelper

  # REMOVE_ON_PROCESS_BEGIN

  def dynamic_stylesheet_path(filename)
    mtime = File.stat(File.dirname(__FILE__) + "/../../../static/stylesheets/#{filename}.css").mtime.to_i
    "/~devcss#{KApp.global(:appearance_update_serial)}/#{filename}.css?#{mtime}"
  end

  def dynamic_image_path(filename)
    "/~devimg#{KApp.global(:appearance_update_serial)}/#{filename}"
  end

  if false
  # REMOVE_ON_PROCESS_END
  def dynamic_stylesheet_path(filename)
    "/~#{KApp.global(:appearance_update_serial)}/#{filename}.css"
  end
  def dynamic_image_path(filename)
    "/~#{KApp.global(:appearance_update_serial)}/#{filename}"
  end
  # REMOVE_ON_PROCESS_BEGIN
  end
  # REMOVE_ON_PROCESS_END

end

