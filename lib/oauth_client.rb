# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class OAuthClient

  COMMON_ACCOUNT_PROPERTIES = {
    "auth_url" => "https://accounts.google.com/o/oauth2/auth",
      # The URL to redirect the user to, to allow authentication
    "token_url" => "https://accounts.google.com/o/oauth2/token",
     # The URL that Haplo should use to verify the authentication token against the provider.
    "ssl_ciphers" => "",
      # Optional override of the SSL cipher suites
    "domain" => "example.com",
      # The email domain to allow logins under
    "client_id" => "CLIENT_ID",
      # This is provided by the authentication provider, and should be copied exactly
    "max_auth_age" => "0",
      # Ask the auth provider to require the user to re-enter their password if the last time
      # they did this was more than X minutes ago.  (Note there is usually a minimum time of a
      # few minutes enforced by the server).
  }
  COMMON_SECRET_PROPERTIES = {
    "client_secret" => ""
      # This is provided by the authentication provider
  }

  KNotificationCentre.when(:server, :starting) do
    KeychainCredential::MODELS.push({
      :kind => 'OAuth Identity Provider',
      :instance_kind => 'OAuth2',
      :account => COMMON_ACCOUNT_PROPERTIES,
      :secret => COMMON_SECRET_PROPERTIES
    })

    KeychainCredential::MODELS.push({
      :kind => 'OAuth Identity Provider',
      :instance_kind => 'Google Apps',
      :account => COMMON_ACCOUNT_PROPERTIES.merge({
        "cert_url" => "https://www.googleapis.com/oauth2/v1/certs",
          # In google-flavoured OAuth, the token response contains a JWT signed message,
          # this URL should return a dictionary of PEM encoded keys used to sign the JWT.
        "issuer" => "accounts.google.com",
          # Check that the identity token has been provided by this issuer
        "client_id" => "XXXXXXXXXXX.apps.googleusercontent.com"
          # This is provided by the authentication provider, and should be copied exactly
      }),
      :secret => COMMON_SECRET_PROPERTIES
    })
  end

  # In google's case (and probably others?) the public key for signing the user info record
  # is rotated on the order of every day (from the docs) so cache the keys.
  PUBLIC_KEYS = KApp.cache_register(Hash, 'OAuth provider public signing keys')

  def initialize
  end

  def setup(session, details = {})
    @secret = session[:oauth_secret] ||= KRandom.random_base64(48)
    if details.has_key?(:state)
      decoded = decode_state(details[:state])
      @service_name = decoded['n']
      @user_data = decoded['d']
    else
      @service_name = details[:service_name]
      @user_data = details[:user_data]
    end

    # Load credentials, build config
    conditions = {:kind => 'OAuth Identity Provider'}
    conditions[:name] = @service_name if @service_name
    @credential = KeychainCredential.where(conditions).order(:id).first()
    raise OAuthError.new('no_config') if @credential.nil?

    return_url = "#{KApp.url_base(:logged_in)}/do/authentication/oauth-rtx"

    @config = @credential.account.merge(@credential.secret).merge({'return_url' => return_url})
    @extra_configuration = details[:extra_configuration]
    @account_kind =
      case @credential.instance_kind
      when "Google Apps"
        :google
      when "OAuth2"
        :plain
      else
        raise OAuthError.new('bad_kind')
      end

    self
  end

  attr_reader :config

  def encode_state(fields)
    encoded = Base64.urlsafe_encode64(JSON.generate(fields))
    "#{HMAC::SHA256.sign(@secret, encoded)}.#{encoded}"
  end

  # Must throw an exception if the state is invalid
  def decode_state(state)
    signature, encoded = state.split('.',2)
    unless signature && encoded && (Digest::SHA256.hexdigest(signature) == Digest::SHA256.hexdigest(HMAC::SHA256.sign(@secret, encoded)))
      raise OAuthError.new('invalid_state')
    end
    JSON.parse(Base64.urlsafe_decode64(encoded))
  end

  def issuer
    @config ? @config['issuer'] : 'NOT CONFIGURED'
  end

  def redirect_url
    state_details = {"n" => @credential.name}
    state_details["d"] = @user_data if @user_data
    case @account_kind
    when :google
      scope = 'openid email'
    when :plain
      scope = @extra_configuration['scope']
    end
    query = URI.encode_www_form({
      'client_id' => @config['client_id'],
      'response_type' => 'code',
      'scope' => scope,
      'redirect_uri' => @config['return_url'],
      'state' => encode_state(state_details),
      'hd' => @config['domain'],
      'max_auth_age' => @config['max_auth_age'].to_i
    })
    "#{@config['auth_url']}?#{query}"
  end

  # TODO: Suspend the user's HTTP request while performing HTTP requests (probably in a new authentication scheme)
  def perform_https_request(method, url, data = nil, accept_header = nil)
    if method == :POST
      uri = URI(url)
      request = Net::HTTP::Post.new(uri.to_s)
      request.form_data = data if data
    else
      uri = URI(url)
      uri.query = URI.encode_www_form(data) if data
      request = Net::HTTP::Get.new(uri.to_s)
    end
    if accept_header
      request['Accept'] = accept_header
    end
    http = Net::HTTP.new(uri.host, uri.port)
    if @config['ssl_ciphers']
      http.ciphers = @config['ssl_ciphers']
    end
    http.use_ssl = true
    http.ssl_version = :TLSv1_2 # force version
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.ca_file = SSL_CERTIFICATE_AUTHORITY_ROOTS_FILE
    raise OAuthError.new('insecure_address') unless uri.kind_of? URI::HTTPS
    begin
      response = http.start{ |http| http.request(request) }
    rescue StandardError => e
      KApp.logger.log_exception(e)
      raise OAuthError.new("connection_failed", { :url => url })
    end

    case response
    when Net::HTTPSuccess
      response.body
    when Net::HTTPRedirection
      location = response['location']
      perform_https_request method, location, data, accept_header
    else
      raise OAuthError.new('unexpected_status_code', { 'code' => response.code })
    end
  end

  def get_public_key(keyId)
    public_key_cache = KApp.cache(PUBLIC_KEYS)
    unless public_key_cache.has_key? keyId
      certificate_factory = Java::JavaSecurityCert::CertificateFactory.getInstance('X509')
      input_stream = Java::JavaIo::ByteArrayInputStream
      public_key_cache.clear if public_key_cache.length > 4 # Only keep a few keys in the cache (for multiple providers) and be tolerant of gradual changeover
      body = perform_https_request(:GET, @config['cert_url'])
      JSON.parse(body).each_pair do |key, value|
        certificate_stream = Java::JavaIo::StringReader.new(value)
        begin
          pem = Java::OrgBouncycastleUtilIoPem::PemReader.new(certificate_stream).readPemObject()
          public_key_cache[key] = certificate_factory.generateCertificate(input_stream.new(pem.getContent()))
        rescue => e
          KApp.logger.log_exception(e)
          raise OAuthError.new('bad_cert', { 'message' => e.to_s})
        end
      end
    end
    cert = public_key_cache[keyId]
    raise OAuthError.new('no_pubkey') if cert.nil?
    cert
  end

  def verify_rsa256(certificate, signature, data)
    signer = Java::JavaSecurity::Signature.getInstance 'SHA256withRSA'
    signer.initVerify certificate
    signer.update data.to_java_bytes
    raise OAuthError.new('bad_sign') unless signer.verify signature.to_java_bytes
  end

  def parse_and_validate_jwt(payload)
    components = payload.split('.')
    if components.length != 3
      raise OAuthError.new('invalid_response')
    end
    decoded = components.map { |x| Base64.decode64 x.tr('-_', '+/') + '==' }
    begin
      header, claims = decoded[0..1].map { |x| JSON.parse(x) }
    rescue JSON::ParserError => e
      KApp.logger.log_exception(e)
      raise OAuthError.new('invalid_response', {'payload' => payload})
    end
    providerKey = get_public_key(header['kid'])
    verify_rsa256 providerKey, decoded[2], components[0] + '.' + components[1]
    claims
  end

  def get_id_token_from_server(params)
    params = {
      'client_id' => @config['client_id'],
      'client_secret' => @config['client_secret'],
      'code' => params['code'],
      'redirect_uri' => @config['return_url'],
      'grant_type' => 'authorization_code'
    }
    response = perform_https_request(:POST, @config['token_url'], params, 'application/json')
    body = JSON.parse(response)
    raise OAuthError.new('invalid_response') unless (body.has_key? 'token_type') && (body['token_type'].downcase == 'bearer')
    raise OAuthError.new('invalid_response') unless body.has_key? 'access_token'
    case @account_kind
    when :google
      # Google token bodies contain an id_token field, which is a JWT-signed
      # user profile.

      id_token = parse_and_validate_jwt(body['id_token'])

      # To be compatible with existing users of the OAuth API to
      # perform logins against google apps, while still allowing
      # future uses of the OAuth client to access stuff in the
      # response body such as access tokens, we embed the body in the
      # returned ID token.
      id_token["$$token_response_body"] = body
      
      id_token
    when :plain
      # Just return the body, and the invoking plugin will rummage in there
      # for anything they need
      body
    end
  end

  def authenticate(params)
    details = decode_state(params['state']) # validates state
    raise OAuthError.new(params['error']) unless params['error'].nil?

    id_token = get_id_token_from_server(params)
    case @account_kind
    when :google
      raise OAuthError.new('invalid_issuer') if id_token['iss'] != @config['issuer']
      raise OAuthError.new('invalid_client_id') if id_token['aud'] != @config['client_id']
    when :plain
      # No extra rules to check
    end

    # Return the verified details
    auth_info = {
      'token' => id_token,
      'provider' => self.issuer,
      'service' => @credential.name
    }
    auth_info["data"] = @user_data if @user_data
    auth_info
  end

  class OAuthError < StandardError
    attr_accessor :error_code, :detail

    # If something went wrong with oauth (such as server failure) then this is used to create an alert, for situations
    # where the exception is handled to produce a nice error page
    OAUTH_FAILURE_REPORTER = KFramework::HealthEventReporter.new('OAUTH_ERROR')

    ERROR_MESSAGES = {
      'invalid_request' => 'The request is missing a required parameter, includes an
                           invalid parameter value, includes a parameter more than
                           once, or is otherwise malformed.',
      'unauthorized_client' => 'The client is not authorized to request an authorization
                               code using this method.',
      'access_denied' => 'The user or authorization server denied the client access request.',
      'unsupported_response_type' => 'The authorization server does not support obtaining an
                                     authorization code using this method.',
      'invalid_scope' => 'The requested scope is invalid, unknown, or malformed.',
      'server_error' => 'The authorization server encountered an unexpected
                        condition that prevented it from fulfilling the request.
                        (This error code is needed because a 500 Internal Server
                        Error HTTP status code cannot be returned to the client
                        via an HTTP redirect.)',
      'temporarily_unavailable' => 'The authorization server is currently unable to handle
                                   the request due to a temporary overloading or maintenance
                                   of the server.  (This error code is needed because a 503
                                   Service Unavailable HTTP status code cannot be returned
                                   to the client via an HTTP redirect.)',
      'no_pubkey' => 'Could not retrieve the authentication provider\'s public key to verify token',
      'no_config' => 'No stored OAuth provider configuration could be found in the Keychain',
      'bad_kind' => 'The OAuth provider configuration in the Keychain did not have a valid instance kind',
      'invalid_response' => 'The response from the OAuth provider could not be parsed',
      'invalid_issuer' => 'The issuer indicated in the ID token does not match the configured issuer',
      'invalid_client_id' => 'The client ID in the ID token does not match our ID.
                              This authentication is for a different app.',
      'unexpected_status_code' => 'The provider returned an unexpected status code to an HTTP request',
      'bad_sign' => 'The ID token signature verification failed',
      'insecure_url' => 'Attempted to fetch a sensitive resource over HTTP',
      'invalid_state' => 'The state returned by the browser does not match the internal
                          state key, or the session has timed out',
      'connection_failed' => 'A connection to the server could not be made',
      'bad_cert' => 'The authentication provider\'s public certificate is invalid'
    }
    UNREPORTED_CODES = Set.new ['no_user', 'access_denied', 'temporarily_unavailable', 'invalid_state']

    def initialize(error_code, detail = nil)
      @detail = detail
      @error_code = error_code
    end

    def to_s
      message = ERROR_MESSAGES[error_code] || @error_code
      message.gsub(/\s+/, ' ')
    end

    def reportable?
      not UNREPORTED_CODES.include? @error_code
    end

    def maybe_report
      OAUTH_FAILURE_REPORTER.log_and_report_exception(self, "#*#*  Oauth identity server error: #{self.to_s}") if self.reportable?
    end

  end

end
