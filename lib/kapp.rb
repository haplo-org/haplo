# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# KApp is a singleton class which provides:
#
#   * Control of switching which application (customer) is being handled in this request
#   * 'Globals', a set of key/values on per application basis
#   * Caches, a set of containers for other parts of the application to cache data on a per application basis.
#
# ApplicationController calls KApp.switch at the beginning of each request to set which application is used
# by everything else.
#

# TODO: Proper automated tests for application switching and app globals updating

module KApp

  # Find all hostnames for the current application (uses database access)
  def self.all_hostnames_for_current_app
    db = get_pg_database
    r = db.exec("SELECT hostname FROM public.applications WHERE application_id=$1 ORDER BY hostname", current_application)
    all_hostnames = Array.new
    r.each do |a|
      h = a[0].to_s
      all_hostnames << h if h != '*'
    end
    r.clear
    all_hostnames
  end

  # SSL policy
  URL_TYPE = {:anonymous => 0, :logged_in => 1, :visible => 2}  # also supports :unencrypted
  def self.use_ssl_for(url_type)
    # Can override to get unencrypted URLs on demand, regardless of user settings
    return false if url_type == :unencrypted
    (KApp.global(:ssl_policy)[URL_TYPE[url_type]] != 'c')
  end

  # Server ports
  SERVER_PORT_INTERNAL_CLEAR,
  SERVER_PORT_EXTERNAL_CLEAR,
  SERVER_PORT_INTERNAL_ENCRYPTED,
  SERVER_PORT_EXTERNAL_ENCRYPTED = Java::OrgHaploFramework::Boot.getConfiguredListeningPorts(KFRAMEWORK_ENV)
  SERVER_PORT_EXTERNAL_CLEAR_IN_URL =     (SERVER_PORT_EXTERNAL_CLEAR == 80) ?      '' : ":#{SERVER_PORT_EXTERNAL_CLEAR}"
  SERVER_PORT_EXTERNAL_ENCRYPTED_IN_URL = (SERVER_PORT_EXTERNAL_ENCRYPTED == 443) ? '' : ":#{SERVER_PORT_EXTERNAL_ENCRYPTED}"

  # Base of URL for this app, eg 'https://oneis.example.com'
  def self.url_base(url_type = :logged_in)
    self.use_ssl_for(url_type) ?
      "https://#{KApp.global(:ssl_hostname)}#{SERVER_PORT_EXTERNAL_ENCRYPTED_IN_URL}" :
      "http://#{KApp.global(:url_hostname)}#{SERVER_PORT_EXTERNAL_CLEAR_IN_URL}"
  end

end
