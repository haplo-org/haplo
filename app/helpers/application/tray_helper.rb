# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module Application_TrayHelper
  include KConstants

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
