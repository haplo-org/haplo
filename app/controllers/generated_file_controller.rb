# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class GeneratedFileController < ApplicationController
  policies_required nil

  GENERATION_DOWNLOAD_MAX_WAIT_TIME = 90000 # 1.5 minutes
  FILE_MAX_AGE = 600 # 10 minutes

  # -------------------------------------------------------------------------

  Util = Java::OrgHaploApp::GeneratedFileController

  # -------------------------------------------------------------------------

  # Files are stored in temp directory, name includes the app ID and a random identifier

  def self.pathname_for_identifier(identifier, kind)
    # Identifiers are generated one the JS side, and are therefore not trusted
    raise "Bad identifier" unless identifier =~ /\A[a-zA-Z0-9_-]{32,}\z/
    "#{GENERATED_FILE_DOWNLOADS_TEMPORARY_DIR}/#{KApp.current_application}.#{identifier}.#{kind}"
  end

  def self.clean_up_downloads
    oldest = Time.now - FILE_MAX_AGE
    Dir.glob("#{GENERATED_FILE_DOWNLOADS_TEMPORARY_DIR}/*.info").each do |info_file|
      if File.mtime(info_file) < oldest
        Dir.glob(info_file.gsub(/\.info\z/,'.*')).each do |to_delete|
          File.unlink(to_delete)
        end
      end
    end
  end

  KFramework.scheduled_task_register(
    "generated_cleanup", "Clean up generated emails",
    0, 0, FILE_MAX_AGE,
    proc do
      GeneratedFileController.clean_up_downloads
      GeneratedFileController.clean_up_continuations
    end
  )

  # -------------------------------------------------------------------------

  # Continuations stored
  SUSPENDED_CONTINUATIONS = Hash.new { |h,k| h[k] = Hash.new { |h,k| h[k] = [] }}
  SUSPENDED_CONTINUATIONS_LOCK = Mutex.new
  def self.clean_up_continuations
    SUSPENDED_CONTINUATIONS_LOCK.synchronize do
      SUSPENDED_CONTINUATIONS.each do |app_id, continuations|
        continuations.delete_if do |identifier, list|
          # If none of the continuations are suspended, there's nothing to resume
          nil == list.find { |c| c.isSuspended() }
        end
      end
    end
  end

  def self.resume_suspended_requests_for_identifier(identifier)
    SUSPENDED_CONTINUATIONS_LOCK.synchronize do
      continuations = SUSPENDED_CONTINUATIONS[KApp.current_application].delete(identifier)
      if continuations
        continuations.each { |c| Util.safelyResumeContinuation(c) }
      end
    end
  end

  # -------------------------------------------------------------------------

  # Handle notifications from the pipeline object

  KNotificationCentre.when(:jsfiletransformpipeline, :prepare) do |name, detail, identifier, prepare|
    details = {
      "identifier" => identifier,
      "filename" => prepare.filename,
      "application" => KApp.current_application,
      "redirectTo" => prepare.redirect_to, # untrusted
      "view" => prepare.plugin_view # untrusted
    }
    json = JSON.generate(details)
    File.open(self.pathname_for_identifier(identifier, :info), "w") { |f| f.write json }
  end

  KNotificationCentre.when(:jsfiletransformpipeline, :ready) do |name, detail, identifier, disk_pathname, mime_type|
    # Add MIME type to info file (if it's for a generated file)
    info_pathname = self.pathname_for_identifier(identifier, :info)
    info_pathname_new = "#{info_pathname}.t"
    info = JSON.parse(File.open(info_pathname) { |f| f.read })
    info['ready'] = true
    info['mimeType'] = mime_type if mime_type
    File.open(info_pathname_new, "w") { |f| f.write JSON.generate(info) }
    File.rename(info_pathname_new, info_pathname)
    # Make a hardlink to the file, as it's probably temporary
    if disk_pathname
      download_pathname = self.pathname_for_identifier(identifier, :file)
      File.link(disk_pathname, download_pathname)
    end
    # Resume any requests which were suspended to wait for the file
    self.resume_suspended_requests_for_identifier(identifier)
  end

  KNotificationCentre.when(:jsfiletransformpipeline, :failure) do |name, detail, identifier|
    [:info, :file].each do |kind|
      temp_file = self.pathname_for_identifier(identifier, kind)
      File.unlink(temp_file) if File.exist?(temp_file)
    end
    self.resume_suspended_requests_for_identifier(identifier)
  end

  # -------------------------------------------------------------------------

  def handle_file
    identifier = params[:id]
    info_pathname = GeneratedFileController.pathname_for_identifier(identifier, :info)
    file_pathname = GeneratedFileController.pathname_for_identifier(identifier, :file)

    unless File.exist?(info_pathname)
      return render :text => 'Not found', :status => 404
    end

    unless File.exist?(file_pathname)
      # Not available yet, suspend the request for later
      continuation = request.continuation
      continuation.setTimeout(GENERATION_DOWNLOAD_MAX_WAIT_TIME)
      continuation.suspend()
      # Store the continuation
      SUSPENDED_CONTINUATIONS_LOCK.synchronize do
        SUSPENDED_CONTINUATIONS[KApp.current_application][identifier].push(continuation)
      end
      KApp.logger.info("Suspending request to wait for generated file")
      # While the request was being suspended, the file might have appeared. Check again
      Util.safelyResumeContinuation(continuation) if File.exist?(file_pathname)
      # But even if it was resumed, request handling stops now
      return render_continuation_suspended
    end

    # File exists for download, return it - will be cleaned up later
    info = JSON.parse(File.open(info_pathname) { |f| f.read })
    render_send_file file_pathname,
      :type => info['mimeType'],
      :filename => KMIMETypes.correct_filename_extension(info['mimeType'], info['filename']),
      :disposition => 'attachment'
  end

  # -------------------------------------------------------------------------

  # When using waiting views, allow selection of minimal layout
  def render_layout
    if @info && @info['view'] && @info['view']['layout'] === 'std:minimal'
      'minimal'
    else
      super
    end
  end

  def setup_for_waiting_view
    identifier = params[:id]
    info_pathname = GeneratedFileController.pathname_for_identifier(identifier, :info)
    return unless File.exist?(info_pathname)
    @info = JSON.parse(File.open(info_pathname) { |f| f.read })
  end

  def handle_download
    setup_for_waiting_view
  end
  def handle_wait
    setup_for_waiting_view
  end

  # -------------------------------------------------------------------------

  def handle_availability_api
    identifier = params[:id]
    info_pathname = GeneratedFileController.pathname_for_identifier(identifier, :info)
    file_pathname = GeneratedFileController.pathname_for_identifier(identifier, :file)
    result = {}
    unless File.exists?(info_pathname)
      result['status'] = 'unknown'
    else
      info = JSON.parse(File.open(info_pathname) { |f| f.read })
      if info['ready'] && (info['redirectTo'] || File.exists?(file_pathname))
        result['status'] = 'available'
        if info['redirectTo']
          result['redirectTo'] = info['redirectTo']
        else
          result['url'] = "/do/generated/file/#{params[:id]}/#{info['filename']}"
        end
        result['mimeType'] = info['mimeType']
      else
        # Not available yet, suspend, if it's the first time
        continuation = request.continuation
        if continuation.isInitial()
          timeout = (params[:timeout] || 0).to_i
          if timeout < 1 || timeout > GENERATION_DOWNLOAD_MAX_WAIT_TIME
            timeout = GENERATION_DOWNLOAD_MAX_WAIT_TIME
          end
          continuation.setTimeout(timeout)
          continuation.suspend()
          SUSPENDED_CONTINUATIONS_LOCK.synchronize do
            SUSPENDED_CONTINUATIONS[KApp.current_application][identifier].push(continuation)
          end
          Util.safelyResumeContinuation(continuation) if File.exist?(file_pathname)
          return render_continuation_suspended
        end
        result['status'] = 'working'
      end
    end
    render :text => JSON.generate(result), :kind => :json
  end

end
