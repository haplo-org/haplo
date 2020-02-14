# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module JSMessageBus

  KNotificationCentre.when(:server, :starting) do
    KeychainCredential::MODELS.push({
      :kind => 'Message Bus',
      :instance_kind => 'Amazon SQS Queue',
      :account => {
        "SQS Queue Name" => '',
        "AWS Region" => '',
        "AWS Access Key ID" => ''},
      :secret => {"AWS Access Key Secret" => ''}
    })
  end

  BUS_QUERY['Amazon SQS Queue'] = Proc.new do |credential|
    {'kind'=>'Amazon SQS Queue', 'name'=>credential.name}
  end

  BUS_DELIVERY['Amazon SQS Queue'] = Proc.new do |is_send, credential, reliability, body, transport_options|
    if is_send
      aws_credentials_provider = Java::ComAmazonawsAuth::AWSStaticCredentialsProvider.new(
        Java::ComAmazonawsAuth::BasicAWSCredentials.new(
          credential.account['AWS Access Key ID'], credential.secret['AWS Access Key Secret']
        )
      )
      client = Java::ComAmazonawsServicesSqs::AmazonSQSClientBuilder.standard().
        withRegion(credential.account['AWS Region']).
        withCredentials(aws_credentials_provider).
        build()
      queue_url = client.getQueueUrl(credential.account['SQS Queue Name'].to_java_string).getQueueUrl()
      begin
        # TODO: AWS SQS sending retry logic?
        send_msg_request = Java::ComAmazonawsServicesSqsModel::SendMessageRequest.new().
          withQueueUrl(queue_url).
          withMessageBody(body.to_java_string)   # has to be a string
        res = client.sendMessage(send_msg_request)
        KApp.logger.info("AWS SQS: Send message into queue #{credential.name}: #{res.toString()}")
        report_status = 'success'
        report_infomation = {"result" => res.toString()}
      rescue => e
        report_status = 'failure'
        report_infomation = {"exception" => e.to_s}
      end
      # Only send delivery reports if the application is interested
      if JSMessageBus::MessageBusPlatformConfiguration.new.for_bus(credential.id).has_delivery_report
        runtime = KJSPluginRuntime.current
        runtime.using_runtime do
          runtime.runtime.callSharedScopeJSClassFunction("O", "$messageBusSQSMessageAction", [credential.name, body, "report", report_status, JSON.generate(report_infomation)])
        end
        KApp.logger.info("AWS SQS: Done delivery notification for #{credential.name}: #{res.toString()}")
      end
    else
      KApp.logger.info("AWS SQS: Receiving not supported (#{credential.name} on app #{KApp.current_application})")
    end
  end

  # -------------------------------------------------------------------------

  module AmazonSQS

    def self.send_message(busId, reliability, body)
      # Check there's all the valid details at the point the message is sent
      ks = KeychainCredential.find(:first, :conditions => {:id=>busId, :instance_kind=>'Amazon SQS Queue'})
      raise JavaScriptAPIError, "Couldn't load SQS queue details" if ks.nil?
      JSMessageBus.add_to_delivery_queue(KApp.current_application, busId, true, reliability, body, '{}')
    end

  end

end
