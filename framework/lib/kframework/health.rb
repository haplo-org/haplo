# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class KFramework

  # Registration of health check procs
  def self.health_check_register(name, p)
    @@health_check_procs << [name, p]
  end
  @@health_check_procs = Array.new

  # Register a simple database check
  health_check_register('DATABASE', proc do
    h = KApp.all_hostnames
    app_id = h[rand(h.length)].first
    KApp.in_application(app_id) do
      r = KApp.with_pg_database do |db|
        db.exec("SELECT value_string FROM #{KApp.db_schema_name}.app_globals WHERE key='url_hostname'")
      end
      return "DATABASE #{app_id}" unless r.length == 1 && r.first.first.length > 1
    end
    nil
  end)

  # Utility class for reporting events
  class HealthEventReporter
    SHOW_ERROR_FOR = 60*15    # report an error for 15 minutes
    def initialize(name)
      @name = name
      @last_event = 0
      KFramework.health_check_register(name, self)
    end

    # Reporting to health checks
    def report_health_event(data = nil)
      @last_event = Time.now.to_i
    end
    def call
      ((Time.now.to_i - SHOW_ERROR_FOR) < @last_event) ? @name : nil
    end

    # Reporting exceptions via email
    def log_and_report_exception(exception, event_title = nil)
      event_title ||= 'Exception thrown'
      if exception
        event_text = "#{exception.inspect}\n  #{exception.backtrace.join("\n  ")}"
      end
      self.log_and_report_event(event_title, event_text)
    end

    def log_and_report_event(event_title, event_text)
      begin
        event_title ||= 'Application health event'
        KApp.logger.error("EVENT: #{@name} - #{event_title}")
        KApp.logger.error(event_text)
        app_id = KApp.current_application
        app_hostname = (app_id && (app_id != :no_app)) ? KApp.global(:ssl_hostname) : ''
        event_id = KRandom.random_api_key(15)
        KApp.logger.error("EVENT ID: #{event_id}") # for easy location of error
        path = nil
        method = nil
        # Attempt to get information about the active request from the request context
        rc = KFramework.request_context
        if rc
          begin
            method = rc.exchange.request.method if method == nil
            path = rc.exchange.request.path if path == nil
          rescue
            # Ignore problems trying to find addition info
          end
        end
        # Write a nice email
        # NOTE: This email avoids including more of the logs, as it might contain sensitive email
        # that shouldn't be sent via email.
        report_email_address = KInstallProperties.get(:report_email_address, :disable)
        email = <<__E
From: #{KHostname.hostname} <#{report_email_address}>
To: Tech Alerts <#{report_email_address}>
Subject: #{@name} - #{KHostname.hostname} - #{event_id}


Time:         #{Time.now.to_s}
Host:         #{KHostname.hostname}
Event ID:     #{event_id}
Application:  #{app_id || 'NONE'} (#{app_hostname})
Request:      #{method} #{path || 'NO REQUEST'}

#{event_title}

#{event_text}


__E
        if report_email_address == :disable || PLUGIN_DEBUGGING_SUPPORT_LOADED
          KApp.logger.info("===== BEGIN ERROR REPORT =====\n#{email}\n===== END ERROR REPORT =====")
        else
          Net::SMTP.start('127.0.0.1', 25) do |smtp|
            smtp.send_message(email, report_email_address, report_email_address)
          end
        end
      rescue => e
        # Failed to log or email health data - trigger monitoring
        report_health_event() # before the attempt to log
        KApp.logger.error("EXCEPTION IN EXCEPTION REPORTING")
        KApp.logger.log_exception(e)
      end
    end
  end

  # Called from the Java app server
  def check_health
    failures = @@health_check_procs.map do |name, p|
      begin
        p.call
      rescue => e
        "#{name} exception"
      end
    end .compact

    # Return a result which is sent in response, or nill for no error
    if failures.empty?
      nil
    else
      failures.join(',')
    end
  end

end

