# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
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
      p = "/file/#{file.digest}/#{file.size}/"
      p << "#{transform}/" if transform
      p << ERB::Util.url_encode(file.presentation_filename)
    end
    # Sign path?
    if options && (session = options[:sign_with])
      # Get or generate a key, then add signature to URL
      key = (session[:file_auth_key] ||= KRandom.random_base64(16))
      p = "#{p}?s=#{HMAC::SHA256.sign(key, "*#{KApp.current_application}:#{p}*")}"
    end
    p
  end

  def file_request_check_signature(signature, path, session)
    # Is there a signature key in the session?
    key = session[:file_auth_key]
    return false if key == nil
    # Signature looks OK?
    return false unless signature.kind_of?(String) && signature.length > 16
    # Generate a signature to compare it with
    valid_signature = HMAC::SHA256.sign(key, "*#{KApp.current_application}:#{path}*")
    # And compare with hashes to avoid timing attacks
    return (Digest::SHA1.hexdigest(signature) == Digest::SHA1.hexdigest(valid_signature))
  end

end
