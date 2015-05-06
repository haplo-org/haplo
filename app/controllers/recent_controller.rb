# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class RecentController < ApplicationController
  include KConstants
  policies_required nil

  NUMBER_OF_ITEMS = 24
  NUMBER_OF_ITEMS_MOBILE = 20

  def handle_index
    @days = recent_get_relevant_audit_entries(NUMBER_OF_ITEMS, nil)
  end

  # AJAX callback when scrolling.
  def handle_more
    @days = recent_get_relevant_audit_entries(NUMBER_OF_ITEMS, params[:t].to_i)
    # Client side sends the text of the last date displayed so it's not repeated in the inserted HTML
    @unnecessary_date_text = (params[:d] || '').gsub(/[^a-zA-Z0-9 ]/,'')
    render :action => 'more', :layout => false
  end

  # ---------------------------------------------------------------------------------------------------------------------------------
private

  RecentDay = Struct.new(:date_text, :day_name_text, :entries)

  def recent_get_relevant_audit_entries(number_of_items, older_than)
    permission_denied unless @request_user.permissions.something_allowed?(:read)
    # Get *displayable* entries from audit trail
    finder = AuditEntry.where_labels_permit(:read, @request_user.permissions).where({:displayable => true}).
      where("user_id <> #{User::USER_SYSTEM}"). # don't include SYSTEM user because it's likely to be just automatic changes
      where("obj_id IS NOT NULL"). # for backwards compatibility with converted applications
      limit(number_of_items).
      order('id DESC');
    finder = finder.where(['id < ?', older_than]) if older_than != nil
    # Timezone info
    tz = TZInfo::Timezone.get(time_user_timezone)
    # Split them into days, using local timezone
    days = []
    current_day = nil
    finder.each do |entry|
      local_time = tz.utc_to_local(entry.created_at)
      date_text = local_time.to_s(:date_only_full_month)
      if current_day == nil || current_day.date_text != date_text
        current_day = RecentDay.new(date_text, local_time.strftime('%A'), [])
        days << current_day
      end
      current_day.entries << entry
    end
    # Return array of RecentDay objects
    days
  end

end
