# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



# Provide utility functions to KQueryClause JavaScript objects

module JSConvertSupport
  java_import java.util.GregorianCalendar
  java_import java.util.Calendar

  def self.convertJavaDateToRuby(value)
    return nil if value == nil
    if value.kind_of?(java.util.Date)
      c = GregorianCalendar.new
      c.setTime(value)
      Time.new(c.get(Calendar::YEAR), c.get(Calendar::MONTH) + 1, c.get(Calendar::DAY_OF_MONTH),
          c.get(Calendar::HOUR_OF_DAY), c.get(Calendar::MINUTE), c.get(Calendar::SECOND))
    else
      nil
    end
  end

end

Java::OrgHaploJavascript::JsConvert.setRubyInterface(JSConvertSupport)
