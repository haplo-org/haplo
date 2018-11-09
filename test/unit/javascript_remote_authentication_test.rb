# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavascriptRemoteAuthenticationTest < Test::Unit::TestCase
  include JavaScriptTestHelper

  HAVE_OTP_IMPLEMENTATION = KFRAMEWORK_LOADED_COMPONENTS.include?('management')

  def test_remote_authentication_api
    db_reset_test_data
    install_grant_privileges_plugin_with_privileges('pRemoteAuthenticationService')
    begin
      # Check error cases
      run_javascript_test(:file, 'unit/javascript/javascript_remote_authentication/test_remote_authentication1_no_priv.js')
      run_javascript_test(:file, 'unit/javascript/javascript_remote_authentication/test_remote_authentication1.js', nil, "grant_privileges_plugin")
      # Set a known password
      user42 = User.find(42)
      user42.password = 'abcd5432'
      user42.save!
      # Create credentials for the LDAP server
      ldap_account = {
        "URL" => 'ldaps://127.0.0.1:1636',
        "Certificate" => "test.#{KHostname.hostname}",
        "CA" => File.open(File.expand_path("~/haplo-dev-support/certificates/server.crt")) { |f| f.read }, # expect CA
        "Path" => "ou=Department Y,dc=example,dc=com : ou=Department X,dc=example,dc=com",
        "Search" => "uid={0}",
        "Username" => "cn=service_account"
      }
      credential = KeychainCredential.new({:name => 'test-ldap', :kind => 'Authentication Service', :instance_kind => 'LDAP' })
      credential.account = ldap_account
      credential.secret = {"Password" => 'abcd9876'}
      credential.save
      # And another with a different set of attributes
      ldap_account2 = ldap_account.dup
      ldap_account2['Attributes (single value)'] = 'uid cn notarealattribute'
      ldap_account2['Attributes (multi-value)'] = 'notarealmultivalue'
      credential2 = KeychainCredential.new({:name => 'test-ldap-reduced-attributes', :kind => 'Authentication Service', :instance_kind => 'LDAP' })
      credential2.account = ldap_account2
      credential2.secret = {"Password" => 'abcd9876'}
      credential2.save
      # Wait for LDAP server to start (probably have started by now anyway, so no point in doing anything fancy with mutexes etc)
      sleep(0.1) while ! @@test_ldap_server_started
      # Check normal use
      run_javascript_test(:file, 'unit/javascript/javascript_remote_authentication/test_remote_authentication2.js', nil, "grant_privileges_plugin")
    ensure
      KeychainCredential.delete_all
      uninstall_grant_privileges_plugin
    end
  end

  # ---------------------------------------------------------------------------------------------------

  def test_local_otp_provider
    install_grant_privileges_plugin_with_privileges('pRemoteAuthenticationService')
    return unless HAVE_OTP_IMPLEMENTATION
    IntegrationTest::AUTHENTICATION_LOGIN_TEST_FAILURE_LOCK.synchronize do
      time1_token = HardwareOtpToken.find_by_identifier('test-1-time')
      time1_token.counter = 12345
      time1_token.save! # reset counter
      data = {
        "NEXT_OTP" => TestHardwareOTP.next_otp_for("test-1-time")
      }
      run_javascript_test(:file, 'unit/javascript/javascript_remote_authentication/test_local_otp_provider.js', data, "grant_privileges_plugin")
    end
  ensure
    uninstall_grant_privileges_plugin
  end

  # ---------------------------------------------------------------------------------------------------

  # Configure very small test page size for LDAP searches
  raise "Was expecting a different page size" unless JSRemoteAuthenticationServiceSupport::LDAPAuthenticationService::LDAP_SEARCH_RESULT_PAGE_SIZE == 2048
  begin
    old_verbosity = $VERBOSE
    $VERBOSE = nil # prevent warning about changing constant being displayed
    JSRemoteAuthenticationServiceSupport::LDAPAuthenticationService.const_set(:LDAP_SEARCH_RESULT_PAGE_SIZE, 1)
    $VERBOSE = old_verbosity
  end

  # ---------------------------------------------------------------------------------------------------

  # Test LDAP server

  @@test_ldap_server_started = false

  def self.start_test_ldap_server
    # Run the startup process in a new thread, to avoid delaying startup any more than necessary
    Thread.new do
      # Create listening LDAP server using test SSL certificates
      config = Java::ComUnboundidLdapListener::InMemoryDirectoryServerConfig.new("dc=example,dc=com")
      config.addAdditionalBindCredentials("cn=service_account", "abcd9876")
      sslContext = Java::OrgHaploCommonUtils::SSLCertificates.load(File.expand_path("~/haplo-dev-support/certificates"), "server", nil, true)
      config.setListenerConfigs(Java::ComUnboundidLdapListener::InMemoryListenerConfig.createLDAPSConfig(
          "LDAPS", 1636, sslContext.getServerSocketFactory()
      ))
      ds = Java::ComUnboundidLdapListener::InMemoryDirectoryServer.new(config)
      ds.importFromLDIF(false, "#{File.dirname(__FILE__)}/javascript/javascript_remote_authentication/ldap_test_directory_contents.ldif")
      ds.startListening()
      @@test_ldap_server_started = true;
      at_exit { ds.shutDown(true); puts "hustdown " }
    end
  end

  start_test_ldap_server()

end
