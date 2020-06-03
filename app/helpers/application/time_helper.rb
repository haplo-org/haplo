# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module Application_TimeHelper

  TIMEZONE_NAMES = TZInfo::TIMEZONE_NAMES

  # Formatting time for the current user
  def time_format_local(time, format)
    TZInfo::Timezone.get(time_user_timezone).utc_to_local(time).to_s(format)
  end

  def time_user_timezone
    @request_user.get_user_data(UserData::NAME_TIME_ZONE) || KDisplayConfig::DEFAULT_TIME_ZONE
  end

  def time_zone_list
    (KApp.global(:timezones) || KDisplayConfig::DEFAULT_TIME_ZONE_LIST).split(',')
  end

  def time_attribute_should_be_local_time(desc)
    schema = KObjectStore.schema
    d = schema.attribute_descriptor(desc) || schema.aliased_attribute_descriptor(desc)
    return false if d == nil || d.data_type != KConstants::T_DATETIME
    options = (d.ui_options || KConstants::DEFAULT_UI_OPTIONS_DATETIME).split(',')
    # TODO: Handle date time UI options in a more elegant manner for rendering
    (options[4] == 'y')
  end

end

