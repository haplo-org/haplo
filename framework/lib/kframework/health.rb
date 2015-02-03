# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
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
    # To make sure the same database connection isn't repeatedly used for the check, choose an application at random.
    h = KApp.all_hostnames
    app_id = h[rand(h.length)].first
    KApp.in_application(app_id) do
      db = KApp.get_pg_database
      r = db.exec("SELECT value_string FROM app_globals WHERE key='url_hostname'")
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
    def log_and_report_exception(exception, info_text = nil)
      begin
        KApp.logger.error("EVENT: #{@name} - #{info_text || '(no info)'}")
        if exception
          KApp.logger.log_exception(exception)
        else
          KApp.logger.error("(no exception)")
        end
        app_id = KApp.current_application
        app_hostname = (app_id && (app_id != :no_app)) ? KApp.global(:ssl_hostname) : ''
        event_id = KRandom.random_api_key(15)
        KApp.logger.error("EVENT ID: #{event_id}") # for easy location of error
        path = nil
        # Was the exception thrown while handling a request?
        handle_info = exception.instance_variable_get(:@__handle_info);
        if handle_info
          app_id, app_hostname, method, path = handle_info
        end
        # Write a nice email
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

__E
        # NOTE: This email avoids including more of the logs, as it might contain sensitive email
        # that shouldn't be sent via email.
        if exception
          email << "#{exception.inspect}\n  #{exception.backtrace.join("\n  ")}"
        else
          email << "NO EXCEPTION"
        end
        email << "\n\n\n\n"
        if report_email_address == :disable || (PLUGIN_DEBUGGING_SUPPORT_LOADED && KFramework.is_exception_reportable?(exception))
          # Either emailing of reports is disabled (eg development or production mode)
          # or plugin debugging is active, and it's a reportable error. Log the message instead.
          KApp.logger.info("===== BEGIN ERROR REPORT =====\n#{email}\n===== END ERROR REPORT =====")
        else
          # Otherwise it gets reported by email
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

