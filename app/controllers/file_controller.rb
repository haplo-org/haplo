# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Implements URLs of the form
#   /file/<StoredFile#digest>/<StoredFile#size>/[spec/]filename.ext
# where spec is 'directories' formed of
#   ext - output format, as file extension (see KMIMETypes::MIME_TYPE_FROM_EXTENSION), eg 'jpeg'
#   s, m, l - standard sizes, specified by width
#   w<dimension> - width in pixels
#   h<dimension> - height in pixels
#   q<quality> - JPEG quality
#   p<number> - Page number
# Image size can only be specified once. (eg s/w100 is not allowed)
# If only one of w or h is specified, it is calculated to keep the image proportion constant.

class FileController < ApplicationController
  include KConstants
  include KFileUrls


  MAX_DIMENSION = 4096    # don't allow images over that size

  MIME_TYPES_WHICH_MUST_NOT_BE_DISPLAYED_INLINE = ['text/html','application/x-ms-web-archive']

  def url_decode_for_handle(exchange, path_elements)
    if exchange.annotations[:file_request]
      # It's a /file request
      'file'
    elsif exchange.annotations[:thumbnail_request]
      # Request a thumbnail
      'thumbnail'
    else
      super
    end
  end

  # -------------------------------------------------------------------------------------------------------------------

  _PoliciesRequired nil
  def handle_thumbnail
    request_path = exchange.annotations[:request_path]
    if 2 == request_path.length
      fvid = $1.to_i
      stored_file = StoredFile.find_by_digest_and_size(request_path[0], request_path[1])
      if stored_file && stored_file.thumbnail_format != nil
        # Security and client side caching
        security_checks_for stored_file
        return if file_is_up_to_date_in_client_cache
        # Set validity time and ETag
        set_response_validity_time(345600)  # 4 days
        response.headers['Etag'] = "#{stored_file.digest}_thumbnail"
        # Send file
        render_send_file stored_file.disk_pathname_thumbnail, :type => stored_file.thumbnail_mime_type
        return
      end
    end
    render(:action => 'not_found', :status => 404)
  end

  # -------------------------------------------------------------------------------------------------------------------

  _PoliciesRequired nil
  def handle_file
    # Decode the rest of the URL
    filespec = exchange.annotations[:request_path].dup
    if filespec.length < 2
      render :text => 'Bad file request', :kind => :text, :status => 404
      return
    end
    stored_file_digest = filespec.shift
    stored_file_size = filespec.shift.to_i
    # Remove the filename from the file spec. Used for:
    #   Choosing *which* filename to download it as, as long as it's verified by the objects in the store or a URL signature
    #   Extracting from zip files
    # FILE TODO: Tests for filename name verification, including % encoding
    if filespec.length > 0
      @requested_filename = URI.unescape(filespec.pop)
    else
      # 404 if a 'directory' was requested
      if request.path =~ /\/\z/
        raise KFramework::RequestPathNotFound.new("Bad file URL")
      end
      # Otherwise set empty filename and let it be filled in later
      @requested_filename = ''
    end

    stored_file = StoredFile.find_by_digest_and_size(stored_file_digest, stored_file_size)

    security_checks_for stored_file
    return if file_is_up_to_date_in_client_cache

    # Check underlying file exists to prevent reportable exceptions when applications are copied without files
    unless File.exist?(stored_file.disk_pathname)
      render(:action => 'not_in_store', :status => 404, :layout => false)
      return
    end

    what = :not_found
    data = nil
    mime_type = nil
    spec_error = false
    as_attachment = false
    etag_extra = nil
    # Zip file handling
    zipped = false
    zipped_default_filename = nil;
    zipped_dir_name = nil;

    as_attachment = true if params.has_key?(:attachment)

    call_hook(:hPreFileDownload) do |hooks|
      h = hooks.run(stored_file, filespec.join('/'))
      # Plugins can redirect away from file download
      if h.redirectPath
        redirect_to h.redirectPath
        return
      end
    end

    # Audit the requested download
    KNotificationCentre.notify(:file_controller, :download, stored_file, filespec)

    # Remove any 'preview' flags from the spec, as they're only used to flag to plugins and the audit,
    # but mustn't be included in the transform in the cache.
    filespec.delete('preview')

    # Go through options, setting up suitable parameters for a transform
    unless filespec.empty?
      output_format = nil
      width = nil
      height = nil
      quality = nil
      page_number = nil
      filespec.each do |spec|
        if KFileTransform::SIZE_TO_WIDTH.has_key?(spec)
          # Special size
          spec_error = true if width != nil || height != nil
          width = KFileTransform::SIZE_TO_WIDTH[spec]
          height = nil
        elsif spec =~ /\A([whqp])(\d+)\z/
          # Options with numeric parameters
          num = $2.to_i
          case $1
          when 'w' then spec_error = true if width != nil;    width = num
          when 'h' then spec_error = true if height != nil;   height = num
          when 'q' then spec_error = true if quality != nil;  quality = num
          when 'p' then spec_error = true if page_number != nil; page_number = num
          end
        elsif spec == 'html'
          # HTML is handled specially, because it needs processing and extraction from zip files
          output_format = KFileTransform::MIME_TYPE_HTML_IN_ZIP
          zipped = true
          zipped_default_filename = 'doc/index.html'
          zipped_dir_name = 'doc'
        elsif spec == 'text'
          output_format = 'text/plain'
        elsif spec == 'pdfview'
          return special_pdf_preview_handling(stored_file) # and return to stop all other handling
        elsif spec.length >= 3 && KMIMETypes::MIME_TYPE_FROM_EXTENSION.has_key?(spec)
          # Output format - CHECK THIS LAST!!!
          spec_error = true if output_format != nil # only specify once!
          output_format = KMIMETypes::MIME_TYPE_FROM_EXTENSION[spec]
        else
          spec_error = true
        end
      end
      # Adjust width/height to maintain proportions
      if !spec_error && (width != nil || height != nil)
        # Get dimensions
        dims = stored_file.dimensions
        if dims == nil || dims.width == 0 || dims.height == 0 # avoid divide by 0 later
          spec_error = true
        else
          # Clamp dimensions to given file
          width = dims.width if width != nil && width > dims.width
          height = dims.height if height != nil && height > dims.height
          # Adjust
          if width != nil && height == nil
            height = ((width.to_f / dims.width.to_f) * dims.height.to_f).to_i
          elsif width == nil && height != nil
            width = ((height.to_f / dims.height.to_f) * dims.width.to_f).to_i
          end
          # Don't resize if size is unchanged for an image
          if width == dims.width && height == dims.height && stored_file.mime_type =~ /\Aimage\//
            width = nil
            height = nil
          end
        end
      end
      # Few more checks
      width = 1 if width != nil && width < 1
      height = 1 if height != nil && height < 1
      # Transform?
      unless spec_error
        if width == nil && ((output_format == nil) || (output_format == stored_file.mime_type))
          # No transform
          what = :file
          data = stored_file.disk_pathname
          mime_type = stored_file.mime_type
        else
          # Transform
          # Protect against unnnecessarily large images being generated
          width = MAX_DIMENSION if width != nil && width > MAX_DIMENSION
          height = MAX_DIMENSION if height != nil && height > MAX_DIMENSION
          # Default to same output format as input format
          output_format ||= stored_file.mime_type
          # Setup options
          options = Hash.new
          options[:w] = width if width != nil
          options[:h] = height if height != nil
          options[:q] = quality if quality != nil
          page_number = nil if page_number == 1   # default number, avoids two cache entries
          options[:page] = page_number if page_number != nil
          # Do transform
          data = do_file_transform_request(stored_file, output_format, options)
          if data == :stop
            return  # an error has been handled, or the request has been suspended
          elsif data != nil
            # Setup parameters for download
            what = :file
            mime_type = output_format
          end
        end
      end
    else
      # Normal download
      what = :file
      data = stored_file.disk_pathname
      mime_type = stored_file.mime_type
    end

    # Zip file handling
    if what == :file && zipped
      results = Java::ComOneisApp::FileController.zipFileExtraction(
          data, zipped_default_filename, "#{zipped_dir_name}/#{@requested_filename}"
        )
      if results == nil
        what = :not_found
      else
        what = :data
        # Use the extension of the file we're sending to determine the mime type in the response
        data = String.from_java_bytes(results.data)
        if results.chosenFile =~ /\.([a-zA-Z0-9]+)\z/
          mime_type = KMIMETypes.type_from_extension($1)
        else
          mime_type = nil
        end
        # Need to add in a bit to the etag to distinguish files
        etag_extra = "_#{results.etagSuggestion.to_s(36)}"
      end
    end

    if spec_error
      render(:action => 'bad_request', :layout => false, :status => 400)
      return
    end

    if what == :not_found
      render(:action => 'not_found', :status => 404)
      return
    end

    # Just in case there wasn't a mime type set
    mime_type ||= 'application/octet-stream'

    # Work around for IE/Office problem
    # http://blogs.msdn.com/vsofficedeveloper/pages/Office-Existence-Discovery-Protocol.aspx
    if KMIMETypes.is_msoffice_type?(mime_type) && request.user_agent =~ /MSIE/
      as_attachment = true
    end

    # === SECURITY ===
    # If the file came from the user and hasn't been processed, check we don't need to be paranoid
    # Raw HTML from untrusted sources could do all sorts of bad things in the context of the application.
    # This isn't a foolproof measure, but is a useful first step.
    if filespec.empty? && MIME_TYPES_WHICH_MUST_NOT_BE_DISPLAYED_INLINE.include?(mime_type)
      as_attachment = true
    end
    # Set a CSP to make sure no scripts can be executed
    set_content_security_policy '$NO-SCRIPT'

    # === AUDIO AND VIDEO ===
    # Make sure that downloads of audio and video files are always attachments. Browsers have interesting
    # behaviour when they receive a file, so ensure they're downloaded.
    if mime_type =~ /\A(audio|video)\//i
      as_attachment = true
    end

    # Set caching headers
    set_response_validity_time(345600)  # 4 days
    etag = stored_file.digest
    unless filespec.empty?
      etag += '_'+(filespec.join('_').gsub(/[^a-zA-Z0-9]/,'__'))
    end
    etag += etag_extra if etag_extra != nil
    response.headers['Etag'] = etag

    case what
    when :file
      render_send_file data, :type => mime_type,
        :filename => (@verified_download_filename || stored_file.upload_filename),
        :disposition => (as_attachment ? 'attachment' : 'inline')
    when :data
      render :text => data, :content_type => mime_type
    else
      raise "Bad handling in FileController"
    end
  end

private

  # Called to generate the HTML preview for a file
  def special_pdf_preview_handling(stored_file)
    # Special handling of PDF previews
    @pages = stored_file.dimensions_pages || 1
    @current_page = params[:page].to_i  # might not be present, so nil -> 0
    @current_page = 1 if @current_page < 1
    @current_page = @pages if @current_page > @pages
    @stored_file = stored_file
    render :layout => false, :action => 'preview_pdf'
    return nil
  end

public

  # ==========================================================================================================
  #   On-demand file transformation logic
  # ==========================================================================================================

  # How long to wait for a file transform to complete
  TRANSFORM_MAX_WAIT_TIME = 90000 # 1.5 minutes

  MultiRequestOperationTarget = Java::ComOneisApp::MultiRequestOperationTarget

  class InProgressTransforms
    def initialize
      @mutex = Mutex.new
      @trackers = Hash.new
    end
    attr_reader :mutex
    attr_reader :trackers
  end

  class InProgressTransformTracker
    def initialize(file_transform)
      @file_transform = file_transform
      @target = MultiRequestOperationTarget.new
      @finished = false
      @tracked_requests = 0
      @result = nil
    end
    attr_reader :file_transform
    attr_reader :target
    attr_reader :tracked_requests
    attr_reader :result
    def matches?(other_file_transform)
      (@file_transform != nil) && (@file_transform.is_same_as?(other_file_transform))
    end
    def add_continuation(continuation)
      raise "Too many requests waiting on a transform" if @target.numberOfContinuations() > 64
      # Returns false if the operation has completed
      @target.addContinuation(continuation)
    end
    def do_completion_tasks_if_complete
      if @result == nil && @target.isComplete()
        unless @finished
          KApp.logger.info("Doing completion tasks for transform #{@file_transform.transform_id}")
          exception = nil
          begin
            @file_transform.operation_performed()
            exception = @target.getException()
            unless exception
              @result = @file_transform.result_pathname
            end
          rescue => e
            @file_transform.clean_up_on_failure()
            exception = e
          end
          @finished = true
          if exception
            KApp.logger.error("Couldn't transform file with error #{exception}")
            KApp.logger.log_exception(exception)
            @result = :error
          end
          raise "Logic error, @result should be set" if @result == nil
          # Might hang around for a while, so discard potentially big objects
          @target = nil
          @file_transform = nil
        end
      end
    end
    def inc_tracked_count
      @tracked_requests += 1
    end
    def dec_tracked_count
      @tracked_requests -= 1
    end
    def tracking_no_longer_needed?
      (@tracked_requests == 0) && (@result != nil)
    end
  end

  # Use the cache system to have a per-application object for storing transforms in progress
  IN_PROGRESS_CACHE = KApp.cache_register(InProgressTransforms, "File transforms", :shared)
  TRANSFORM_CONTINUATION_ATTRIBUTE = "com.oneis.app.filecontroller.transform".to_java_string

  # This complicated way of handling file transformations does two things:
  #   1) Suspends the request while the file is being processed, as only a few request can
  #      be processed at once per application, to avoid them hogging resources.
  #   2) If there are multiple requests for the same file which isn't in the cache, only do
  #      the transformation once.
  # While there's quite a lot of stuff going on inside the synchronized block, this ensures
  # that there are no race conditions. The lock is per-application, so only affects one
  # client.
  def do_file_transform_request(stored_file, output_format, options)
    continuation = request.continuation
    logger = KApp.logger
    result = nil
    # Use a per-application mutex to avoid race conditions
    in_progress = KApp.cache(IN_PROGRESS_CACHE)
    in_progress.mutex.synchronize do
      raise "Too many outstanding file transform trackers" if in_progress.trackers.length > 64
      tracker = nil
      file_transform = nil
      unless continuation.isInitial()
        tid = continuation.getAttribute(TRANSFORM_CONTINUATION_ATTRIBUTE)
        logger.info("Attempt to resume for transform #{tid}")
        tracker = in_progress.trackers[tid]
        raise "No transform tracker" unless tracker
        file_transform = tracker.file_transform
      else
        # Create a transform object which may be used, or discarded for one which is in progress
        file_transform = KFileTransform.new(stored_file, output_format, options)
        # If the result was in the cache, return it now
        result_pathname = file_transform.result_pathname
        if result_pathname
          logger.info("Requested transformed file was found in cache")
          return result_pathname
        end
        # Check it's possible
        unless file_transform.can_transform?
          logger.info("File transform requested has no supported transformation available")
          render :action => 'bad_request', :layout => false, :status => 400
          return :stop
        end
        # Not cached, so search to see if it's in progress
        tracker = in_progress.trackers.values.find { |t| t.matches?(file_transform) }
        if tracker
          logger.info("File transform has already been requested and is in progress")
          file_transform = tracker.file_transform
        else
          # Not in progress - create tracker and start the operation
          logger.info("Starting new file transform")
          tracker = InProgressTransformTracker.new(file_transform)
          in_progress.trackers[file_transform.transform_id] = tracker
          file_transform.operation.performInBackground(tracker.target)
        end
        tracker.inc_tracked_count
        # Suspend this request
        logger.info("Suspending request for transform #{file_transform.transform_id}")
        continuation.setTimeout(TRANSFORM_MAX_WAIT_TIME)
        continuation.setAttribute(TRANSFORM_CONTINUATION_ATTRIBUTE, file_transform.transform_id)
        continuation.suspend()
        unless tracker.add_continuation(continuation)
          logger.info("When suspending, found transform operation had already completed")
          # Operation has already completed!
          use_result_of_transform = true
          continuation.complete();
        else
          # Suspend the request
          render_continuation_suspended
          return :stop
        end
      end
      # Will get here if:
      #  - Operation has finished correctly
      #  - Operation timed out (and not finished)
      #  - Operation threw an exception
      #  - Operation was started (or this was set to wait on existing op), but finished so no suspend is needed
      #  - Suspend timed out, and the operation hasn't finished

      # Go through *all* the trackers and process results - gets them into the database ASAP and uses
      # results from any transforms where all the requests timed out.
      in_progress.trackers.each do |tid,trk|
        trk.do_completion_tasks_if_complete
      end
      # Not interested in this tracker any more
      tracker.dec_tracked_count
      # Discard *all* finished trackers - might be delayed cleanup from a previous go if everything timed out
      # TODO: Background clean up of expired trackers (eg if all requests time out, leaving it dangling)
      in_progress.trackers.delete_if do |tid,trk|
        if trk.tracking_no_longer_needed?
          logger.info("Retiring transform tracker for transform #{tid}")
          true
        else
          false
        end
      end
      # Get the result!
      result = tracker.result
      case result
      when nil;     logger.info("Transform operation hasn't completed yet")
      when :error;  logger.info("An error occurred during the transform operation")
      else          logger.info("Transform operation completed")
      end
    end
    if result == :error || result == nil
      render :action => 'bad_request', :layout => false, :status => 400
      :stop
    else
      result # filename
    end
  end

  # ==========================================================================================================
  #   XML API access
  # ==========================================================================================================

  _PostOnly
  _PoliciesRequired nil # NOTE: requirement to have :not_anonymous tested below
  def handle_upload_new_file_api
    # Can only be used by an API key. While this isn't going to help right now, it's a useful restriction
    # in case uploads are ever tightened up.
    unless @request_user.policy.is_not_anonymous? && @request_uses_api_key
      response.headers['X-ONEIS-Reportable-Error'] = 'yes'
      render :text => 'Must be authenticated with an API key', :status => 403
      return
    end

    uploads = exchange.annotations[:uploads]
    unless request.post? && uploads != nil
      render :text => 'Upload required', :status => 400
      return
    end

    if uploads.getInstructionsRequired()
      # Use the URL to determine whether or not this is compressed
      inflate_file = (params[:id] == 'with_deflate') || (params[:id] == 'with-deflate')
      uploads.addFileInstruction('file', FILE_UPLOADS_TEMPORARY_DIR, StoredFile::FILE_DIGEST_ALGORITHM, inflate_file ? 'inflate' : nil)
      render :text => ''
      return
    end

    # TODO: Refactor to use XML API functions in object_controller?
    builder = Builder::XmlMarkup.new
    builder.instruct!
    error_message = nil
    # Check basics
    if !(@request_user.permissions.something_allowed?(:create) || @request_user.permissions.something_allowed?(:update))
      # Return error
      error_message = 'No permission'
    elsif KProduct.limit_storage_exceeded?
      error_message = 'Storage limit exceeded'
    elsif ! request.post?
      error_message = 'Must POST file'
    else
      # Handle the uploaded file
      upload = uploads.getFile('file')
      opts = Hash.new
      opts[:expected_hash] = params[:digest] if params.has_key?(:digest)
      opts[:expected_size] = params[:file_size].to_i if params.has_key?(:file_size)
      file = StoredFile.from_upload(upload, opts)
      if file == nil
        error_message = 'Bad upload'
      else
        builder.response(:status => 'success') do |r|
          KIdentifierFile.new(file).build_xml(r)
        end
      end
    end
    if error_message != nil
      builder.response(:status => 'error') do |r|
        r.message error_message
      end
    end
    render :text => builder.target!, :kind => :xml
  end

  # -------------------------------------------------------------------------------------------------------------------

private
  def security_checks_for(stored_file)
    permitted = false
    # Check the request for a session-specific signature which authenticates the user
    # Do this *first*, so that requests which override the filename don't rewrite that filename
    unless permitted
      signature = params[:s]
      if signature
        permitted = true if file_request_check_signature(signature, request.path, session)
        @is_signed_file_url = true
        # Permit the filename because it's been signed?
        if @requested_filename
          @verified_download_filename = @requested_filename
        end
      end
    end
    # If the user has read permission on at least one object which has a file identifer value referring to this file,
    # they are permitted to read this file.
    unless permitted
      query = KObjectStore.query_and.identifier(KIdentifierFile.new(stored_file))
      query.add_exclude_labels([KConstants::O_LABEL_STRUCTURE])
      objects = query.execute(:all, :date_asc)
      if objects.length > 0
        permitted = true
        # Check to see if the filename is in one of the file values in these objects
        if @requested_filename
          objects.each do |obj|
            obj.each do |v,d,q|
              if v.kind_of? KIdentifierFile
                if (v.digest == stored_file.digest) && (v.size == stored_file.size) && (v.presentation_filename == @requested_filename)
                  # File identifier contains this filename, so it can be used for the download
                  @verified_download_filename = @requested_filename
                  break
                end
              end
            end
          end
        end
      end
    end
    # Bail out if not permitted
    permission_denied unless permitted
    true
  end

  def file_is_up_to_date_in_client_cache
    h = request.headers
    if h.has_header?(KFramework::Headers::IF_NONE_MATCH) || h.has_header?(KFramework::Headers::IF_MODIFIED_SINCE)
      # Don't need to send the file
      render :text => '', :status => 304  # not modified
      true
    else
      # Need to send that file!
      false
    end
  end
end
