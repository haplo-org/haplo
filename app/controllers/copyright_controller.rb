# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class CopyrightController < ApplicationController
  policies_required nil

  def handle_index
    version_pathname = "#{KFRAMEWORK_ROOT}/VERSION.txt"
    text = if File.exist?(version_pathname)
      "Version: #{File.open(version_pathname) { |f| f.read[0,10] }}"
    else
      'DEVELOPMENT VERSION'
    end
    @page_creation_label_html = h(text)
  end
end
