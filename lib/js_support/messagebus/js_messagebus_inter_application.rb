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

  # -------------------------------------------------------------------------

  module InterApplication

    KNotificationCentre.when_each([
      [:keychain, :modified],
      [:applications, :changed]
    ], {:max_arguments => 0}) do
      # New queues may have been set up, so invalidate to get destinations rebuilt
      KApp.logger.info("INTER-APP MESSAGE: flushing messaging destinations because of configuration changes")
      LOCK.synchronize { DESTINATIONS.delete(:bus) }
    end

    def self.send_message(bus_name, bus_secret, message)
      LOCK.synchronize do
        QUEUE.push([KApp.current_application, bus_name, bus_secret, message])
      end
      FLAG.setFlag()
    end

    def self.deliver_queued_messages
      # Loops until all messages sent, to avoid losing messages on app restart
      # TODO: Better message persistence and guaranteed delivery, as app shutdown could be prevented by loops which generate messages
      while to_send = LOCK.synchronize { QUEUE.pop }
        sending_app_id, bus_name, bus_secret, json_message = to_send

        # Worked out receiving applications?
        busses = LOCK.synchronize { DESTINATIONS[:bus] }
        unless busses
          KApp.logger.info("INTER-APP MESSAGE: Scanning application keychains for bus definitions")
          busses = {}
          KApp.in_every_application do |app_id|
            KeychainCredential.where({:kind=>'Message Bus', :instance_kind=>'Inter-application'}).each do |c|
              key = [c.account['Bus'],c.secret['Secret']]
              busses[key] = [] unless busses.has_key?(key)
              busses[key].push(app_id)
            end
          end
          KApp.logger.info("INTER-APP MESSAGE: #{busses.length} busses found")
          LOCK.synchronize { DESTINATIONS[:bus] = busses }
        end

        # Deliver message to all receiving applications (including the one which sent it)
        bus = busses[[bus_name, bus_secret]]
        unless bus
          KApp.logger.info("INTER-APP MESSAGE: Dropping message for bus #{bus_name} as no destination applications")
        else
          bus.each do |destination_app_id|
            begin
              KApp.in_application(destination_app_id) do
                runtime = KJSPluginRuntime.current
                runtime.using_runtime do
                  runtime.runtime.callSharedScopeJSClassFunction("O", "$messageBusInterApplicationMessageDeliver", [bus_name, bus_secret, json_message])
                end
              end
              KApp.logger.info("INTER-APP MESSAGE: Delivered message on #{bus_name} to app #{destination_app_id}")
            rescue => e
              KApp.logger.error("INTER-APP MESSAGE: Exception when delivering message on #{bus_name} to app #{destination_app_id}")
              KApp.logger.log_exception(e)
            end
          end
        end
        KApp.logger.flush_buffered
      end
    end

    # -----------------------------------------------------------------------

    FLAG = Java::OrgHaploCommonUtils::WaitingFlag.new
    QUEUE = []  # array of [sending_app_id, bus_name, bus_secret, json_message]
    DESTINATIONS = {}
    LOCK = Mutex.new

    class DeliveryTask < KFramework::BackgroundTask
      def initialize
        @do_delivery = true
      end
      def start
        while @do_delivery
          InterApplication.deliver_queued_messages
          FLAG.waitForFlag(900000)
        end
      end
      def stop
        @do_delivery = false
        FLAG.setFlag()
      end
      def description
        "Inter-application message delivery"
      end
    end
    KFramework.register_background_task(DeliveryTask.new)

  end

end
