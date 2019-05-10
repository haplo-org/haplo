# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2019            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Setup_SAML2Controller < ApplicationController
  policies_required :setup_system
  include SystemManagementHelper

  def render_layout
    'management'
  end

  VALID_NAME = /\A[a-z0-9.-]+\z/

  _GetAndPost
  def handle_add
    @name = params[:name] || ''
    if request.post? && @name =~ VALID_NAME

      gen = Java::SunSecurityToolsKeytool::CertAndKeyGen.new("RSA", "SHA256WithRSA", nil)
      gen.generate(2048)
      private_key = gen.getPrivateKey()
      name = Java::SunSecurityX509::X500Name.new("CN=sp #{@name}", "DEFAULT")
      cert = gen.getSelfCertificate(name, java.util.Date.new, 10*365*24*60*60)
      sp_key = "-----BEGIN PRIVATE KEY-----\r\n"+java.util.Base64.getMimeEncoder().encodeToString(private_key.getEncoded())+"\r\n-----END PRIVATE KEY-----"
      sp_cert = "-----BEGIN CERTIFICATE-----\r\n"+java.util.Base64.getMimeEncoder().encodeToString(cert.getEncoded())+"\r\n-----END CERTIFICATE-----"

      credential = KeychainCredential.new
      credential.name = @name
      credential.kind = Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_KIND
      credential.instance_kind = Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_INSTANCE_KIND
      credential.account = {
        Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_IDP_SSO_SERVICE_URL => "https://invalid.example.org/saml2",
        Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_IDP_ENTITYID => "https://invalid.example.org/",
        Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_IDP_METADATA_URL => "https://invalid.example.org/FederationMetadata/2007-06/FederationMetadata.xml",
        Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_IDP_LOGOUT_SERVICE_URL => "https://invalid.example.org/common/wsfederation?wa=wsignout1.0",
        Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_OPTIONS => '',
        Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_IDP_X509CERT => "Must update from IdP metadata URL",
        Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_SP_X509CERT => sp_cert,
        Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_ERROR_MESSAGE => Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_ERROR_MESSAGE__DEFAULT_TEXT
      }
      credential.secret = {
        Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_SP_PRIVATEKEY => sp_key
      }
      credential.save

      redirect_to "/do/setup/keychain/info/#{credential.id}?update=1"
    end
  end

  _GetAndPost
  def handle_config_with_metadata_url
    @credential = KeychainCredential.find(params[:id].to_i)
    raise "Bad credential ID" unless @credential && @credential.kind == Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_KIND
    if request.post?
      @url = params[:url]
      begin
        if @url && @url =~ /\Ahttps/i
          settings = Java::ComOneloginSaml2Settings::IdPMetadataParser.parseRemoteXML(Java::JavaNet::URL.new(@url))
          s = Java::ComOneloginSaml2Settings::SettingsBuilder
          account = @credential.account
          [
            [Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_IDP_SSO_SERVICE_URL, s::IDP_SINGLE_SIGN_ON_SERVICE_URL_PROPERTY_KEY],
            [Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_IDP_ENTITYID, s::IDP_ENTITYID_PROPERTY_KEY],
            [Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_IDP_LOGOUT_SERVICE_URL, s::IDP_SINGLE_LOGOUT_SERVICE_URL_PROPERTY_KEY],
            [Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_IDP_X509CERT, s::IDP_X509CERT_PROPERTY_KEY]
          ].each do |key, prop|
            value = settings.get(prop)
            if value.nil?
              account[key] = ''
            else
              if key == Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_IDP_LOGOUT_SERVICE_URL
                value += '?wa=wsignout1.0' unless value =~ /\?/
              end
              account[key] = value
            end
          end
          # The IdP might have additional certificates
          multi_cert_index = 0
          while multi_cert_index < 256
            multi_cert_key = "#{s::IDP_X509CERTMULTI_PROPERTY_KEY}.#{multi_cert_index}"
            cert = settings.get(multi_cert_key.to_java_string)
            if cert.nil?
              break
            else
              account[Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_IDP_X509CERT] += "\n,\n"+cert
            end
            multi_cert_index += 1
          end
          account[Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_IDP_METADATA_URL] = @url
          @credential.account = account
          @credential.save
          redirect_to "/do/setup/keychain/info/#{@credential.id}"
        end
      rescue => e
        KApp.logger.error("Request to update credential from URL failed: #{@url}")
        KApp.logger.log_exception(e)
      end
    end
  end

end
