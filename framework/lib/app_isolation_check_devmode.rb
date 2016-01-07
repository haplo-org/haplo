# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# In development mode, check the postgres search path is correct
if KFRAMEWORK_ENV == 'development'

  module ActiveRecord
    class Base
      class << self
        @@_app_isolation_lock = Mutex.new
        @@_app_isolation_db_con_check = Hash.new
        alias_method :orig_connection, :connection
        def connection
          c = orig_connection
          statement = c.raw_connection.connection.createStatement()
          sp = statement.executeQuery("SHOW search_path")
          sp.next()
          search_path = sp.getString(1)
          sp.close()
          statement.close()
          # Check the search path
          app_id = KApp.current_application
          expected_search_path = if app_id == :no_app
            "public"
          elsif app_id.kind_of? Integer
            "a#{app_id}, public"
          else
            raise "Bad app_id"
          end
          if expected_search_path != search_path
            raise "PG database wasn't set to expected search path. Expected '#{expected_search_path}', got '#{search_path}'"
          end
          # Check the postgres backend pid hasn't changed underneath - detects funny games with pooling
          statement = c.raw_connection.connection.createStatement()
          sp = statement.executeQuery("SELECT pg_backend_pid()")
          sp.next()
          pgpid = sp.getString(1)
          sp.close()
          statement.close()
          @@_app_isolation_lock.synchronize do
            cid = c.object_id
            if @@_app_isolation_db_con_check.has_key?(cid)
              if @@_app_isolation_db_con_check[cid] != pgpid
                raise "PG connection has had underlying backend pid change #{@@_app_isolation_db_con_check[cid]} -> #{pgpid}"
              end
            else
              @@_app_isolation_db_con_check[cid] = pgpid
            end
          end
          c
        end
      end
    end
  end

end

