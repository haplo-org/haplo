# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# NOTE: This is not a normal ApplicationController because it needs direct access to the Java
# request & response, so doesn't fit the usual model at all.
class Saml2ServiceProviderController

  include KPlugin::HookSite

  ADFS_KEYCHAIN_CRED_KIND = "SAML2 Identity Provider".freeze
  ADFS_KEYCHAIN_CRED_INSTANCE_KIND = "AD FS".freeze

  ADFS_KEYCHAIN_CRED_IDP_SSO_SERVICE_URL = "IdP SSO Service URL".freeze
  ADFS_KEYCHAIN_CRED_IDP_ENTITYID = "IdP Entity ID".freeze
  ADFS_KEYCHAIN_CRED_IDP_LOGOUT_SERVICE_URL = "IdP Sign-Out URL".freeze
  ADFS_KEYCHAIN_CRED_IDP_X509CERT = "IdP x509 Certificate".freeze

  ADFS_KEYCHAIN_CRED_SP_X509CERT = "SP x509 Certificate".freeze
  ADFS_KEYCHAIN_CRED_SP_PRIVATEKEY = "SP Private Key".freeze

  ADFS_KEYCHAIN_VALID_NAME_REGEXP = /\A[a-zA-Z0-9\.-]+\z/
  
  SAML2_PROTOCOL_HEALTH_EVENTS = KFramework::HealthEventReporter.new('SAML2_PROTOCOL_ERROR')

  KeychainCredential::MODELS.push({
    :kind => ADFS_KEYCHAIN_CRED_KIND,
    :instance_kind => ADFS_KEYCHAIN_CRED_INSTANCE_KIND,
    :account => {
      ADFS_KEYCHAIN_CRED_IDP_SSO_SERVICE_URL => "https://login.example.com/2424242-42aa-42aa-aa42-42aa42aaaa42/saml2",
      ADFS_KEYCHAIN_CRED_IDP_ENTITYID => "https://identity-provider.example.com/424242-42aa-42aa-aa42-42aa42aaaa42/",
      ADFS_KEYCHAIN_CRED_IDP_LOGOUT_SERVICE_URL => "https://login.example.com/common/wsfederation?wa=wsignout1.0",
      # x509 encoded certificate for validating the Identity Provider.
      ADFS_KEYCHAIN_CRED_IDP_X509CERT => "Certificate created by your AD FS server.\nObtain from IdP and paste it in here.",
      # x509 encoded certificate for validating the Service Provider.
      ADFS_KEYCHAIN_CRED_SP_X509CERT => "Generate a unique certificate and key for this SP.\nPaste certificate here, private key below.",
    },
    :secret => {
      ADFS_KEYCHAIN_CRED_SP_PRIVATEKEY => ""
    }
  })
  KeychainCredential::USER_INTERFACE[[ADFS_KEYCHAIN_CRED_KIND,ADFS_KEYCHAIN_CRED_INSTANCE_KIND]] = {
    :notes_edit => "#{ADFS_KEYCHAIN_CRED_IDP_SSO_SERVICE_URL} is the Single Sign-On Service URL, #{ADFS_KEYCHAIN_CRED_IDP_ENTITYID} is the Entity ID of the identity provider,  #{ADFS_KEYCHAIN_CRED_IDP_LOGOUT_SERVICE_URL} is the Sign-Out URL and #{ADFS_KEYCHAIN_CRED_IDP_X509CERT} is that provider's certificate. These will all be given to you when the IdP is configured.\nYou should generate a self-signed SSL certificate for this Service Provider (SP), and place the certificate in #{ADFS_KEYCHAIN_CRED_SP_X509CERT} and the key in #{ADFS_KEYCHAIN_CRED_SP_PRIVATEKEY}.\nThe name of this credential must be formed of a-z, A-Z, 0-9, . and - characters only.",
    :information => Proc.new do |credential|
      information = []
      unless credential.name =~ ADFS_KEYCHAIN_VALID_NAME_REGEXP
        information.push([:warning, "The name of this credential is not valid. It must be formed of a-z, A-Z, 0-9, . and - characters only."])
      end
      information
    end
  }

  # -------------------------------------------------------------------------

  def self.handle(path, request, response)
    _, _, _, sp_name, action = path.split('/')
    controller = Saml2ServiceProviderController.new
    case action
    when 'login'
      controller.handle_login(sp_name, request, response)   
    when 'metadata'
      controller.handle_metadata(sp_name, request, response)      
    when 'assertion-consumer-service'
      controller.handle_assertion_consumer_service(sp_name, request, response)      
    else
      response.setStatus(404)
      response.addHeader("Cache-Control", "private, no-cache")
      response.getWriter().print("Unknown SAML2 SP action")
    end
  end

  # This code is based on the OneLogin sample web app:
  # https://github.com/onelogin/java-saml/blob/master/samples/java-saml-tookit-jspsample/src/main/webapp/metadata.jsp

  def handle_metadata(sp_name, request, response)
    settings, idp_url = get_saml2_settings(sp_name)

    return if respond_with_error_when_no_settings(settings, response)

    settings.setSPValidationOnly(true)

    metadata = settings.getSPMetadata()

    # To-do check errors!
    errors = Java::ComOneloginSaml2Settings::Saml2Settings.validateMetadata(metadata);

    response.addHeader("Content-Type", "text/xml; charset=utf-8")
    response.getWriter().print(metadata)
  end

  # Sends a request to an AD FS server, asking it to authenticate a principal (e.g. a user). Based on:
  # https://github.com/onelogin/java-saml/blob/master/samples/java-saml-tookit-jspsample/src/main/webapp/dologin.jsp

  def handle_login(sp_name, request, response)
    # Follow the AD FS convention of passing the RelayState around as an HTTP parameter.
    return_url = get_relay_state(request)

    settings, idp_url = get_saml2_settings(sp_name)

    return if respond_with_error_when_no_settings(settings, response)

    # If we haven't got a name, it's an invalid request.
    if settings.nil?
      response.setStatus(500)
      response.addHeader("Cache-Control", "private, no-cache")
      response.getWriter().print("Unknown SAML2 Name.")
      return
    end

    # Create a com.onelogin.saml2.Auth object ...
    auth = Java::ComOneloginSaml2::Auth.new(settings, request, response)

    # ... and initiate a login request.
    auth.login(return_url)
  end

  # Handle the acs response from the AD FS server. Based on:
  # https://github.com/onelogin/java-saml/blob/master/samples/java-saml-tookit-jspsample/src/main/webapp/acs.jsp

  def handle_assertion_consumer_service(sp_name, request, response)

    settings, idp_url = get_saml2_settings(sp_name)

    return if respond_with_error_when_no_settings(settings, response)

    # onelogin.saml2.security.want_nameid - set to false to avoid scary exception being thown from OneLogin.
    # See discussion at https://github.com/onelogin/python-saml/issues/112
    settings.setWantNameId(false);

    auth = Java::ComOneloginSaml2::Auth.new(settings, request, response)

    auth.processResponse();

    errors = auth.getErrors();

    if errors.isEmpty()
      # Successfully authenticated

      # RelayState isn't included in the block of signed attributes, but outside as an HTTP param
      relaystate = get_relay_state(request)

      jattributes = auth.getAttributes()

      # Rebuild the Java data structure into a Ruby one that we can later serialise to JSON
      attributes = {}
      jattributes.each do |key, value|
        attributes[key] = value.to_a
      end

      auth_info = {
        'token' => attributes,
        'provider' => idp_url,
        'service' => sp_name
      }

      # Add in the RelayState as user data.
      auth_info["data"] = relaystate if relaystate

      json = JSON.generate(auth_info)

      # Call the hook so a plugin can set a user and return a redirect path
      redirect_path = nil
      # To be able to set logged in users, the hook needs to be able to write to the session
      # and set cookies in the response.
      # Create a controller and set as active request to enable it to use the normal handling
      # infrastructure, even though this controller is 'special'. Some poking is required to
      # get the current user for this session.
      exchange = KFramework::Exchange.new(KApp.current_application, KFramework::JavaRequest.new(request, '', true))
      session = ApplicationController.make_background_controller(User.cache[User::USER_ANONYMOUS], exchange).session
      user = User.cache[session[:uid] || User::USER_ANONYMOUS]
      AuthContext.with_user(user) do
        controller = ApplicationController.make_background_controller(user, exchange)
        controller.session # load session so it can be modified
        KFramework.with_request_context(controller, exchange) do
          call_hook(:hOAuthSuccess) do |hooks|
            redirect_path = hooks.run(json).redirectPath
          end
        end
        # Commit any session changes and apply Set-cookie headers
        controller.session_commit
        exchange.response.set_cookie_headers()
        exchange.response.headers.values(KFramework::Headers::SET_COOKIE).each do |value|
          response.addHeader(KFramework::Headers::SET_COOKIE, value)
        end
      end
      # TODO: The code to allow a plugin to set users repeats a lot of functionality. It would be better to use the normal controller functionality, but this requires a lot of changes to allow access to Java request and response and the framework to leave them alone.

      if redirect_path
        response.sendRedirect redirect_path
        return
      end

    else
      SAML2_PROTOCOL_HEALTH_EVENTS.log_and_report_event("Error while handling SAML ACS for "+sp_name, errors.to_a.inspect)
      response.setStatus(500)
      response.addHeader("Cache-Control", "private, no-cache")
      response.getWriter().print("Error while handling SAML ACS for "+sp_name+".\n"+errors.to_a.inspect)
    end
  end

  def get_saml2_settings(sp_name)

    # Rather than using a onelogin.saml.properties file, we create a properties object to pass to the constructor.

    properties = Java::JavaUtil::Properties.new()

    s = Java::ComOneloginSaml2Settings::SettingsBuilder

    #  If 'strict' is True, then the Java Toolkit will reject unsigned
    #  or unencrypted messages if it expects them signed or encrypted
    #  Also will reject the messages if not strictly follow the SAML
    properties.setProperty(s::STRICT_PROPERTY_KEY, 'true')

    # Minimum requirements (to avoid an Invalid settings error) are:
    # Invalid settings: sp_entityId_not_found, sp_acs_not_found, idp_entityId_not_found, idp_sso_url_invalid, idp_cert_or_fingerprint_not_found_and_required

    #  Service Provider Data that we are deploying.

    sp_url = KApp.url_base+'/do/saml2-sp/'+sp_name+'/'

    #  Identifier of the SP entity  (must be a URI - otherwise sp_entityId_not_found)
    properties.setProperty(s::SP_ENTITYID_PROPERTY_KEY, sp_url+'metadata')

    # Specifies info about where and how the <AuthnResponse> message MUST be
    # returned to the requester, in this case our onelogin.saml2.sp.
    # URL Location where the <Response> from the IdP will be returned
    properties.setProperty(s::SP_ASSERTION_CONSUMER_SERVICE_URL_PROPERTY_KEY, sp_url+'assertion-consumer-service')

    # SAML protocol binding to be used when returning the <Response>
    # message.  Onelogin Toolkit supports for this endpoint the
    # HTTP-POST binding only
    properties.setProperty(s::SP_ASSERTION_CONSUMER_SERVICE_BINDING_PROPERTY_KEY, 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST')

    # Specifies info about where and how the <Logout Response> message MUST be
    # returned to the requester, in this case our onelogin.saml2.sp.
    properties.setProperty(s::SP_SINGLE_LOGOUT_SERVICE_URL_PROPERTY_KEY, sp_url+'single-logout-service')

    # SAML protocol binding to be used when returning the <LogoutResponse> or sending the <LogoutRequest>
    # message.  Onelogin Toolkit supports for this endpoint the
    # HTTP-Redirect binding only
    properties.setProperty(s::SP_SINGLE_LOGOUT_SERVICE_BINDING_PROPERTY_KEY, 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect')

    # Specifies constraints on the name identifier to be used to
    # represent the requested subject.
    # Take a look on lib/Saml2/Constants.php to see the NameIdFormat supported
    properties.setProperty(s::SP_NAMEIDFORMAT_PROPERTY_KEY, 'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified')

    # Usually x509cert and privateKey of the SP are provided by files placed at
    # the certs folder. But we can also provide them with the following parameters

    conditions = {:kind => ADFS_KEYCHAIN_CRED_KIND, :instance_kind => ADFS_KEYCHAIN_CRED_INSTANCE_KIND}
    conditions[:name] = sp_name

    credential = KeychainCredential.find(:first, :conditions => conditions, :order => :id)

    # If we couldn't find any credentials with the given name, return nil
    if credential.nil?
      return nil
    end

    properties.setProperty(s::SP_X509CERT_PROPERTY_KEY, credential.account[ADFS_KEYCHAIN_CRED_SP_X509CERT])

    # Requires Format PKCS#8   BEGIN PRIVATE KEY         
    # If you have     PKCS#1   BEGIN RSA PRIVATE KEY  convert it by   openssl pkcs8 -topk8 -inform pem -nocrypt -in onelogin.saml2.sp.rsa_key -outform pem -out onelogin.saml2.sp.pem
    properties.setProperty(s::SP_PRIVATEKEY_PROPERTY_KEY, credential.secret[ADFS_KEYCHAIN_CRED_SP_PRIVATEKEY])

    # Identifier of the IdP entity  (must be a URI)
    # Example - onelogin.saml2.idp.entityid = http://adfs.vc.example.com/adfs/services/trust
    # TODO: Remind users of Windows Server 2012 R2 that (unlike AAD) their entity ID is http:, not https:
    properties.setProperty(s::IDP_ENTITYID_PROPERTY_KEY, credential.account[ADFS_KEYCHAIN_CRED_IDP_ENTITYID])
    
    # SSO endpoint info of the onelogin.saml2.idp. (Authentication Request protocol)
    # URL Target of the IdP where the SP will send the Authentication Request Message
    properties.setProperty(s::IDP_SINGLE_SIGN_ON_SERVICE_URL_PROPERTY_KEY, credential.account[ADFS_KEYCHAIN_CRED_IDP_SSO_SERVICE_URL])

    # SAML protocol binding to be used when returning the <Response>
    # message.  Onelogin Toolkit supports for this endpoint the
    # HTTP-Redirect binding only
    properties.setProperty(s::IDP_SINGLE_SIGN_ON_SERVICE_BINDING_PROPERTY_KEY, 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect')

    # SLO endpoint info of the onelogin.saml2.idp.
    # URL Location of the IdP where the SP will send the SLO Request
    properties.setProperty(s::IDP_SINGLE_LOGOUT_SERVICE_URL_PROPERTY_KEY, credential.account[ADFS_KEYCHAIN_CRED_IDP_LOGOUT_SERVICE_URL])

    # Optional SLO Response endpoint info of the onelogin.saml2.idp.
    # URL Location of the IdP where the SP will send the SLO Response. If left blank, same URL as onelogin.saml2.idp.single_logout_service.url will be used.
    # Some IdPs use a separate URL for sending a logout request and response, use this property to set the separate response url
  # properties.setProperty(s::IDP_SINGLE_LOGOUT_SERVICE_RESPONSE_URL_PROPERTY_KEY, '{tbd}')

    # SAML protocol binding to be used when returning the <Response>
    # message.  Onelogin Toolkit supports for this endpoint the
    # HTTP-Redirect binding only
    properties.setProperty(s::IDP_SINGLE_LOGOUT_SERVICE_BINDING_PROPERTY_KEY, 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect')

    # Public x509 certificate of the IdP
    properties.setProperty(s::IDP_X509CERT_PROPERTY_KEY, credential.account[ADFS_KEYCHAIN_CRED_IDP_X509CERT])

    # Create settings, check strict mode is set
    settings = Java::ComOneloginSaml2Settings::SettingsBuilder.new.fromProperties(properties).build()
    throw "SAML2 is not set to strict mode" unless settings.isStrict()

    # OneLogin settings, and the URL of the identity provider.
    [settings, credential.account[ADFS_KEYCHAIN_CRED_IDP_ENTITYID]]
  end

  def respond_with_error_when_no_settings(settings, response)
    return false unless settings.nil?
    # Invalid request when the name in the URL does not refer to a SAML2 keychain credential
    response.setStatus(500)
    response.addHeader("Cache-Control", "private, no-cache")
    response.getWriter().print("Unknown SAML2 Name.")
    true
  end

  def get_relay_state(request)
    relaystatelist = request.getParameterValues("RelayState")
    relaystatelist.nil? ? "" : relaystatelist.first
  end

end
