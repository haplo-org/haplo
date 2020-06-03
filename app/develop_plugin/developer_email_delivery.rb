# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



unless PLUGIN_DEBUGGING_SUPPORT_LOADED
  raise "DeveloperEmailDelivery should only be loaded if plugin debugging support is explicitly required"
end

class DeveloperEmailDelivery

  EMAIL_HOLD_TIME = 30
  MAX_TOKENS_PER_APP = 32

  # Everything must work within this lock
  LOCK = Mutex.new

  KNotificationCentre.when(:email, :send) do |name, operation, delivery|
    # Development servers always prevent delivery of emails
    delivery.prevent_default_delivery = true
    # Store the message in the queue
    LOCK.synchronize do
      Queue.current.add_message(delivery.message, delivery.to_address)
    end
    # Also notify on the plugin tool console
    KNotificationCentre.notify(:javascript_console_log, :INFO, "#{delivery.to_address} (#{delivery.message.header.subject})", "EMAIL")
  end

  KNotificationCentre.when(:email, :html_to_plain_error) do |name, operation, error_message, html|
    simple_error = error_message.split(/[\r\n]+/,2).first
    # Send JS console notification so developers might notice the problem
    KNotificationCentre.notify(:javascript_console_log, :ERROR, "Error converting HTML body to plain text: #{simple_error}\nUse email viewer to see full details.", "EMAIL")
    # Add an 'email' to the viewer
    source = html.split(/\r?\n/).each_with_index.map { |l,i| "#{i+1}: #{l}\n" }.join
    body_html = %Q!<html><body><h2>Error</h2><pre>#{ERB::Util.h(error_message)}</pre><h2>Source</h2><pre>#{ERB::Util.h(source)}</pre></body></html>!
    message = RMail::Message.new
    message.header.subject = simple_error
    body = RMail::Message.new
    body.header.add 'Content-Type', 'text/html; charset=utf-8'
    body.body = [body_html].pack("M*")
    message.body = body
    LOCK.synchronize do
      Queue.current.add_message(message, "HTML error")
    end
  end

  # Add the email client to the tools menu
  KNotificationCentre.when(:developer_support, :tools_menu) do |name, operation, section, request_user|
    if request_user.policy.can_use_testing_tools?
      section.push(['/do/development-email-client', 'Test email viewer'])
    end
  end

  # ------------------------------------------------------------------------------------------------------------------------

  Entry = Struct.new(:message, :to_address, :time, :id)

  class Queue
    def initialize
      @queue = []
      @tokens = []
      @continuations = []
      @next_id = Time.now.to_i
    end
    attr_reader :next_id

    def add_message(message, to_address)
      now = Time.now.to_i
      # Clean out old entries
      min_time = now - EMAIL_HOLD_TIME
      @queue.delete_if { |item| item.time < min_time }
      # Add the new entry
      @queue.push Entry.new(message, to_address, now, @next_id)
      @next_id += 1
      # Notify anything waiting
      @continuations.each do |c|
        begin
          c.resume() if c.isSuspended()
        rescue => e
          # Do nothing
        end
      end
      @continuations = []
    end

    def messages_after(min_id)
      @queue.select { |entry| entry.id >= min_id }
    end

    def add_token(token)
      while @tokens.length > DeveloperEmailDelivery::MAX_TOKENS_PER_APP
        @tokens.shift
      end
      @tokens.push(token)
    end

    def token_valid?(token)
      return false unless @tokens.include?(token)
      # Move token to the front of the queue so it expires last
      @tokens.delete token
      @tokens.push token
    end

    def notify_continuation(continuation)
      @continuations << continuation
    end

    @@queues = {}
    def self.current
      @@queues[KApp.current_application] ||= Queue.new
    end
  end

  # ------------------------------------------------------------------------------------------------------------------------

  class Controller < ApplicationController

    # Impersonation would be very inconvenient if it interrupted the email delivery. But also, you can't have
    # development systems giving away info to just anyone.
    # So, to start the client, you need to have :use_testing_tools. This gives you a token, which can be used to
    # fetch email in the future, whatever happens.
    _PoliciesRequired :not_anonymous, :use_testing_tools
    def handle_index; render(:text => File.open("#{File.dirname(__FILE__)}/static/developer_email_client.html").read, :kind => :html); end
    _PoliciesRequired :not_anonymous, :use_testing_tools
    def handle_js; render(:text => File.open("#{File.dirname(__FILE__)}/static/developer_email_client.js").read, :kind => :javascript); end
    _PoliciesRequired :not_anonymous, :use_testing_tools
    def handle_start_api
      token = KRandom.random_api_key
      LOCK.synchronize do
        Queue.current.add_token(token)
      end
      render :text => JSON.dump("token" => token, "app" => KApp.global(:ssl_hostname)), :kind => :json
    end

    _PoliciesRequired nil
    def handle_fetch_api
      messages = nil
      next_id = nil
      LOCK.synchronize do
        queue = Queue.current
        if queue.token_valid?(params['id'])
          messages = queue.messages_after(params['next'].to_i)
          next_id = queue.next_id
        end
      end
      unless messages
        render :text => "Token not valid", :status => 403
      else
        # Pause if there aren't any messages
        continuation = request.continuation
        if messages.empty? && continuation.isInitial()
          continuation.setTimeout(55000)
          continuation.suspend()
          LOCK.synchronize { Queue.current.notify_continuation(continuation) }
          return render_continuation_suspended
        end
        # Otherwise send the messages to the client
        render :kind => :json, :text => JSON.dump({"next" => next_id, "messages" => messages.map do |entry|
          headers = []
          entry.message.header.each do |k,v|
            headers << [k,v].join(": ")
          end
          parts = [["HEADERS", headers.join("\n")]]
          body = entry.message.body
          body = [body] unless body.kind_of?(Array)
          body.each do |part|
            if part.kind_of?(String)
              parts.push ["text/plain", part.unpack('M*').first.force_encoding(Encoding::UTF_8)]
            else
              parts.push [part.header['Content-Type'], part.body.unpack('M*').first.force_encoding(Encoding::UTF_8)]
            end
          end
          {
            "time" => entry.time,
            "to" => entry.to_address.dup.force_encoding(Encoding::UTF_8),
            "subject" => entry.message.header.subject.dup.force_encoding(Encoding::UTF_8),
            "message" => parts.reverse
          }
        end})
      end
    end
  end

  # Add this controller to the server's URL namespace
  KNotificationCentre.when(:server, :starting) do
    namespace = KFRAMEWORK__BOOT_OBJECT.instance_variable_get(:@namespace).class.const_get(:MAIN_MAP)
    namespace['do'].last['development-email-client'] = [:controller, {}, Controller]
    namespace['api'].last['development-email-client'] = [:controller, {}, Controller]
  end

end

