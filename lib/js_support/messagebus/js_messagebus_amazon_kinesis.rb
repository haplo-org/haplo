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
      :account => {"AWS Credential Name" => '', "AWS Region" => '', "Kinesis Stream Name" => ''},
      :secret => {}
    })
    KeychainCredential::MODELS.push({
      :kind => 'Public Cloud Provider',
      :instance_kind => 'Amazon Web Services',
      :account => {"Access Key ID" => ''},
      :secret => {"Access Key Secret" => ''}
    })
  end

  BUS_QUERY['Amazon Kinesis Stream'] = Proc.new do |credential|
    {'kind'=>'Amazon Kinesis Stream', 'name'=>credential.name}
  end

  # -------------------------------------------------------------------------

  module AmazonKinesis

    KNotificationCentre.when_each([
      [:keychain, :modified],
      [:applications, :changed]
    ], {:max_arguments => 0}) do
      # New queues may have been set up, so invalidate to get destinations rebuilt
    end

    def self.send_message(bus_name, bus_secret, message)
      ks = KeychainCredential.where({:kind=>'Message Bus', :instance_kind=>'Amazon Kinesis Stream', :name=>bus_name}).first
      raise JavaScriptAPIError, "couldn't load Kinesis stream details" if ks.nil?
      c = KeychainCredential.where({:kind=>'Public Cloud Provider', :instance_kind=>'Amazon Web Services', :name=>ks.account['AWS Credential Name']}).first
      raise JavaScriptAPIError, "couldn't load AWS credential" if c.nil?
      LOCK.synchronize do
        QUEUE.push([KApp.current_application, ks, c, message])
      end
      FLAG.setFlag()
    end

    def self.deliver_queued_messages
      # Loops until all messages sent, to avoid losing messages on app restart
      # TODO: Better message persistence and guaranteed delivery, as app shutdown could be prevented by loops which generate messages
      while to_send = LOCK.synchronize { QUEUE.pop }
        sending_app_id, ks, c, message = to_send
        aws_credentials_provider = Java::ComAmazonawsAuth::AWSStaticCredentialsProvider.new(
          Java::ComAmazonawsAuth::BasicAWSCredentials.new(
            c.account['Access Key ID'], c.secret['Access Key Secret']
          )
        )
        client = Java::ComAmazonawsServicesKinesis::AmazonKinesisClientBuilder.standard().
          withRegion(ks.account['AWS Region']).
          withCredentials(aws_credentials_provider).
          build()
        put_record_request = Java::ComAmazonawsServicesKinesisModel::PutRecordRequest.new().
          withStreamName(ks.account['Kinesis Stream Name']).
          withPartitionKey("main"). # how do we actually do this - leave up to implementation?
          withData(java.nio.ByteBuffer.wrap(message.to_java_bytes))
        res = client.putRecord(put_record_request)
        # prev = res.getSequenceNumber()
        KApp.logger.info("AWS KINESIS: Put record into stream #{ks.name}: #{res.toString()}")
      end
    end

    # -----------------------------------------------------------------------

    FLAG = Java::OrgHaploCommonUtils::WaitingFlag.new
    QUEUE = []  # array of [sending_app_id, kinsesis stream keychain, aws credential keychain, message]
    LOCK = Mutex.new

    class DeliveryTask < KFramework::BackgroundTask
      def initialize
        @do_delivery = true
      end
      def start
        while @do_delivery
          AmazonKinesis.deliver_queued_messages
          FLAG.waitForFlag(900000)
        end
      end
      def stop
        @do_delivery = false
        FLAG.setFlag()
      end
      def description
        "AWS Kinesis message delivery"
      end
    end
    KFramework.register_background_task(DeliveryTask.new)

  end

end
