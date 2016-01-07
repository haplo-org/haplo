# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KScheduledTasks

  KFramework.scheduled_task_register(
    "latestemails", "Send latest updates emails",
    6, 30, KFramework::SECONDS_IN_DAY,   # Once a day at 6:30am
    proc { KScheduledTasks.send_latest_emails }
  )

  def self.send_latest_emails
    KApp.logger.info "#{Time.now.to_s}: Starting latest updates email sending"
    KApp.in_every_application do
      begin
        LatestEmailSender.new.send_all
      rescue => e
        KApp.logger.log_exception(e)
      end
      KApp.logger.flush_buffered
    end
  end

end


class LatestEmailSender
  include LatestUtils

  # Do latest updates from 5am - 5am
  CUT_OFF_HOUR = 5

  def send_all
    today = Time.now
    base_time = Time.local(today.year, today.month, today.day, CUT_OFF_HOUR, 0)

    emails_sent = 0
    application_send_start = Time.now

    feature_name = KApp.global(:name_latest).capitalize

    templates = Hash.new

    User.find(:all, :conditions => "kind=#{User::KIND_USER}").each do |user|

      schedule = UserData.get(user, UserData::NAME_LATEST_EMAIL_SCHEDULE) || UserData::Latest::DEFAULT_SCHEDULE
      start_time = latest_start_time_for_email(schedule, base_time)

      if start_time != nil
        next unless user.policy.can_use_latest?

        controller = ApplicationController.make_background_controller(user)

        AuthContext.with_user(user, user) do
          # Find relevant objects constrained to date range
          requests = requests_by(user)
          query = query_from_requests requests
          query.constrain_to_time_interval(start_time, base_time)
          results = query.execute(:all, :date)

          email_format = (user.get_user_data(UserData::NAME_LATEST_EMAIL_FORMAT) == UserData::Latest::FORMAT_HTML) ? :html : :plain

          # Render objects
          items = ''
          results.each do |obj|
            items << controller.render_obj(obj, :latest_email_html)
          end
          if items == ''
            items = '<p>There are no items in this update.</p>'
          end

          unsub_token = KRandom.random_hex(KRandom::TOKEN_FOR_EMAIL_LENGTH)
          user.set_user_data(UserData::NAME_LATEST_UNSUB_TOKEN, unsub_token)

          email_template_id = user.get_user_data(UserData::NAME_LATEST_EMAIL_TEMPLATE) || EmailTemplate::ID_LATEST_UPDATES
          email_template = templates[email_template_id]
          if email_template == nil
            email_template = EmailTemplate.find(email_template_id)
            templates[email_template_id] = email_template
          end

          email_template.deliver(
            :to => user,
            :subject => feature_name,
            :message => items,
            :format => email_format,
            :interpolate => {
              'FEATURE_NAME' => feature_name,
              'UNSUBSCRIBE_URL' => %Q!#{KApp.url_base(:visible)}/do/unsubscribe/latest/#{user.id}?t=#{unsub_token}!
            }
          )

          emails_sent += 1
        end
      end
    end

    KApp.logger.info "Sent #{emails_sent} emails in #{Time.now - application_send_start} seconds for application #{KApp.current_application} (#{KApp.global(:url_hostname)})"
  end
end

