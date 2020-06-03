# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Time
  DATE_FORMATS = {
    :rfc822    => "%a, %d %b %Y %H:%M:%S +0000", # always UTC
    :obj_dates => '%d/%m/%Y',
    :date_only => '%d %b %Y',
    :date_and_time => '%d %b %Y, %H:%M',
    :date_only_full_month => '%d %B %Y'
  }

  def to_formatted_s(format = :default)
    formatter = DATE_FORMATS[format]
    formatter ? strftime(formatter) : self.to_default_s
  end
  alias_method :to_default_s, :to_s
  alias_method :to_s, :to_formatted_s

  def to_iso8601_s
    # strftime doesn't do %z in a ISO8601 compatible way, preferring RFC822.
    strftime('%Y-%m-%dT%H:%M:%S%z').gsub(/([-+])(\d\d)(\d\d)$/,'\1\2:\3')
  end
end
