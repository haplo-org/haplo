# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KHostname
  unless ENV.has_key?('KSERVER_HOSTNAME')
    raise "KSERVER_HOSTNAME not set in environment - check paths-<OS>.sh file"
  end

  @@domainname = nil

  def self.ensure_setup
    return if @@domainname
    domainname = KInstallProperties.get(:domainname)
    @@hostname = ENV['KSERVER_HOSTNAME'].gsub(/\.local\z/i,'').chomp.downcase
    raise "Host name not set" unless @@hostname =~ /\S/
    # Append domainname to hostname
    @@hostname = "#{@@hostname}.#{domainname}"
    @@domainname = domainname # set last to avoid concurrency issues
  end

  def self.hostname
    ensure_setup()
    @@hostname
  end
  def self.domainname
    ensure_setup()
    @@domainname
  end
end
