# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# A temporary store for data, accessed via random keys.
# Intended for data to be stored in one session / API key and accessed in another, with the
# random key passed between them as a secure reference.
# Will be deleted if the data is not collected 'soon'.

module KTempDataStore

  # Minimum time to retain some data
  RETAIN_FOR_HOURS = 6

  # Returns a key. Data must be a String
  def self.set(purpose, data)
    raise 'Bad arguments to KTempDataStore' unless (purpose.kind_of?(String) || purpose.kind_of?(Symbol)) && data.kind_of?(String)
    pg = KApp.get_pg_database
    key = KRandom.random_api_key(KRandom::TEMP_DATA_KEY_LENGTH)
    pg.perform("INSERT INTO public.temp_data_store (created_at,key,purpose,data) VALUES(NOW(),$1,$2,E'#{PGconn.escape_bytea(data)}')",
        key, purpose.to_s)
    key
  end

  # Get data given a key and a purpose. Returns nil if it's not found.
  # Deletes the data from the store.
  def self.get(key, purpose)
    raise 'Bad arguments to KTempDataStore' unless key.kind_of?(String) && (purpose.kind_of?(String) || purpose.kind_of?(Symbol))
    pg = KApp.get_pg_database
    results = pg.exec('SELECT id,data FROM public.temp_data_store WHERE key=$1 AND purpose=$2', key, purpose.to_s)
    return nil if results.length != 1
    id_s, data = results.first
    results.clear
    pg.perform('DELETE FROM public.temp_data_store WHERE id=$1', id_s.to_i)
    PGconn.unescape_bytea(data)
  end

  # Housekeeping
  def self.delete_old_data
    KApp.get_pg_database.perform("DELETE FROM public.temp_data_store WHERE created_at < (NOW() - interval '#{RETAIN_FOR_HOURS} hours')")
  end

end

