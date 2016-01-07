# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class UserPolicy

  def can_search_subset_be_used?(search_subset)
    # Allow if all *include* labels allowed for read
    permissions = @user.permissions
    allowed = true
    search_subset.each(KConstants::A_INCLUDE_LABEL) do |value,d,q|
      allowed = false unless permissions.label_is_allowed?(:read, value)
    end
    allowed
  end

end

