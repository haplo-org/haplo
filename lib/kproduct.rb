# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module KProduct

  def self.product_exists?(product_name)
    (product_name == 'haplo' || product_name == 'oneis')
  end

  # Counting logic
  def self.count_users
    User.where(:kind => User::KIND_USER).where_id_is_not(User::USER_ANONYMOUS).count
  end

end
