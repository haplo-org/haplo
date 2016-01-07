# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KHooks

  define_hook :hScheduleHourly do |h|
    h.argument    :year,        Fixnum,   "Year, four digits"
    h.argument    :month,       Fixnum,   "Month, 0 - 11"
    h.argument    :dayOfMonth,  Fixnum,   "Day of the month, 1 - 31"
    h.argument    :hour,        Fixnum,   "Hour of the day, 0 - 23"
    h.argument    :dayOfWeek,   Fixnum,   "Day of the week, 0 (Sunday) - 6 (Saturday)"
  end

  define_hook :hScheduleDailyMidnight do |h|
    h.argument    :year,        Fixnum,   "Year, four digits"
    h.argument    :month,       Fixnum,   "Month, 0 - 11"
    h.argument    :dayOfMonth,  Fixnum,   "Day of the month, 1 - 31"
    h.argument    :hour,        Fixnum,   "Hour of the day, 0 - 23"
    h.argument    :dayOfWeek,   Fixnum,   "Day of the week, 0 (Sunday) - 6 (Saturday)"
  end

  define_hook :hScheduleDailyEarly do |h|
    h.argument    :year,        Fixnum,   "Year, four digits"
    h.argument    :month,       Fixnum,   "Month, 0 - 11"
    h.argument    :dayOfMonth,  Fixnum,   "Day of the month, 1 - 31"
    h.argument    :hour,        Fixnum,   "Hour of the day, 0 - 23"
    h.argument    :dayOfWeek,   Fixnum,   "Day of the week, 0 (Sunday) - 6 (Saturday)"
  end

  define_hook :hScheduleDailyMidday do |h|
    h.argument    :year,        Fixnum,   "Year, four digits"
    h.argument    :month,       Fixnum,   "Month, 0 - 11"
    h.argument    :dayOfMonth,  Fixnum,   "Day of the month, 1 - 31"
    h.argument    :hour,        Fixnum,   "Hour of the day, 0 - 23"
    h.argument    :dayOfWeek,   Fixnum,   "Day of the week, 0 (Sunday) - 6 (Saturday)"
  end

  define_hook :hScheduleDailyLate do |h|
    h.argument    :year,        Fixnum,   "Year, four digits"
    h.argument    :month,       Fixnum,   "Month, 0 - 11"
    h.argument    :dayOfMonth,  Fixnum,   "Day of the month, 1 - 31"
    h.argument    :hour,        Fixnum,   "Hour of the day, 0 - 23"
    h.argument    :dayOfWeek,   Fixnum,   "Day of the week, 0 (Sunday) - 6 (Saturday)"
  end

end
