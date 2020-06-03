# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module Admin_UserHelper

  def user_html(user)
    %Q!<div class="#{user.kind.to_i == User::KIND_GROUP ? 'z__mng_group_display' : 'z__mng_user_display'}">#{h(user.name)}</div>!
  end

end
