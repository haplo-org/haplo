# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class UserDataTest < Test::Unit::TestCase

  def test_kdatetime3

    # TODO: Check all the bad creations exception properly

    # Check all the different input value classes for construction
    d1 = KDateTime.new("2011") # String
    assert_equal KConstants::T_DATETIME, d1.k_typecode
    assert_equal 'Y', d1.precision
    assert_equal nil, d1.timezone
    assert_equal ['2011', '', 'Y', ''], d1.keditor_values
    assert_equal '2011', d1.to_s
    assert_equal ['2011-01-01 00:00:00', '2012-01-01 00:00:00'], d1.range_pg
    assert_equal DateTime.new(2011, 7, 2, 12, 0), d1.midpoint_datetime
    assert_equal DateTime.new(2011, 1, 1, 0, 0), d1.start_datetime

    assert d1 == d1
    assert d1 != KDateTime.new("2011", "2012")

    d2 = KDateTime.new([2011, 12, 27]) # Array of ints
    assert_equal 'd', d2.precision
    assert_equal ['2011 12 27', '', 'd', ''], d2.keditor_values
    assert_equal '27 Dec 2011', d2.to_s
    assert_equal ['2011-12-27 00:00:00', '2011-12-28 00:00:00'], d2.range_pg
    assert_equal DateTime.new(2011, 12, 27, 12, 0), d2.midpoint_datetime

    d3 = KDateTime.new(DateTime.new(2011, 10, 19, 21, 24)) # DateTime
    assert_equal 'm', d3.precision
    assert_equal ['2011 10 19 21 24', '', 'm', ''], d3.keditor_values
    assert_equal '19 Oct 2011, 21:24', d3.to_s
    assert_equal ['2011-10-19 21:24:00', '2011-10-19 21:25:00'], d3.range_pg
    assert_equal DateTime.new(2011, 10, 19, 21, 24, 30), d3.midpoint_datetime # includes 30 secs

    d3b = KDateTime.new(Date.new(2010, 11, 9)) # Date
    assert_equal 'd', d3b.precision
    assert_equal ['2010 11 9', '', 'd', ''], d3b.keditor_values
    assert_equal '09 Nov 2010', d3b.to_s
    assert_equal ['2010-11-09 00:00:00', '2010-11-10 00:00:00'], d3b.range_pg
    assert_equal DateTime.new(2010, 11, 9, 12, 0), d3b.midpoint_datetime

    d4 = KDateTime.new(Time.utc(2011, 9, 12, 14, 23)) # Time
    assert_equal 'm', d4.precision
    assert_equal ['2011 9 12 14 23', '', 'm', ''], d4.keditor_values
    assert_equal '12 Sep 2011, 14:23', d4.to_s
    assert_equal ['2011-09-12 14:23:00', '2011-09-12 14:24:00'], d4.range_pg
    assert_equal DateTime.new(2011, 9, 12, 14, 23, 30), d4.midpoint_datetime

    # Check truncation
    d5 = KDateTime.new(DateTime.new(2011, 10, 20, 21, 24), nil, 'd')
    assert_equal 'd', d5.precision
    assert_equal ['2011 10 20', '', 'd', ''], d5.keditor_values
    assert_equal '20 Oct 2011', d5.to_s
    assert_equal ['2011-10-20 00:00:00', '2011-10-21 00:00:00'], d5.range_pg
    assert_equal DateTime.new(2011, 10, 20, 12, 00), d5.midpoint_datetime
    d6 = KDateTime.new("2011", nil, 'D')
    assert_equal ['2010', '', 'D', ''], d6.keditor_values
    assert_equal '2010s', d6.to_s
    assert_equal ['2010-01-01 00:00:00', '2020-01-01 00:00:00'], d6.range_pg
    assert_equal DateTime.new(2015, 1, 1, 0, 0), d6.midpoint_datetime
    d7 = KDateTime.new("1986", nil, 'C')
    assert_equal ['1900', '', 'C', ''], d7.keditor_values
    assert_equal '1900c', d7.to_s
    assert_equal ['1900-01-01 00:00:00', '2000-01-01 00:00:00'], d7.range_pg
    assert_equal DateTime.new(1950, 1, 1, 0, 0), d7.midpoint_datetime
    d8 = KDateTime.new("2019 10 23", nil, 'Y')
    assert_equal ['2019', '', 'Y', ''], d8.keditor_values
    assert_equal '2019', d8.to_s
    assert_equal ['2019-01-01 00:00:00', '2020-01-01 00:00:00'], d8.range_pg
    assert_equal DateTime.new(2019, 7, 2, 12, 0), d8.midpoint_datetime

    # Check range creation
    d10 = KDateTime.new("2011 10 19", "2011 10 23")
    assert_equal 'd', d10.precision
    assert_equal ["2011 10 19", "2011 10 23", 'd', ''], d10.keditor_values
    assert_equal '19 to end of 23 Oct 2011', d10.to_s
    assert_equal '<span class="z__object_date_value"><span>19</span> <i>to end of</i> <span>23</span> <span>Oct 2011</span></span>', d10.to_html
    assert_equal ['2011-10-19 00:00:00', '2011-10-24 00:00:00'], d10.range_pg
    assert_equal DateTime.new(2011, 10, 21, 12, 0), d10.midpoint_datetime
    # And it'll reverse them if the second is later than the first
    d11 = KDateTime.new("2011 10 10", "2011 10 08")
    assert_equal ['2011 10 8', '2011 10 10', 'd', ''], d11.keditor_values
    assert_equal '08 to end of 10 Oct 2011', d11.to_s
    assert_equal ['2011-10-08 00:00:00', '2011-10-11 00:00:00'], d11.range_pg
    assert_equal DateTime.new(2011, 10, 9, 12, 0), d11.midpoint_datetime
    # And using the same one is OK
    d12 = KDateTime.new("2011 10 08 7", "2011 10 08 07")
    assert_equal 'h', d12.precision
    assert_equal ['2011 10 8 7', '2011 10 8 7', 'h', ''], d12.keditor_values
    assert_equal '08 Oct 2011, from 07:00 to 07:00', d12.to_s
    assert_equal ['2011-10-08 07:00:00', '2011-10-08 07:00:00'], d12.range_pg # not extended by precision time unit
    assert_equal DateTime.new(2011, 10, 8, 7, 0), d12.midpoint_datetime # midpoint is between non-extended end points
    # Hour time unit ranges aren't extended for ranges
    d13 = KDateTime.new("2065 4 2 1", "2065 4 2 4")
    assert_equal 'h', d13.precision
    assert_equal ["2065 4 2 1", "2065 4 2 4", 'h', ''], d13.keditor_values
    assert_equal '02 Apr 2065, from 01:00 to 04:00', d13.to_s
    assert_equal '<span class="z__object_date_value"><span>02 Apr 2065</span>, <i>from</i> <span>01:00</span> <i>to</i> <span>04:00</span></span>', d13.to_html
    assert_equal ['2065-04-02 01:00:00', '2065-04-02 04:00:00'], d13.range_pg # not extended by precision time unit
    # Minute time unit ranges aren't extended either
    d14 = KDateTime.new("2065 4 2 1 2", "2065 4 2 4 9")
    assert_equal 'm', d14.precision
    assert_equal ["2065 4 2 1 2", "2065 4 2 4 9", 'm', ''], d14.keditor_values
    assert_equal '02 Apr 2065, from 01:02 to 04:09', d14.to_s
    assert_equal ['2065-04-02 01:02:00', '2065-04-02 04:09:00'], d14.range_pg # not extended by precision time unit

    # Check range roll-over
    d20 = KDateTime.new("2011 10 17 23 59")
    assert_equal ['2011-10-17 23:59:00', '2011-10-18 00:00:00'], d20.range_pg
    assert_equal DateTime.new(2011, 10, 17, 23, 59, 30), d20.midpoint_datetime

    # Check timezone support
    d30 = KDateTime.new("2011 11 23 13 40", nil, 'm', 'America/New_York')
    assert_equal 'm', d30.precision
    assert_equal 'America/New_York', d30.timezone
    assert_equal ['2011 11 23 13 40', '', 'm', 'America/New_York'], d30.keditor_values
    assert_equal '2011-11-23T18:40:00+00:00', d30.start_datetime.to_s # includes check it has +00:00 timezone
    assert_equal '2011-11-23T18:40:30+00:00', d30.midpoint_datetime.to_s
    assert_equal ['2011-11-23 18:40:00', '2011-11-23 18:41:00'], d30.range_pg
    assert_equal '23 Nov 2011, 13:40 (America/New_York)', d30.to_s
    assert_equal '<span class="z__object_date_value"><span>23 Nov 2011, 13:40</span> (America/New_York)</span>', d30.to_html
    assert_equal '23 Nov 2011, 18:40', d30.to_s('GMT')
    assert_equal '<span class="z__object_date_value"><span>23 Nov 2011, 18:40</span></span>', d30.to_html('GMT')

    # Check equality with timezones
    d30_n = KDateTime.new("2011 11 23 13 40", nil, 'm')
    assert d30_n != d30 # check equality with timezones
    assert d30 == KDateTime.new("2011 11 23 13 40", nil, 'm', 'America/New_York')

    # Check ranges with timezones
    d31 = KDateTime.new("2011 11 24 23 40", "2011 11 26 12 50", 'm', 'Asia/Tokyo')
    assert_equal ["2011 11 24 23 40", "2011 11 26 12 50", 'm', 'Asia/Tokyo'], d31.keditor_values
    assert_equal '24 Nov 2011, 23:40 to 26 Nov 2011, 12:50 (Asia/Tokyo)', d31.to_s
    assert_equal '<span class="z__object_date_value"><span>24 Nov 2011, 23:40</span> <i>to</i> <span>26 Nov 2011, 12:50</span> (Asia/Tokyo)</span>', d31.to_html
    assert_equal '24 Nov 2011, 15:40 to 26 Nov 2011, 04:50', d31.to_s('Europe/Berlin')
    assert_equal '<span class="z__object_date_value"><span>24 Nov 2011, 15:40</span> <i>to</i> <span>26 Nov 2011, 04:50</span></span>', d31.to_html('Europe/Berlin')
  end

  # ----------------------------------------------------------------------------------------------------

  def test_range_to_string_and_html
    [
      ['1901', '2001', 'C', '1900c to end of 2000c', '<span>1900c</span> <i>to end of</i> <span>2000c</span>'],
      ['1901', '1901', 'C', '1900c to end of 1900c', '<span>1900c</span> <i>to end of</i> <span>1900c</span>'],
      ['1901', '2001', 'D', '1900s to end of 2000s', '<span>1900s</span> <i>to end of</i> <span>2000s</span>'],
      ['1901', '1901', 'D', '1900s to end of 1900s', '<span>1900s</span> <i>to end of</i> <span>1900s</span>'],
      ['1901', '2001', 'Y', '1901 to end of 2001', '<span>1901</span> <i>to end of</i> <span>2001</span>'],
      ['1901', '1901', 'Y', '1901 to end of 1901', '<span>1901</span> <i>to end of</i> <span>1901</span>'],
      ['2011 1', '2011 4', 'M', 'Jan to end of Apr 2011', '<span>Jan</span> <i>to end of</i> <span>Apr</span> <span>2011</span>'],
      ['2011 1', '2020 4', 'M', 'Jan 2011 to end of Apr 2020', '<span>Jan 2011</span> <i>to end of</i> <span>Apr 2020</span>'],
      ['2011 1 12', '2011 4 13', 'd', '12 Jan 2011 to end of 13 Apr 2011', '<span>12 Jan 2011</span> <i>to end of</i> <span>13 Apr 2011</span>'],
      ['2011 1 12', '2011 1 12', 'd', '12 to end of 12 Jan 2011', '<span>12</span> <i>to end of</i> <span>12</span> <span>Jan 2011</span>'],
      ['2011 1 12', '2011 1 14', 'd', '12 to end of 14 Jan 2011', '<span>12</span> <i>to end of</i> <span>14</span> <span>Jan 2011</span>'],
      ['2011 1 12 13', '2011 1 12 14', 'h', '12 Jan 2011, from 13:00 to 14:00', '<span>12 Jan 2011</span>, <i>from</i> <span>13:00</span> <i>to</i> <span>14:00</span>'],
      ['2011 1 12 15', '2011 2 13 16', 'h', '12 Jan 2011, 15:00 to 13 Feb 2011, 16:00', '<span>12 Jan 2011, 15:00</span> <i>to</i> <span>13 Feb 2011, 16:00</span>'],
      ['2011 1 12 13 2', '2011 1 12 14 3', 'm', '12 Jan 2011, from 13:02 to 14:03', '<span>12 Jan 2011</span>, <i>from</i> <span>13:02</span> <i>to</i> <span>14:03</span>'],
      ['2011 1 12 15 5', '2011 2 13 16 6', 'm', '12 Jan 2011, 15:05 to 13 Feb 2011, 16:06', '<span>12 Jan 2011, 15:05</span> <i>to</i> <span>13 Feb 2011, 16:06</span>']
    ].each do |s, e, p, str, html|
      d = KDateTime.new(s, e, p)
      assert_equal str, d.to_s
      assert_equal %Q!<span class="z__object_date_value">#{html}</span>!, d.to_html
    end
  end

end
