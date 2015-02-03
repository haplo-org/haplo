# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module Application_TrayHelper
  include KConstants

  def tray_text_for_tab_with_num_items(n)
    "Tray <span>#{n.to_s}</span>"
  end

  # Returns nil if the tray doesn't need to be sent
  def tray_client_side_url
    i = tray_contents_full_info
    if i.contents.empty?
      nil
    else
      "/api/tray/contents/#{i.last_change}/#{@request_user.id}"
    end
  end

end
