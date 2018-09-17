# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class ADFSAuthenticationTest < IntegrationTest
  include JavaScriptTestHelper

  ADFS_KEYCHAIN_CRED_KIND = "SAML2 Identity Provider".freeze
  ADFS_KEYCHAIN_CRED_INSTANCE_KIND = "AD FS".freeze

  ADFS_KEYCHAIN_CRED_IDP_ENTITYID = "IdP Entity ID".freeze
  ADFS_KEYCHAIN_CRED_IDP_SSO_SERVICE_URL = "IdP SSO Service URL".freeze
  ADFS_KEYCHAIN_CRED_IDP_LOGOUT_SERVICE_URL = "IdP Sign-Out URL".freeze
  ADFS_KEYCHAIN_CRED_IDP_X509CERT = "IdP x509 Certificate".freeze

  ADFS_KEYCHAIN_CRED_SP_X509CERT = "SP x509 Certificate".freeze
  ADFS_KEYCHAIN_CRED_SP_PRIVATEKEY = "SP Private Key".freeze

  VALID_IDP_CERT = %q(MIICvjCCAaYCCQCLlkVW+aSqUTANBgkqhkiG9w0BAQsFADAhMR8wHQYDVQQDDBZU
ZXN0IFNBTUwyIENlcnRpZmljYXRlMB4XDTE4MDMxNDE5NDY0OFoXDTI4MDMxMTE5
NDY0OFowITEfMB0GA1UEAwwWVGVzdCBTQU1MMiBDZXJ0aWZpY2F0ZTCCASIwDQYJ
KoZIhvcNAQEBBQADggEPADCCAQoCggEBALjqOFsPFZ8y+F4ijQcOeYWWaj9esETh
/O0/kXzA9eRcIFgnOhPGspNx3/I/SYFyM/Aq9cjngZryIVkfuENZczKr90IxSpid
4l5N1sSjlUVFd2dA2pBZz9VYSlYSYP6afoJWhq/Qy9nUhUpObXC//ZYOASwTEdWL
UeFNaWjuqgnIeGOYY+7oifpdpyWNYeQwnXGZicw/0NUphfT9vh0tmJzVQC85Ak67
1E0tq1Fp8iltRau2mZJNHRT6ZTQ6uHTe0mfT+8BvLf6I9lrMsqb9oWuxnB/8XsW8
fPfBDlT56yPrUMABGtYpYdzsK54sVQ4lYD+8nw4QTnQZd9AUD4yxlvUCAwEAATAN
BgkqhkiG9w0BAQsFAAOCAQEAVunFhd8i2Jir3BCaoM6SPclnsFfG5Ph9Z+6c0S6H
TQ1bsLenxZ8tujcM/LkPKycXxGyRRUR9XX/ecriQJ944JLl1dZJuONYh1sSbCEvR
aTv2PMQ7L42K5qYPJ+szOLI+SS95Dhc5NEA9aZERT3MdAWZYmkqcqjsYmHJeM51f
KWfX9VMbiqkKiqeE1uucfSsqeovNW6I1kGcmAHldSvXH1Aljffspp8Gh7pfHru1m
huwWg0oJ+xiUiy1FxS7cC/OreIULQLr4tEDQ8GUr0wFsISMcE2MeYmxz0Xfq0XLh
eBl4A19/xqjLW/al9KOZpi/4PaoNwL1tscwwWuQ+zYBNQw==).freeze

  def teardown
    KeychainCredential.destroy_all
  end

  # -------------------------------------------------------------------------

  def create_an_adfs_keychain_credential(sp_name, idp_url)
    credential = KeychainCredential.new({
      :name => sp_name,
      :kind => ADFS_KEYCHAIN_CRED_KIND,
      :instance_kind => ADFS_KEYCHAIN_CRED_INSTANCE_KIND,
      :account => { ADFS_KEYCHAIN_CRED_IDP_SSO_SERVICE_URL => idp_url,
                    ADFS_KEYCHAIN_CRED_IDP_ENTITYID => "https://identity-provider.example.com/424242-42aa-42aa-aa42-42aa42aaaa42/",
                    ADFS_KEYCHAIN_CRED_IDP_LOGOUT_SERVICE_URL => "https://login.example.com/common/wsfederation?wa=wsignout1.0",
                    # x509 encoded certificate for validating the Identity Provider.
                    ADFS_KEYCHAIN_CRED_IDP_X509CERT => VALID_IDP_CERT,

                    # x509 encoded certificate for validating the Service Provider.
                    ADFS_KEYCHAIN_CRED_SP_X509CERT => "{blah cert}",
                  },
      :secret => { ADFS_KEYCHAIN_CRED_SP_PRIVATEKEY => "{blah key}" }
    })
    credential.save!
  end

  # -------------------------------------------------------------------------

  def test_metadata_and_redirect_to_adfs

    idp_url = "https://login.example.com/2424242-42aa-42aa-aa42-42aa42aaaa42/saml2"
    sp_name = "TEST_SERVICE_NAME"

    create_an_adfs_keychain_credential(sp_name, idp_url)

    # Fetch the metadata and check it looks OK
    get '/do/saml2-sp/'+sp_name+'/metadata'
    assert response.body.starts_with?('<?xml version="1.0"?><md:EntityDescriptor')
    assert response.body =~ /AssertionConsumerService/

    # Fetch the local login URL, expecting it to redirect to the IDP.
    get_302 '/do/saml2-sp/'+sp_name+'/login'
    assert response.kind_of? Net::HTTPRedirection

    location = URI(response['location'])
    expected = URI(idp_url)

    # Check that the host we're redirected to is the IdP's SSO server ...
    assert_equal location.host, expected.host

    # ... and that the redirected path is the same.
    assert_equal location.path, expected.path

    # Now try it again with a non-existent service name – we expect a 500 back from this.
    get_500 '/do/saml2-sp/THIS_WILL_NOT_WORK/login'
    assert response.body.include?("Unknown SAML2 Name.")
  end

  # -------------------------------------------------------------------------

  def test_adfs_javascript_interface_basics
    create_an_adfs_keychain_credential('js-idp.example.org', 'https://js-idp.example.org/idp')
    create_an_adfs_keychain_credential('bad-name!/', 'https://js-idp.example.org/bad-name')
    run_javascript_test(:file, 'integration/javascript/adfs_saml_controller/test_adfs_javascript_interface_no_priv.js')
    install_grant_privileges_plugin_with_privileges('pStartOAuth')
    run_javascript_test(:file, 'integration/javascript/adfs_saml_controller/test_adfs_javascript_interface_basics.js', nil, "grant_privileges_plugin")
  ensure
    uninstall_grant_privileges_plugin
  end

end
