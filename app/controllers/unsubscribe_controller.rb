# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class UnsubscribeController < ApplicationController
  policies_required nil

  # --------------------------------------------------------
  # Handle unsubscribe links in emails
  _GetAndPost
  def handle_latest
    @token = params['t']
    @unsub_user = User.read(params['id'].to_i)
    @token_ok = (@token == UserData.get(@unsub_user, UserData::NAME_LATEST_UNSUB_TOKEN))
    if @token_ok && request.post?
      # Do instant unsubscribe -- set email frequency to never
      settings = UserData.get(@unsub_user, UserData::NAME_LATEST_EMAIL_SCHEDULE) || UserData::Latest::DEFAULT_SCHEDULE
      settings_a = settings.split(/:/)
      settings_a[0] = UserData::Latest::SCHEDULE_NEVER
      UserData.set(@unsub_user, UserData::NAME_LATEST_EMAIL_SCHEDULE, settings_a.join(':'))
      @done_update = true
    end
  end
end

