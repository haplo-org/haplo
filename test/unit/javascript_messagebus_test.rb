# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavascriptRuntimeTest < Test::Unit::TestCase
  include JavaScriptTestHelper

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_messagebus/messagebus_test1")

  def test_messagebus_loopback
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
    KeychainCredential.new({
      :kind => 'Message Bus', :instance_kind => 'Inter-application', :name => 'Test Inter App Bus',
      :account_json => '{"Bus":"https://example.org/name"}', :secret_json => '{"Secret":"secret1234"}'
    }).save!
    install_grant_privileges_plugin_with_privileges('pMessageBusRemote')
    assert KPlugin.install_plugin('messagebus_test1')
    begin
      run_javascript_test(:file, 'unit/javascript/javascript_messagebus/test_messagebus_interapp_single_app.js', nil, "grant_privileges_plugin") do |runtime|
        support_root = runtime.host.getSupportRoot
        runtime.host.setTestCallback(proc { |string|
          if string == 'deliverInterAppMessages'
            thread = Thread.new { JSMessageBus::InterApplication.deliver_queued_messages }
            thread.join
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

end
