# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# NOTE: Initialisation of directory structure on disc performed by KFileStore.init_store_on_disc_for_app

# TODO: Better tests for text extraction, including checking normalisation of accents

class KFileTransform

  # Additional file transformation components
  COMPONENTS = []

  # Maximum file size for transformation
  MAX_TRANSFORM_FILE_SIZE = (128*1024*1024) # 128MB
  MSOFFICE_XML_FILE_SIZE_LIMIT = (5*1024*1024) # 5MB
  MSOFFICE_BINARY_FILE_SIZE_LIMIT = (64*1024*1024) # 64MB
  MAX_TRANSFORM_FILE_SIZE_EXCEPTIONS = {} # filled in later

  # Limits for storing plain text as render text - prevent loading too big a file, and only store the first bit anyway
  MAX_RENDER_TEXT_CONVERTED_FILE_SIZE = (2*1024*1024) # 2MB
  MAX_RENDER_TEXT_CHARS = (64*1024)

  # Internal format for handling HTML with attached images in a single zip file
  MIME_TYPE_HTML_IN_ZIP = 'x-oneis/html-zipped'

  # These constants are also used by the KTextExtract module
  THUMBNAIL_MAX_DIMENSION = 64.0  # float
  THUMBNAIL_MIN_DIMENSION = 2     # int
  SIZE_TO_WIDTH = {'s' => 128, 'm' => 320, 'l' => 512}
  OPENOFFICE_MIME_TYPE_REGEXP = /\Aapplication\/vnd\.oasis\.opendocument\./
  MSOFFICE_MIME_TYPES =
    %w(doc dot xls xlt ppt pot xlsx xltx potx ppsx pptx sldx docx dotx).map {|a| KMIMETypes::MIME_TYPE_FROM_EXTENSION[a]}
  MSOFFICE_OLD_MIME_TYPES = %w(doc dot xls xlt ppt pot).map {|a| KMIMETypes::MIME_TYPE_FROM_EXTENSION[a]}
  MSOFFICE_NEW_MIME_TYPES = %w(xlsx xltx potx ppsx pptx sldx docx dotx).map {|a| KMIMETypes::MIME_TYPE_FROM_EXTENSION[a]}
  MSOFFICE_RTF_MIME_TYPE = 'application/rtf'
  IWORK_MIME_TYPES = %w(pages template key kth numbers nmbtemplate).map {|a| KMIMETypes::MIME_TYPE_FROM_EXTENSION[a]}
  FIXED_INDEXABLE_MIME_TYPES = ['application/pdf', 'application/rtf', 'text/html', 'text/plain']

  # Microsoft Office XML files are handled very inefficiently by Apache POI.
  # This limit still results in about 1GB of swap being used, but it's acceptable.
  MSOFFICE_NEW_MIME_TYPES.each { |t| MAX_TRANSFORM_FILE_SIZE_EXCEPTIONS[t] = MSOFFICE_XML_FILE_SIZE_LIMIT }
  # Put a higher limit on the old binary formats, which are still a bit inefficient, but nowhere as bad
  MSOFFICE_OLD_MIME_TYPES.each { |t| MAX_TRANSFORM_FILE_SIZE_EXCEPTIONS[t] = MSOFFICE_BINARY_FILE_SIZE_LIMIT }

  # -----------------------------------------------------------------------------------------------------------------
  # Java classes used

  ImageIdentifier = Java::ComOneisGraphics::ImageIdentifier
  ImageTransform = Java::ComOneisGraphics::ImageTransform
  ThumbnailFinder = Java::ComOneisGraphics::ThumbnailFinder
  HTMLToText = Java::ComOneisConvert::HTMLToText

  # -----------------------------------------------------------------------------------------------------------------

  def self.max_file_size_for_mime_type(mime_type)
    MAX_TRANSFORM_FILE_SIZE_EXCEPTIONS[mime_type] || MAX_TRANSFORM_FILE_SIZE
  end

  # -----------------------------------------------------------------------------------------------------------------

  def self.can_transform?(what, output_mime_type = nil, output_options = nil)
    # Determine a source mime type given various forms of input
    mime_type = case what
    when String
      what
    when StoredFile, KIdentifierFile
      what.mime_type
    else
      raise "Bad input to KFileTransform.can_transform?"
    end
    # See if it can be transformed by trying to find a transformer to transform it.
    (self.get_transformer(KMIMETypes.canonical_base_type(mime_type), output_mime_type) != nil) ? true : false
  end

  # -----------------------------------------------------------------------------------------------------------------

  # Synchronous tranform method - should be done async in request handlers
  def self.do_transform(stored_file, output_mime_type = nil, output_options = nil)
    file_transform = KFileTransform.new(stored_file, output_mime_type, output_options || {})
    result_pathname = file_transform.result_pathname
    return file_transform if result_pathname # cached result
    return nil unless file_transform.can_transform?
    begin
      # Perform the operation synchronously
      file_transform.operation.perform()
      # Then let the transform object use the result
      file_transform.operation_performed()
    rescue
      file_transform.clean_up_on_failure()
      return nil
    end
    file_transform
  end

  # Synchronous tranform method - should be done async in request handlers
  def self.transform(stored_file, output_mime_type = nil, output_options = nil)
    file_transform = do_transform(stored_file, output_mime_type, output_options)
    file_transform ? file_transform.result_pathname : nil
  end

  def initialize(stored_file, output_mime_type = nil, output_options = nil)
    @output_mime_type = output_mime_type
    # Info on stored file
    @stored_file_id = stored_file.id # only keep the ID, since completion may happen in different thread
    input_mime_type = KMIMETypes.canonical_base_type(stored_file.mime_type)
    input_disk_pathname = stored_file.disk_pathname
    # Options need to be converted to text for various caching lookups
    if output_options != nil
      @output_options_str = output_options.keys.map {|k| "#{k.to_s}=#{output_options[k].to_s}"}.sort.join(',') # sort after map
    else
      @output_options_str = ''
    end
    # Try to find a cache entry
    cached = FileCacheEntry.for(stored_file, output_mime_type, @output_options_str)
    if cached != nil
      cached.update_usage_info!
      @result_pathname = cached.disk_pathname
      return
    end
    # Only setup a transformer for files which are small enough
    if File.size(input_disk_pathname) <= KFileTransform.max_file_size_for_mime_type(input_mime_type)
      # Might not be able to find a transformer.
      @transformer = KFileTransform.get_transformer(input_mime_type, output_mime_type)
      if @transformer
        @transform_id = KRandom.random_api_key(33) # used for disk filenames to avoid collisions - thread ID not good enough
        @temp_disk_pathname = "#{FILE_UPLOADS_TEMPORARY_DIR}/temptransform_#{Thread.current.object_id}.#{@transform_id}.tmp"
        @operation = @transformer.make_op(self, input_disk_pathname, @temp_disk_pathname, input_mime_type, output_mime_type, output_options)
      end
    end
  end

  attr_reader :output_options_str
  attr_reader :result_pathname
  attr_reader :transform_id
  attr_reader :operation
  attr_reader :stored_file_id
  attr_reader :created_cache_entry

  def can_transform?
    (@transformer != nil)
  end

  def operation_performed
    success = @transformer.complete_op(self, @operation)
    entry = nil
    begin
      raise "KFileTransform conversion failed" unless File.exists?(@temp_disk_pathname) && success
      # Make cache entry
      entry = FileCacheEntry.new(
        :last_access => Time.now,
        :stored_file_id => @stored_file_id,
        :output_mime_type => @output_mime_type || '',
        :output_options => @output_options_str || ''
      )
      entry.save!
      entry_pathname = entry.disk_pathname
      entry.ensure_target_directory_exists
      File.rename(@temp_disk_pathname, entry_pathname)
      @created_cache_entry = entry
      @result_pathname = entry_pathname
    rescue
      entry.destroy if entry
      clean_up_on_failure
      raise
    end
    nil
  end

  def clean_up_on_failure
    File.unlink(@temp_disk_pathname) if File.exists?(@temp_disk_pathname)
    @transformer.clean_up()
    nil
  end

  def is_same_as?(other_transform)
    ((@stored_file_id == other_transform.stored_file_id) && (@output_options_str == other_transform.output_options_str))
  end

  # -----------------------------------------------------------------------------------------------------------------

  def self.get_transformer(input_mime_type, output_mime_type)

    if input_mime_type =~ /\Aimage\// && output_mime_type =~ /\Aimage\//
      TransformImage

    elsif input_mime_type == 'text/html' && output_mime_type == 'text/plain'
      TransformHTMLToText.new

    else
      COMPONENTS.each do |transform_component|
        transformer = transform_component.get_transformer(input_mime_type, output_mime_type)
        return transformer if transformer
      end
      nil
    end
  end

  class TransformImage
    def self.make_op(file_transform, input_disk_pathname, output_disk_pathname, input_mime_type, output_mime_type, output_options)
      raise "Can only resize into another image" unless output_mime_type =~ /\Aimage\/(\w+)/
      transformer = ImageTransform.new(input_disk_pathname, output_disk_pathname, $1)
      # Width, height, quality
      opts = Hash.new
      if output_options.has_key?(:w) && output_options.has_key?(:h)
        transformer.setResize(output_options[:w].to_i, output_options[:h].to_i)
      end
      if output_mime_type =~ /\Aimage\/jpe?g/
        transformer.setQuality((output_options[:q] || 70).to_i)
      end
      transformer
    end
    def self.complete_op(file_transform, op)
      op.getSuccess()
    end
    def self.clean_up
    end
  end

  class TransformHTMLToText
    def initialize
    end
    def make_op(file_transform, input_disk_pathname, output_disk_pathname, input_mime_type, output_mime_type, output_options)
      @output_disk_pathname = output_disk_pathname
      HTMLToText.new(input_disk_pathname, output_disk_pathname)
    end
    def complete_op(file_transform, op)
      File.exist?(@output_disk_pathname)
    end
    def clean_up
    end
  end

  # -----------------------------------------------------------------------------------------------------------------

  def self.set_render_text(stored_file)
    return if stored_file.render_text_chars

    file_transform = do_transform(stored_file, "text/plain")
    return unless file_transform

    result_pathname = file_transform.result_pathname
    if result_pathname && File.size(result_pathname) < MAX_RENDER_TEXT_CONVERTED_FILE_SIZE
      chars = File.open(result_pathname) { |f| f.read.force_encoding(Encoding::UTF_8) }
      chars = chars.slice(0, MAX_RENDER_TEXT_CHARS) if chars.length > MAX_RENDER_TEXT_CHARS
      chars = KTextAnalyser.normalise(chars)
      chars.force_encoding(Encoding::BINARY)

      temp_pathname = "#{FILE_UPLOADS_TEMPORARY_DIR}/temprendertext_#{Thread.current.object_id}.#{file_transform.transform_id}.tmp"
      begin
        File.open(temp_pathname, "wb") do |f|
          f.write Zlib::Deflate.deflate(chars)
        end
        File.rename(temp_pathname, stored_file.disk_pathname_render_text)
        stored_file.render_text_chars = chars.length
        stored_file.save!
      rescue => e
        KApp.logger.error("Exception when attempting to generate and save rendering text for stored file #{stored_file.digest} (id #{stored_file.id})")
        KApp.logger.log_exception(e)
      ensure
        File.unlink(temp_pathname) if File.exist?(temp_pathname)
      end
    end

    # Plain text conversions probably won't be needed again. If a cache entry was created just now, delete it.
    entry = file_transform.created_cache_entry
    entry.destroy() if entry
  end

  # -----------------------------------------------------------------------------------------------------------------

  Dimensions = Struct.new(:width,:height,:units)

  def self.calculate_thumbnail_size(stored_file)
    # Return size in pixels of scaled image
    scale = 0.0
    ow = stored_file.dimensions_w.to_f
    oh = stored_file.dimensions_h.to_f
    if ow > oh
      # scale by width
      scale = THUMBNAIL_MAX_DIMENSION / ow
    else
      # scale by height
      scale = THUMBNAIL_MAX_DIMENSION / oh
    end
    scale = 1.0 if scale > 1.0

    w = (ow * scale).to_i
    h = (oh * scale).to_i
    return nil if w < THUMBNAIL_MIN_DIMENSION || h < THUMBNAIL_MIN_DIMENSION

    [w, h]
  end

  def self.set_image_dimensions_and_make_thumbnail(stored_file)
    mime_type = KMIMETypes.canonical_base_type(stored_file.mime_type)
    disk_pathname = stored_file.disk_pathname
    thumbnail_pathname = stored_file.disk_pathname_thumbnail
    is_iwork_file = IWORK_MIME_TYPES.include?(mime_type)
    thumbfinder_op = nil

    return nil if File.size(disk_pathname) > max_file_size_for_mime_type(mime_type)

    begin
      if mime_type =~ /\Aimage/

        # IMAGE - get the dimensions
        identifier = ImageIdentifier.new(stored_file.disk_pathname)
        identifier.perform()
        if identifier.getSuccess()
          stored_file.set_dimensions(identifier.getWidth(), identifier.getHeight(), 'px')

          w, h = calculate_thumbnail_size(stored_file)
          if w != nil
            output_format = identifier.getFormat()
            unless StoredFile::THUMBNAIL_FORMAT__LOOKUP.has_key?(output_format)
              # Default to PNG
              output_format = 'png'
            end
            transformer = ImageTransform.new(stored_file.disk_pathname, thumbnail_pathname, output_format)
            transformer.setResize(w,h)
            transformer.setQuality(70)
            transformer.perform()
            if transformer.getSuccess() && File.exists?(thumbnail_pathname)
              stored_file.set_thumbnail(w, h, StoredFile::THUMBNAIL_FORMAT__LOOKUP[output_format])
              stored_file.dimensions_pages = 1
            end
          end
        end

      elsif is_iwork_file || mime_type =~ OPENOFFICE_MIME_TYPE_REGEXP
        # Try to extract from iWork / OpenOffice file
        thumbfinder_op = ThumbnailFinder.new(disk_pathname, thumbnail_pathname, "png", THUMBNAIL_MAX_DIMENSION,
            is_iwork_file ? "QuickLook/Thumbnail" : "Thumbnails/thumbnail",
            ThumbnailFinder::EXPECTATION_IMAGE
        )

      elsif MSOFFICE_NEW_MIME_TYPES.include?(mime_type)
        # Try to extract from new MSOffice file
        thumbfinder_op = ThumbnailFinder.new(disk_pathname, thumbnail_pathname, "png", THUMBNAIL_MAX_DIMENSION,
            "docProps/thumbnail",
            ThumbnailFinder::EXPECTATION_WMF
        )

      elsif MSOFFICE_OLD_MIME_TYPES.include?(mime_type)
        # Try to extract from old MSOffice file
        thumbfinder_op = ThumbnailFinder.new(disk_pathname, thumbnail_pathname, "png", THUMBNAIL_MAX_DIMENSION,
            "OLD-MSOFFICE",
            ThumbnailFinder::EXPECTATION_WMF
        )

      end

      # Pick up from any of the java conversions
      if thumbfinder_op != nil
        thumbfinder_op.perform()
        if thumbfinder_op.hasMadeThumbnail() && File.exists?(thumbnail_pathname)
          thumb_info = thumbfinder_op.getThumbnailDimensions()
          stored_file.set_thumbnail(thumb_info.width, thumb_info.height, StoredFile::THUMBNAIL_FORMAT_PNG)
        end
      end

      # Try optional components
      if stored_file.thumbnail == nil
        COMPONENTS.each do |transform_component|
          break if transform_component.set_image_dimensions_and_make_thumbnail(mime_type, stored_file, disk_pathname, thumbnail_pathname)
        end
      end

    rescue => e
      # Ignore errors
      KApp.logger.log_exception(e)
    end

    # Set permissions on any file which was created so the backup user can read it
    File.chmod(0640, thumbnail_pathname) if File.exists?(thumbnail_pathname)

    stored_file.save! if stored_file.changed?
  end

  # -----------------------------------------------------------------------------------------------------------------

  def self.transform_to_thumbnail(file_identifier)
    info = get_thumbnail_info(file_identifier)
    return nil if info == nil
    output_file = transform(file_identifier, info.mime_type, {:w => info.width, :h => info.height})
    if output_file != nil
      [output_file, info.mime_type]
    else
      nil
    end
  end

  # -----------------------------------------------------------------------------------------------------------------

  def self.output_mime_type_if_thumbnailable(mime_type)
    return 'image/png' if mime_type == 'application/pdf'  # turn PDFs into PNGs
    return mime_type.dup if mime_type =~ /\Aimage\/(gif|jpeg|png|bmp|tiff)\z/      # same format for other images
    nil
  end

  # -----------------------------------------------------------------------------------------------------------------

  # Given the dimensions for a file and a 'size' specifier, return some new dimensions
  def self.transform_dimensions_for_size(dims, size)
    # Check there's a width
    return nil unless SIZE_TO_WIDTH.has_key?(size)
    width = SIZE_TO_WIDTH[size]
    # Don't make it bigger
    return dims.dup if width > dims.width || dims.width == 0  # avoid /by0
    # Calculate a nice height
    height = ((width.to_f / dims.width.to_f) * dims.height.to_f).to_i
    height = 1 if height < 1
    Dimensions.new(width,height,:px)
  end

  # -----------------------------------------------------------------------------------------------------------------

  class TransformComponent
    def get_transformer(input_mime_type, output_mime_type)
      nil
    end
    def set_image_dimensions_and_make_thumbnail(mime_type, stored_file, disk_pathname, thumbnail_pathname)
      false
    end
  end

end
