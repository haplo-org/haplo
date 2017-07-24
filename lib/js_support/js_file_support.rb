# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Provide utility functions to KStoredFile JavaScript objects

module JSFileSupport
  extend KFileUrls

  def self.makeIdentifierForFile(storedFile)
    KIdentifierFile.new(storedFile)
  end

  def self.tryLoadFile(ktext)
    return nil unless ktext.kind_of? KIdentifierFile
    ktext.find_stored_file()
  end

  def self.tryFindFile(digest, fileSizeMaybe)
    return nil unless digest.kind_of? String
    return nil unless fileSizeMaybe == nil || fileSizeMaybe.to_i >= 0
    (fileSizeMaybe == nil) ?
        StoredFile.from_digest(digest) :
        StoredFile.from_digest_and_size(digest, fileSizeMaybe.to_i)
  end

  # ------------------------------------------------------------------------------------------------------------

  def self.newStoredFileFromData(data, filename, mimeType)
    temp_pathname = "#{FILE_UPLOADS_TEMPORARY_DIR}/temp_js_genfile_#{Thread.current.object_id}.#{Time.now.to_f}.tmp"
    begin
      File.open(temp_pathname, "w:BINARY") { |f| f.write(data) }
      StoredFile.move_file_into_store(temp_pathname, filename, mimeType)
    ensure
      File.unlink(temp_pathname) if File.exist?(temp_pathname)
    end
  end

  # ------------------------------------------------------------------------------------------------------------

  def self.getFilePropertiesJSON(storedFile)
    properties = {}
    if (dimensions = storedFile.dimensions)
      properties['dimensions'] = {
        "width" => dimensions.width,
        "height" => dimensions.height,
        "units" => dimensions.units
      }
    end
    if (pages = storedFile.dimensions_pages)
      properties["numberOfPages"] = pages
    end
    if (thumbnail = storedFile.thumbnail)
      properties['thumbnail'] = {
        "width" => thumbnail.width,
        "height" => thumbnail.height,
        "mimeType" => storedFile.thumbnail_mime_type
      }
    end
    JSON.generate(properties)
  end

  # ------------------------------------------------------------------------------------------------------------

  def self.oFormsFileHTML(stored_file, where)
    if where == 'form'
      # Icon + filename, not linked
      if !(rc = KFramework.request_context) || !(controller = rc.controller)
        raise JavaScriptAPIError, "oForms file rendering outside of request handler"
      end
      # NOTE: Rendering of file should match that in file_upload.js
      %Q!#{controller.img_tag_for_mime_type(stored_file.mime_type)} #{ERB::Util.h(stored_file.presentation_filename)}!

    elsif where == 'document'
      # Thumbnail + filename, linked
      options = org.haplo.jsinterface.KStoredFile::FileRenderOptions.new()
      options.authenticationSignature = true
      options.forceDownload = true
      path = fileIdentifierMakePathOrHTML(stored_file, options, false)
      options.transform = "thumbnail"
      thumbnail = fileIdentifierMakePathOrHTML(stored_file, options, true)
      %Q!<div class="z__oforms_file"><a href="#{path}"><span class="z__oforms_file_thumbnail">#{thumbnail}</span><span class="z__oforms_file_filename">#{ERB::Util.h(stored_file.presentation_filename)}</span></a></div>!

    else
      raise JavaScriptAPIError, "Bad oForms where value for rendering"
    end
  end

  # ------------------------------------------------------------------------------------------------------------

  def self.fileIdentifierMakePathOrHTML(stored_file, options, makeHTML)
    raise JavaScriptAPIError, "Not a file" unless stored_file.kind_of? StoredFile
    # Need a controller?
    controller = nil
    if options.asFullURL || options.authenticationSignature
      rc = KFramework.request_context
      controller = rc.controller if rc != nil
      raise JavaScriptAPIError, "Not in request context for generating file identifier path or HTML" unless controller != nil
    end
    # Need a persistent session?
    session = nil
    if options.authenticationSignature
      session = controller.session
      # Make sure it's a session which is going to be kept
      if session.discarded_after_request?
        controller.session_create
        session = controller.session
      end
    end
    # Transform?
    requested_transform = options.transform
    as_thumbnail_html = (requested_transform == 'thumbnail')
    width = nil
    height = nil
    # Check that requested_transform is URL safe and find the height and width if given
    if requested_transform
      requested_transform.split('/').each do |part|
        if KFileTransform::SIZE_TO_WIDTH.has_key?(part)
          width = KFileTransform::SIZE_TO_WIDTH[part]
        else
          raise JavaScriptAPIError, "Bad file transform #{requested_transform}" unless part =~ /\A([a-z]+)(\d*)\z/
          case $1
          when 'w'; width = $2.to_i
          when 'h'; height = $2.to_i
          end
        end
      end
    end
    # Generate the file path
    url_path_options = options.authenticationSignature ? {:sign_with => session} : nil
    file_path = file_url_path(stored_file, as_thumbnail_html ? nil : requested_transform, url_path_options) # requested_transform is known URL safe
    file_path = KApp.url_base() + file_path if options.asFullURL
    # As an attachment?
    if options.forceDownload
      file_path = "#{file_path}#{options.authenticationSignature ? '&' : '?'}attachment=1"
    end
    # If only the path of the file was requested, return it now
    return file_path unless makeHTML
    # Generate some HTML
    #  * If a thumbnail is requested, or not an image, a thumbnail
    #  * If it's an image, an img tag, with height and width as appropraite
    html = nil
    if !as_thumbnail_html
      # Try to make an img tag for the actual file
      if !(stored_file.mime_type =~ /\Aimage\//) || stored_file.dimensions == nil
        as_thumbnail_html = true
      else
        # Looks good to make an img tag - sort out height and width
        dims = stored_file.dimensions
        if width != nil && height == nil
          height = ((width.to_f / dims.width.to_f) * dims.height.to_f).to_i
        elsif width == nil && height != nil
          width = ((height.to_f / dims.height.to_f) * dims.width.to_f).to_i
        else
          width = dims.width
          height = dims.height
        end
        html = %Q!<img src="#{file_path}" width="#{width}" height="#{height}">!
      end
    end
    if as_thumbnail_html
      # Generate the thumbnail HTML
      thumb_info = stored_file.thumbnail
      html = if thumb_info == nil
        # No thumbnail, use a placeholder
        '<img src="/images/nothumbnail.gif" width="47" height="47" alt="">'
      else
        # Generate the tag
        thumbnail_url = thumb_info.urlpath || file_url_path(stored_file, :thumbnail, url_path_options)
        thumbnail_url = KApp.url_base() + thumbnail_url if options.asFullURL
        %Q!<img src="#{thumbnail_url}" width="#{thumb_info.width}" height="#{thumb_info.height}" alt="">!
      end
    end
    # Wrap it with the download link?
    if options.linkToDownload
      html = %Q!<a href="#{file_path}">#{html}</a>!
    end
    html
  end

  # ------------------------------------------------------------------------------------------------------------

  def self.setBinaryDataForThumbnail(stored_file, binary_data)
    thumb_info = stored_file.thumbnail
    raise JavaScriptAPIError, "No thumbnail image available" unless thumb_info
    binary_data.setFile(stored_file.disk_pathname_thumbnail, "thumbnail", stored_file.thumbnail_mime_type)
  end

  # ------------------------------------------------------------------------------------------------------------

  def self.verifyFileTransformPipelineTransform(name, json)
    KJSFileTransformPipeline.verify_transform(name, json)
  end
  def self.executeFileTransformPipeline(json)
    pipeline = KJSFileTransformPipeline.new(json)
    pipeline.prepare
    pipeline.submit
  end

end

Java::OrgHaploJsinterface::KStoredFile.setRubyInterface(JSFileSupport)
