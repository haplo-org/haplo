# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

module MiniORM
  class MiniORMException < Exception
  end
  class MiniORMRecordNotFoundException < MiniORMException
  end
end

require 'framework/lib/miniorm/transaction'
require 'framework/lib/miniorm/table'
require 'framework/lib/miniorm/query_base'
require 'framework/lib/miniorm/column'
require 'framework/lib/miniorm/record'
require 'framework/lib/miniorm/transfer'
