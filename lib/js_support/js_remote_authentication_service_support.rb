# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module JSRemoteAuthenticationServiceSupport

  # Start OAuth
  def self.urlToStartOAuth(haveData, data, haveName, name)
    begin
      # Info for OAuth
      details = {}
      details[:service_name] = name if haveName
      details[:user_data] = data if haveData
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
        "Path" => "OU=Unit1,DC=example,DC=com : OU=Unit1,DC=example,DC=com",
            # ' : ' separated list of paths to search for user, entries may contain spaces
        "Search" => "(& (sAMAccountName={0})(objectClass=user))",
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
    TRUSTED_ROOTS_KEYSTORE = "#{java.lang.System.getProperty('java.home')}/lib/security/cacerts"

    # Which attributes should be extracted for the user info?
    ATTRS_SINGLE = ['distinguishedName', 'personalTitle', 'mail', 'uid', 'name', 'uidNumber', 'sn', 'cn', 'givenName', 'displayName', 'userPrincipalName', 'sAMAccountName']
    ATTRS_MULTIPLE = ['memberOf']
    ATTRS_REQUESTED = ATTRS_SINGLE.concat(ATTRS_MULTIPLE).map {|a| a.to_java_string}

    def initialize(credential)
      @credential = credential
    end
    def getName
      @credential.name
    end
    def do_authenticate(username, password)
      auth_info = nil

      return {"result" => "failure", "failureInfo" => "Usernames cannot contain whitespace"} if username =~ /\s/
      return {"result" => "error", "errorInfo" => "Search string from keychain cannot contain whitespace"} if @credential.account["Search"] =~ /\s/

      server = URI(@credential.account['URL'])
      raise "Protocol '#{server.scheme}' not supported" unless server.scheme == "ldaps"

      # Since this is using a Java interface, use a Java-ish style of coding.
      # Use the Java::... names inline, rather than making nice constants, so the code is only loaded
      # when it's actually used.

      # Allowed certificate names. (same separator as search paths for consistency)
      certNames = @credential.account['Certificate'].split(/\s+:\s+/)

      # Build a socket factory for correctly configured SSL connections. Don't cache it, because different
      # credentials accounts will have different allowed certificates
      trustCA = Java::ComUnboundidUtilSsl::TrustStoreTrustManager.new(TRUSTED_ROOTS_KEYSTORE)
      trustCertNames = Java::ComUnboundidUtilSsl::HostNameTrustManager.new(true, *certNames) # true for allow wildcards
      sslUtil = Java::ComUnboundidUtilSsl::SSLUtil.new(Java::ComUnboundidUtilSsl::AggregateTrustManager.new(true, [trustCA, trustCertNames]))
      socketFactory = sslUtil.createSSLSocketFactory()

      # Interpolate the username into the search filter
      # Don't use gsub as the \ back references confict with the escaping mechanism
      searchFilter = @credential.account["Search"].dup
      searchFilter['{0}'] = Java::ComUnboundidLdapSdk::Filter.encodeValue(username.to_java_string)

      searchConnection = nil
      result = nil
      begin
        # Log into server
        searchConnection = Java::ComUnboundidLdapSdk::LDAPConnection.new(socketFactory)
        searchConnection.connect(server.host, server.port, EXTERNAL_TIMEOUT)
        searchConnection.bind(@credential.account["Username"], @credential.secret["Password"])

        # Search each of the configured paths...
        searchPaths = @credential.account["Path"].split(/\s+:\s+/)
        searchPaths.each do |path|
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
            break
          end
        end
        # If nothing found, report failure
        unless result
          KApp.logger.info("Couldn't find user when searching LDAP directory")
          auth_info = {"result" => "failure"}
        end
      rescue => e
        KApp.logger.error("Exception when attempting to search LDAP server")
        KApp.logger.log_exception(e)
        auth_info = {"result" => "error"}
      ensure
        searchConnection.close() if searchConnection
      end

      return auth_info if auth_info

      # Collect all the interesting information from the user
      user = {}
      ATTRS_SINGLE.each do |attrName|
        value = result.getAttribute(attrName)
        user[attrName] = value.getValue() if value
      end
      ATTRS_MULTIPLE.each do |attrName|
        value = result.getAttribute(attrName)
        user[attrName] = (value ? value.getValues() : []).map {|v| v.to_s} # note getValues(), with an 's'
      end

      unless user['distinguishedName']
        user['distinguishedName'] = result.getDN()
      end

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
  end

end

Java::ComOneisJsinterfaceRemote::KAuthenticationService.setRubyInterface(JSRemoteAuthenticationServiceSupport)
