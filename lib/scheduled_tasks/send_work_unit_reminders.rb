# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KScheduledTasks

  KFramework.scheduled_task_register(
    "work_unit_reminders", "Send work unit reminder emails",
    7, 30, KFramework::SECONDS_IN_DAY,   # Once a day at 7:30am
    proc {
      if Time.now.thursday?
        KScheduledTasks.send_work_unit_reminders
      end
    }
  )

  def self.send_work_unit_reminders
    KApp.logger.info "#{Time.now.to_s}: Starting work unit reminders email sending"
    KApp.in_every_application do
      begin
        WorkUnitRemindersSender.new.send_all
      rescue => e
        KApp.logger.log_exception(e)
      end
      KApp.logger.flush_buffered
    end
  end

end


# TODO: Better implementation of work unit reminders, including the way plugins render the entries for the email.
class WorkUnitRemindersSender
  include Application_TextHelper

  def send_all

    emails_sent = 0
    application_send_start = Time.now

    # TODO: Email template selection for work unit reminders - should probably refactor the UI and system for latest updates to give more control
    email_template = EmailTemplate.find(:first, :conditions => {:code => 'std:email-template:task-reminder'})
    return unless email_template # Emails only sent if template exists

    js_runtime = KJSPluginRuntime.current
    url_base = KApp.url_base(:logged_in)

    User.find(:all, :conditions => "kind=#{User::KIND_USER}").each do |user|
      AuthContext.with_user(user) do
        work_units = WorkUnit.find_actionable_by_user(user, :now)
        unless work_units.empty?

          subject = "Reminder - #{work_units.length} task"
          subject << 's' if work_units.length != 1
          subject << ' waiting'

          html = ""
          work_units.each do |wu|
            begin
              json = js_runtime.call_fast_work_unit_render(wu, "reminderEmail")
              if json
                info = JSON.parse(json)
                text = info["text"]
                url = info["fullInfo"]
                if text && url
                  url = "#{url_base}#{url}" if url =~ /\A\//
                  html << %Q!<p>#{text_simple_format(text)}</p><p class="button"><a href="#{url}">#{ERB::Util.h(info["fullInfoText"])}</a></p><hr>\n!
                end
              end
            rescue => e
              KApp.logger.error("Exception when rendering work unit id #{wu.id} for reminder email")
              KApp.logger.log_exception(e)
            end
          end

          email_template.deliver(
            :to => user,
            :subject => subject,
            :message => html
          )

          emails_sent += 1
        end
      end
    end

    KApp.logger.info "Sent #{emails_sent} emails in #{Time.now - application_send_start} seconds for application #{KApp.current_application} (#{KApp.global(:url_hostname)})"
  end
end

