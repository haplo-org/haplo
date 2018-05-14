# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module JSRemoteAuthenticationServiceSupport

  # Start OAuth
  def self.urlToStartOAuth(haveData, data, haveName, name, extraConfiguration)
    begin
      # Info for OAuth
      details = {}
      details[:service_name] = name if haveName
      details[:user_data] = data if haveData
      details[:extra_configuration] = JSON.parse(extraConfiguration)

      # See whether our service name is associated with AD FS credentials in the keychain:
      if haveName
        conditions = {
          :name => name,
          :kind => Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_KIND,
          :instance_kind => Saml2ServiceProviderController::ADFS_KEYCHAIN_CRED_INSTANCE_KIND
        }
        credentials = KeychainCredential.find(:first, :conditions => conditions, :order => :id)
        if credentials
          # Check that the name is URL safe
          unless name =~ Saml2ServiceProviderController::ADFS_KEYCHAIN_VALID_NAME_REGEXP
            raise JavaScriptAPIError, "Invalid name for SAML2 keychain entry: '#{name}' (name must be URL safe)"
          end
          # AD FS authentication is hardwired
          adfs_login_url = "/do/saml2-sp/" + name + "/login"
          if haveData
            #Append the user-supplied data as an HTTP query param
            adfs_login_url += "?RelayState=" + ERB::Util.url_encode(data)
          end
          return adfs_login_url
        end
      end

      # No AD FS keychain exists, so do generic OAuth stuff.

      # Create client, and generate the redirect URL
      rc = KFramework.request_context
      raise JavaScriptAPIError, "Request not in progress" unless rc
      rc.controller.session_create if rc.controller.session.discarded_after_request?
      oauth_client = OAuthClient.new.setup(rc.controller.session, details)
      oauth_client.redirect_url
    rescue OAuthClient::OAuthError => error
      if error.error_code == 'no_config'
        raise JavaScriptAPIError, "Could not find requested configuration for OAuth"
      end
      KApp.logger.error("Failed to generate OAuth start URL")
      KApp.logger.log_exception(error)
      raise JavaScriptAPIError, "Unable to generate OAuth URL, check configuration"
    end
  end

  # -----------------------------------------------------------------------------------------------------------

  def self.createServiceObject(searchByName, serviceName)
    # Special case the LOCAL service
    if searchByName && serviceName == 'LOCAL'
      return LocalAuthenticationService.new
    end

    # Attempt to find credentials for this service
    conditions = {:kind => 'Authentication Service'}
    conditions[:name] = serviceName if searchByName
    credential = KeychainCredential.find(:first, :conditions => conditions, :order => :id)
    return nil unless credential

    unless credential.instance_kind == "LDAP"
      raise JavaScriptAPIError, "Can't connect to authentication server of kind '#{credential.instance_kind}'"
    end

    return LDAPAuthenticationService.new(credential)
  end

  # -----------------------------------------------------------------------------------------------------------

  class ConnectionlessService
    def getName; raise "Not implemented"; end
    def connect; end
    def isConnected; true; end
    def disconnect; end
    def authenticate(username, password)
      auth_info = nil
      # Usernames can't be all blank
      return '{"result":"failure","failureInfo":"Usernames cannot be all whitespace"}' unless username =~ /\S/
      # Passwords can't be all blank
      return '{"result":"failure","failureInfo":"Passwords cannot be empty"}' if password.empty?
      # Determine IP, falling back to invalid IP if there's no active request
      rc = KFramework.request_context
      remote_ip = rc ? rc.controller.request.remote_ip : '0.0.0.0'
      # Authenticate the password, using the login throttle
      KApp.logger.info("JS remote authentication using #{self.getName} for '#{username}' from #{remote_ip}")
      begin
        KLoginAttemptThrottle.with_bad_login_throttling(remote_ip) do |outcome|
          auth_info = do_authenticate(username, password)
          outcome.was_success = (auth_info['result'] == "success")  # whether login was OK (this also throttles if there was an error, not just bad passwords)
        end
      rescue KLoginAttemptThrottle::LoginThrottled
        KApp.logger.info("JS remote authentication attempt was throttled for #{remote_ip}")
        auth_info = {"result" => "throttle"}
      end
      auth_info ||= {"result" => "error"}
      auth_info["service"] = self.getName
      json = JSON.generate(auth_info)
      KApp.logger.info("JS remote authentication result was #{auth_info["result"]}, full info returned: #{json}")
      json
    end
    def search(criteria)
      results = do_search(criteria) || []
      KApp.logger.info("JS remote search for #{criteria} returned #{results.length} results")
      JSON.generate(results)
    end
    def do_search(criteria)
      []
    end
  end

  # -----------------------------------------------------------------------------------------------------------

  class LocalAuthenticationService < ConnectionlessService
    def getName; "LOCAL"; end
    def do_authenticate(username, password)
      user = User.login_without_throttle(username, password)
      user ?
        {"result" => "success", "user" => {"id" => user.id, "email" => user.email, "name" => user.name } } :
        {"result" => "failure"}
    end
  end

  # -----------------------------------------------------------------------------------------------------------

  # LDAP authentication requires a KeychainCredential with:

  KNotificationCentre.when(:server, :starting) do
    KeychainCredential::MODELS.push({
      :kind => 'Authentication Service',
      :instance_kind => 'LDAP',
      :account => {
        "URL" => 'ldaps://HOSTNAME:PORT',
        "Certificate" => "name1.example.com : name2.example.com",
            # ' : ' separated list of allowed certificate hostnames (separated as Path for consistency)
        "CA" => "\n",
            # PEM encoded root CA certificate used for validating the server
        "Path" => "OU=Unit1,DC=example,DC=com : OU=Unit1,DC=example,DC=com",
            # ' : ' separated list of paths to search for user, entries may contain spaces
        "Search" => "(&(sAMAccountName={0})(objectClass=user))",
            # search criteria, no spaces allowed, {0} is username. Could also query userPrincipalName as username@domain.tld
        "Username" => ""
      },
      :secret => {
        "Password" => ""
      }
    })
  end

  class LDAPAuthenticationService < ConnectionlessService
    EXTERNAL_TIMEOUT = 4000 # 4 seconds
    EXTERNAL_TIMEOUT_SEARCH = 30000 # 30 seconds
    LDAP_SEARCH_RESULT_PAGE_SIZE = 2048
    DEFAULT_TRUSTED_ROOTS_KEYSTORE = "#{java.lang.System.getProperty('java.home')}/lib/security/cacerts"

    # Which attributes should be extracted for the user info?
    ATTRS_SINGLE = ['distinguishedName', 'personalTitle', 'mail', 'uid', 'name', 'uidNumber', 'sn', 'cn', 'givenName', 'displayName', 'userPrincipalName', 'sAMAccountName', 'description']
    ATTRS_MULTIPLE = ['memberOf']
    ATTRS_REQUESTED = ATTRS_SINGLE.concat(ATTRS_MULTIPLE).map {|a| a.to_java_string}

    def initialize(credential)
      @credential = credential
    end
    def getName
      @credential.name
    end

    # -----------------------------------------------------------------------

    def with_configured_server
      server = URI(@credential.account['URL'])
      raise "Protocol '#{server.scheme}' not supported" unless server.scheme == "ldaps"

      # Explicitly configured CAs need to be written to a temporary keystore file on disk, and this file must exist
      # throughout the remote authentication process because the Unbound SDK reads it at an unhelpful point in time.
      # TODO: Rewrite LDAP SSL connections using raw Java APIs to have more control over lifetimes, and cache socket factories.
      tempfile = nil
      begin
        # Determine the CA trust manager
        trustCA = nil
        configuredCA = @credential.account['CA']
        unless configuredCA && configuredCA =~ /\S/
          trustCA = Java::ComUnboundidUtilSsl::TrustStoreTrustManager.new(DEFAULT_TRUSTED_ROOTS_KEYSTORE)
        else
          begin
            # Generate a keychain with a trusted certificate
            cf = java.security.cert.CertificateFactory.getInstance("X.509")
            cert = cf.generateCertificate(Java::OrgHaploCommonUtils::SSLCertificates.readPEM(
                java.io.StringReader.new(configuredCA), "CA root from LDAP credential"))
            ks = java.security.KeyStore.getInstance("JKS", "SUN")
            ks.load(nil, Java::char[0].new)
            ks.setEntry("SERVER", java.security.KeyStore::TrustedCertificateEntry.new(cert), nil)
            # Save the keystore in a temporary file
            tempfile = Tempfile.new('ldapauthenticationservice-keystore')
            tempfile.close
            ks_file = java.io.FileOutputStream.new(tempfile.path)
            ks.store(ks_file, Java::char[0].new)
            ks_file.close()
            # And now it's on disk, the Unbound SDK SSL utility can use it
            trustCA = Java::ComUnboundidUtilSsl::TrustStoreTrustManager.new(tempfile.path)
          rescue => e
            KApp.logger.error("LDAPAuthenticationService: Failed to create keystore for CA certificate")
            KApp.logger.log_exception(e)
            return {"result" => "error", "errorInfo" => "Bad root CA in LDAP credential #{@credential.id}"}
          end
        end

        # Allowed certificate names. (same separator as search paths for consistency)
        certNames = @credential.account['Certificate'].split(/\s+:\s+/)

        # Make socket keystore given rest of crendential
        trustCertNames = Java::ComUnboundidUtilSsl::HostNameTrustManager.new(true, *certNames) # true for allow wildcards
        sslUtil = Java::ComUnboundidUtilSsl::SSLUtil.new(Java::ComUnboundidUtilSsl::AggregateTrustManager.new(true, [trustCA, trustCertNames]))
        socketFactory = sslUtil.createSSLSocketFactory()

        # Rest of the authentication process
        yield server, socketFactory
      ensure
        tempfile.unlink if tempfile
      end
    end

    def with_search_connection_for_each_search_path(server, socketFactory)
      search_succeeded = true
      searchConnection = nil
      begin
        # Log into server
        searchConnection = Java::ComUnboundidLdapSdk::LDAPConnection.new(socketFactory)
        searchConnection.connect(server.host, server.port, EXTERNAL_TIMEOUT)
        searchConnection.bind(@credential.account["Username"], @credential.secret["Password"])

        # Search each of the configured paths...
        searchPaths = @credential.account["Path"].split(/\s+:\s+/)
        searchPaths.each do |path|
          break unless yield searchConnection, path
        end
      rescue => e
        KApp.logger.error("Exception when attempting to search LDAP server")
        KApp.logger.log_exception(e)
        search_succeeded = false
      ensure
        searchConnection.close() if searchConnection
      end
      search_succeeded
    end

    def get_ldap_user_information(ldap_user)
      user = {}
      ATTRS_SINGLE.each do |attrName|
        value = ldap_user.getAttribute(attrName)
        user[attrName] = value.getValue() if value
      end
      ATTRS_MULTIPLE.each do |attrName|
        value = ldap_user.getAttribute(attrName)
        user[attrName] = (value ? value.getValues() : []).map {|v| v.to_s} # note getValues(), with an 's'
      end
      unless user['distinguishedName']
        user['distinguishedName'] = ldap_user.getDN()
      end
      user
    end

    # -----------------------------------------------------------------------

    def do_authenticate(username, password)
      auth_info = nil

      return {"result" => "failure", "failureInfo" => "Usernames cannot contain whitespace"} if username =~ /\s/
      return {"result" => "error", "errorInfo" => "Search string from keychain cannot contain whitespace"} if @credential.account["Search"] =~ /\s/

      with_configured_server do |server, socketFactory|
        auth_info = do_authenticate_with_server(username, password, server, socketFactory)
      end

      auth_info
    end

    def do_authenticate_with_server(username, password, server, socketFactory)
      # Since this is using a Java interface, use a Java-ish style of coding.
      # Use the Java::... names inline, rather than making nice constants, so the code is only loaded
      # when it's actually used.

      # Interpolate the username into the search filter
      # Don't use gsub as the \ back references confict with the escaping mechanism
      searchFilter = @credential.account["Search"].dup
      searchFilter['{0}'] = Java::ComUnboundidLdapSdk::Filter.encodeValue(username.to_java_string)

      result = nil
      search_succeeded = with_search_connection_for_each_search_path(server, socketFactory) do |searchConnection, path|
        searchResults = searchConnection.search(
            path, # baseDN to search
            Java::ComUnboundidLdapSdk::SearchScope::SUB, # search the entire subtree
            Java::ComUnboundidLdapSdk::DereferencePolicy::SEARCHING,  # resolve aliases in the search,
            1,  # max entries to return
            EXTERNAL_TIMEOUT / 1000,  # in seconds
            false,  # values as well as types
            searchFilter,
            *ATTRS_REQUESTED
          )

        if searchResults.getEntryCount() > 0
          result = searchResults.getSearchEntries().first
          false
        else
          true  # continue with search
        end
      end

      return {"result" => "error"} unless search_succeeded

      # If nothing found, report failure
      unless result
        KApp.logger.info("Couldn't find user when searching LDAP directory")
        return {"result" => "failure"}
      end

      # Collect all the interesting information from the user
      user = get_ldap_user_information(result)
      KApp.logger.info("LDAP search for '#{username}' found distinguishedName of #{user['distinguishedName']}")

      # Attempt to log into the LDAP server using the user's DN and given password
      userConnection = nil
      begin
        userConnection = Java::ComUnboundidLdapSdk::LDAPConnection.new(socketFactory)
        userConnection.connect(server.host, server.port, EXTERNAL_TIMEOUT)
        userConnection.bind(user['distinguishedName'], password)
        # Logged in OK, password must be correct
        auth_info = {"result" => "success", "user" => user}
      rescue => e
        if e.kind_of?(Java::ComUnboundidLdapSdk::LDAPException) && e.getResultCode().equals(Java::ComUnboundidLdapSdk::ResultCode::INVALID_CREDENTIALS)
          # Password is wrong
          auth_info = {"result" => "failure"}
        else
          KApp.logger.error("Exception when attempting to login to LDAP as user #{user['distinguishedName']}")
          KApp.logger.log_exception(e)
          auth_info = {"result" => "error"}
        end
      ensure
        userConnection.close() if userConnection
      end

      auth_info
    end

    # -----------------------------------------------------------------------

    def do_search(criteria)
      results = []
      with_configured_server do |server, socketFactory|
        with_search_connection_for_each_search_path(server, socketFactory) do |searchConnection, path|
          resumeCookie = nil
          searchRequest = Java::ComUnboundidLdapSdk::SearchRequest.new(
              path, # baseDN to search
              Java::ComUnboundidLdapSdk::SearchScope::SUB, # search the entire subtree
              Java::ComUnboundidLdapSdk::DereferencePolicy::SEARCHING,  # resolve aliases in the search,
              0,  # return all results
              EXTERNAL_TIMEOUT_SEARCH / 1000,  # in seconds
              false,  # values as well as types
              criteria,
              *ATTRS_REQUESTED
            )
          while true
            searchRequest.setControls(Java::ComUnboundidLdapSdkControls::SimplePagedResultsControl.new(LDAP_SEARCH_RESULT_PAGE_SIZE, resumeCookie))
            searchResults = searchConnection.search(searchRequest)
            searchResults.getSearchEntries().each do |ldap_user|
              results.push get_ldap_user_information(ldap_user)
            end
            responseControl = Java::ComUnboundidLdapSdkControls::SimplePagedResultsControl.get(searchResults)
            if responseControl.moreResultsToReturn()
              resumeCookie = responseControl.getCookie()
            else
              break
            end
          end
          true # continue with search
        end
      end
      results
    end

  end

end

Java::OrgHaploJsinterfaceRemote::KAuthenticationService.setRubyInterface(JSRemoteAuthenticationServiceSupport)
