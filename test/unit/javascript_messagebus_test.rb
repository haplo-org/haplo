# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavascriptRuntimeTest < Test::Unit::TestCase
  include JavaScriptTestHelper

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_messagebus/messagebus_test1")
  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_messagebus/messagebus_test_kinesis")
  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_messagebus/messagebus_test_sqs")

  def test_messagebus_loopback
    db_reset_test_data
    run_javascript_test(:file, 'unit/javascript/javascript_messagebus/test_messagebus_loopback.js')
  end

  def test_messagebus_loopback_keychain_nopriv
    run_javascript_test(:file, 'unit/javascript/javascript_messagebus/test_messagebus_loopback_keychain_nopriv.js')
  end

  def test_messagebus_loopback_keychain
    KeychainCredential.delete_all
    KeychainCredential.new({
      :kind => 'Message Bus', :instance_kind => 'Loopback', :name => 'Test Message Bus',
      :account_json => '{"API code":"test:loopback:from_keychain"}', :secret_json => '{}'
    }).save!
    install_grant_privileges_plugin_with_privileges('pMessageBusRemote')
    begin
      run_javascript_test(:file, 'unit/javascript/javascript_messagebus/test_messagebus_loopback_keychain.js', nil, "grant_privileges_plugin")
    ensure
      uninstall_grant_privileges_plugin
      KeychainCredential.delete_all
    end
  end

  def test_messagebus_interapp_single_app
    KeychainCredential.delete_all
    bus = KeychainCredential.new({
      :kind => 'Message Bus', :instance_kind => 'Inter-application', :name => 'Test Inter App Bus',
      # Include the app ID in the name of the bus, otherwise tests run in parallel will interfere with each other
      :account_json => %Q!{"Bus":"https://example.org/name/#{_TEST_APP_ID}"}!,
      :secret_json => '{"Secret":"secret1234"}'
    })
    bus.save!
    install_grant_privileges_plugin_with_privileges('pMessageBusRemote')
    assert KPlugin.install_plugin('messagebus_test1')
    # Check platform bus configuration
    expected_plugin_messagebus_config = {}
    expected_plugin_messagebus_config[bus.id.to_s] = [true,false]
    assert_equal expected_plugin_messagebus_config, JSON.parse(KApp.global(:js_messagebus_config))
    platform_config = JSMessageBus::MessageBusPlatformConfiguration.new
    assert_equal true, platform_config.for_bus(bus.id).has_receive
    assert_equal false, platform_config.for_bus(bus.id).has_delivery_report
    begin
      run_javascript_test(:file, 'unit/javascript/javascript_messagebus/test_messagebus_interapp_single_app.js', nil, "grant_privileges_plugin") do |runtime|
        support_root = runtime.host.getSupportRoot
        runtime.host.setTestCallback(proc { |string|
          if string == 'deliverInterAppMessages'
            deliver = JSMessageBus::DeliverMessages.new(_TEST_APP_ID)
            deliver.deliver_from_queue
          end
          ''
        })
      end
    ensure
      uninstall_grant_privileges_plugin
      KPlugin.uninstall_plugin('messagebus_test1')
      KeychainCredential.delete_all
    end
  end

  # -------------------------------------------------------------------------

  # To run this test, a file .haplo-test-kinesis-credentials.json must exist in the home directory, like this:
  <<_
      {
        "kinesis": {
          "stream": "stream-name",
          "region": "eu-west-2"
        },
        "aws": {
          "id": "AWS ACCESS ID",
          "secret": "AWS ACCESS SECRET KEY"
        }
      }
_
  # -----

  KINESIS_CREDENTIALS_FILE = "#{ENV['HOME']}/.haplo-test-kinesis-credentials.json"
  if File.exist?(KINESIS_CREDENTIALS_FILE)
    KINESIS_CREDENTIALS = File.open(KINESIS_CREDENTIALS_FILE) { |f| JSON.parse(f.read) }
  else
    puts
    puts "*** Not testing Amazon Kinesis functionality because #{KINESIS_CREDENTIALS_FILE} does not exist."
    puts
    KINESIS_CREDENTIALS = nil
  end

  def test_messagebus_amazonkinesis
    return unless KINESIS_CREDENTIALS
    KeychainCredential.delete_all
    ks_account = {
      "Kinesis Stream Name" => KINESIS_CREDENTIALS['kinesis']['stream'],
      "Kinesis Stream Partition Key" => 'partition1',
      "AWS Region" => KINESIS_CREDENTIALS['kinesis']['region'],
      "AWS Access Key ID" => KINESIS_CREDENTIALS['aws']['id']
    }
    ks_secret = { "AWS Access Key Secret" => KINESIS_CREDENTIALS['aws']['secret'] }
    KeychainCredential.new({
      :kind => 'Message Bus', :instance_kind => 'Amazon Kinesis Stream', :name => 'test-kinesis',
      :account_json => ks_account.to_json, :secret_json => ks_secret.to_json
    }).save!
    assert KPlugin.install_plugin('messagebus_test_kinesis')
    install_grant_privileges_plugin_with_privileges('pMessageBusRemote')
    begin
      run_javascript_test(:file, 'unit/javascript/javascript_messagebus/test_messagebus_amazonkinesis.js', nil, "grant_privileges_plugin") do |runtime|
        support_root = runtime.host.getSupportRoot
        runtime.host.setTestCallback(proc { |string|
          if string == 'deliverAmazonKinesisMessages'
            deliver = JSMessageBus::DeliverMessages.new(_TEST_APP_ID)
            deliver.deliver_from_queue
          end
          ''
        })
      end
    ensure
      uninstall_grant_privileges_plugin
      KPlugin.uninstall_plugin('messagebus_test_kinesis')
      KeychainCredential.delete_all
    end
  end

  # -------------------------------------------------------------------------

  # To run this test, a file .haplo-test-sqs-credentials.json must exist in the home directory, like this:
  <<_
      {
        "sqs": {
          "queue": "queue-name",
          "region": "eu-west-2"
        },
        "aws": {
          "id": "AWS ACCESS ID",
          "secret": "AWS ACCESS SECRET KEY"
        }
      }
_
  # -----

  SQS_CREDENTIALS_FILE = "#{ENV['HOME']}/.haplo-test-sqs-credentials.json"
  if File.exist?(SQS_CREDENTIALS_FILE)
    SQS_CREDENTIALS = File.open(SQS_CREDENTIALS_FILE) { |f| JSON.parse(f.read) }
  else
    puts
    puts "*** Not testing Amazon SQS functionality because #{SQS_CREDENTIALS_FILE} does not exist."
    puts
    SQS_CREDENTIALS = nil
  end

  def test_messagebus_amazonsqs
    return unless SQS_CREDENTIALS
    KeychainCredential.delete_all
    ks_account = {
      "SQS Queue Name" => SQS_CREDENTIALS['sqs']['queue'],
      "AWS Region" => SQS_CREDENTIALS['sqs']['region'],
      "AWS Access Key ID" => SQS_CREDENTIALS['aws']['id']
    }
    ks_secret = { "AWS Access Key Secret" => SQS_CREDENTIALS['aws']['secret'] }
    KeychainCredential.new({
      :kind => 'Message Bus', :instance_kind => 'Amazon SQS Queue', :name => 'test-sqs',
      :account_json => ks_account.to_json, :secret_json => ks_secret.to_json
    }).save!
    assert KPlugin.install_plugin('messagebus_test_sqs')
    install_grant_privileges_plugin_with_privileges('pMessageBusRemote')
    begin
      run_javascript_test(:file, 'unit/javascript/javascript_messagebus/test_messagebus_amazonsqs.js', nil, "grant_privileges_plugin") do |runtime|
        support_root = runtime.host.getSupportRoot
        runtime.host.setTestCallback(proc { |string|
          if string == 'deliverAmazonSQSMessages'
            deliver = JSMessageBus::DeliverMessages.new(_TEST_APP_ID)
            deliver.deliver_from_queue
          end
          ''
        })
      end
    ensure
      uninstall_grant_privileges_plugin
      KPlugin.uninstall_plugin('messagebus_test_sqs')
      KeychainCredential.delete_all
    end
  end


  # -------------------------------------------------------------------------

  def test_message_bus_platform_config_decoding
    c0 = JSMessageBus::MessageBusPlatformConfiguration.new('{"42":[false,true],"98":[true,false],"65":[false,false]}')
    assert_equal false, c0.for_bus(42).has_receive
    assert_equal true,  c0.for_bus(42).has_delivery_report
    assert_equal true,  c0.for_bus(98).has_receive
    assert_equal false, c0.for_bus(65).has_delivery_report
    # Not explicitly configured
    assert_equal true,  c0.for_bus(9999).has_receive
    assert_equal true,  c0.for_bus(9999).has_delivery_report

    c1 = JSMessageBus::MessageBusPlatformConfiguration.new('{}')
    assert_equal true,  c1.for_bus(42).has_receive
    assert_equal true,  c1.for_bus(42).has_delivery_report

    # Use app global
    KApp.set_global(:js_messagebus_config, '{"42":[true,false],"87":[true,true]}')
    c2 = JSMessageBus::MessageBusPlatformConfiguration.new
    assert_equal true,  c2.for_bus(42).has_receive
    assert_equal false, c2.for_bus(42).has_delivery_report
  end

end
