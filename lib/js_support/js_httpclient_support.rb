# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Provide utility functions to the HTTPClient

module JSHTTPClientSupport

  def self.scheduleHttpClientJob(callbackName, callbackDataJSON, details)
    job = KHTTPClientJob.new(callbackName, callbackDataJSON, details.to_hash)
    job.submit()
  end

end

Java::OrgHaploHttpclient::HTTPClient.setRubyInterface(JSHTTPClientSupport)
