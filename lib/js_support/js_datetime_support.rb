# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Provide utility functions to KDateTime JavaScript objects

module JSKDateTimeSupport

  # Create new Ruby datetime object
  def self.construct(startDate, endDate, precision, timezone)
    KDateTime.new(startDate, endDate, precision, timezone)
  end

end

Java::ComOneisJsinterface::KDateTime.setRubyInterface(JSKDateTimeSupport)
