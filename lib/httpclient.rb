# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


KNotificationCentre.when(:server, :starting) do
  KeychainCredential::MODELS.push({
    :kind => 'HTTP',
    :instance_kind => "Basic",
    :account => {"Username" => ""},
    :secret => {"Password" => ""}
  })
  KeychainCredential::MODELS.push({
    :kind => 'X.509',
    :instance_kind => "Certificate and Key",
    :account => {"Certificate" => "\n"},
    :secret => {"Key" => ""}
  })
  KeychainCredential::USER_INTERFACE[['X.509','Certificate and Key']] = {
    :secrets_use_textareas => true,
    :notes_edit => "The certificate and keys should be PEM encoded. These will appear as base64 data and typically begin '-----BEGIN CERTIFICATE-----' and '-----BEGIN RSA PRIVATE KEY-----'.\nThe certificate and key are stored separately. Copy and paste the two PEM encoded files into the Certificate and Key fields below.\nThe Key is stored as a password field and cannot be viewed."
  }
end

class KHTTPClientJob < KJob

  def default_queue
    QUEUE_HTTP_CLIENT
  end

  def default_retries_allowed
    2
  end

  def initialize(callback_name, callback_data_JSON, request_settings)
    @callback_name = callback_name
    @callback_data_JSON = callback_data_JSON
    @request_settings = request_settings
    @keychain_data = {}
    @retry_count = 0
  end

  def headerParts(hdr)
    parts = /\s*([^;]+)\s*(.*)?/.match(hdr)
    unless parts
      return false
    end

    body = parts[1]
    params = {}
    rest = parts[2]
    while rest
      # Look for a quoted string
      parts = /\s*;\s*(\w+)="((?:[^"\\]|\\.)*)"\s*(.*)?/.match(rest)
      unless parts
        # Look for a plain atom
        parts = /\s*;\s*(\w+)=([^;\s]+)\s*(.*)?/.match(rest)
        unless parts
          rest = false
        else
          params[parts[1].downcase] = parts[2]
          rest = parts[3]
        end
      else
        unquoted = parts[2].gsub(/\\(.)/, '\1')
        params[parts[1].downcase] = unquoted
        rest = parts[3]
      end
    end
    return body, params
  end

  def callback()
    KJSPluginRuntime.current.using_runtime do
      body = nil
      if @result.has_key?("body") || @result.has_key?("bodySpilledToFile")
        # Wrap body in a KBinaryData
        mimeType, mimeParams = headerParts(@result["header:content-type"])
        if mimeType
          mimeType = mimeType.downcase
        else
          mimeType = "application/octet-stream"
        end
        if mimeParams
          charset = mimeParams["charset"]
        end
        if charset
          charset.upcase!
        else
          charset = "UTF-8"
        end
        dispType, dispParams = headerParts(@result["header:content-disposition"])
        if dispParams
          filename = dispParams["filename"]
        end
        unless filename
          filename = "response.bin"
        end
        if @result.has_key?("bodySpilledToFile")
          body = Java::OrgHaploJavascript::Runtime.createHostObjectInCurrentRuntime("$BinaryDataTempFile")
          body.setTempFile(@body_spill_pathname, filename, mimeType)
        else
          body = Java::OrgHaploJavascript::Runtime.createHostObjectInCurrentRuntime("$BinaryDataInMemory", false, nil, nil, filename, mimeType)
          body.setBinaryData(@result.delete("body"))
        end
        @result["charset"] = charset
      end

      KJSPluginRuntime.current.call_callback(@callback_name,
                                             ["parseJSON",@callback_data_JSON,
                                              "makeHTTPClient",@request_settings,
                                              "makeHTTPResponse",@result.to_hash,body])
    end
  end

  def giving_up()
    callback()
  end

  def run(context)
    # Authentication
    if @request_settings.has_key?("auth")
      name = @request_settings["auth"]
      credential = KeychainCredential.where(:kind => 'HTTP', :name => name).order(:id).first()
      if credential
        if credential.instance_kind != "Basic"
          raise JavaScriptAPIError, "Can't attempt HTTP authentication with a login of kind '#{credential.instance_kind}'"
        end
      else
        raise JavaScriptAPIError, "Can't find an HTTP keychain entry called '#{name}'"
      end
      @keychain_data["auth_type"] = "Basic"
      @keychain_data["auth_username"] = credential.account['Username']
      @keychain_data["auth_password"] = credential.secret['Password']
    end

    # Client certificate
    if @request_settings.has_key?("clientCertificate")
      name = @request_settings["clientCertificate"]
      credential = KeychainCredential.where(:kind => 'X.509', :instance_kind => 'Certificate and Key', :name => name).order(:id).first()
      unless credential
        raise JavaScriptAPIError, "Can't find an X.509 Certificate and Key called '#{name}'"
      end
      @keychain_data["tls_client_certificate"] = credential.account['Certificate']
      @keychain_data["tls_client_certificate_key"] = credential.secret['Key']
    end

    @body_spill_pathname = @temp_pathname_prefix = "#{FILE_UPLOADS_TEMPORARY_DIR}/tmp.httpclient.body.#{Thread.current.object_id}"

    begin
      @result = Java::OrgHaploHttpclient::HTTPClient.attemptHTTP(
        @request_settings,
        @keychain_data,
        @body_spill_pathname,
        KInstallProperties.get(:network_client_blacklist))

      # Result map is set up in HTTPOperation.java
      if @result["type"] == "TEMP_FAIL"
        context.job_failed_and_retry(@result["errorMessage"], @request_settings["retryDelay"].to_i)
      else
        callback()

        if @result["type"] == "SUCCEEDED"
          # Nothing else to do
        elsif @result["type"] == "FAIL"
          context.job_failed(@result["errorMessage"])
        else
          context.job_failed("Unknown job result #{@result["type"]}")
        end
      end
    ensure
      # Make sure spilled files are cleaned up if they aren't added to the store
      File.unlink(@body_spill_pathname) if File.exist?(@body_spill_pathname)
    end
  end
end
