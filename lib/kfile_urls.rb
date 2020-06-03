# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module KFileUrls

  # ----------------------------------------------------------------------------------------------------------------
  #   Paths for fetching files
  # ----------------------------------------------------------------------------------------------------------------

  # NOTE: :preview transform may return nil, others will always return a path
  def file_url_path(file, transform = nil, options = nil)
    # Turn preview requests into an appropraite transform
    if transform == :preview
      if file.mime_type == 'application/pdf' && KFileTransform.can_transform?(file, 'image/png')
        transform = 'preview/pdfview'
      elsif KFileTransform.can_transform?(file, KFileTransform::MIME_TYPE_HTML_IN_ZIP)
        transform = 'preview/html'
      elsif file.mime_type =~ /\Aimage\//
        transform = 'preview/jpeg/q40/l'
      elsif file.mime_type == 'text/html'
        transform = 'preview/text'
      elsif KFileTransform.can_transform?(file, 'image/png')
        transform = 'preview/png/l'
      else
        # Can't make a preview of this
        return nil
      end
    end
    p = nil
    if transform == :thumbnail
      p = "/_t/#{file.digest}/#{file.size}"
    else
      p = "/file/#{file.digest}/#{file.size}/".dup
      p << "#{transform}/" if transform
      p << ERB::Util.url_encode(file.presentation_filename)
    end
    # Sign path?
    if options
      if (age = options[:sign_for_validity]) && age.length == 2
        # Signature with global static key
        start_time, end_time = age.map { |x| x.to_i }
        key = KApp.global(:file_static_signature_key)
        unless key
          # Make sure there's only a key when it's actually needed, at cost of race condition for first URLs.
          KApp.logger.info("Setting file_static_signature_key global for application")
          KApp.set_global(:file_static_signature_key, key = KRandom.random_base64(KRandom::FILE_STATIC_SIGNATURE_KEY_LENGTH))
        end
        p = "#{p}?s=#{HMAC::SHA256.sign(key, "*#{KApp.current_application}:#{p}:#{start_time}:#{end_time}*")},#{start_time},#{end_time}"
      elsif (session = options[:sign_with])
        # Session based signature
        # Get or generate a key, then add signature to URL
        key = (session[:file_auth_key] ||= KRandom.random_base64(16))
        p = "#{p}?s=#{HMAC::SHA256.sign(key, "*#{KApp.current_application}:#{p}*")}"
      end
    end
    p
  end

  def file_request_check_signature(signature_param, path, session)
    signature, start_time_s, end_time_s = signature_param.split(',')
    # Basic signature check
    return false unless signature.kind_of?(String) && signature.length > 16
    # Generate a signature to compare it with, with additional checks
    valid_signature = 'INVALID'
    if start_time_s && end_time_s
      # Time based static signature - check time first
      start_time = start_time_s.to_i
      end_time = end_time_s.to_i
      time_now = Time.now.to_i
      return false unless start_time <= end_time
      return false unless (time_now >= start_time) && (time_now < end_time)
      key = KApp.global(:file_static_signature_key)
      return false if key == nil
      valid_signature = HMAC::SHA256.sign(key, "*#{KApp.current_application}:#{path}:#{start_time}:#{end_time}*")
    else
      # Session based signature
      # Is there a signature key in the session?
      key = session[:file_auth_key]
      return false if key == nil
      valid_signature = HMAC::SHA256.sign(key, "*#{KApp.current_application}:#{path}*")
    end
    # Compare signature with hashes to avoid timing attacks
    return (Digest::SHA256.hexdigest(signature) == Digest::SHA256.hexdigest(valid_signature))
  end

end
