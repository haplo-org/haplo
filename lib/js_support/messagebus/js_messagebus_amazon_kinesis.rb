# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module JSMessageBus

  KNotificationCentre.when(:server, :starting) do
    KeychainCredential::MODELS.push({
      :kind => 'Message Bus',
      :instance_kind => 'Amazon Kinesis Stream',
      :account => {
        "Kinesis Stream Name" => '',
        "Kinesis Stream Partition Key" => '',
        "AWS Region" => '',
        "AWS Access Key ID" => ''},
      :secret => {"AWS Access Key Secret" => ''}
    })
  end

  BUS_QUERY['Amazon Kinesis Stream'] = Proc.new do |credential|
    {'kind'=>'Amazon Kinesis Stream', 'name'=>credential.name}
  end

  BUS_DELIVERY['Amazon Kinesis Stream'] = Proc.new do |is_send, credential, reliability, body, transport_options|
    if is_send
      aws_credentials_provider = Java::ComAmazonawsAuth::AWSStaticCredentialsProvider.new(
        Java::ComAmazonawsAuth::BasicAWSCredentials.new(
          credential.account['AWS Access Key ID'], credential.secret['AWS Access Key Secret']
        )
      )
      client = Java::ComAmazonawsServicesKinesis::AmazonKinesisClientBuilder.standard().
        withRegion(credential.account['AWS Region']).
        withCredentials(aws_credentials_provider).
        build()
      put_record_request = Java::ComAmazonawsServicesKinesisModel::PutRecordRequest.new().
        withStreamName(credential.account['Kinesis Stream Name']).
        withPartitionKey(credential.account['Kinesis Stream Partition Key']).
        withData(java.nio.ByteBuffer.wrap(body.to_java_bytes))
      res = client.putRecord(put_record_request)
      KApp.logger.info("AWS KINESIS: Put record into stream #{credential.name}: #{res.toString()}")
    else
      begin
        runtime = KJSPluginRuntime.current
        runtime.using_runtime do
          runtime.runtime.callSharedScopeJSClassFunction("O", "$messageBusKinesisMessageDeliver", [credential.name, body])
        end
        KApp.logger.info("INTER-APP MESSAGE: Delivered message on #{credential.name} to app #{KApp.current_application}")
      rescue => e
        KApp.logger.error("INTER-APP MESSAGE: Exception when delivering message on #{credential.name} to app #{KApp.current_application}")
        KApp.logger.log_exception(e)
      end
    end
  end

  # -------------------------------------------------------------------------

  module AmazonKinesis

    KNotificationCentre.when_each(NOTIFICATIONS_WHERE_MESSAGE_BUS_CONFIG_CHANGED, {:max_arguments => 0}) do
      # New queues may have been set up, so invalidate to get listeners running
      KApp.logger.info("KINESIS RECEIVE: checking listeners because of configuration changes")
      LOCK.synchronize { STATUS.delete(:listening) }
      FLAG.setFlag() # Reconfiguration needs to happen now
    end

    # -------------------------------------------------------------------------

    def self.send_message(busId, reliability, body)
      # Check there's all the valid details at the point the message is sent
      ks = KeychainCredential.find(:first, :conditions => {:id=>busId, :instance_kind=>'Amazon Kinesis Stream'})
      raise JavaScriptAPIError, "Couldn't load Kinesis stream details" if ks.nil?
      JSMessageBus.add_to_delivery_queue(KApp.current_application, busId, true, reliability, body, '{}')
    end

    # -------------------------------------------------------------------------

    FLAG = Java::OrgHaploCommonUtils::WaitingFlag.new
    STATUS = {}
    LOCK = Mutex.new

    class ReceiveTask < KFramework::BackgroundTask
      Info = Struct.new(:worker, :thread)

      def initialize
        @do_receive = true
        @workers = {} # [app_id,credential.id] => Info
      end

      def start
        while @do_receive
          should_reconfig = false
          LOCK.synchronize do
            # This is written to avoid race conditions
            unless STATUS[:listening]
              should_reconfig = true
              STATUS[:listening] = true # now so additonal reconfigs will reconfig
            end
          end
          if should_reconfig
            KApp.logger.info("KINESIS RECEIVE: starting listener reconfiguration")
            # TODO: Be a bit more clever about reconfiguring Kinesis listeners without having to shut everything down and start again
            shutdown_listeners
            # Find applications with kinesis streams, start their listener
            KApp.in_every_application do |app_id|
              app_bus_config = nil
              KeychainCredential.where({:kind=>'Message Bus', :instance_kind=>'Amazon Kinesis Stream'}).each do |c|
                app_bus_config ||= MessageBusPlatformConfiguration.new
                # Only start a listener if a receive function is registered
                if app_bus_config.for_bus(c.id).has_receive
                  key = [app_id,c.id]
                  if @workers.has_key?(key)
                    KApp.logger.info("KINESIS RECEIVE: already listening for #{key}")
                  else
                    KApp.logger.info("KINESIS RECEIVE: starting listener for #{key}")
                    @workers[key] = start_listener(app_id, c)
                  end
                end
              end
            end
            KApp.logger.info("KINESIS RECEIVE: done reconfiguration")
            KApp.logger.flush_buffered
          end
          FLAG.waitForFlag(3603000)
        end
        shutdown_listeners
        KApp.logger.flush_buffered
      end

      def shutdown_listeners
        KApp.logger.info("KINESIS RECEIVE: shutting down #{@workers.length} listeners")
        @workers.each_value { |info| info.worker.shutdown() }
        @workers.each_value { |info| info.thread.join() }
        KApp.logger.info("KINESIS RECEIVE: shutdown complete")
        @workers = {}
      end

      def stop
        @do_receive = false
        FLAG.setFlag()
      end

      def description
        "AWS Kinesis message receipt"
      end

      def start_listener(app_id, credential)
        aws_credentials_provider = Java::ComAmazonawsAuth::AWSStaticCredentialsProvider.new(
          Java::ComAmazonawsAuth::BasicAWSCredentials.new(
            credential.account['AWS Access Key ID'], credential.secret['AWS Access Key Secret']
          )
        )
        # See "Application name" heading here http://docs.aws.amazon.com/streams/latest/dev/kinesis-record-processor-implementation-app-java.html
        safe_hostname = KApp.global(:ssl_hostname).gsub(/[^a-zA-Z0-9_-]/,'-')
        config = com.amazonaws.services.kinesis.clientlibrary.lib.worker.KinesisClientLibConfiguration.new(
          "haplo-application-#{safe_hostname}",
          credential.account['Kinesis Stream Name'],
          aws_credentials_provider,
          "haplo-worker-#{safe_hostname}"
        )
        config.withInitialPositionInStream(com.amazonaws.services.kinesis.clientlibrary.lib.worker.InitialPositionInStream::LATEST)
        config.withRegionName(credential.account['AWS Region'])
        factory = RecordProcessorFactory.new(app_id, credential.id)
        worker = com.amazonaws.services.kinesis.clientlibrary.lib.worker.Worker.new(factory, config)
        thread = Thread.new { worker.run() }
        Info.new(worker, thread)
      end

      class RecordProcessorFactory
        def initialize(app_id, credential_id)
          @app_id = app_id
          @credential_id = credential_id
        end
        def createProcessor
          processor = RecordProcessor.new
          processor.set_target(@app_id, @credential_id)
          processor
        end
      end

      class RecordProcessor
        # 'initialize' is part of Java interface, so need a separate function for setting key info
        def set_target(app_id, credential_id)
          @app_id = app_id
          @credential_id = credential_id
        end
        def initialize(shardId = nil)
        end
        def processRecords(records, checkpointer)
          records.each do |record|
            body = java.nio.charset.StandardCharsets::UTF_8.decode(record.getData()).toString()
            KApp.in_application(@app_id) do
              JSMessageBus.add_to_delivery_queue(@app_id, @credential_id, false, RELIABILITY_BEST, body, '{}')
            end
          end
          checkpointer.checkpoint()
        end
        def shutdown(checkpointer, reason)
        end
      end
    end
    KFramework.register_background_task(ReceiveTask.new)

  end

end
