# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module JSMessageBus

  KNotificationCentre.when(:server, :starting) do
    KeychainCredential::MODELS.push({
      :kind => 'Message Bus',
      :instance_kind => 'Amazon SNS Topic',
      :account => {
        "SNS Topic ARN" => '',
        "AWS Region" => '',
        "AWS Access Key ID" => '',
        "AWS Assume Role" => '',
        "AWS ExternalID" => ''},
      :secret => {"AWS Access Key Secret" => ''}
    })
    KeychainCredential::USER_INTERFACE[['Message Bus','Amazon SNS Topic']] = {
      :notes_edit => "'AWS Assume Role' and 'AWS ExternalID' are optional. Leave blank to use a static credential."
    }
  end

  BUS_QUERY['Amazon SNS Topic'] = Proc.new do |credential|
    {'kind'=>'Amazon SNS Topic', 'name'=>credential.name}
  end

  BUS_DELIVERY['Amazon SNS Topic'] = Proc.new do |is_send, credential, reliability, body, transport_options|
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
        client = Java::ComAmazonawsServicesSNS::AmazonSNSClientBuilder.standard().
          withRegion(credential.account['AWS Region']).
          withCredentials(aws_credentials_provider).
          build()
        # Topic name can be specified as a simple queue name inside this account, or an ARN to specify another account
        topic_arn = credential.account['SNS Topic ARN']
        res = client.publish(topic_arn, body.to_java_string)
        KApp.logger.info("AWS SNS: Send message into queue #{credential.name}: #{res.toString()}")
        report_status = 'success'
        report_infomation = {"result" => res.toString()}
      rescue => e
        KApp.logger.error("AWS SNS: Exception when delivering to #{credential.name}")
        KApp.logger.log_exception(e)
        report_status = 'failure'
        report_infomation = {"exception" => e.to_s}
      end
      # Only send delivery reports if the application is interested
      if JSMessageBus::MessageBusPlatformConfiguration.new.for_bus(credential.id).has_delivery_report
        runtime = KJSPluginRuntime.current
        runtime.using_runtime do
          runtime.runtime.callSharedScopeJSClassFunction("O", "$messageBusSNSMessageAction", [credential.name, body, "report", report_status, JSON.generate(report_infomation)])
        end
        KApp.logger.info("AWS SNS: Done delivery notification for #{credential.name}: #{res.nil? ? "(no result)" : res.toString()}")
      end
    else
      KApp.logger.info("AWS SNS: Receiving not supported (#{credential.name} on app #{KApp.current_application})")
    end
  end

  # -------------------------------------------------------------------------

  module AmazonSNS

    def self.send_message(busId, reliability, body)
      # Check there's all the valid details at the point the message is sent
      ks = KeychainCredential.find(:first, :conditions => {:id=>busId, :instance_kind=>'Amazon SNS Topic'})
      raise JavaScriptAPIError, "Couldn't load SNS topic details" if ks.nil?
      JSMessageBus.add_to_delivery_queue(KApp.current_application, busId, true, reliability, body, '{}')
    end

  end

end
