# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# This file extends various parts of Ruby and Rails.
# ----------------------------------------------------------------------------------------

# Atom feeds need to send dates in ISO8601.


# Native inbuilt formatter for dates won't work, so can't do this:
#   ActiveSupport::CoreExtensions::Time::Conversions::DATE_FORMATS.update(:iso8601 => '%Y-%m-%dT%H:%M:%S%z') # BAD!
# Instead...
class Time
  def to_iso8601_s
    # strftime doesn't do %z in a ISO8601 compatible way, preferring RFC822. So correct it.
    strftime('%Y-%m-%dT%H:%M:%S%z').gsub(/([-+])(\d\d)(\d\d)$/,'\1\2:\3')
  end
end
class Date
  def to_iso8601_s
    # strftime doesn't do %z in a ISO8601 compatible way, preferring RFC822. So correct it.
    strftime('%Y-%m-%dT%H:%M:%S%z').gsub(/([-+])(\d\d)(\d\d)$/,'\1\2:\3')
  end
end


K_EMAIL_VALIDATION_REGEX = /\A[a-zA-Z0-9!\#$%*\/?\|\^{}`~&'+=_\.-]+\@[a-zA-Z0-9-]+\.[a-zA-Z0-9\.-]+\z/

class ActiveRecord::Base

  # Validate email addresses
  def self.validates_email_format(field, options = {})
    validates_each field, options do |model,attr,value|
      if !(value =~ K_EMAIL_VALIDATION_REGEX)
        model.errors.add(attr, 'is not a valid email address')
      end
    end
  end

end

