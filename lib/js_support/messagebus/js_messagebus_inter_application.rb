# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module JSMessageBus

  KNotificationCentre.when(:server, :starting) do
    KeychainCredential::MODELS.push({
      :kind => 'Message Bus',
      :instance_kind => 'Inter-application',
      :account => {"Bus" => ''},
      :secret => {"Secret" => ''}
    })
  end

  BUS_QUERY['Inter-application'] = Proc.new do |credential|
    {'kind'=>'Inter-application', 'name'=>credential.account['Bus'], 'secret'=>credential.secret['Secret']}
  end

  BUS_DELIVERY['Inter-application'] = Proc.new do |is_send, credential, reliability, body, transport_options|
    raise "Inter-application messages shouldn't have send entries in queue" if is_send
    bus_name = credential.account['Bus']
    bus_secret = credential.secret['Secret']
    begin
      runtime = KJSPluginRuntime.current
      runtime.using_runtime do
        runtime.runtime.callSharedScopeJSClassFunction("O", "$messageBusInterApplicationMessageDeliver", [bus_name, bus_secret, body])
      end
      KApp.logger.info("INTER-APP MESSAGE: Delivered message on #{bus_name} to app #{KApp.current_application}")
    rescue => e
      KApp.logger.error("INTER-APP MESSAGE: Exception when delivering message on #{bus_name} to app #{KApp.current_application}")
      KApp.logger.log_exception(e)
    end
  end

  # -------------------------------------------------------------------------

  module InterApplication

    KNotificationCentre.when_each(NOTIFICATIONS_WHERE_MESSAGE_BUS_CONFIG_CHANGED, {:max_arguments => 0}) do
      # New queues may have been set up, so invalidate to get destinations rebuilt
      KApp.logger.info("INTER-APP MESSAGE: flushing messaging destinations because of configuration changes")
      LOCK.synchronize { DESTINATIONS.delete(:bus) }
    end

    DIRECT_INSERT_INTO_QUEUE = "INSERT INTO js_message_bus_queue(created_at,application_id,bus_id,is_send,reliability,body,transport_options) VALUES(NOW(),$1,$2,false,$3,$4,'{}')".freeze

    def self.send_message(bus_name, bus_secret, reliability, body)
      # Inter-app messaging inserts the message directly into the bus message queue
      # for delivery, skipping the sending stage.
      busses = get_interapp_busses()
      bus = busses[[bus_name, bus_secret]]
      unless bus
        KApp.logger.info("INTER-APP MESSAGE: Dropping message for bus #{bus_name} as no destination applications")
      else
        queued_to = []
        bus.each do |destination_app_id, bus_id|
          JSMessageBus.with_transaction_for_reliability(reliability) do |db|
            db.perform(DIRECT_INSERT_INTO_QUEUE, destination_app_id, bus_id, reliability, body);
            queued_to << destination_app_id
          end
        end
        KApp.logger.info("INTER-APP MESSAGE: Queued message on #{bus_name} to applications #{queued_to.join(',')}")
      end
      DELIVERY_WORK_FLAG.setFlag()
    end

    def self.get_interapp_busses
      # Worked out receiving applications?
      busses = LOCK.synchronize { DESTINATIONS[:bus] }
      unless busses
        KApp.logger.info("INTER-APP MESSAGE: Scanning application keychains for bus definitions")
        busses = {}
        # Get the configuration in a different thread so we don't change the selected application in this one
        isolating_thread = Thread.new do
          KApp.in_every_application do |app_id|
            app_bus_config = nil
            KeychainCredential.where({:kind=>'Message Bus', :instance_kind=>'Inter-application'}).each do |c|
              app_bus_config ||= MessageBusPlatformConfiguration.new
              # Only include the bus for delivery if it has a receive function registered
              if app_bus_config.for_bus(c.id).has_receive
                key = [c.account['Bus'],c.secret['Secret']]
                busses[key] = [] unless busses.has_key?(key)
                busses[key].push([app_id, c.id])
              end
            end
          end
        end
        isolating_thread.join
        KApp.logger.info("INTER-APP MESSAGE: #{busses.length} busses found")
        LOCK.synchronize { DESTINATIONS[:bus] = busses }
      end
      busses
    end

    # -----------------------------------------------------------------------

    DESTINATIONS = {}
    LOCK = Mutex.new

  end

end
