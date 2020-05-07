# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module JSMessageBus

  RELIABILITY_MINIMUM_EFFORT    = 0
  RELIABILITY_BEST              = 255
  RELIABILITY__MIN_SYNC_COMMIT  = 128

  # -------------------------------------------------------------------------

  NOTIFICATIONS_WHERE_MESSAGE_BUS_CONFIG_CHANGED = [
    [:keychain, :modified],
    [:app_global_change, :js_messagebus_config],
    [:applications, :changed]
  ]

  # -------------------------------------------------------------------------

  BUS_QUERY = {}
  BUS_DELIVERY = {}

  class MessageBusSupport
    def self.setBusPlatformConfig(json)
      # NOTE: Other parts of the message bus system rely on the notification this generates
      KApp.set_global(:js_messagebus_config, json)
    end

    def self.queryKeychain(name)
      credential = KeychainCredential.where({:kind=>'Message Bus', :name=>name}).first()
      return nil unless credential
      make_info = BUS_QUERY[credential.instance_kind]
      return nil unless make_info
      info = make_info.call(credential)
      return nil unless info
      info["_platformBusId"] = credential.id
      JSON.generate(info)
    end

    def self.sendMessageToBus(busKind, busId, busName, busSecret, reliability, body)
      case busKind
      when "$InterApplication"
        InterApplication.send_message(busName, busSecret, reliability, body)
      when "$AmazonKinesis"
        AmazonKinesis.send_message(busId, reliability, body)
      when "$AmazonSQS"
        AmazonSQS.send_message(busId, reliability, body)
      when "$AmazonSNS"
        AmazonSNS.send_message(busId, reliability, body)
      else
        throw new JavaScriptAPIError, "bad message bus kind"
      end
    end
  end

  Java::OrgHaploJsinterface::KMessageBusPlatformSupport.setRubyInterface(MessageBusSupport)

  # -------------------------------------------------------------------------
  # Decoding the bus platform configuration
  # See message_bus.js implementation of _getPlatformConfig()
  class MessageBusPlatformConfiguration
    BusConfig = Struct.new(:has_receive, :has_delivery_report)
    # Default config says there are all functions, so if there is a pause between
    # creating the credential and loading the runtime, the default is to try to
    # deliver the message until it's known otherwise. This avoids potentially
    # losing messages.
    DEFAULT_CONFIG = BusConfig.new(true, true).freeze
    def initialize(override_json = nil)
      @config = JSON.parse(override_json || KApp.global(:js_messagebus_config) || '{}')
    end
    def for_bus(id)
      c = @config[id.to_s] # because JSON only has string keys
      return DEFAULT_CONFIG unless c.kind_of?(Array)
      BusConfig.new(!!c[0], !!c[1])
    end
  end

  # -------------------------------------------------------------------------
  # Reliability and database transactions
  def self.with_transaction_for_reliability(reliability)
    db = KApp.get_pg_database
    sql_begin = 'BEGIN'
    if reliability < RELIABILITY__MIN_SYNC_COMMIT
      sql_begin << '; SET LOCAL synchronous_commit TO OFF'
    end
    db.perform(sql_begin)
    begin
      yield db
      db.perform('COMMIT')
    rescue
      db.perform('ROLLBACK')
      raise
    end
  end

  # -------------------------------------------------------------------------
  # Adding to queues
  INSERT_INTO_QUEUE = "INSERT INTO js_message_bus_queue(created_at,application_id,bus_id,is_send,reliability,body,transport_options) VALUES(NOW(),$1,$2,$3,$4,$5,$6)".freeze
  def self.add_to_delivery_queue(app_id, bus_id, is_send, reliability, body, transport_options)
    with_transaction_for_reliability(reliability) do |db|
      db.perform(INSERT_INTO_QUEUE, app_id, bus_id, is_send, reliability, body, transport_options);
    end
    DELIVERY_WORK_FLAG.setFlag()
  end

  # -------------------------------------------------------------------------
  # Delivery of messages to JS runtime and external systems
  class DeliverMessages
    SELECT_MESSAGES = "SELECT id,bus_id,is_send,reliability,body,transport_options FROM js_message_bus_queue WHERE application_id=$1 ORDER BY id LIMIT 20".freeze
    DELETE_MESSAGE = "DELETE FROM js_message_bus_queue WHERE id=$1".freeze
    def initialize(application_id)
      @application_id = application_id
      @credentials = {}
    end
    def deliver_from_queue
      raise "In wrong application" unless @application_id == KApp.current_application
      db = KApp.get_pg_database
      results = db.exec(SELECT_MESSAGES, @application_id)
      results.each do |id,bus_id,is_send_s,reliability,body,transport_options|
        is_send = (is_send_s == 't')
        credential = @credentials[bus_id.to_i] ||= begin
          KeychainCredential.find(:first, :conditions => {:id => bus_id.to_i, :kind => 'Message Bus'})
        end
        if credential.nil?
          KApp.logger.error("Dropping message for bus id #{bus_id} as no credential exists")
        else
          delivery = BUS_DELIVERY[credential.instance_kind]
          if delivery.nil?
            KApp.logger.error("Dropping message for bus id #{bus_id} as bus credential has unknown instance kind #{credential.instance_kind}")
          else
            delivery.call(is_send, credential, reliability.to_i, body, transport_options)
          end
          JSMessageBus.with_transaction_for_reliability(reliability.to_i) do
            db.perform(DELETE_MESSAGE, id.to_i)
          end
        end
      end
      results.clear
    end
  end

  # -------------------------------------------------------------------------
  # Task to deliver messages from the queue
  DELIVERY_WORK_FLAG = Java::OrgHaploCommonUtils::WaitingFlag.new
  SELECT_APPLICATIONS_WITH_MESSAGES = 'SELECT application_id,count(id) FROM js_message_bus_queue GROUP BY application_id ORDER BY application_id'
  class DeliveryTask < KFramework::BackgroundTask
    def initialize
      @do_delivery = true
      @current_threads = {} # app_id -> Thread
    end

    def start
      while @do_delivery
        did_something = [
          join_with_finished_threads(),
          deliver_queued_messages()
        ]
        if did_something.include?(true)
          # short delay to avoid too much work when messages are being generated quickly (use Java's sleep, because Ruby's tends to return immediately)
          java.lang.Thread.sleep(200)
        else
          DELIVERY_WORK_FLAG.waitForFlag(900000)
        end
      end
    end

    def stop
      @do_delivery = false
      DELIVERY_WORK_FLAG.setFlag()
    end

    def description
      "Message delivery for JS message busses"
    end

    def join_with_finished_threads
      completed_threads = []
      @current_threads.each do |application_id, thread|
        # Tempting to use thread.alive?, but can get stuck if flagging work flag means this runs before thread properly ended
        completed_threads << application_id if thread[:messagebus_delivery_work_complete]
      end
      completed_threads.each do |application_id|
        @current_threads.delete(application_id).join
      end
      !completed_threads.empty?
    end

    def deliver_queued_messages
      did_something = false
      applications_with_messages_in_queue.each do |application_id|
        if @current_threads.has_key?(application_id)
          KApp.logger.info("Application #{application_id} has a delivery thread running, not starting another")
        else
          did_something = true
          @current_threads[application_id] = Thread.new do
            delivery_thread(application_id)
          end
        end
      end
      did_something
    ensure
      KApp.logger.flush_buffered
    end

    def delivery_thread(application_id)
      # Each bus type has different requirements for error handling and reports back to the JS, so retry isn't implemented here.
      # TODO: More control over bus specific retry mechanisms, and stopping promptly when server is shutting down.
      KApp.in_application(application_id) do
        deliver = JSMessageBus::DeliverMessages.new(application_id)
        deliver.deliver_from_queue
      end
    ensure
      # Trigger main loop to join this thread
      KApp.logger.flush_buffered
      Thread.current[:messagebus_delivery_work_complete] = true
      DELIVERY_WORK_FLAG.setFlag()
    end

    def applications_with_messages_in_queue
      applications = []
      KApp.in_application(:no_app) do
        KApp.get_pg_database.exec(SELECT_APPLICATIONS_WITH_MESSAGES).each do |application_id, count|
          KApp.logger.info("Application #{application_id} has message queue length #{count}")
          applications.push(application_id.to_i)
        end
      end
      applications
    end
  end
  KFramework.register_background_task(DeliveryTask.new)

  # -------------------------------------------------------------------------
  # Support for Loopback message bus
  KNotificationCentre.when(:server, :starting) do
    KeychainCredential::MODELS.push({
      :kind => 'Message Bus',
      :instance_kind => 'Loopback',
      :account => {"API code" => ''},
      :secret => {}
    })
  end

  BUS_QUERY['Loopback'] = Proc.new do |credential|
    {'kind'=>'Loopback', 'name'=>credential.account['API code']}
  end

  BUS_DELIVERY['Loopback'] = Proc.new do
    KApp.logger.error("Unexpected message for Loopback in persisted message queue")
  end

end
