# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class LatestUpdatesEmailsTest < Test::Unit::TestCase
  include LatestUtils
  include UserData::Latest

  # TODO: Add tests for latest updates emails which test that settings for users are followed, and the right objects added to it

  def test_schedule
    # Some sample dates
    wed_28_feb_07 = Time.local(2007, 2, 28, 5, 0)
    fri_4_jan = Time.local(2008, 1, 4, 5, 0)
    sat_5_jan = Time.local(2008, 1, 5, 5, 0)
    mon_7_jan = Time.local(2008, 1, 7, 5, 0)
    mon_28_jan = Time.local(2008, 1, 28, 5, 0)
    weds_30_jan = Time.local(2008, 1, 30, 5, 0)
    thurs_31_jan = Time.local(2008, 1, 31, 5, 0)
    fri_29_feb = Time.local(2008, 2, 29, 5, 0)
    wed_15_apr = Time.local(2008, 4, 15, 5, 0)
    thurs_16_apr = Time.local(2008, 4, 16, 5, 0)

    # Never
    assert_equal nil, latest_start_time_for_email("#{SCHEDULE_NEVER}:0:1:1", fri_4_jan)

    # Very simple daily schedule
    assert_equal Time.local(2008, 1, 3, 5, 0), latest_start_time_for_email("#{SCHEDULE_DAILY}:0:1:1", fri_4_jan)
    assert_equal Time.local(2008, 1, 4, 5, 0), latest_start_time_for_email("#{SCHEDULE_DAILY}:0:1:1", sat_5_jan)
    assert_equal nil, latest_start_time_for_email("#{SCHEDULE_DAILY}:1:1:1", sat_5_jan) # not on weekends
    assert_equal Time.local(2008, 1, 4, 5, 0), latest_start_time_for_email("#{SCHEDULE_DAILY}:1:1:1", mon_7_jan) # mondays get all the weekend along with Friday

    # Weekly
    assert_equal Time.local(2007, 12, 28, 5, 0), latest_start_time_for_email("#{SCHEDULE_WEEKLY}:0:5:1", fri_4_jan)
    assert_equal nil, latest_start_time_for_email("#{SCHEDULE_WEEKLY}:0:4:1", fri_4_jan)
    assert_equal Time.local(2008, 1, 21, 5, 0), latest_start_time_for_email("#{SCHEDULE_WEEKLY}:0:1:1", mon_28_jan)
    assert_equal nil, latest_start_time_for_email("#{SCHEDULE_WEEKLY}:0:1:1", weds_30_jan)
    assert_equal nil, latest_start_time_for_email("#{SCHEDULE_WEEKLY}:0:1:1", thurs_31_jan)

    # Monthly
    assert_equal nil, latest_start_time_for_email("#{SCHEDULE_MONTHLY}:0:1:31", fri_4_jan)
    assert_equal Time.local(2007, 12, 31, 5, 0), latest_start_time_for_email("#{SCHEDULE_MONTHLY}:0:1:31", thurs_31_jan)
    assert_equal nil, latest_start_time_for_email("#{SCHEDULE_MONTHLY}:0:1:31", weds_30_jan)
    assert_equal Time.local(2008, 1, 31, 5, 0), latest_start_time_for_email("#{SCHEDULE_MONTHLY}:0:1:31", fri_29_feb)
    # non-leap year
    assert_equal Time.local(2007, 1, 31, 5, 0), latest_start_time_for_email("#{SCHEDULE_MONTHLY}:0:1:31", wed_28_feb_07)

    assert_equal Time.local(2008, 3, 15, 5, 0), latest_start_time_for_email("#{SCHEDULE_MONTHLY}:0:1:15", wed_15_apr)
    assert_equal nil, latest_start_time_for_email("#{SCHEDULE_MONTHLY}:0:1:15", thurs_16_apr)

  end

end

