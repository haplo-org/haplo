# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module MiniORM

  def self.transaction
    KApp.with_jdbc_database do |db|
      Java::OrgHaploFramework::Database.execute(db, "BEGIN")
      begin
        yield
        Java::OrgHaploFramework::Database.execute(db, "COMMIT")
      rescue
        Java::OrgHaploFramework::Database.execute(db, "ROLLBACK")
        raise
      end
    end
  end

end
