# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Separate out these utilities into another module
module LatestUtils
  DAYS_IN_MONTHS = [-1, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

  # --------------------------------------------------------
  # Find selected requests for a user
  def requests_by(user)
    # This could probably be written more efficiently
    requests = LatestRequest.find_all_relevant_to_user(user)
    uid = user.id
    user_reqs = Hash.new
    group_reqs = Hash.new
    # Assume that the user has valid sets of request, in that there aren't any excludes masking forced choices
    requests.each do |req|
      ((req.user_id == uid) ? user_reqs : group_reqs)[req.objref] = (req.inclusion != LatestRequest::REQ_EXCLUDE)
    end
    # Merge, overriding group requests with user requests
    merged = group_reqs.merge(user_reqs)
    # Return the requests where the value in merged == true
    requests.delete_if { |req| merged[req.objref] != true }
  end

  # --------------------------------------------------------
  # Turn a request list into a query, ready for further constraints and execution. Constrains to permissions.
  def query_from_requests(requests)
    query = KObjectStore.query_or
    requests.each do |req|
      query.link(req.objref)
    end
    query.add_exclude_labels([KConstants::O_LABEL_STRUCTURE])
    query
  end

  # ---------------------------------------------------------------------
  # Given a schedule and a base time (which is a set time 'today'), return the start time
  # or nil for no email due today.
  def latest_start_time_for_email(schedule, base_time)
    settings_when,
      settings_workdays_only,
      settings_day_of_week,
      settings_day_of_month = schedule.split(':').map {|v| v.to_i}

    # Work out how many days to send
    days_of_updates = 0
    start_time = nil

    case settings_when
    when UserData::Latest::SCHEDULE_NEVER
      # nothing
    when UserData::Latest::SCHEDULE_DAILY
      if settings_workdays_only == 0
        # Simple; always send one day
        days_of_updates = 1
      else
        # Otherwise, is this a working day?
        case base_time.wday
        when 0, 6
          # Don't send anything on a weekend
        when 1
          # Monday; do updates from the weekend too
          days_of_updates = 3
        else
          days_of_updates = 1
        end
      end
    when UserData::Latest::SCHEDULE_WEEKLY
      # Send a week's worth on the specified day
      days_of_updates = (settings_day_of_week == base_time.wday) ? 7 : 0
    when UserData::Latest::SCHEDULE_MONTHLY
      target_day = latest_capped_mday(base_time, settings_day_of_month)
      # Send a month's worth on the specified day
      if target_day == base_time.mday
        # Move back a month
        b = base_time.months_ago(1)
        start_time = Time.local(b.year, b.month, latest_capped_mday(b, settings_day_of_month), b.hour, b.min)
      end
    end

    # Calculate start time, if not calclated already
    start_time = base_time - (days_of_updates * 60 * 60 * 24) if days_of_updates > 0

    start_time
  end

  def latest_capped_mday(time, mday)
    m = time.month
    days_in_this_month = DAYS_IN_MONTHS[m]
    # Cope with leap years
    if m == 2 # feb
      y = time.year
      if ((y % 4 == 0) && (y % 100 != 0)) || (y % 400 == 0)
        days_in_this_month = 29
      end
    end
    (mday > days_in_this_month) ? days_in_this_month : mday
  end

  # ---------------------------------------------------------------------
  # Format info nicely

  def latest_schedule_to_text(schedule)
    settings_when,
      settings_workdays_only,
      settings_day_of_week,
      settings_day_of_month = schedule.split(':').map {|v| v.to_i}
    case settings_when
    when UserData::Latest::SCHEDULE_NEVER
      'Never'
    when UserData::Latest::SCHEDULE_DAILY
      (settings_workdays_only == 0) ? 'Daily' : 'Daily, working days only'
    when UserData::Latest::SCHEDULE_WEEKLY
      "Weekly on #{Date::DAYNAMES[settings_day_of_week]}"
    when UserData::Latest::SCHEDULE_MONTHLY
      "Monthly on #{settings_day_of_month}"
    end
  end

  def latest_format_to_text(format)
    (format == UserData::Latest::FORMAT_PLAIN) ? 'Plain' : 'Formatted'
  end

  # ---------------------------------------------------------------------
  # Handle the settings form -- used by LatestController and
  def latest_settings_form_for_user(user, redirect_on_submit_to, dont_save = false)
    if request.post? && !dont_save
      format = params[:format]
      if format != nil
        UserData.set(user, UserData::NAME_LATEST_EMAIL_FORMAT, format.to_i)
      end
      swhen = params[:when]
      if swhen != nil
        workdays = (params.has_key?(:workdays_only)) ? 1 : 0
        UserData.set(user, UserData::NAME_LATEST_EMAIL_SCHEDULE,
          "#{swhen.to_i}:#{workdays}:#{params[:day_of_week].to_i}:#{params[:day_of_month].to_i}")
      end
      redirect_to redirect_on_submit_to
      return
    end
    @latest_settings_format = UserData.get(user, UserData::NAME_LATEST_EMAIL_FORMAT) || UserData::Latest::DEFAULT_FORMAT
    @latest_settings_schedule = UserData.get(user, UserData::NAME_LATEST_EMAIL_SCHEDULE) || UserData::Latest::DEFAULT_SCHEDULE
    @latest_settings_when,
      @latest_settings_workdays_only,
      @latest_settings_day_of_week,
      @latest_settings_day_of_month = @latest_settings_schedule.split(':').map {|v| v.to_i}
  end
end
