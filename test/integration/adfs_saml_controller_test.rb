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
                    ADFS_KEYCHAIN_CRED_SP_X509CERT => "MIICnTCCAYWgAwIBAgIBATANBgkqhkiG9w0BAQsFADASMRAwDgYDVQQDDAdzcCB0 ZXN0MB4XDTE5MDIyNzIzMzA0NloXDTI5MDIyNDIzMzA0NlowEjEQMA4GA1UEAwwH c3AgdGVzdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJZP47vyYxqN Wcg8CyyQrYEj2DDm4XoaTrJLWQQxVHChG1i2S78btjI79f3Z5gSggpeIDFx9Fdfa GjudqUkk1NEk1a5mn64ndmUUQvS67D3kPTQPjUASRIWBpNJY+Z5EbXLq01wmyYEp 0Kr5te7Q6acIaBqSSHdV/opczvFRB7VQT6RlZ9DiOoxm9NbC3Omhp6yfhQsj0Z9h EfjOcxYCKwUlyAFtQeeYUZzsCF9CQ7nw/Cth6EJyjLDHsDF5I3x5QLKOF4UUaYxn uvM/cluBitAse2tpDMMH836++8yaAopucmzARu4tRNetvPN3wLvNLPyI/ozJvfRE 0GAXdt2PjisCAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAh1auV8vZ2djFBa47Kij3 xU9UWO1pwIzIdNy5JhA4xFvBFjWWInsdyy3UxQcS6bZneL/mPH+v6KnGsJ4vTMgo yrsfvGGZXVZz3pP3k8Ctvoj1x7yB+4BvJyQl/gtoxb2oEbEw5JQaKm67Rq37SRHq xWc/1NoJj87rDl9LRhn5juXDvNTQEDKZJSGPEd91Hq15jYf5972vdWPJwQHSoFra +q5ZTHWGwycBSUdPLa+3iXJTjy8gIAMxXNiRrz7qRSDiF6mWXQ/hT2d8BRbI/+tD 1EZoh5URwFhbySa8fgHLe+UjKOdXFa83aNuaTLzIuYAqCgWeqHcqPFTmHdOLlbTs nA==",
                  },
      :secret => { ADFS_KEYCHAIN_CRED_SP_PRIVATEKEY => "MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCWT+O78mMajVnI PAsskK2BI9gw5uF6Gk6yS1kEMVRwoRtYtku/G7YyO/X92eYEoIKXiAxcfRXX2ho7 nalJJNTRJNWuZp+uJ3ZlFEL0uuw95D00D41AEkSFgaTSWPmeRG1y6tNcJsmBKdCq +bXu0OmnCGgakkh3Vf6KXM7xUQe1UE+kZWfQ4jqMZvTWwtzpoaesn4ULI9GfYRH4 znMWAisFJcgBbUHnmFGc7AhfQkO58PwrYehCcoywx7AxeSN8eUCyjheFFGmMZ7rz P3JbgYrQLHtraQzDB/N+vvvMmgKKbnJswEbuLUTXrbzzd8C7zSz8iP6Myb30RNBg F3bdj44rAgMBAAECggEAWuxKapctYZNdWuUPMU721SY0kSgn/i9JqUowt3uLg3HA 1AG5ggmmRW7F119mZygctsLCD3ROsToqIiO1khwoa7anVw6WysbuNCh0dAtZ+fpF F2fM3pPuRP/uDptpq1XjCt+HKLgBrhL4OWRBrAtNOw+3wVL5aM5o4ZNQTuLgEclm sERblDt+uc2vSh4RsCWAhOwjb92fVYzj/GgHRfUJmnOrmaPdyTOPGqrGiCYiXgfh YQY0Q8mYoBPhX43WHNMjrcerWlYHOm2iSDG6PHs5HUAP2W81P4PacciIt16hVRBH vzcMkmqCZGYl8e5F5qUnsweMzAZ2TIcbnDPhzmu1AQKBgQD0rR+MIPx62n88YQAc IJKrmonhkhBclWaWCAzxTAkzGUTl6NAJh/5tWOb8KV7CPt3TYrjTFDiDjmjwU0NK QTk8UC1x209UTfMZXlFTK/smyH8RK2K2tQjgaxFs3jyRv8FacE9g8QmZv81Bk4Dh g6ci8A7UaNOFuV/SfgQ6tMs5gQKBgQCdRMH7OO2QFLRN5BSmaTg0tTM7SRN2XJbq uCD45m3n98cxwxEc1MkdR1ifAYT5wM2C1g5qAGxw+aHQyMG5G136MC4aND0K9eEO he3UFP55Gsp1+VUo+2+9uolzUaLPeBQ8e0A6hClW4T3m/abjhvAVX84OjmNt12Yr WxM6fcClqwKBgHpD7KjMbv5BIyWb3z8u87v2zIHAyJZLPeko+ra1ZT94mBo/PX4V zAj+TOajEawFWDnicjNgPmFXD49QPCbl8uD1u8/SZJDfJuR9YiwqpSUbOYvt3zUn v9jNB/ccEq5OYSN9Td1GdaKz2rCzMcr/S8zEotR30YNYP87ik+B2KbuBAoGAYaBs NrKJLnbb0rpyYzdQD9AoJHZhoYkqmjyBI2GP+n7i5a4s8lPZINbIWbSMwqmAKecN fZoTtzIP1Fa7g1hMx2GfTN7+wc4OzoAvOgdqTO1nn0KPLeif3gxtBOw5gEcPcNgl 7+1Y6Djcv4bYUcfTQ8F8XabgbDBZmTJpRlcH/w8CgYEAzJXMvpJOeHtQ4U5y79Bp +g0jGPq2MHvwIHo0+iyVrWnvj6gIlZj5Y169Uz2a5VkvYOUI1bH0CfnsMqBeO2De orT+iB/Mpn448UVn5/fASuFcpddSyuHV4sqg6hdLNhRpmvwyOG3CGijpCopQIfxU FOu7Fnb4eEAPVce4huq5iRk=" }
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
