# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KeychainCredential < ActiveRecord::Base

  def account
    JSON.parse(self.account_json)
  end
  def account=(info)
    self.account_json = info.to_json
  end

  def secret
    JSON.parse(self.secret_json)
  end
  def secret=(info)
    self.secret_json = info.to_json
  end

end
