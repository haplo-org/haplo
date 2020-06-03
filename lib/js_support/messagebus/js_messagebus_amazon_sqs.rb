# frozen_string_literal: true

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
        "AWS Access Key ID" => '',
        "AWS Assume Role" => '',
        "AWS ExternalID" => ''},
      :secret => {"AWS Access Key Secret" => ''}
    })
    KeychainCredential::USER_INTERFACE[['Message Bus','Amazon SQS Queue']] = {
      :notes_edit => "'AWS Assume Role' and 'AWS ExternalID' are optional. Leave blank to use a static credential. Queue Name can be a simple name inside this account, or an ARN."
    }
  end

  BUS_QUERY['Amazon SQS Queue'] = Proc.new do |credential|
    {'kind'=>'Amazon SQS Queue', 'name'=>credential.name}
  end

  BUS_DELIVERY['Amazon SQS Queue'] = Proc.new do |is_send, credential, reliability, body, transport_options|
    if is_send
      begin
        aws_credentials_provider = Java::ComAmazonawsAuth::AWSStaticCredentialsProvider.new(
          Java::ComAmazonawsAuth::BasicAWSCredentials.new(
            credential.account['AWS Access Key ID'], credential.secret['AWS Access Key Secret']
          )
        )
        assume_role = credential.account['AWS Assume Role']
        unless assume_role.nil? || assume_role.empty?
          sts_client = Java::ComAmazonawsServicesSecuritytoken::AWSSecurityTokenServiceClient.new(aws_credentials_provider)
          assume_request = Java::ComAmazonawsServicesSecuritytokenModel::AssumeRoleRequest.new.
            withRoleArn(assume_role).
            withDurationSeconds(900).
            withRoleSessionName("haplo-#{KApp.current_application}-#{credential.id}")
          external_id = credential.account['AWS ExternalID']
          assume_request.setExternalId(external_id) unless external_id.nil? || external_id.empty?
          assume_result = sts_client.assumeRole(assume_request)
          aws_credentials_provider = Java::ComAmazonawsAuth::AWSStaticCredentialsProvider.new(
            Java::ComAmazonawsAuth::BasicSessionCredentials.new(
              assume_result.getCredentials().getAccessKeyId(),
              assume_result.getCredentials().getSecretAccessKey(),
              assume_result.getCredentials().getSessionToken()
            )
          )
        end
        client = Java::ComAmazonawsServicesSqs::AmazonSQSClientBuilder.standard().
          withRegion(credential.account['AWS Region']).
          withCredentials(aws_credentials_provider).
          build()
        # Queue name can be specified as a simple queue name inside this account, or an ARN to specify another account
        queue_name = credential.account['SQS Queue Name']
        get_queue_url_request = Java::ComAmazonawsServicesSqsModel::GetQueueUrlRequest.new
        if queue_name =~ /\Aarn:aws:sqs:.+?:(\d+):([^:]+)\s*\z/
          get_queue_url_request.setQueueOwnerAWSAccountId($1.to_java_string)
          get_queue_url_request.setQueueName($2.to_java_string)
        else
          get_queue_url_request.setQueueName(queue_name.to_java_string)
        end
        queue_url = client.getQueueUrl(get_queue_url_request).getQueueUrl()
        # TODO: AWS SQS sending retry logic?
        send_msg_request = Java::ComAmazonawsServicesSqsModel::SendMessageRequest.new().
          withQueueUrl(queue_url).
          withMessageBody(body.to_java_string)   # has to be a string
        res = client.sendMessage(send_msg_request)
        KApp.logger.info("AWS SQS: Send message into queue #{credential.name}: #{res.toString()}")
        report_status = 'success'
        report_infomation = {"result" => res.toString()}
      rescue => e
        KApp.logger.error("AWS SQS: Exception when delivering to #{credential.name}")
        KApp.logger.log_exception(e)
        report_status = 'failure'
        report_infomation = {"exception" => e.to_s}
      end
      # Only send delivery reports if the application is interested
      if JSMessageBus::MessageBusPlatformConfiguration.new.for_bus(credential.id).has_delivery_report
        runtime = KJSPluginRuntime.current
        runtime.using_runtime do
          runtime.runtime.callSharedScopeJSClassFunction("O", "$messageBusSQSMessageAction", [credential.name, body, "report", report_status, JSON.generate(report_infomation)])
        end
        KApp.logger.info("AWS SQS: Done delivery notification for #{credential.name}: #{res.nil? ? "(no result)" : res.toString()}")
      end
    else
      KApp.logger.info("AWS SQS: Receiving not supported (#{credential.name} on app #{KApp.current_application})")
    end
  end

  # -------------------------------------------------------------------------

  module AmazonSQS

    def self.send_message(busId, reliability, body)
      # Check there's all the valid details at the point the message is sent
      ks = KeychainCredential.where_id_maybe(busId).where(:instance_kind=>'Amazon SQS Queue').first()
      raise JavaScriptAPIError, "Couldn't load SQS queue details" if ks.nil?
      JSMessageBus.add_to_delivery_queue(KApp.current_application, busId, true, reliability, body, '{}')
    end

  end

end
